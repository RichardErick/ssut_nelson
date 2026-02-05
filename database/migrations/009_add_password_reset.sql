-- Recuperación de contraseña por correo: token y vencimiento en usuarios
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS reset_token VARCHAR(255) NULL;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS reset_token_expiry TIMESTAMP NULL;
COMMENT ON COLUMN usuarios.reset_token IS 'Token para restablecer contraseña (enlace por correo)';
COMMENT ON COLUMN usuarios.reset_token_expiry IS 'Vencimiento del token (ej. 1 hora)';
