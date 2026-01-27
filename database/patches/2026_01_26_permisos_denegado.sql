-- Patch: agrega columna faltante en usuario_permisos (denegado)
BEGIN;

ALTER TABLE usuario_permisos
  ADD COLUMN IF NOT EXISTS denegado BOOLEAN DEFAULT FALSE;

COMMIT;
