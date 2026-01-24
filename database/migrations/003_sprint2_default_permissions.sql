-- Migración Sprint 2: Permisos por Defecto para Roles
-- Fecha: 2026-01-24
-- Descripción: Define los permisos por defecto para cada rol del sistema

-- =====================================================
-- 1. CREACIÓN DE PERMISOS BÁSICOS
-- =====================================================
INSERT INTO permisos (nombre, codigo, modulo, descripcion) VALUES
-- Módulo Documentos
('Ver Documentos', 'documentos.ver', 'DOCUMENTOS', 'Permite visualizar la lista y detalles de documentos'),
('Crear Documentos', 'documentos.crear', 'DOCUMENTOS', 'Permite registrar nuevos documentos'),
('Editar Documentos', 'documentos.editar', 'DOCUMENTOS', 'Permite modificar documentos existentes'),
('Eliminar Documentos', 'documentos.eliminar', 'DOCUMENTOS', 'Permite eliminar documentos (lógicamente)'),
('Generar QR', 'documentos.qr', 'DOCUMENTOS', 'Permite generar códigos QR para documentos'),

-- Módulo Movimientos
('Ver Movimientos', 'movimientos.ver', 'MOVIMIENTOS', 'Permite visualizar el historial de movimientos'),
('Registrar Movimiento', 'movimientos.crear', 'MOVIMIENTOS', 'Permite registrar nuevos movimientos/derivaciones'),

-- Módulo Carpetas
('Ver Carpetas', 'carpetas.ver', 'CARPETAS', 'Permite visualizar la estructura de carpetas'),
('Gestionar Carpetas', 'carpetas.gestionar', 'CARPETAS', 'Permite crear, editar y eliminar carpetas'),

-- Módulo Reportes
('Ver Reportes', 'reportes.ver', 'REPORTES', 'Permite visualizar reportes y estadísticas'),
('Exportar Reportes', 'reportes.exportar', 'REPORTES', 'Permite exportar reportes a PDF/Excel'),

-- Módulo Administración
('Gestionar Usuarios', 'admin.usuarios', 'ADMINISTRACION', 'Permite gestionar usuarios del sistema'),
('Gestionar Roles', 'admin.roles', 'ADMINISTRACION', 'Permite gestionar roles y permisos'),
('Ver Auditoría', 'admin.auditoria', 'ADMINISTRACION', 'Permite visualizar logs de auditoría')
ON CONFLICT (codigo) DO NOTHING;

-- =====================================================
-- 2. ASIGNACIÓN DE PERMISOS A ROLES (ROL_PERMISOS)
-- =====================================================

-- Limpiar asignaciones previas para evitar duplicados masivos si se re-ejecuta
-- (Opcional, mejor usar ON CONFLICT)

-- -----------------------------------------------------
-- ROL: ADMINISTRADOR DEL SISTEMA (Todos los permisos)
-- -----------------------------------------------------
INSERT INTO rol_permisos (rol, permiso_id)
SELECT 'AdministradorSistema', id FROM permisos
ON CONFLICT (rol, permiso_id) DO NOTHING;

-- -----------------------------------------------------
-- ROL: ADMINISTRADOR DE DOCUMENTOS (Gestión total de documentos, sin gestión de usuarios)
-- -----------------------------------------------------
INSERT INTO rol_permisos (rol, permiso_id)
SELECT 'AdministradorDocumentos', id FROM permisos 
WHERE modulo IN ('DOCUMENTOS', 'MOVIMIENTOS', 'CARPETAS', 'REPORTES')
ON CONFLICT (rol, permiso_id) DO NOTHING;

-- -----------------------------------------------------
-- ROL: CONTADOR (Operativo: Ver, Crear, Editar, Mover)
-- -----------------------------------------------------
INSERT INTO rol_permisos (rol, permiso_id)
SELECT 'Contador', id FROM permisos 
WHERE codigo IN (
    'documentos.ver', 
    'documentos.crear', 
    'documentos.editar', 
    'documentos.qr',
    'movimientos.ver',
    'movimientos.crear',
    'carpetas.ver'
)
ON CONFLICT (rol, permiso_id) DO NOTHING;

-- -----------------------------------------------------
-- ROL: GERENTE (Solo lectura / Supervisión)
-- -----------------------------------------------------
INSERT INTO rol_permisos (rol, permiso_id)
SELECT 'Gerente', id FROM permisos 
WHERE codigo IN (
    'documentos.ver', 
    'movimientos.ver',
    'carpetas.ver',
    'reportes.ver',
    'reportes.exportar'
)
ON CONFLICT (rol, permiso_id) DO NOTHING;

-- =====================================================
-- 3. NOTAS
-- =====================================================
-- AdministradorSistema: Acceso total.
-- AdministradorDocumentos: Control total sobre el flujo documental, pero no toca usuarios ni auditoría global.
-- Contador: Usuario operativo principal. Crea y mueve documentos. Puede ver carpetas pero no alterarlas.
-- Gerente: Rol de consulta. Ve todo lo relacionado a documentos y reportes, pero no crea ni edita.
