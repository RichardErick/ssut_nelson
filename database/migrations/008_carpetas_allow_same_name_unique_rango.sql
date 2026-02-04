-- Permitir varias carpetas con el mismo nombre (misma ubicación y gestión).
-- La unicidad se valida por rango (rango_inicio, rango_fin) en código.
-- Elimina el índice único sobre (nombre, gestion, carpeta_padre_id).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'carpetas'
      AND indexname = 'IX_carpetas_Nombre_Gestion_CarpetaPadreId'
  ) THEN
    DROP INDEX IF EXISTS "IX_carpetas_Nombre_Gestion_CarpetaPadreId";
  END IF;
END $$;

-- Índice no único para búsquedas (opcional, EF puede recrearlo)
CREATE INDEX IF NOT EXISTS "IX_carpetas_Nombre_Gestion_CarpetaPadreId"
  ON carpetas (nombre, gestion, carpeta_padre_id);
