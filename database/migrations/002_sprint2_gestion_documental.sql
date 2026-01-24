-- Migración Sprint 2: Gestión Documental Completa
-- Fecha: 2026-01-23
-- Descripción: Agrega tablas para carpetas, subcarpetas, palabras clave y mejora la tabla documentos

-- =====================================================
-- 1. TABLA DE CARPETAS (Clasificación de documentos)
-- =====================================================
CREATE TABLE IF NOT EXISTS carpetas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(20),
    gestion VARCHAR(4) NOT NULL,
    descripcion VARCHAR(300),
    carpeta_padre_id INTEGER REFERENCES carpetas(id) ON DELETE CASCADE,
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_creacion_id INTEGER REFERENCES usuarios(id),
    UNIQUE(nombre, gestion, carpeta_padre_id)
);

-- Índices para carpetas
CREATE INDEX IF NOT EXISTS idx_carpetas_gestion ON carpetas(gestion);
CREATE INDEX IF NOT EXISTS idx_carpetas_padre ON carpetas(carpeta_padre_id);
CREATE INDEX IF NOT EXISTS idx_carpetas_activo ON carpetas(activo);

-- =====================================================
-- 2. TABLA DE PALABRAS CLAVE (Tags para documentos)
-- =====================================================
CREATE TABLE IF NOT EXISTS palabras_clave (
    id SERIAL PRIMARY KEY,
    palabra VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200),
    activo BOOLEAN DEFAULT TRUE
);

-- =====================================================
-- 3. TABLA RELACIÓN DOCUMENTOS - PALABRAS CLAVE
-- =====================================================
CREATE TABLE IF NOT EXISTS documento_palabras_clave (
    documento_id INTEGER NOT NULL REFERENCES documentos(id) ON DELETE CASCADE,
    palabra_clave_id INTEGER NOT NULL REFERENCES palabras_clave(id) ON DELETE CASCADE,
    PRIMARY KEY (documento_id, palabra_clave_id)
);

CREATE INDEX IF NOT EXISTS idx_doc_palabras_documento ON documento_palabras_clave(documento_id);
CREATE INDEX IF NOT EXISTS idx_doc_palabras_palabra ON documento_palabras_clave(palabra_clave_id);

-- =====================================================
-- 4. AGREGAR CAMPOS A TABLA DOCUMENTOS
-- =====================================================
-- Agregar carpeta_id si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'documentos' AND column_name = 'carpeta_id'
    ) THEN
        ALTER TABLE documentos ADD COLUMN carpeta_id INTEGER REFERENCES carpetas(id);
    END IF;
END $$;

-- Agregar id_documento único (para QR y referencias externas)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'documentos' AND column_name = 'id_documento'
    ) THEN
        ALTER TABLE documentos ADD COLUMN id_documento VARCHAR(100) UNIQUE;
    END IF;
END $$;

-- Agregar url_qr para almacenar la imagen del QR
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'documentos' AND column_name = 'url_qr'
    ) THEN
        ALTER TABLE documentos ADD COLUMN url_qr VARCHAR(500);
    END IF;
END $$;

-- Agregar campo activo para borrado lógico
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'documentos' AND column_name = 'activo'
    ) THEN
        ALTER TABLE documentos ADD COLUMN activo BOOLEAN DEFAULT TRUE;
    END IF;
END $$;

-- Crear índices adicionales para documentos
CREATE INDEX IF NOT EXISTS idx_documentos_carpeta ON documentos(carpeta_id);
CREATE INDEX IF NOT EXISTS idx_documentos_id_documento ON documentos(id_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_activo ON documentos(activo);
CREATE INDEX IF NOT EXISTS idx_documentos_fecha ON documentos(fecha_documento);
CREATE INDEX IF NOT EXISTS idx_documentos_responsable ON documentos(responsable_id);

-- =====================================================
-- 5. FUNCIÓN PARA GENERAR ID_DOCUMENTO ÚNICO
-- =====================================================
CREATE OR REPLACE FUNCTION generar_id_documento(
    p_tipo_codigo VARCHAR,
    p_area_codigo VARCHAR,
    p_gestion VARCHAR,
    p_correlativo VARCHAR
) RETURNS VARCHAR AS $$
BEGIN
    -- Formato: TIPO-AREA-GESTION-CORRELATIVO
    -- Ejemplo: CI-ADM-2026-0001
    RETURN CONCAT(
        UPPER(COALESCE(p_tipo_codigo, 'DOC')),
        '-',
        UPPER(COALESCE(p_area_codigo, 'GEN')),
        '-',
        p_gestion,
        '-',
        LPAD(p_correlativo, 4, '0')
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. TRIGGER PARA GENERAR ID_DOCUMENTO AUTOMÁTICAMENTE
-- =====================================================
CREATE OR REPLACE FUNCTION trigger_generar_id_documento()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_codigo VARCHAR;
    v_area_codigo VARCHAR;
BEGIN
    -- Solo generar si no existe id_documento
    IF NEW.id_documento IS NULL OR NEW.id_documento = '' THEN
        -- Obtener código del tipo de documento
        SELECT codigo INTO v_tipo_codigo
        FROM tipos_documento
        WHERE id = NEW.tipo_documento_id;

        -- Obtener código del área
        SELECT codigo INTO v_area_codigo
        FROM areas
        WHERE id = NEW.area_origen_id;

        -- Generar id_documento
        NEW.id_documento := generar_id_documento(
            v_tipo_codigo,
            v_area_codigo,
            NEW.gestion,
            NEW.numero_correlativo
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger si no existe
DROP TRIGGER IF EXISTS trg_generar_id_documento ON documentos;
CREATE TRIGGER trg_generar_id_documento
    BEFORE INSERT OR UPDATE ON documentos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_generar_id_documento();

-- =====================================================
-- 7. ACTUALIZAR TABLA HISTORIAL_DOCUMENTO
-- =====================================================
-- Agregar campo carpeta_anterior y carpeta_nueva
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'historial_documento' AND column_name = 'carpeta_anterior_id'
    ) THEN
        ALTER TABLE historial_documento ADD COLUMN carpeta_anterior_id INTEGER REFERENCES carpetas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'historial_documento' AND column_name = 'carpeta_nueva_id'
    ) THEN
        ALTER TABLE historial_documento ADD COLUMN carpeta_nueva_id INTEGER REFERENCES carpetas(id);
    END IF;
END $$;

-- =====================================================
-- 8. DATOS INICIALES - CARPETAS POR DEFECTO
-- =====================================================
-- Carpetas para gestión 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion) VALUES
('Comprobantes', 'COMP', '2026', 'Comprobantes contables'),
('Correspondencia', 'CORR', '2026', 'Correspondencia oficial'),
('Resoluciones', 'RES', '2026', 'Resoluciones administrativas'),
('Contratos', 'CONT', '2026', 'Contratos y convenios'),
('Archivo General', 'ARCH', '2026', 'Archivo general')
ON CONFLICT DO NOTHING;

-- Subcarpetas para Comprobantes
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) 
SELECT 'Ingresos', 'ING', '2026', 'Comprobantes de ingreso', id 
FROM carpetas WHERE codigo = 'COMP' AND gestion = '2026'
ON CONFLICT DO NOTHING;

INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) 
SELECT 'Egresos', 'EGR', '2026', 'Comprobantes de egreso', id 
FROM carpetas WHERE codigo = 'COMP' AND gestion = '2026'
ON CONFLICT DO NOTHING;

-- Subcarpetas para Correspondencia
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) 
SELECT 'Oficios', 'OF', '2026', 'Oficios institucionales', id 
FROM carpetas WHERE codigo = 'CORR' AND gestion = '2026'
ON CONFLICT DO NOTHING;

INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) 
SELECT 'Memorándums', 'MEM', '2026', 'Memorándums administrativos', id 
FROM carpetas WHERE codigo = 'CORR' AND gestion = '2026'
ON CONFLICT DO NOTHING;

-- =====================================================
-- 9. PALABRAS CLAVE INICIALES
-- =====================================================
INSERT INTO palabras_clave (palabra, descripcion) VALUES
('urgente', 'Documentos de atención urgente'),
('confidencial', 'Documentos confidenciales'),
('público', 'Documentos de acceso público'),
('interno', 'Documentos de uso interno'),
('externo', 'Documentos para entidades externas'),
('financiero', 'Documentos financieros'),
('legal', 'Documentos legales'),
('administrativo', 'Documentos administrativos'),
('técnico', 'Documentos técnicos'),
('académico', 'Documentos académicos')
ON CONFLICT DO NOTHING;

-- =====================================================
-- 10. VISTA PARA BÚSQUEDA AVANZADA
-- =====================================================
CREATE OR REPLACE VIEW vista_documentos_completa AS
SELECT 
    d.id,
    d.id_documento,
    d.codigo,
    d.numero_correlativo,
    d.gestion,
    d.fecha_documento,
    d.descripcion,
    d.codigo_qr,
    d.url_qr,
    d.ubicacion_fisica,
    d.estado,
    d.activo,
    d.fecha_registro,
    d.fecha_actualizacion,
    -- Tipo de documento
    td.id AS tipo_documento_id,
    td.nombre AS tipo_documento_nombre,
    td.codigo AS tipo_documento_codigo,
    -- Área origen
    a.id AS area_origen_id,
    a.nombre AS area_origen_nombre,
    a.codigo AS area_origen_codigo,
    -- Responsable
    u.id AS responsable_id,
    u.nombre_completo AS responsable_nombre,
    u.nombre_usuario AS responsable_usuario,
    -- Carpeta
    c.id AS carpeta_id,
    c.nombre AS carpeta_nombre,
    c.codigo AS carpeta_codigo,
    c.carpeta_padre_id,
    cp.nombre AS carpeta_padre_nombre,
    -- Palabras clave (concatenadas)
    STRING_AGG(DISTINCT pc.palabra, ', ' ORDER BY pc.palabra) AS palabras_clave
FROM documentos d
LEFT JOIN tipos_documento td ON d.tipo_documento_id = td.id
LEFT JOIN areas a ON d.area_origen_id = a.id
LEFT JOIN usuarios u ON d.responsable_id = u.id
LEFT JOIN carpetas c ON d.carpeta_id = c.id
LEFT JOIN carpetas cp ON c.carpeta_padre_id = cp.id
LEFT JOIN documento_palabras_clave dpc ON d.id = dpc.documento_id
LEFT JOIN palabras_clave pc ON dpc.palabra_clave_id = pc.id
GROUP BY 
    d.id, d.id_documento, d.codigo, d.numero_correlativo, d.gestion,
    d.fecha_documento, d.descripcion, d.codigo_qr, d.url_qr,
    d.ubicacion_fisica, d.estado, d.activo, d.fecha_registro, d.fecha_actualizacion,
    td.id, td.nombre, td.codigo,
    a.id, a.nombre, a.codigo,
    u.id, u.nombre_completo, u.nombre_usuario,
    c.id, c.nombre, c.codigo, c.carpeta_padre_id,
    cp.nombre;

-- =====================================================
-- COMENTARIOS FINALES
-- =====================================================
COMMENT ON TABLE carpetas IS 'Clasificación jerárquica de documentos por gestión';
COMMENT ON TABLE palabras_clave IS 'Etiquetas para categorizar documentos';
COMMENT ON TABLE documento_palabras_clave IS 'Relación muchos a muchos entre documentos y palabras clave';
COMMENT ON COLUMN documentos.id_documento IS 'Identificador único legible del documento (formato: TIPO-AREA-GESTION-CORRELATIVO)';
COMMENT ON COLUMN documentos.carpeta_id IS 'Carpeta donde está clasificado el documento';
COMMENT ON COLUMN documentos.url_qr IS 'URL de la imagen del código QR generado';
COMMENT ON VIEW vista_documentos_completa IS 'Vista completa de documentos con todas sus relaciones para búsqueda avanzada';
