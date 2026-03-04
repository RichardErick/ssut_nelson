-- Agregar área de Auditoría
-- Fecha: Marzo 4, 2026
-- Descripción: Agrega el área de Auditoría para que pueda ser seleccionada como destino en préstamos

-- Primero verificar si ya existe
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
