-- Base de datos para Sistema de Gestión Documental SSUT
-- PostgreSQL

-- Crear base de datos (ejecutar manualmente si es necesario)
-- CREATE DATABASE ssut_gestion_documental;

-- Tabla de Áreas
CREATE TABLE IF NOT EXISTS areas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(20),
    descripcion VARCHAR(300),
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de Tipos de Documento
CREATE TABLE IF NOT EXISTS tipos_documento (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(20),
    descripcion VARCHAR(300),
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de Usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
    nombre_completo VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(30) DEFAULT 'Usuario',
    area_id INTEGER REFERENCES areas(id),
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de Documentos
CREATE TABLE IF NOT EXISTS documentos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    numero_correlativo VARCHAR(50) NOT NULL,
    tipo_documento_id INTEGER NOT NULL REFERENCES tipos_documento(id),
    area_origen_id INTEGER NOT NULL REFERENCES areas(id),
    gestion VARCHAR(4) NOT NULL,
    fecha_documento DATE NOT NULL,
    descripcion VARCHAR(500),
    responsable_id INTEGER REFERENCES usuarios(id),
    codigo_qr VARCHAR(255),
    ubicacion_fisica VARCHAR(200),
    estado VARCHAR(20) DEFAULT 'Activo',
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP
);

-- Tabla de Movimientos
CREATE TABLE IF NOT EXISTS movimientos (
    id SERIAL PRIMARY KEY,
    documento_id INTEGER NOT NULL REFERENCES documentos(id),
    tipo_movimiento VARCHAR(20) NOT NULL,
    area_origen_id INTEGER REFERENCES areas(id),
    area_destino_id INTEGER REFERENCES areas(id),
    usuario_id INTEGER REFERENCES usuarios(id),
    observaciones VARCHAR(500),
    fecha_movimiento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_devolucion TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'Activo'
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_documentos_codigo ON documentos(codigo);
CREATE INDEX IF NOT EXISTS idx_documentos_gestion_correlativo ON documentos(gestion, numero_correlativo);
CREATE INDEX IF NOT EXISTS idx_documentos_tipo ON documentos(tipo_documento_id);
CREATE INDEX IF NOT EXISTS idx_documentos_area ON documentos(area_origen_id);
CREATE INDEX IF NOT EXISTS idx_documentos_qr ON documentos(codigo_qr);
CREATE INDEX IF NOT EXISTS idx_movimientos_documento ON movimientos(documento_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON movimientos(fecha_movimiento);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON movimientos(tipo_movimiento);

-- Datos iniciales
INSERT INTO areas (nombre, codigo, descripcion) VALUES
('Administración', 'ADM', 'Área de administración general'),
('Contabilidad', 'CONT', 'Área de contabilidad y finanzas'),
('Recursos Humanos', 'RH', 'Área de recursos humanos'),
('Archivo', 'ARCH', 'Área de archivo documental')
ON CONFLICT DO NOTHING;

INSERT INTO tipos_documento (nombre, codigo, descripcion) VALUES
('Comprobante de Ingreso', 'CI', 'Comprobantes de ingresos contables'),
('Comprobante de Egreso', 'CE', 'Comprobantes de egresos contables'),
('Memorándum', 'MEM', 'Memorándums administrativos'),
('Oficio', 'OF', 'Oficios institucionales'),
('Resolución', 'RES', 'Resoluciones administrativas')
ON CONFLICT DO NOTHING;

-- Usuario administrador por defecto (admin/admin123, doc_admin/admin; backend acepta texto plano como fallback)
INSERT INTO usuarios (nombre_usuario, nombre_completo, email, password_hash, rol, area_id) VALUES
('admin', 'Administrador del Sistema', 'admin@ssut.edu.bo', 'admin123', 'Administrador', 1),
('doc_admin', 'Administrador de Documentos', 'docadmin@ssut.edu.bo', 'admin', 'AdministradorDocumentos', 4)
ON CONFLICT DO NOTHING;

-- Tabla de Anexos (Archivos digitales)
CREATE TABLE IF NOT EXISTS anexos (
    id SERIAL PRIMARY KEY,
    documento_id INTEGER NOT NULL REFERENCES documentos(id),
    nombre_archivo VARCHAR(255) NOT NULL,
    extension VARCHAR(10),
    tamano_bytes BIGINT,
    url_archivo VARCHAR(500),
    tipo_contenido VARCHAR(100),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de Historial de Documentos
CREATE TABLE IF NOT EXISTS historial_documento (
    id SERIAL PRIMARY KEY,
    documento_id INTEGER NOT NULL REFERENCES documentos(id),
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_id INTEGER REFERENCES usuarios(id),
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    area_anterior_id INTEGER REFERENCES areas(id),
    area_nueva_id INTEGER REFERENCES areas(id),
    observacion VARCHAR(500)
);

-- Tabla de Auditoría (Logs de acciones)
CREATE TABLE IF NOT EXISTS auditoria (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    accion VARCHAR(100) NOT NULL,
    tabla_afectada VARCHAR(50),
    registro_id INTEGER,
    detalle TEXT,
    ip_address VARCHAR(50),
    fecha_accion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para las nuevas tablas
CREATE INDEX IF NOT EXISTS idx_anexos_documento ON anexos(documento_id);
CREATE INDEX IF NOT EXISTS idx_historial_documento ON historial_documento(documento_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria(usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria(fecha_accion);

