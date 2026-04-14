-- Script para restaurar el rol de administrador al usuario 'admin'
-- Ejecutar si el admin perdió acceso a Roles y Permisos

-- 1. Verificar el usuario admin y su rol actual
SELECT id, nombre_usuario, nombre_completo, rol, activo 
FROM usuarios 
WHERE nombre_usuario = 'admin' OR id = 3;

-- 2. Restaurar rol de Administrador (si se cambió)
UPDATE usuarios 
SET rol = 'Administrador'
WHERE nombre_usuario = 'admin';

-- 3. Verificar que el cambio se aplicó
SELECT id, nombre_usuario, nombre_completo, rol, activo 
FROM usuarios 
WHERE nombre_usuario = 'admin';

-- NOTA: Después de ejecutar este script, el usuario debe:
-- 1. Cerrar sesión en la aplicación
-- 2. Volver a iniciar sesión
-- 3. Verificar que vuelve a ver "Roles y Permisos" en el menú lateral
