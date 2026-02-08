# Cómo aplicar la migración 011 (pregunta secreta)

El error **"no existe la columna u.pregunta_secreta_id"** aparece porque la tabla `usuarios` en PostgreSQL no tiene aún las columnas de pregunta secreta.

## Qué hacer

Ejecuta el SQL de la migración **011_add_pregunta_secreta.sql** contra tu base de datos.

### Opción A – Con psql (terminal)

```bash
psql -U TU_USUARIO -d TU_BASE_DE_DATOS -f "database/migrations/011_add_pregunta_secreta.sql"
```

Sustituye:
- `TU_USUARIO` = usuario de PostgreSQL (ej: postgres)
- `TU_BASE_DE_DATOS` = nombre de la base (ej: SistemaGestionDocumental)

Ejemplo en Windows (PowerShell), desde la raíz del proyecto:

```powershell
cd "D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion"
psql -U postgres -d tu_base -f "database\migrations\011_add_pregunta_secreta.sql"
```

### Opción B – Con pgAdmin u otro cliente

1. Abre pgAdmin (o DBeaver, etc.) y conéctate a tu servidor PostgreSQL.
2. Selecciona la base de datos del proyecto.
3. Abre una ventana de consulta (Query Tool).
4. Copia y pega este SQL y ejecútalo:

```sql
-- Pregunta secreta obligatoria en registro; usada para recuperar contraseña
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS pregunta_secreta_id INTEGER NULL;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS respuesta_secreta_hash VARCHAR(255) NULL;
COMMENT ON COLUMN usuarios.pregunta_secreta_id IS 'ID de la pregunta de seguridad elegida (1-N, ver lista en API)';
COMMENT ON COLUMN usuarios.respuesta_secreta_hash IS 'Hash de la respuesta de seguridad';
```

5. Ejecuta (F5 o botón Run).

### Después

Reinicia el backend y vuelve a probar el login. El error debería desaparecer.
