-- =====================================================
-- INSERTAR CARPETAS PARA GESTIÓN 2025 Y 2026
-- =====================================================
-- Este script crea la estructura de carpetas que necesitas:
-- Gestión 2025 / Gestión 2026
--   └── Comprobante de Egreso
--       ├── Egresos (con rangos)
--       ├── Ingresos (con rangos)
--       └── etc.

-- =====================================================
-- CARPETAS PRINCIPALES (GESTIÓN 2025)
-- =====================================================

-- Carpeta principal: Comprobante de Egreso para 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) VALUES
('Comprobante de Egreso', 'CE', '2025', 'Carpeta principal de comprobantes de egreso para la gestión 2025', NULL)
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Carpeta principal: Comprobante de Ingreso para 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) VALUES
('Comprobante de Ingreso', 'CI', '2025', 'Carpeta principal de comprobantes de ingreso para la gestión 2025', NULL)
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- =====================================================
-- SUBCARPETAS CON RANGOS (GESTIÓN 2025 - EGRESOS)
-- =====================================================

-- Subcarpeta Egresos 1-50 dentro de Comprobante de Egreso 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Egresos 1-50', 'EGR-1-50', '2025', 'Comprobantes de egreso del 1 al 50', id, 1, 50
FROM carpetas WHERE nombre = 'Comprobante de Egreso' AND gestion = '2025' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Subcarpeta Egresos 51-100 dentro de Comprobante de Egreso 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Egresos 51-100', 'EGR-51-100', '2025', 'Comprobantes de egreso del 51 al 100', id, 51, 100
FROM carpetas WHERE nombre = 'Comprobante de Egreso' AND gestion = '2025' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Subcarpeta Egresos 101-150 dentro de Comprobante de Egreso 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Egresos 101-150', 'EGR-101-150', '2025', 'Comprobantes de egreso del 101 al 150', id, 101, 150
FROM carpetas WHERE nombre = 'Comprobante de Egreso' AND gestion = '2025' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- =====================================================
-- SUBCARPETAS CON RANGOS (GESTIÓN 2025 - INGRESOS)
-- =====================================================

-- Subcarpeta Ingresos 1-50 dentro de Comprobante de Ingreso 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Ingresos 1-50', 'ING-1-50', '2025', 'Comprobantes de ingreso del 1 al 50', id, 1, 50
FROM carpetas WHERE nombre = 'Comprobante de Ingreso' AND gestion = '2025' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Subcarpeta Ingresos 51-100 dentro de Comprobante de Ingreso 2025
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Ingresos 51-100', 'ING-51-100', '2025', 'Comprobantes de ingreso del 51 al 100', id, 51, 100
FROM carpetas WHERE nombre = 'Comprobante de Ingreso' AND gestion = '2025' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- =====================================================
-- CARPETAS PRINCIPALES (GESTIÓN 2026)
-- =====================================================

-- Carpeta principal: Comprobante de Egreso para 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) VALUES
('Comprobante de Egreso', 'CE', '2026', 'Carpeta principal de comprobantes de egreso para la gestión 2026', NULL)
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Carpeta principal: Comprobante de Ingreso para 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id) VALUES
('Comprobante de Ingreso', 'CI', '2026', 'Carpeta principal de comprobantes de ingreso para la gestión 2026', NULL)
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- =====================================================
-- SUBCARPETAS CON RANGOS (GESTIÓN 2026 - EGRESOS)
-- =====================================================

-- Subcarpeta Egresos 1-50 dentro de Comprobante de Egreso 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Egresos 1-50', 'EGR-1-50', '2026', 'Comprobantes de egreso del 1 al 50', id, 1, 50
FROM carpetas WHERE nombre = 'Comprobante de Egreso' AND gestion = '2026' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Subcarpeta Egresos 51-100 dentro de Comprobante de Egreso 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Egresos 51-100', 'EGR-51-100', '2026', 'Comprobantes de egreso del 51 al 100', id, 51, 100
FROM carpetas WHERE nombre = 'Comprobante de Egreso' AND gestion = '2026' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Subcarpeta Egresos 101-150 dentro de Comprobante de Egreso 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Egresos 101-150', 'EGR-101-150', '2026', 'Comprobantes de egreso del 101 al 150', id, 101, 150
FROM carpetas WHERE nombre = 'Comprobante de Egreso' AND gestion = '2026' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- =====================================================
-- SUBCARPETAS CON RANGOS (GESTIÓN 2026 - INGRESOS)
-- =====================================================

-- Subcarpeta Ingresos 1-50 dentro de Comprobante de Ingreso 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Ingresos 1-50', 'ING-1-50', '2026', 'Comprobantes de ingreso del 1 al 50', id, 1, 50
FROM carpetas WHERE nombre = 'Comprobante de Ingreso' AND gestion = '2026' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- Subcarpeta Ingresos 51-100 dentro de Comprobante de Ingreso 2026
INSERT INTO carpetas (nombre, codigo, gestion, descripcion, carpeta_padre_id, rango_inicio, rango_fin) 
SELECT 'Ingresos 51-100', 'ING-51-100', '2026', 'Comprobantes de ingreso del 51 al 100', id, 51, 100
FROM carpetas WHERE nombre = 'Comprobante de Ingreso' AND gestion = '2026' AND carpeta_padre_id IS NULL
ON CONFLICT (nombre, gestion, carpeta_padre_id) DO NOTHING;

-- =====================================================
-- VERIFICAR DATOS INSERTADOS
-- =====================================================

-- Ver todas las carpetas principales de 2025 y 2026
SELECT id, nombre, codigo, gestion, carpeta_padre_id, rango_inicio, rango_fin
FROM carpetas
WHERE gestion IN ('2025', '2026')
ORDER BY gestion, carpeta_padre_id NULLS FIRST, nombre;
