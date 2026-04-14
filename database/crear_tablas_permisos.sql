-- Script para crear las tablas de permisos y rol_permisos
-- Ejecutar después de cambiar la columna rol a text

BEGIN;

-- Tabla de Permisos
CREATE TABLE IF NOT EXISTS permisos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),
    modulo VARCHAR(50) DEFAULT 'Documentos',
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla intermedia Rol-Permiso
CREATE TABLE IF NOT EXISTS rol_permisos (
    id SERIAL PRIMARY KEY,
    rol VARCHAR(50) NOT NULL,
    permiso_id INTEGER NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
    activo BOOLEAN DEFAULT TRUE,
    fecha_asignacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(rol, permiso_id)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_permisos_codigo ON permisos(codigo);
CREATE INDEX IF NOT EXISTS idx_permisos_modulo ON permisos(modulo);
CREATE INDEX IF NOT EXISTS idx_rol_permisos_rol ON rol_permisos(rol);
CREATE INDEX IF NOT EXISTS idx_rol_permisos_permiso ON rol_permisos(permiso_id);

-- Insertar permisos base según la matriz
INSERT INTO permisos (codigo, nombre, descripcion, modulo) VALUES
('ver_documento', 'Ver Documento', 'Permite visualizar documentos', 'Documentos'),
('subir_documento', 'Subir Documento', 'Permite subir/crear nuevos documentos', 'Documentos'),
('editar_metadatos', 'Editar Metadatos', 'Permite editar información de documentos', 'Documentos'),
('borrar_documento', 'Borrar Documento', 'Permite eliminar documentos', 'Documentos'),
('ver_movimientos', 'Ver Movimientos', 'Permite ver el historial de movimientos de documentos', 'Movimientos'),
('gestionar_seguridad', 'Gestionar Seguridad', 'Permite administrar usuarios, roles y permisos', 'Seguridad')
ON CONFLICT (codigo) DO NOTHING;

-- Asignar permisos según la matriz:
-- Administrador de Sistema: ver_documento + gestionar_seguridad + movimientos
-- Administrador de Documentos: todos los permisos de Documentos + movimientos
-- Contador: ver_documento, subir_documento + movimientos
-- Gerente: ver_documento + movimientos

-- Administrador de Sistema
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorSistema', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'gestionar_seguridad', 'ver_movimientos')
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

-- Administrador de Documentos
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'AdministradorDocumentos', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'subir_documento', 'editar_metadatos', 'borrar_documento', 'ver_movimientos')
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

-- Contador
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'Contador', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'subir_documento', 'ver_movimientos')
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

-- Gerente
INSERT INTO rol_permisos (rol, permiso_id, activo)
SELECT 'Gerente', id, true
FROM permisos WHERE codigo IN ('ver_documento', 'ver_movimientos')
ON CONFLICT (rol, permiso_id) DO UPDATE SET activo = true;

COMMIT;

-- Verificar la configuración
SELECT rp.rol, p.codigo, p.nombre, rp.activo
FROM rol_permisos rp
JOIN permisos p ON rp.permiso_id = p.id
WHERE rp.activo = true
ORDER BY rp.rol, p.codigo;
