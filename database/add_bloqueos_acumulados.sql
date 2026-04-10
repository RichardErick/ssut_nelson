-- Agregar columna bloqueos_acumulados a la tabla usuarios
-- Esta columna cuenta cuántas veces el usuario ha sido bloqueado por intentos fallidos
-- Se usa para aumentar progresivamente el tiempo de bloqueo

ALTER TABLE usuarios
ADD COLUMN IF NOT EXISTS bloqueos_acumulados INTEGER NOT NULL DEFAULT 0;

-- Comentario para documentar
COMMENT ON COLUMN usuarios.bloqueos_acumulados IS 'Número de veces que el usuario ha sido bloqueado por intentos fallidos. Se usa para cálculo progresivo del tiempo de bloqueo.';
