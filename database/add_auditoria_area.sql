-- Agregar área de Auditoría
-- Fecha: Marzo 4, 2026
-- Descripción: Agrega el área de Auditoría para que pueda ser seleccionada como destino en préstamos

INSERT INTO areas (nombre, codigo, descripcion, activo) 
VALUES ('Auditoría', 'AUD', 'Área de auditoría y control', true)
ON CONFLICT (codigo) DO NOTHING;
