-- Consolidated DB fixes (Sprint 2)
-- Ejecutar con cuidado. Idealmente en un backup.

BEGIN;

-- Extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Tipos enum (si no existen)
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

-- Columnas base
ALTER TABLE areas ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS creado_por INTEGER REFERENCES usuarios(id);
ALTER TABLE areas ALTER COLUMN codigo SET NOT NULL;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'areas_codigo_unique') THEN
        ALTER TABLE areas ADD CONSTRAINT areas_codigo_unique UNIQUE (codigo);
    END IF;
END $$;

ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS creado_por INTEGER REFERENCES usuarios(id);
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS requiere_aprobacion BOOLEAN DEFAULT FALSE;
ALTER TABLE tipos_documento ADD COLUMN IF NOT EXISTS plazo_retencion_dias INTEGER DEFAULT 365;
ALTER TABLE tipos_documento ALTER COLUMN codigo SET NOT NULL;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tipos_documento_codigo_unique') THEN
        ALTER TABLE tipos_documento ADD CONSTRAINT tipos_documento_codigo_unique UNIQUE (codigo);
    END IF;
END $$;

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMP WITH TIME ZONE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS intentos_fallidos INTEGER DEFAULT 0;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMP WITH TIME ZONE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS rol rol_enum DEFAULT 'Usuario';
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'email_valido') THEN
        ALTER TABLE usuarios ADD CONSTRAINT email_valido CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    END IF;
END $$;

ALTER TABLE documentos ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS area_actual_id INTEGER REFERENCES areas(id);
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS nivel_confidencialidad INTEGER DEFAULT 1;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS fecha_vencimiento DATE;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS estado estado_documento_enum DEFAULT 'Activo';
UPDATE documentos SET area_actual_id = area_origen_id WHERE area_actual_id IS NULL;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gestion_formato') THEN
        ALTER TABLE documentos ADD CONSTRAINT gestion_formato CHECK (gestion ~* '^[0-9]{4}$');
    END IF;
END $$;
ALTER TABLE documentos DROP CONSTRAINT IF EXISTS codigo_formato;
ALTER TABLE documentos ADD CONSTRAINT codigo_formato CHECK (codigo ~* '^[A-Z0-9]{2,10}-[A-Z0-9]{2,10}-[0-9]{4}-[0-9]{4,6}$');
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'nivel_confidencialidad_rango') THEN
        ALTER TABLE documentos ADD CONSTRAINT nivel_confidencialidad_rango CHECK (nivel_confidencialidad BETWEEN 1 AND 5);
    END IF;
END $$;
ALTER TABLE documentos ALTER COLUMN codigo_qr TYPE text;

ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS usuario_autoriza_id INTEGER REFERENCES usuarios(id);
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS plazo_dias INTEGER DEFAULT 7;
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS tipo_movimiento tipo_movimiento_enum;
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS estado estado_movimiento_enum DEFAULT 'Activo';

ALTER TABLE anexos ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE anexos ADD COLUMN IF NOT EXISTS hash_archivo VARCHAR(64);
ALTER TABLE anexos ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;
ALTER TABLE anexos ALTER COLUMN tamano TYPE BIGINT USING tamano::BIGINT;
ALTER TABLE anexos RENAME COLUMN tamano TO tamano_bytes;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tamano_positivo') THEN
        ALTER TABLE anexos ADD CONSTRAINT tamano_positivo CHECK (tamano_bytes > 0);
    END IF;
END $$;

ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS tipo_cambio VARCHAR(50);
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS campo_modificado VARCHAR(100);
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS valor_anterior TEXT;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS valor_nuevo TEXT;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS estado_anterior estado_documento_enum;
ALTER TABLE historial_documento ADD COLUMN IF NOT EXISTS estado_nuevo estado_documento_enum;

ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS sesion_id VARCHAR(255);
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS registro_uuid UUID;
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE auditoria ALTER COLUMN ip_address TYPE INET USING ip_address::INET;
ALTER TABLE auditoria ALTER COLUMN detalle TYPE JSONB USING detalle::JSONB;

-- Tablas nuevas
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

-- Carpetas
CREATE TABLE IF NOT EXISTS carpetas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    codigo VARCHAR(50),
    gestion VARCHAR(4) NOT NULL,
    descripcion TEXT,
    carpeta_padre_id INTEGER REFERENCES carpetas(id),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    usuario_creacion_id INTEGER REFERENCES usuarios(id)
);

ALTER TABLE documentos ADD COLUMN IF NOT EXISTS carpeta_id INTEGER;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_documentos_carpeta') THEN
        ALTER TABLE documentos ADD CONSTRAINT fk_documentos_carpeta FOREIGN KEY (carpeta_id) REFERENCES carpetas(id);
    END IF;
END $$;

-- Palabras clave
CREATE TABLE IF NOT EXISTS palabras_clave (
    id SERIAL PRIMARY KEY,
    palabra VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS documento_palabras_clave (
    id SERIAL PRIMARY KEY,
    documento_id INTEGER REFERENCES documentos(id) ON DELETE CASCADE,
    palabra_clave_id INTEGER REFERENCES palabras_clave(id) ON DELETE CASCADE
);

ALTER TABLE palabras_clave ADD COLUMN IF NOT EXISTS descripcion TEXT;
ALTER TABLE palabras_clave ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;

-- Backfill QR / id_documento
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS id_documento VARCHAR(50);
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS url_qr TEXT;
ALTER TABLE documentos ADD COLUMN IF NOT EXISTS codigo_qr TEXT;
UPDATE documentos
SET id_documento = COALESCE(NULLIF(id_documento, ''), codigo)
WHERE id_documento IS NULL OR id_documento = '';
UPDATE documentos
SET url_qr = CONCAT('http://localhost:5000', '/documentos/ver/', id_documento),
    codigo_qr = url_qr
WHERE (url_qr IS NULL OR url_qr = '')
   OR (codigo_qr IS NULL OR codigo_qr = '');

-- Indices clave
CREATE INDEX IF NOT EXISTS idx_documentos_codigo ON documentos(codigo);
CREATE INDEX IF NOT EXISTS idx_documentos_gestion_correlativo ON documentos(gestion, numero_correlativo);
CREATE INDEX IF NOT EXISTS idx_documentos_tipo ON documentos(tipo_documento_id);
CREATE INDEX IF NOT EXISTS idx_documentos_area ON documentos(area_actual_id);
CREATE INDEX IF NOT EXISTS idx_documentos_busqueda ON documentos USING gin(to_tsvector('spanish', COALESCE(descripcion, '') || ' ' || codigo));
CREATE INDEX IF NOT EXISTS idx_movimientos_documento ON movimientos(documento_id);
CREATE INDEX IF NOT EXISTS idx_anexos_documento ON anexos(documento_id);
CREATE INDEX IF NOT EXISTS idx_historial_documento ON historial_documento(documento_id);
CREATE INDEX IF NOT EXISTS idx_alertas_usuario ON alertas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_alertas_no_leidas ON alertas(leida) WHERE leida = FALSE;

ANALYZE;
COMMIT;
