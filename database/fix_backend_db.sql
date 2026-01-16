-- Fixes for backend runtime errors (PostgreSQL)

-- 1) Ensure usuario_permisos exists
CREATE TABLE IF NOT EXISTS usuario_permisos (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    permiso_id INTEGER NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_usuario_permiso UNIQUE (usuario_id, permiso_id)
);

CREATE INDEX IF NOT EXISTS idx_usuario_permisos_usuario_id ON usuario_permisos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_usuario_permisos_permiso_id ON usuario_permisos(permiso_id);

-- 2) Fix auditoria.detalle type and index if it was jsonb/text mismatch
DO $$
DECLARE
    detalle_type text;
    idx_name text;
BEGIN
    SELECT data_type
      INTO detalle_type
      FROM information_schema.columns
     WHERE table_name = 'auditoria'
       AND column_name = 'detalle'
     LIMIT 1;

    IF detalle_type IS NOT NULL THEN
        -- Drop any gin index on detalle (text cannot use gin without opclass)
        SELECT indexname
          INTO idx_name
          FROM pg_indexes
         WHERE tablename = 'auditoria'
           AND indexdef ILIKE '% USING gin %detalle%'
         LIMIT 1;

        IF idx_name IS NOT NULL THEN
            EXECUTE format('DROP INDEX IF EXISTS %I', idx_name);
        END IF;

        -- Force detalle to text to avoid jsonb/text mismatch
        IF detalle_type <> 'text' THEN
            EXECUTE 'ALTER TABLE auditoria ALTER COLUMN detalle TYPE text USING detalle::text';
        END IF;
    END IF;
END $$;

-- 3) Fix auditoria.ip_address type mismatch (inet vs varchar)
DO $$
DECLARE
    ip_type text;
BEGIN
    SELECT data_type
      INTO ip_type
      FROM information_schema.columns
     WHERE table_name = 'auditoria'
       AND column_name = 'ip_address'
     LIMIT 1;

    IF ip_type IS NOT NULL AND ip_type <> 'text' THEN
        EXECUTE 'ALTER TABLE auditoria ALTER COLUMN ip_address TYPE text USING ip_address::text';
    END IF;
END $$;

-- 4) Normalize roles to valid enum names
UPDATE usuarios
   SET rol = 'Administrador'
 WHERE rol = 'AdministradorSistema';

UPDATE usuarios
   SET rol = 'AdministradorDocumentos'
 WHERE rol IN ('ArchivoCentral', 'TramiteDocumentario');

UPDATE usuarios
   SET rol = 'Gerente'
 WHERE rol = 'Supervisor';

UPDATE usuarios
   SET rol = 'Contador'
 WHERE rol = 'Usuario';

UPDATE usuarios
   SET rol = 'AdministradorDocumentos'
 WHERE rol NOT IN ('Administrador', 'AdministradorDocumentos', 'Contador', 'Gerente');

-- 5) If rol is text, apply a strict CHECK constraint
DO $$
DECLARE
    rol_type text;
BEGIN
    SELECT data_type
      INTO rol_type
      FROM information_schema.columns
     WHERE table_name = 'usuarios'
       AND column_name = 'rol'
     LIMIT 1;

    IF rol_type = 'text' OR rol_type = 'character varying' THEN
        EXECUTE 'ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check';
        EXECUTE 'ALTER TABLE usuarios ADD CONSTRAINT usuarios_rol_check CHECK (rol IN (''Administrador'', ''AdministradorDocumentos'', ''Contador'', ''Gerente''))';
    END IF;
END $$;

-- 6) Add enum value Prestado if estado_documento_enum exists and is missing it
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_documento_enum') THEN
        IF NOT EXISTS (
            SELECT 1
              FROM pg_enum
             WHERE enumlabel = 'Prestado'
               AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'estado_documento_enum')
        ) THEN
            EXECUTE 'ALTER TYPE estado_documento_enum ADD VALUE ''Prestado''';
        END IF;
    END IF;
END $$;
