-- Permitir varias carpetas con el mismo nombre (misma ubicación y gestión).
-- La unicidad se valida por rango (rango_inicio, rango_fin) en código.
-- Elimina el índice único sobre (nombre, gestion, carpeta_padre_id).
-- Solo se ejecuta si la tabla carpetas existe (p. ej. tras 002_sprint2_gestion_documental.sql).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'carpetas'
  ) THEN
    -- Quitar índice único si existe
    IF EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename = 'carpetas'
        AND indexname = 'IX_carpetas_Nombre_Gestion_CarpetaPadreId'
    ) THEN
      DROP INDEX IF EXISTS public."IX_carpetas_Nombre_Gestion_CarpetaPadreId";
    END IF;
    -- Índice no único para búsquedas
    CREATE INDEX IF NOT EXISTS "IX_carpetas_Nombre_Gestion_CarpetaPadreId"
      ON public.carpetas (nombre, gestion, carpeta_padre_id);
  END IF;
END $$;
