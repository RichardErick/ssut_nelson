-- =====================================================
-- AGREGAR COLUMNAS DE RANGO A LA TABLA CARPETAS
-- =====================================================
-- Fecha: 2026-01-29
-- Descripción: Agrega las columnas rango_inicio y rango_fin para manejar rangos de documentos

-- Agregar columna rango_inicio
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'carpetas' AND column_name = 'rango_inicio'
    ) THEN
        ALTER TABLE carpetas ADD COLUMN rango_inicio INTEGER;
        COMMENT ON COLUMN carpetas.rango_inicio IS 'Número inicial del rango de documentos que contiene esta carpeta';
    END IF;
END $$;

-- Agregar columna rango_fin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'carpetas' AND column_name = 'rango_fin'
    ) THEN
        ALTER TABLE carpetas ADD COLUMN rango_fin INTEGER;
        COMMENT ON COLUMN carpetas.rango_fin IS 'Número final del rango de documentos que contiene esta carpeta';
    END IF;
END $$;

-- Agregar columna numero_carpeta (para el número romano o secuencial)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'carpetas' AND column_name = 'numero_carpeta'
    ) THEN
        ALTER TABLE carpetas ADD COLUMN numero_carpeta INTEGER;
        COMMENT ON COLUMN carpetas.numero_carpeta IS 'Número secuencial de la carpeta dentro de su nivel';
    END IF;
END $$;

-- Agregar columna codigo_romano (para almacenar el código romano si existe)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'carpetas' AND column_name = 'codigo_romano'
    ) THEN
        ALTER TABLE carpetas ADD COLUMN codigo_romano VARCHAR(20);
        COMMENT ON COLUMN carpetas.codigo_romano IS 'Código romano de la carpeta (I, II, III, etc.)';
    END IF;
END $$;

-- Crear índice compuesto para rangos
CREATE INDEX IF NOT EXISTS idx_carpetas_rango ON carpetas(rango_inicio, rango_fin) WHERE rango_inicio IS NOT NULL;

-- Verificar las nuevas columnas
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'carpetas' 
  AND column_name IN ('rango_inicio', 'rango_fin', 'numero_carpeta', 'codigo_romano')
ORDER BY column_name;
