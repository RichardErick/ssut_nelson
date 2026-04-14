-- Script para corregir roles incorrectos en usuarios
-- Ejecutar para solucionar roles mal asignados

-- 1. Ver estado actual de todos los usuarios y sus roles
SELECT 
    id, 
    nombre_usuario, 
    nombre_completo, 
    rol, 
    activo
FROM usuarios
ORDER BY id;

-- 2. Corregir roles específicos basándose en el propósito del usuario

-- Usuario admin (id=3): debe ser Administrador (AdministradorSistema en el código)
UPDATE usuarios 
SET rol = 'Administrador'
WHERE id = 3 AND nombre_usuario = 'admin';

-- Usuario doc_admin (id=4): debe ser AdministradorDocumentos
UPDATE usuarios 
SET rol = 'AdministradorDocumentos'
WHERE id = 4 AND nombre_usuario = 'doc_admin';

-- Usuario carlos (id=5): si debe ser admin de documentos, cambiar
-- Si debe ser admin de sistema, dejarlo como "Administrador"
-- Descomentar según corresponda:
-- UPDATE usuarios SET rol = 'AdministradorDocumentos' WHERE id = 5;

-- Usuario carmen (id=15): si debe ser admin de documentos, cambiar
-- UPDATE usuarios SET rol = 'AdministradorDocumentos' WHERE id = 15;

-- 3. Verificar cambios aplicados
SELECT 
    id, 
    nombre_usuario, 
    nombre_completo, 
    rol, 
    activo,
    CASE 
        WHEN rol = 'Administrador' THEN '✓ Admin Sistema'
        WHEN rol = 'AdministradorDocumentos' THEN '✓ Admin Documentos'
        WHEN rol = 'Contador' THEN '✓ Contador'
        WHEN rol = 'Gerente' THEN '✓ Gerente'
        ELSE '⚠ Rol desconocido'
    END AS rol_descripcion
FROM usuarios
ORDER BY id;

-- 4. Información de roles válidos
/*
ROLES VÁLIDOS EN EL SISTEMA:
- "Administrador" (AdministradorSistema): Acceso total, gestión de roles y permisos
- "AdministradorDocumentos": Gestión completa de documentos
- "Gerente": Gestión de documentos de su área
- "Contador": Solo ver documentos

NOTA: 
- En el frontend, "Administrador" se mapea a UserRole.administradorSistema
- En el backend, el rol se llama "AdministradorSistema" pero en BD puede ser "Administrador"
*/
