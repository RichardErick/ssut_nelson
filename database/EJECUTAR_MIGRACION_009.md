# Si ves el error "no existe la columna u.reset_token"

El backend espera las columnas `reset_token` y `reset_token_expiry` en la tabla `usuarios`. Hay que ejecutar la migración **009** una sola vez.

## Opción 1: Con psql (línea de comandos)

Desde la raíz del proyecto (donde está esta carpeta `database`):

```bash
psql -U postgres -d ssut_gestion_documental -f database/migrations/009_add_password_reset.sql
```

En Windows (PowerShell), si `psql` está en el PATH:

```powershell
psql -U postgres -d ssut_gestion_documental -f database\migrations\009_add_password_reset.sql
```

Ajusta `-U postgres` y el nombre de la base `ssut_gestion_documental` si usas otro usuario o base.

## Opción 2: Desde pgAdmin o DBeaver

1. Conéctate a la base `ssut_gestion_documental`.
2. Abre un editor SQL y pega el contenido del archivo `database/migrations/009_add_password_reset.sql`:

```sql
-- Recuperación de contraseña por correo: token y vencimiento en usuarios
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS reset_token VARCHAR(255) NULL;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS reset_token_expiry TIMESTAMP NULL;
COMMENT ON COLUMN usuarios.reset_token IS 'Token para restablecer contraseña (enlace por correo)';
COMMENT ON COLUMN usuarios.reset_token_expiry IS 'Vencimiento del token (ej. 1 hora)';
```

3. Ejecuta el script.

Después de ejecutarlo, reinicia el backend y el error "no existe la columna u.reset_token" debería desaparecer.
