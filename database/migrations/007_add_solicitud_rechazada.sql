-- Usuarios rechazados por el admin no vuelven a aparecer como "pendientes" en notificaciones.
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS solicitud_rechazada BOOLEAN NOT NULL DEFAULT FALSE;
COMMENT ON COLUMN usuarios.solicitud_rechazada IS 'True si un admin rechazó la solicitud de registro; no se muestra en pendientes.';
