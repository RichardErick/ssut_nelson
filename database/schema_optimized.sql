-- Base de datos optimizada para Sistema de Gestión Documental SSUT
-- PostgreSQL con optimizaciones específicas

-- Crear base de datos (ejecutar manualmente si es necesario)
-- CREATE DATABASE ssut_gestion_documental WITH ENCODING 'UTF8';

-- Extensiones necesarias para PostgreSQL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Enumeraciones para mejor integridad de datos
CREATE TYPE rol_enum AS ENUM ('Administrador', 'AdministradorDocumentos', 'Usuario', 'Supervisor');
CREATE TYPE estado_documento_enum AS ENUM ('Activo', 'Inactivo', 'Archivado', 'Eliminado');
CREATE TYPE tipo_movimiento_enum AS ENUM ('Prestamo', 'Devolucion', 'Transferencia', 'Archivo', 'Eliminacion');
CREATE TYPE estado_movimiento_enum AS ENUM ('Activo', 'Completado', 'Cancelado');

-- Tabla de Áreas con mejoras
CREATE TABLE IF NOT EXISTS areas (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    creado_por INTEGER REFERENCES usuarios(id)
);

-- Tabla de Tipos de Documento mejorada
CREATE TABLE IF NOT EXISTS tipos_documento (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT TRUE,
    requiere_aprobacion BOOLEAN DEFAULT FALSE,
    plazo_retencion_dias INTEGER DEFAULT 365,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    creado_por INTEGER REFERENCES usuarios(id)
);

-- Tabla de Usuarios optimizada
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
    nombre_completo VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol rol_enum DEFAULT 'Usuario',
    area_id INTEGER REFERENCES areas(id),
    activo BOOLEAN DEFAULT TRUE,
    ultimo_acceso TIMESTAMP WITH TIME ZONE,
    intentos_fallidos INTEGER DEFAULT 0,
    bloqueado_hasta TIMESTAMP WITH TIME ZONE,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT email_valido CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Tabla de Documentos con mejoras significativas
CREATE TABLE IF NOT EXISTS documentos (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    numero_correlativo VARCHAR(50) NOT NULL,
    tipo_documento_id INTEGER NOT NULL REFERENCES tipos_documento(id),
    area_origen_id INTEGER NOT NULL REFERENCES areas(id),
    area_actual_id INTEGER REFERENCES areas(id),
    gestion VARCHAR(4) NOT NULL CHECK (gestion ~* '^[0-9]{4}$'),
    fecha_documento DATE NOT NULL,
    descripcion TEXT,
    responsable_id INTEGER REFERENCES usuarios(id),
    codigo_qr TEXT,
    ubicacion_fisica VARCHAR(200),
    estado estado_documento_enum DEFAULT 'Activo',
    nivel_confidencialidad INTEGER DEFAULT 1 CHECK (nivel_confidencialidad BETWEEN 1 AND 5),
    fecha_vencimiento DATE,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT codigo_formato CHECK (codigo ~* '^[A-Z0-9]{2,10}-[A-Z0-9]{2,10}-[0-9]{4}-[0-9]{4,6}$')
);

-- Tabla de Movimientos mejorada
CREATE TABLE IF NOT EXISTS movimientos (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    documento_id INTEGER NOT NULL REFERENCES documentos(id),
    tipo_movimiento tipo_movimiento_enum NOT NULL,
    area_origen_id INTEGER REFERENCES areas(id),
    area_destino_id INTEGER REFERENCES areas(id),
    usuario_id INTEGER REFERENCES usuarios(id),
    usuario_autoriza_id INTEGER REFERENCES usuarios(id),
    observaciones TEXT,
    fecha_movimiento TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_devolucion TIMESTAMP WITH TIME ZONE,
    estado estado_movimiento_enum DEFAULT 'Activo',
    plazo_dias INTEGER DEFAULT 7,
    CONSTRAINT fecha_devolucion_valida CHECK (
        (tipo_movimiento != 'Prestamo' AND fecha_devolucion IS NULL) OR
        (tipo_movimiento = 'Prestamo' AND fecha_devolucion > fecha_movimiento)
    )
);

-- Tabla de Anexos mejorada
CREATE TABLE IF NOT EXISTS anexos (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    documento_id INTEGER NOT NULL REFERENCES documentos(id),
    nombre_archivo VARCHAR(255) NOT NULL,
    extension VARCHAR(10),
    tamano_bytes BIGINT,
    url_archivo VARCHAR(500),
    tipo_contenido VARCHAR(100),
    hash_archivo VARCHAR(64), -- SHA-256 para integridad
    version INTEGER DEFAULT 1,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    CONSTRAINT tamano_positivo CHECK (tamano_bytes > 0)
);

-- Tabla de Historial de Documentos mejorada
CREATE TABLE IF NOT EXISTS historial_documento (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    documento_id INTEGER NOT NULL REFERENCES documentos(id),
    fecha_cambio TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    usuario_id INTEGER REFERENCES usuarios(id),
    tipo_cambio VARCHAR(50) NOT NULL,
    estado_anterior estado_documento_enum,
    estado_nuevo estado_documento_enum,
    area_anterior_id INTEGER REFERENCES areas(id),
    area_nueva_id INTEGER REFERENCES areas(id),
    campo_modificado VARCHAR(100),
    valor_anterior TEXT,
    valor_nuevo TEXT,
    observacion TEXT
);

-- Tabla de Auditoría mejorada
CREATE TABLE IF NOT EXISTS auditoria (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    usuario_id INTEGER REFERENCES usuarios(id),
    sesion_id VARCHAR(255),
    accion VARCHAR(100) NOT NULL,
    tabla_afectada VARCHAR(50),
    registro_id INTEGER,
    registro_uuid UUID,
    detalle JSONB,
    ip_address INET,
    user_agent TEXT,
    fecha_accion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Nueva tabla: Configuración del Sistema
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

-- Nueva tabla: Alertas y Notificaciones
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

-- Índices optimizados para PostgreSQL
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
CREATE INDEX IF NOT EXISTS idx_documentos_busqueda ON documentos USING gin(to_tsvector('spanish', descripcion || ' ' || codigo));

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

-- Triggers para actualización automática de timestamps
CREATE OR REPLACE FUNCTION actualizar_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_areas_actualizacion
    BEFORE UPDATE ON areas
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

CREATE TRIGGER trigger_tipos_documento_actualizacion
    BEFORE UPDATE ON tipos_documento
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

CREATE TRIGGER trigger_usuarios_actualizacion
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

CREATE TRIGGER trigger_documentos_actualizacion
    BEFORE UPDATE ON documentos
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp();

-- Trigger para registro automático en historial
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

CREATE TRIGGER trigger_documentos_historial
    AFTER INSERT OR UPDATE ON documentos
    FOR EACH ROW
    EXECUTE FUNCTION registrar_historial_documento();

-- Función para generación de códigos correlativos
CREATE OR REPLACE FUNCTION generar_correlativo(
    p_tipo_documento_codigo VARCHAR,
    p_gestion VARCHAR,
    p_area_codigo VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
    v_correlativo INTEGER;
    v_codigo VARCHAR;
BEGIN
    -- Obtener el último correlativo para este tipo y gestión
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_correlativo FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_correlativo
    FROM documentos d
    JOIN tipos_documento td ON d.tipo_documento_id = td.id
    WHERE td.codigo = p_tipo_documento_codigo
    AND d.gestion = p_gestion;
    
    -- Formatear el código
    v_codigo := p_tipo_documento_codigo || '-' || p_gestion || '-' || 
                LPAD(v_correlativo::TEXT, 6, '0');
    
    RETURN v_codigo;
END;
$$ LANGUAGE plpgsql;

-- Vista para consultas frecuentes
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

-- Vista para movimientos activos
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

-- Datos iniciales mejorados
INSERT INTO areas (nombre, codigo, descripcion) VALUES
('Administración', 'ADM', 'Área de administración general'),
('Contabilidad', 'CONT', 'Área de contabilidad y finanzas'),
('Recursos Humanos', 'RH', 'Área de recursos humanos'),
('Archivo', 'ARCH', 'Área de archivo documental')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO tipos_documento (nombre, codigo, descripcion, requiere_aprobacion, plazo_retencion_dias) VALUES
('Comprobante de Ingreso', 'CI', 'Comprobantes de ingresos contables', TRUE, 2555),
('Comprobante de Egreso', 'CE', 'Comprobantes de egresos contables', TRUE, 2555),
('Memorándum', 'MEM', 'Memorándums administrativos', FALSE, 1825),
('Oficio', 'OF', 'Oficios institucionales', FALSE, 3650),
('Resolución', 'RES', 'Resoluciones administrativas', TRUE, 3650)
ON CONFLICT (codigo) DO NOTHING;

-- Configuración inicial del sistema
INSERT INTO configuracion (clave, valor, descripcion, tipo_dato) VALUES
('plazo_prestamo_defecto', '7', 'Plazo en días para préstamos por defecto', 'integer'),
('max_intentos_login', '3', 'Máximo de intentos fallidos de login', 'integer'),
('tiempo_bloqueo_minutos', '30', 'Tiempo de bloqueo en minutos tras intentos fallidos', 'integer'),
('version_sistema', '2.0.0', 'Versión actual del sistema', 'string'),
('notificaciones_email', 'true', 'Activar notificaciones por email', 'boolean')
ON CONFLICT (clave) DO NOTHING;

-- Usuario administrador por defecto (password: admin)
INSERT INTO usuarios (nombre_usuario, nombre_completo, email, password_hash, rol, area_id) VALUES
('admin', 'Administrador del Sistema', 'admin@ssut.edu.bo', 'admin', 'Administrador', 1),
('doc_admin', 'Administrador de Documentos', 'docadmin@ssut.edu.bo', 'admin', 'AdministradorDocumentos', 4)
ON CONFLICT (nombre_usuario) DO NOTHING;
