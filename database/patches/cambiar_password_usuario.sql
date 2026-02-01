-- Cambiar contraseña de un usuario (texto plano; el backend acepta texto plano como fallback).
--
-- 1. Edita abajo: cambia 'doc_admin' por el nombre de usuario de tu amigo
--    y 'nel432432' por la contraseña que quieras.
-- 2. Ejecuta este script en la base ssut_gestion_documental (pgAdmin, DBeaver, psql, etc.).

UPDATE usuarios
SET password_hash = 'nel432432'
WHERE nombre_usuario = 'doc_admin';

-- Verificar (opcional)
SELECT id, nombre_usuario, nombre_completo, rol
FROM usuarios
WHERE nombre_usuario = 'doc_admin';
