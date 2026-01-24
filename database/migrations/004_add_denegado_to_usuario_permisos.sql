-- Migración: Agregar columna 'denegado' a usuario_permisos
-- Fecha: 2026-01-24
-- Descripción: Permite denegar explícitamente permisos heredados de roles

ALTER TABLE usuario_permisos
ADD COLUMN IF NOT EXISTS denegado BOOLEAN DEFAULT FALSE;

-- Actualizar registros existentes para tener valor por defecto
UPDATE usuario_permisos SET denegado = FALSE WHERE denegado IS NULL;
