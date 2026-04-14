-- Script para actualizar el enum rol_enum en PostgreSQL
-- Agrega los valores faltantes: ArchivoCentral y TramiteDocumentario
-- Ejecutar este script en PostgreSQL para sincronizar el enum con el código C#

-- Verificar si el tipo enum existe
DO $$ 
BEGIN
    -- Verificar si el enum existe
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol_enum') THEN
        -- Agregar 'ArchivoCentral' si no existe
        IF NOT EXISTS (
            SELECT 1 FROM pg_enum 
            WHERE enumlabel = 'ArchivoCentral' 
            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'rol_enum')
        ) THEN
            ALTER TYPE rol_enum ADD VALUE 'ArchivoCentral';
            RAISE NOTICE 'Valor ArchivoCentral agregado al enum rol_enum';
        ELSE
            RAISE NOTICE 'Valor ArchivoCentral ya existe en rol_enum';
        END IF;
        
        -- Agregar 'TramiteDocumentario' si no existe
        IF NOT EXISTS (
            SELECT 1 FROM pg_enum 
            WHERE enumlabel = 'TramiteDocumentario' 
            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'rol_enum')
        ) THEN
            ALTER TYPE rol_enum ADD VALUE 'TramiteDocumentario';
            RAISE NOTICE 'Valor TramiteDocumentario agregado al enum rol_enum';
        ELSE
            RAISE NOTICE 'Valor TramiteDocumentario ya existe en rol_enum';
        END IF;
    ELSE
        RAISE EXCEPTION 'El tipo enum rol_enum no existe. Ejecuta primero el script schema_fixed.sql o schema_optimized.sql';
    END IF;
END $$;

-- Verificar los valores del enum después de la actualización
SELECT 
    enumlabel AS valor,
    enumsortorder AS orden
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'rol_enum')
ORDER BY enumsortorder;

-- El enum debería tener estos valores:
-- 1. Administrador
-- 2. AdministradorDocumentos
-- 3. Usuario
-- 4. Supervisor
-- 5. ArchivoCentral (agregado)
-- 6. TramiteDocumentario (agregado)

