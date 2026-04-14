-- Script de datos de ejemplo para desarrollo y pruebas
-- Ejecutar después de schema.sql

-- Insertar más áreas si es necesario
INSERT INTO areas (nombre, codigo, descripcion) VALUES
('Dirección General', 'DIR', 'Dirección general de la institución'),
('Secretaría', 'SEC', 'Secretaría administrativa')
ON CONFLICT DO NOTHING;

-- Insertar más tipos de documento
INSERT INTO tipos_documento (nombre, codigo, descripcion) VALUES
('Factura', 'FAC', 'Facturas de compras'),
('Recibo', 'REC', 'Recibos de pago'),
('Contrato', 'CONT', 'Contratos institucionales')
ON CONFLICT DO NOTHING;

-- Documentos de ejemplo (opcional, solo para desarrollo)
-- INSERT INTO documentos (codigo, numero_correlativo, tipo_documento_id, area_origen_id, gestion, fecha_documento, descripcion, ubicacion_fisica, estado)
-- VALUES
-- ('CI-2025-000001', '001', 1, 2, '2025', '2025-01-15', 'Comprobante de ingreso ejemplo', 'Folder I - Estante 1', 'Activo');

