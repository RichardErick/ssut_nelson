# Instrucciones para corregir el enum rol_enum

## Problema
El enum `rol_enum` en PostgreSQL no tiene todos los valores que el enum `UsuarioRol` en C#. 
Faltan los valores: `ArchivoCentral` y `TramiteDocumentario`.

## Solución

Ejecuta el script SQL `fix_rol_enum.sql` en tu base de datos PostgreSQL.

### Opción 1: Usando psql (línea de comandos)
```bash
psql -U postgres -d ssut_gestion_documental -f database/fix_rol_enum.sql
```

### Opción 2: Usando pgAdmin o cualquier cliente PostgreSQL
1. Abre pgAdmin o tu cliente PostgreSQL favorito
2. Conéctate a la base de datos `ssut_gestion_documental`
3. Abre el archivo `database/fix_rol_enum.sql`
4. Ejecuta el script completo

### Opción 3: Usando psql desde PowerShell (Windows)
```powershell
cd "C:\Users\ERICK\Desktop\tareas bro\Sistema_info_web_gestion"
psql -U postgres -d ssut_gestion_documental -f database\fix_rol_enum.sql
```

## Verificación

Después de ejecutar el script, verifica que el enum tenga estos 6 valores:
1. Administrador
2. AdministradorDocumentos
3. Usuario
4. Supervisor
5. ArchivoCentral
6. TramiteDocumentario

Puedes verificar ejecutando:
```sql
SELECT enumlabel, enumsortorder 
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'rol_enum')
ORDER BY enumsortorder;
```

## Nota importante

Después de ejecutar el script, **reinicia el backend** para que los cambios surtan efecto.

