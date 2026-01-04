-- Script para verificar el estado actual del enum rol_enum
-- Ejecuta este script para ver todos los valores del enum y su orden

SELECT 
    enumlabel AS valor,
    enumsortorder AS orden,
    CASE 
        WHEN enumlabel = 'Administrador' THEN '✓'
        WHEN enumlabel = 'AdministradorDocumentos' THEN '✓'
        WHEN enumlabel = 'ArchivoCentral' THEN '✓'
        WHEN enumlabel = 'TramiteDocumentario' THEN '✓'
        WHEN enumlabel = 'Supervisor' THEN '✓'
        WHEN enumlabel = 'Usuario' THEN '✓'
        ELSE '✗'
    END AS esperado
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'rol_enum')
ORDER BY enumsortorder;

-- Verificar si hay usuarios con valores que no están en el enum
SELECT DISTINCT rol::text 
FROM usuarios 
WHERE rol::text NOT IN (
    SELECT enumlabel::text 
    FROM pg_enum 
    WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'rol_enum')
);

