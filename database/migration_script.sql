-- Script de migración desde schema.sql a schema_optimized.sql
-- PostgreSQL Migration Script
-- Ejecutar con precaución - Hacer backup antes de ejecutar

BEGIN;

-- 1. Crear extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. Crear tipos enumerados
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol_enum') THEN
        CREATE TYPE rol_enum AS ENUM ('Administrador', 'AdministradorDocumentos', 'Usuario', 'Supervisor');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_documento_enum') THEN
        CREATE TYPE estado_documento_enum AS ENUM ('Activo', 'Inactivo', 'Archivado', 'Eliminado');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_movimiento_enum') THEN
        CREATE TYPE tipo_movimiento_enum AS ENUM ('Prestamo', 'Devolucion', 'Transferencia', 'Archivo', 'Eliminacion');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_movimiento_enum') THEN
        CREATE TYPE estado_movimiento_enum AS ENUM ('Activo', 'Completado', 'Cancelado');
    END IF;
END $$;

-- 3. Agregar nuevas columnas a tablas existentes

-- Tabla areas
ALTER TABLE areas ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS creado_por INTEGER REFERENCES usuarios(id);
ALTER TABLE areas ALTER COLUMN codigo SET NOT NULL;
ALTER TABLE areas ADD CONSTRAINT areas_codigo_unique UNIQUE (codigo);

-- Tabla tipos_documento
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS creado_por INTEGER REFERENCES usuarios(id);
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS requiere_aprobacion BOOLEAN DEFAULT FALSE;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS plazo_retencion_dias INTEGER DEFAULT 365;
ALTER TABLE tipos_documento ALTER COLUMN codigo SET NOT NULL;
ALTER TABLE tipos_documento ADD CONSTRAINT tipos_documento_codigo_unique UNIQUE (codigo);

-- Tabla usuarios
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMP WITH TIME ZONE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS intentos_fallidos INTEGER DEFAULT 0;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMP WITH TIME ZONE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS rol rol_enum DEFAULT 'Usuario';

-- Migrar roles existentes
UPDATE usuarios SET rol = 'Administrador' WHERE rol = 'Administrador';
UPDATE usuarios SET rol = 'AdministradorDocumentos' WHERE rol = 'AdministradorDocumentos';
UPDATE usuarios SET rol = 'Usuario' WHERE rol = 'Usuario';

-- Agregar constraint de email válido
ALTER TABLE usuarios ADD CONSTRAINT email_valido CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Tabla documentos
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS area_actual_id INTEGER REFERENCES areas(id);
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS nivel_confidencialidad INTEGER DEFAULT 1;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS fecha_vencimiento DATE;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS estado estado_documento_enum DEFAULT 'Activo';

-- Migrar estado existente
UPDATE documentos SET estado = 'Activo' WHERE estado::text = 'Activo';
UPDATE documentos SET estado = 'Inactivo' WHERE estado::text != 'Activo';

-- Establecer area_actual_id igual a area_origen_id si es NULL
UPDATE documentos SET area_actual_id = area_origen_id WHERE area_actual_id IS NULL;

-- Agregar constraints
ALTER TABLE documentos ADD CONSTRAINT gestion_formato CHECK (gestion ~* '^[0-9]{4}$');
ALTER TABLE documentos DROP CONSTRAINT IF EXISTS codigo_formato;
ALTER TABLE documentos ADD CONSTRAINT codigo_formato CHECK (codigo ~* '^[A-Z0-9]{2,10}-[A-Z0-9]{2,10}-[0-9]{4}-[0-9]{4,6}$');
ALTER TABLE documentos ADD CONSTRAINT nivel_confidencialidad_rango CHECK (nivel_confidencialidad BETWEEN 1 AND 5);
-- Ampliar almacenamiento QR a texto
ALTER TABLE documentos ALTER COLUMN codigo_qr TYPE text;

-- Tabla movimientos
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS usuario_autoriza_id INTEGER REFERENCES usuarios(id);
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS plazo_dias INTEGER DEFAULT 7;
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS tipo_movimiento tipo_movimiento_enum;
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS estado estado_movimiento_enum DEFAULT 'Activo';

-- Migrar tipo_movimiento existente
UPDATE movimientos SET tipo_movimiento = 'Prestamo' WHERE tipo_movimiento::text = 'Prestamo';
UPDATE movimientos SET tipo_movimiento = 'Devolucion' WHERE tipo_movimiento::text = 'Devolucion';
UPDATE movimientos SET tipo_movimiento = 'Transferencia' WHERE tipo_movimiento::text NOT IN ('Prestamo', 'Devolucion');

-- Migrar estado existente
UPDATE movimientos SET estado = 'Activo' WHERE estado::text = 'Activo';
UPDATE movimientos SET estado = 'Completado' WHERE estado::text != 'Activo';

-- Tabla anexos
ALTER TABLE anexos ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE anexos ADD COLUMN IF NOT EXISTS hash_archivo VARCHAR(64);
ALTER TABLE anexos ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;
ALTER TABLE anexos ALTER COLUMN tamano TYPE BIGINT USING tamano::BIGINT;
ALTER TABLE anexos RENAME COLUMN tamano TO tamano_bytes;
ALTER TABLE anexos ADD CONSTRAINT tamano_positivo CHECK (tamano_bytes > 0);

-- Tabla historial_documento
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS tipo_cambio VARCHAR(50);
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS campo_modificado VARCHAR(100);
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS valor_anterior TEXT;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS valor_nuevo TEXT;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS estado_anterior estado_documento_enum;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS estado_nuevo estado_documento_enum;

-- Tabla auditoria
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS sesion_id VARCHAR(255);
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS registro_uuid UUID;
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE auditoria ALTER COLUMN ip_address TYPE INET USING ip_address::INET;
ALTER TABLE auditoria ALTER COLUMN detalle TYPE JSONB USING detalle::JSONB;

-- 4. Crear nuevas tablas

-- Tabla configuracion
CREATE TABLE IF NOT EXISTS configuracion (
    id SERIAL PRIMARY KEY,
    clave VARCHAR(100) UNIQUE NOT NULL,
    valor TEXT,
    descripcion TEXT,
    tipo_dato VARCHAR(20) DEFAULT 'string',
    editable BOOLEAN DEFAULT TRUE,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    actualizado_por INTEGER REFERENCES usuarios(id)
);

-- Tabla alertas
CREATE TABLE IF NOT EXISTS alertas (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    usuario_id INTEGER REFERENCES usuarios(id),
    titulo VARCHAR(200) NOT NULL,
    mensaje TEXT NOT NULL,
    tipo_alerta VARCHAR(20) DEFAULT 'info',
    leida BOOLEAN DEFAULT FALSE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_lectura TIMESTAMP WITH TIME ZONE,
    documento_id INTEGER REFERENCES documentos(id),
    movimiento_id INTEGER REFERENCES movimientos(id)
);

-- 5. Crear índices nuevos y optimizados

-- Eliminar índices antiguos si existen
DROP INDEX IF EXISTS idx_documentos_codigo;
DROP INDEX IF EXISTS idx_documentos_gestion_correlativo;
DROP INDEX IF EXISTS idx_documentos_tipo;
DROP INDEX IF EXISTS idx_documentos_area;
DROP INDEX IF EXISTS idx_documentos_qr;
DROP INDEX IF EXISTS idx_movimientos_documento;
DROP INDEX IF EXISTS idx_movimientos_fecha;
DROP INDEX IF EXISTS idx_movimientos_tipo;
DROP INDEX IF EXISTS idx_anexos_documento;
DROP INDEX IF EXISTS idx_historial_documento;
DROP INDEX IF EXISTS idx_auditoria_usuario;
DROP INDEX IF EXISTS idx_auditoria_fecha;

-- Crear índices optimizados
CREATE INDEX IF NOT EXISTS idx_areas_codigo ON areas(codigo);
CREATE INDEX IF NOT EXISTS idx_areas_activas ON areas(activo) WHERE activo = TRUE;

CREATE INDEX IF NOT EXISTS idx_tipos_documento_codigo ON tipos_documento(codigo);
CREATE INDEX IF NOT EXISTS idx_tipos_documento_activos ON tipos_documento(activo) WHERE activo = TRUE;

CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_username ON usuarios(nombre_usuario);
CREATE INDEX IF NOT EXISTS idx_usuarios_activos ON usuarios(activo) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON usuarios(rol);

CREATE INDEX IF NOT EXISTS idx_documentos_codigo ON documentos(codigo);
CREATE INDEX IF NOT EXISTS idx_documentos_gestion_correlativo ON documentos(gestion, numero_correlativo);
CREATE INDEX IF NOT EXISTS idx_documentos_tipo ON documentos(tipo_documento_id);
CREATE INDEX IF NOT EXISTS idx_documentos_area ON documentos(area_actual_id);
CREATE INDEX IF NOT EXISTS idx_documentos_qr ON documentos(codigo_qr);
CREATE INDEX IF NOT EXISTS idx_documentos_estado ON documentos(estado);
CREATE INDEX IF NOT EXISTS idx_documentos_fecha ON documentos(fecha_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_responsable ON documentos(responsable_id);
CREATE INDEX IF NOT EXISTS idx_documentos_busqueda ON documentos USING gin(to_tsvector('spanish', COALESCE(descripcion, '') || ' ' || codigo));

CREATE INDEX IF NOT EXISTS idx_movimientos_documento ON movimientos(documento_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON movimientos(fecha_movimiento);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON movimientos(tipo_movimiento);
CREATE INDEX IF NOT EXISTS idx_movimientos_estado ON movimientos(estado);
CREATE INDEX IF NOT EXISTS idx_movimientos_usuario ON movimientos(usuario_id);

CREATE INDEX IF NOT EXISTS idx_anexos_documento ON anexos(documento_id);
CREATE INDEX IF NOT EXISTS idx_anexos_activos ON anexos(activo) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_anexos_hash ON anexos(hash_archivo);

CREATE INDEX IF NOT EXISTS idx_historial_documento ON historial_documento(documento_id);
CREATE INDEX IF NOT EXISTS idx_historial_fecha ON historial_documento(fecha_cambio);
CREATE INDEX IF NOT EXISTS idx_historial_usuario ON historial_documento(usuario_id);

CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria(usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria(fecha_accion);
CREATE INDEX IF NOT EXISTS idx_auditoria_tabla ON auditoria(tabla_afectada);
CREATE INDEX IF NOT EXISTS idx_auditoria_detalle ON auditoria USING gin(detalle);

CREATE INDEX IF NOT EXISTS idx_alertas_usuario ON alertas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_alertas_no_leidas ON alertas(leida) WHERE leida = FALSE;
CREATE INDEX IF NOT EXISTS idx_alertas_fecha ON alertas(fecha_creacion);

-- 6. Crear funciones y triggers

-- Función para actualizar timestamps
CREATE OR REPLACE FUNCTION actualizar_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear triggers para actualización automática
DROP TRIGGER IF EXISTS trigger_areas_actualizacion ON areas;
CREATE TRIGGER trigger_areas_actualizacion
    BEFORE UPDATE ON areas
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trigger_tipos_documento_actualizacion ON tipos_documento;
CREATE TRIGGER trigger_tipos_documento_actualizacion
    BEFORE UPDATE ON tipos_documento
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trigger_usuarios_actualizacion ON usuarios;
CREATE TRIGGER trigger_usuarios_actualizacion
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

DROP TRIGGER IF EXISTS trigger_documentos_actualizacion ON documentos;
CREATE TRIGGER trigger_documentos_actualizacion
    BEFORE UPDATE ON documentos
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

-- Función para registro en historial
CREATE OR REPLACE FUNCTION registrar_historial_documento()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO historial_documento (
            documento_id, usuario_id, tipo_cambio,
            estado_anterior, estado_nuevo,
            area_anterior_id, area_nueva_id,
            observacion
        ) VALUES (
            NEW.id, NEW.fecha_actualizacion::integer, 'ACTUALIZACION',
            OLD.estado, NEW.estado,
            OLD.area_actual_id, NEW.area_actual_id,
            'Actualización automática de documento'
        );
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO historial_documento (
            documento_id, tipo_cambio, estado_nuevo, area_nueva_id
        ) VALUES (
            NEW.id, 'CREACION', NEW.estado, NEW.area_actual_id
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_documentos_historial ON documentos;
CREATE TRIGGER trigger_documentos_historial
    AFTER INSERT OR UPDATE ON documentos
    FOR EACH ROW
    EXECUTE FUNCTION registrar_historial_documento();

-- Función para generación de correlativos
CREATE OR REPLACE FUNCTION generar_correlativo(
    p_tipo_documento_codigo VARCHAR,
    p_gestion VARCHAR,
    p_area_codigo VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
    v_correlativo INTEGER;
    v_codigo VARCHAR;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_correlativo FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_correlativo
    FROM documentos d
    JOIN tipos_documento td ON d.tipo_documento_id = td.id
    WHERE td.codigo = p_tipo_documento_codigo
    AND d.gestion = p_gestion;
    
    v_codigo := p_tipo_documento_codigo || '-' || p_gestion || '-' || 
                LPAD(v_correlativo::TEXT, 6, '0');
    
    RETURN v_codigo;
END;
$$ LANGUAGE plpgsql;

-- 7. Crear vistas optimizadas

DROP VIEW IF EXISTS vista_documentos_activos;
CREATE OR REPLACE VIEW vista_documentos_activos AS
SELECT 
    d.id,
    d.codigo,
    d.numero_correlativo,
    d.descripcion,
    d.fecha_documento,
    d.estado,
    td.nombre AS tipo_documento,
    a_origen.nombre AS area_origen,
    a_actual.nombre AS area_actual,
    u.nombre_completo AS responsable,
    d.fecha_registro
FROM documentos d
JOIN tipos_documento td ON d.tipo_documento_id = td.id
JOIN areas a_origen ON d.area_origen_id = a_origen.id
JOIN areas a_actual ON d.area_actual_id = a_actual.id
LEFT JOIN usuarios u ON d.responsable_id = u.id
WHERE d.estado = 'Activo';

DROP VIEW IF EXISTS vista_movimientos_activos;
CREATE OR REPLACE VIEW vista_movimientos_activos AS
SELECT 
    m.id,
    m.tipo_movimiento,
    m.fecha_movimiento,
    m.fecha_devolucion,
    m.estado,
    d.codigo AS codigo_documento,
    d.descripcion AS descripcion_documento,
    u_origen.nombre AS area_origen,
    u_destino.nombre AS area_destino,
    u_solicita.nombre_completo AS usuario_solicita,
    u_autoriza.nombre_completo AS usuario_autoriza
FROM movimientos m
JOIN documentos d ON m.documento_id = d.id
LEFT JOIN areas u_origen ON m.area_origen_id = u_origen.id
LEFT JOIN areas u_destino ON m.area_destino_id = u_destino.id
LEFT JOIN usuarios u_solicita ON m.usuario_id = u_solicita.id
LEFT JOIN usuarios u_autoriza ON m.usuario_autoriza_id = u_autoriza.id
WHERE m.estado = 'Activo';

-- 8. Insertar configuración inicial
INSERT INTO configuracion (clave, valor, descripcion, tipo_dato) VALUES
('plazo_prestamo_defecto', '7', 'Plazo en días para préstamos por defecto', 'integer'),
('max_intentos_login', '3', 'Máximo de intentos fallidos de login', 'integer'),
('tiempo_bloqueo_minutos', '30', 'Tiempo de bloqueo en minutos tras intentos fallidos', 'integer'),
('version_sistema', '2.0.0', 'Versión actual del sistema', 'string'),
('notificaciones_email', 'true', 'Activar notificaciones por email', 'boolean')
ON CONFLICT (clave) DO NOTHING;

-- 9. Actualizar estadísticas de la base de datos
ANALYZE;

COMMIT;

-- Mensaje de finalización
DO $$
BEGIN
    RAISE NOTICE 'Migración completada exitosamente';
    RAISE NOTICE 'Verificar que todos los datos se hayan migrado correctamente';
    RAISE NOTICE 'Ejecutar SELECT COUNT(*) FROM cada tabla para verificar integridad';
END $$;
