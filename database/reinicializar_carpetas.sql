-- =====================================================
-- SCRIPT DE REINICIO TOTAL - SOLO GESTIONES RAÍZ
-- =====================================================
-- Este script:
-- 1. ELIMINA ABSOLUTAMENTE TODO el contenido de las tablas de gestión
-- 2. Crea ÚNICAMENTE las carpetas raíz de Gestión 2025 y 2026
-- =====================================================

-- =====================================================
-- PASO 1: LIMPIEZA TOTAL
-- =====================================================

-- Truncar todas las tablas relacionadas con documentos y carpetas
-- CASCADE se encarga de las dependencias (alertas, anexos, movimientos, etc.)
TRUNCATE TABLE documentos, carpetas, alertas, anexos, movimientos, historial_documento, documento_palabras_clave CASCADE;

-- Reiniciar los contadores de ID
ALTER SEQUENCE carpetas_id_seq RESTART WITH 1;
ALTER SEQUENCE documentos_id_seq RESTART WITH 1;

-- =====================================================
-- PASO 2: INSERTAR SOLO GESTIONES
-- =====================================================

INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, fecha_creacion) VALUES
('Gestión 2025', 'G-2025', '2025', 'Carpeta raíz principal para la gestión 2025', NULL, NOW()),
('Gestión 2026', 'G-2026', '2026', 'Carpeta raíz principal para la gestión 2026', NULL, NOW());

-- =====================================================
-- PASO 3: VERIFICACIÓN
-- =====================================================

SELECT id, nombre, codigo, gestion, fecha_creacion 
FROM carpetas 
ORDER BY gestion;
