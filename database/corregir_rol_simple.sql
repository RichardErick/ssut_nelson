-- Script simple para actualizar la restricción CHECK de la columna rol
-- Ejecutar línea por línea si hay problemas de transacciones

-- Paso 1: Verificar usuarios con roles inválidos
SELECT rol, COUNT(*) as cantidad
FROM usuarios
WHERE rol NOT IN ('Administrador', 'AdministradorSistema', 'AdministradorDocumentos', 'Contador', 'Gerente')
GROUP BY rol;

-- Paso 2: Eliminar la restricción antigua
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;

-- Paso 3: Crear la nueva restricción
ALTER TABLE usuarios ADD CONSTRAINT usuarios_rol_check 
    CHECK (rol IN ('Administrador', 'AdministradorSistema', 'AdministradorDocumentos', 'Contador', 'Gerente'));

-- Paso 4: Verificar que funcionó
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'usuarios'::regclass
AND conname = 'usuarios_rol_check';
