-- Pregunta secreta obligatoria en registro; usada para recuperar contraseña
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS pregunta_secreta_id INTEGER NULL;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS respuesta_secreta_hash VARCHAR(255) NULL;
COMMENT ON COLUMN usuarios.pregunta_secreta_id IS 'ID de la pregunta de seguridad elegida (1-N, ver lista en API)';
COMMENT ON COLUMN usuarios.respuesta_secreta_hash IS 'Hash de la respuesta de seguridad';
