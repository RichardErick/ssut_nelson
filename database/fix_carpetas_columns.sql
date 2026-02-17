-- Fix missing columns in carpetas table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carpetas' AND column_name = 'rango_inicio') THEN
        ALTER TABLE carpetas ADD COLUMN rango_inicio INTEGER;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carpetas' AND column_name = 'rango_fin') THEN
        ALTER TABLE carpetas ADD COLUMN rango_fin INTEGER;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'carpetas' AND column_name = 'tipo') THEN
        ALTER TABLE carpetas ADD COLUMN tipo VARCHAR(50);
    END IF;
END $$;
