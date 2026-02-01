# Scripts de Base de Datos PostgreSQL

## Instalación

1. Asegúrate de tener PostgreSQL instalado (versión 14 o superior)

2. Crea la base de datos:
```sql
CREATE DATABASE ssut_gestion_documental;
```

3. Ejecuta los scripts en orden (y migraciones si usas la estructura de carpetas):
```bash
psql -U postgres -d ssut_gestion_documental -f schema.sql
psql -U postgres -d ssut_gestion_documental -f seed_data.sql
# Si al crear subcarpetas obtienes error 500, ejecuta:
psql -U postgres -d ssut_gestion_documental -f migrations/005_add_carpetas_rangos.sql
```

## Configuración de Conexión

Actualiza la cadena de conexión en `backend/appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=ssut_gestion_documental;Username=postgres;Password=admin;Port=5432"
  }
}
```

## Estructura de Tablas

- **areas**: Áreas de la institución
- **tipos_documento**: Tipos de documentos (comprobantes, memorándums, etc.)
- **usuarios**: Usuarios del sistema
- **documentos**: Documentos registrados con sus metadatos
- **movimientos**: Registro de entrada, salida y derivación de documentos

## Migraciones (agregar tablas o columnas)

Este proyecto usa **scripts SQL manuales** en `database/migrations/` (no migraciones automáticas como Laravel). Para aplicar cambios:

1. **Crear la BD desde cero**: ejecuta `schema.sql` y luego `seed_data.sql`.
2. **Añadir columnas/tablas nuevas**: ejecuta el script correspondiente en orden:
   ```bash
   psql -U postgres -d ssut_gestion_documental -f migrations/005_add_carpetas_rangos.sql
   psql -U postgres -d ssut_gestion_documental -f migrations/006_ensure_movimientos_devolucion.sql
   ```
3. **Backend (EF Core)**: el backend usa Entity Framework con una migración inicial (`backend/Migrations/`). Si cambias el modelo en C#, puedes:
   - Crear una nueva migración: `dotnet ef migrations add NombreMigracion --project backend`
   - Aplicarla: `dotnet ef database update --project backend`
   - O bien aplicar los cambios a mano en PostgreSQL y mantener el esquema alineado con los scripts en `database/`.

Si `POST /api/movimientos/devolver` devuelve 500, suele ser por falta de la columna `fecha_devolucion` en `movimientos`. Ejecuta `migrations/006_ensure_movimientos_devolucion.sql`.

## Notas

- Los usuarios por defecto tienen contraseñas placeholder. Debes implementar un sistema de hash de contraseñas en producción.
- Los índices están optimizados para búsquedas frecuentes por código, gestión y fecha.

