-- Minimal DB patch (only missing columns reported in logs)
BEGIN;

-- usuario_permisos.denegado
DO $$
BEGIN
    IF to_regclass('public.usuario_permisos') IS NOT NULL THEN
        ALTER TABLE usuario_permisos ADD COLUMN IF NOT EXISTS denegado BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- palabras_clave.descripcion + activo
DO $$
BEGIN
    IF to_regclass('public.palabras_clave') IS NOT NULL THEN
        ALTER TABLE palabras_clave ADD COLUMN IF NOT EXISTS descripcion TEXT;
        ALTER TABLE palabras_clave ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
    END IF;
END $$;

COMMIT;
