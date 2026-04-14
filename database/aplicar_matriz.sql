-- Script para forzar la matriz de permisos exacta con gestionar_seguridad
BEGIN;

-- Asegurar que los permisos existan
INSERT INTO permisos (codigo, nombre, descripcion, modulo) VALUES
('ver_documento', 'Ver Documento', 'Permite visualizar documentos', 'Documentos'),
('subir_documento', 'Subir Documento', 'Permite subir/crear nuevos documentos', 'Documentos'),
('editar_metadatos', 'Editar Metadatos', 'Permite editar información de documentos', 'Documentos'),
('borrar_documento', 'Borrar Documento', 'Permite eliminar documentos', 'Documentos'),
('gestionar_seguridad', 'Gestionar Seguridad', 'Permite administrar usuarios, roles y permisos', 'Seguridad')
ON CONFLICT (codigo) DO NOTHING;

-- Borrar permisos actuales de los roles para reiniciarlos
DELETE FROM rol_permisos 
WHERE rol IN ('AdministradorSistema', 'AdministradorDocumentos', 'Contador', 'Gerente');

-- 1. Administrador del Sistema: ver_documento + gestionar_seguridad
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorSistema', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'gestionar_seguridad');

-- 2. Administrador de Documentos: Ver, Subir, Editar, Borrar
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorDocumentos', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'subir_documento', 'editar_metadatos', 'borrar_documento');

-- 3. Contador: Ver, Subir
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'Contador', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'subir_documento');

-- 4. Gerente: SOLO ver_documento
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'Gerente', id, true
FROM permisos WHERE codigo IN ('ver_documento');

COMMIT;

-- Verificación
SELECT rp.rol, p.codigo 
FROM rol_permisos rp 
JOIN permisos p ON rp.permiso_id = p.id 
ORDER BY rp.rol, p.codigo;
