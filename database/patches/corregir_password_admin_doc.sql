-- Corrige contraseñas: admin -> admin123, doc_admin -> admin (texto plano, backend acepta fallback).
-- Ejecutar: psql -U postgres -d ssut_gestion_documental -f fix_doc_admin_password.sql

UPDATE usuarios SET password_hash = 'admin123' WHERE nombre_usuario = 'admin';
UPDATE usuarios SET password_hash = 'admin' WHERE nombre_usuario = 'doc_admin';

SELECT nombre_usuario, password_hash FROM usuarios WHERE nombre_usuario IN ('doc_admin', 'admin');
