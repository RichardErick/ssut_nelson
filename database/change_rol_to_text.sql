-- Script para cambiar la columna rol de tipo enum a text
-- Esto resuelve el problema de orden entre el enum de PostgreSQL y C#

BEGIN;

-- 1. Agregar una columna temporal de tipo text
ALTER TABLE usuarios ADD COLUMN rol_temp TEXT;

-- 2. Copiar los valores del enum a la columna temporal (convertir enum a text)
UPDATE usuarios SET rol_temp = rol::text;

-- 3. Eliminar la columna original
ALTER TABLE usuarios DROP COLUMN rol;

-- 4. Renombrar la columna temporal a rol
ALTER TABLE usuarios RENAME COLUMN rol_temp TO rol;

-- 5. Agregar constraint para validar que solo se permitan valores válidos
ALTER TABLE usuarios ADD CONSTRAINT usuarios_rol_check 
    CHECK (rol IN ('Administrador', 'AdministradorDocumentos', 'ArchivoCentral', 'TramiteDocumentario', 'Supervisor', 'Usuario'));

COMMIT;

-- Verificar el cambio
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'usuarios' AND column_name = 'rol';

