-- Agregar permiso "ver_movimientos"
INSERT INTO permisos (codigo, nombre, descripcion, modulo, activo) 
VALUES ('ver_movimientos', 'Ver Movimientos', 'Permite ver el historial de movimientos de documentos', 'Movimientos', true)
ON CONFLICT (codigo) DO NOTHING;

-- Asignar por defecto a todos los roles existentes
-- AdministradorSistema siempre debe tener acceso
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorSistema', id, true
FROM permisos WHERE codigo = 'ver_movimientos'
ON CONFLICT (rol, permiso_id) DO NOTHING;

-- Otros roles (inicialmente activo)
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT rol, (SELECT id FROM permisos WHERE codigo = 'ver_movimientos'), true
FROM (VALUES ('AdministradorDocumentos'), ('Contador'), ('Gerente')) AS roles(rol)
ON CONFLICT (rol, permiso_id) DO NOTHING;
