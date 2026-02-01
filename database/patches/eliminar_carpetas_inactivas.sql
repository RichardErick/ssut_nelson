-- Eliminar carpetas inactivas (soft-deleted) para poder volver a crear
-- carpetas con el mismo nombre y gestión.
--
-- Motivo: Al "borrar" desde la pantalla se hace borrado lógico (activo = false).
-- La tabla carpetas tiene UNIQUE(nombre, gestion, carpeta_padre_id), así que
-- una carpeta inactiva sigue bloqueando crear otra con el mismo nombre.
--
-- Este script borra físicamente las filas con activo = false (primero hijas,
-- luego padres para no violar la FK carpeta_padre_id).

DO $$
DECLARE
  r integer;
BEGIN
  LOOP
    -- Borrar carpetas inactivas que no tienen hijas inactivas (hojas primero)
    DELETE FROM carpetas
    WHERE activo = false
      AND id IN (
        SELECT c.id
        FROM carpetas c
        WHERE c.activo = false
          AND NOT EXISTS (
            SELECT 1 FROM carpetas h
            WHERE h.carpeta_padre_id = c.id AND h.activo = false
          )
      );
    GET DIAGNOSTICS r = ROW_COUNT;
    EXIT WHEN r = 0;
  END LOOP;
END $$;

-- Ver cuántas carpetas activas quedan (opcional)
-- SELECT COUNT(*) AS carpetas_activas FROM carpetas WHERE activo = true;
