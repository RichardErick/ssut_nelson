-- Script para agregar el permiso ver_movimientos
BEGIN;

INSERT INTO permisos (codigo, nombre, descripcion, modulo) 
VALUES ('ver_movimientos', 'Ver Movimientos', 'Permite ver el historial de movimientos de documentos', 'Movimientos')
ON CONFLICT (codigo) DO NOTHING;

-- Asignar a roles por defecto (según la lógica de PermisosController)
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorSistema', id, true FROM permisos WHERE codigo = 'ver_movimientos'
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorDocumentos', id, true FROM permisos WHERE codigo = 'ver_movimientos'
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'Contador', id, true FROM permisos WHERE codigo = 'ver_movimientos'
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'Gerente', id, true FROM permisos WHERE codigo = 'ver_movimientos'
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

COMMIT;
