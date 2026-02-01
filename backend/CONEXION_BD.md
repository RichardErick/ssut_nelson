# Dónde cambiar la conexión a la base de datos

La conexión a PostgreSQL se configura en el **backend**. Tu amigo (o quien clone el proyecto) debe editar estos archivos con **su** Host, Usuario y Contraseña de PostgreSQL.

## Archivos a editar

1. **`backend/appsettings.json`**  
   Sección `ConnectionStrings`:
   - `DefaultConnection`
   - `InstitutionalConnection`

2. **`backend/appsettings.Development.json`**  
   Misma sección (se usa en desarrollo).

## Formato de la cadena de conexión

```
Host=localhost;Database=ssut_gestion_documental;Username=postgres;Password=TU_CONTRASEÑA;Port=5432
```

| Parte        | Qué es                          | Ejemplo / nota                          |
|-------------|----------------------------------|-----------------------------------------|
| **Host**    | Servidor de PostgreSQL           | `localhost` o IP del servidor           |
| **Database**| Nombre de la base                | `ssut_gestion_documental`               |
| **Username**| Usuario de PostgreSQL            | `postgres` u otro usuario                |
| **Password**| Contraseña de ese usuario        | La que puso al instalar/configurar PG   |
| **Port**    | Puerto de PostgreSQL             | `5432` (por defecto)                    |

## Ejemplo para tu amigo

Si en su PC PostgreSQL tiene usuario `postgres` y contraseña `nel432432` (o la que use):

En **`backend/appsettings.json`** y **`backend/appsettings.Development.json`**:

```json
"ConnectionStrings": {
  "DefaultConnection": "Host=localhost;Database=ssut_gestion_documental;Username=postgres;Password=nel432432;Port=5432",
  "InstitutionalConnection": "Host=localhost;Database=ssut_gestion_documental;Username=postgres;Password=nel432432;Port=5432"
}
```

Guarda los archivos y vuelve a ejecutar el backend (`dotnet run` en la carpeta `backend`).

## Nota

- Esta contraseña es la del **usuario de PostgreSQL** (acceso al servidor de BD), no la del usuario de la app (login en la pantalla).
- Si no quieres dejar la contraseña en el repo, puedes usar variables de entorno o `appsettings.Development.json` y añadir ese archivo al `.gitignore` (solo en tu máquina cada uno tiene su copia).
