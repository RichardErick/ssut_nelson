-- Asegura que la tabla movimientos tenga la columna fecha_devolucion (necesaria para devoluciones).
-- Ejecutar si POST /api/movimientos/devolver devuelve 500 por columna faltante.
-- Uso: psql -U postgres -d ssut_gestion_documental -f migrations/006_ensure_movimientos_devolucion.sql

ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS fecha_devolucion TIMESTAMP;
