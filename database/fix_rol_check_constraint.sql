-- Script para actualizar la restricción CHECK de la columna rol
-- Esto permite los 4 roles oficiales: Administrador, AdministradorDocumentos, Contador, Gerente
-- Ejecutar sin BEGIN/COMMIT para evitar problemas de transacciones abortadas

-- 1. Primero, verificar si hay datos que violen la nueva restricción
SELECT rol, COUNT(*) as cantidad
FROM usuarios
WHERE rol NOT IN ('Administrador', 'AdministradorSistema', 'AdministradorDocumentos', 'Contador', 'Gerente')
GROUP BY rol;

-- 2. Si hay roles inválidos, migrarlos primero (ejecutar manualmente si es necesario)
-- UPDATE usuarios SET rol = 'AdministradorDocumentos' WHERE rol NOT IN ('Administrador', 'AdministradorSistema', 'AdministradorDocumentos', 'Contador', 'Gerente');

-- 3. Eliminar la restricción CHECK antigua si existe
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;

-- 4. Crear la nueva restricción CHECK con los 4 roles válidos
ALTER TABLE usuarios ADD CONSTRAINT usuarios_rol_check 
    CHECK (rol IN ('Administrador', 'AdministradorSistema', 'AdministradorDocumentos', 'Contador', 'Gerente'));

-- 5. Verificar que la restricción se aplicó correctamente
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'usuarios'::regclass
AND conname = 'usuarios_rol_check';

-- 6. Verificar que todos los usuarios tienen roles válidos
SELECT rol, COUNT(*) as cantidad
FROM usuarios
GROUP BY rol
ORDER BY rol;

-- Nota: 'AdministradorSistema' se incluye como alias de 'Administrador'
-- El sistema acepta ambos valores pero los trata como el mismo rol
