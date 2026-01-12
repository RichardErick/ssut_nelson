-- Script para limpiar y migrar roles antiguos a los 4 roles oficiales
-- Ejecutar después de actualizar el código

BEGIN;

-- 1. Verificar usuarios con roles antiguos
SELECT rol, COUNT(*) as cantidad
FROM usuarios
GROUP BY rol
ORDER BY cantidad DESC;

-- 2. Migrar roles antiguos a roles válidos
-- ArchivoCentral -> AdministradorDocumentos (más cercano en permisos)
UPDATE usuarios 
SET rol = 'AdministradorDocumentos'
WHERE rol = 'ArchivoCentral';

-- TramiteDocumentario -> AdministradorDocumentos
UPDATE usuarios 
SET rol = 'AdministradorDocumentos'
WHERE rol = 'TramiteDocumentario';

-- Supervisor -> Gerente (más cercano en permisos)
UPDATE usuarios 
SET rol = 'Gerente'
WHERE rol = 'Supervisor';

-- Usuario -> Contador (asumiendo que usuarios normales pueden ser contadores)
-- O puedes cambiarlo a Gerente si prefieres
UPDATE usuarios 
SET rol = 'Contador'
WHERE rol = 'Usuario';

-- 3. Verificar que todos los roles sean válidos
SELECT DISTINCT rol 
FROM usuarios
WHERE rol NOT IN ('Administrador', 'AdministradorDocumentos', 'Contador', 'Gerente');

-- 4. Si hay algún rol que no coincida, asignarlo a AdministradorDocumentos por defecto
UPDATE usuarios 
SET rol = 'AdministradorDocumentos'
WHERE rol NOT IN ('Administrador', 'AdministradorDocumentos', 'Contador', 'Gerente');

-- 5. Verificar resultado final
SELECT rol, COUNT(*) as cantidad
FROM usuarios
GROUP BY rol
ORDER BY rol;

COMMIT;

-- Nota: Después de ejecutar este script, verifica que todos los usuarios tengan roles válidos
-- Los roles válidos son:
-- - Administrador (o AdministradorSistema)
-- - AdministradorDocumentos
-- - Contador
-- - Gerente
