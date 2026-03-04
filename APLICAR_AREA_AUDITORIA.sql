-- Script para agregar el área de Auditoría
-- Ejecutar este script en PostgreSQL

-- Verificar si ya existe el área de Auditoría
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM areas WHERE codigo = 'AUD') THEN
        INSERT INTO areas (nombre, codigo, descripcion, activo) 
        VALUES ('Auditoría', 'AUD', 'Área de auditoría y control', true);
        RAISE NOTICE 'Área de Auditoría agregada exitosamente';
    ELSE
        RAISE NOTICE 'El área de Auditoría ya existe';
    END IF;
END $$;

-- Verificar el resultado
SELECT id, nombre, codigo, descripcion, activo 
FROM areas 
WHERE codigo = 'AUD';
