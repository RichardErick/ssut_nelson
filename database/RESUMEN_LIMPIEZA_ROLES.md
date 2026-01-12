# Resumen de Limpieza de Roles

## Roles Finales del Sistema

El sistema ahora solo tiene **4 roles oficiales** según la matriz de permisos:

1. **Administrador de Sistema** (`Administrador` / `AdministradorSistema`)
2. **Administrador de Documentos** (`AdministradorDocumentos`)
3. **Contador** (`Contador`)
4. **Gerente** (`Gerente`)

## Roles Eliminados

Los siguientes roles han sido eliminados del sistema:
- ❌ ArchivoCentral
- ❌ TramiteDocumentario
- ❌ Supervisor
- ❌ Usuario (genérico)

## Cambios Realizados

### Backend
- ✅ `UsuarioRol` enum actualizado - solo 4 roles
- ✅ `RolesValidos` en `UsuariosController` actualizado
- ✅ `ParseRolOrNull` actualizado para manejar solo roles válidos

### Frontend
- ✅ `UserRole` enum actualizado - solo 4 roles
- ✅ `auth_provider.dart` actualizado para parsear solo roles válidos
- ✅ `roles_permissions_screen.dart` actualizado:
  - Lista de roles actualizada
  - Funciones `_getRolDisplayName`, `_getRolIcon`, `_getRolColor` actualizadas
  - Valor por defecto cambiado a 'Contador'
- ✅ `usuario.dart` modelo actualizado - valor por defecto cambiado a 'Contador'

### Base de Datos
- ✅ Script de migración creado: `migrate_roles_cleanup.sql`

## Pasos para Completar la Migración

### 1. Ejecutar Script de Migración SQL

```sql
-- Ejecuta este script en PostgreSQL para migrar usuarios existentes
psql -U postgres -d ssut_gestion_documental -f database/migrate_roles_cleanup.sql
```

O ejecuta manualmente:

```sql
BEGIN;

-- Migrar roles antiguos a roles válidos
UPDATE usuarios SET rol = 'AdministradorDocumentos' WHERE rol = 'ArchivoCentral';
UPDATE usuarios SET rol = 'AdministradorDocumentos' WHERE rol = 'TramiteDocumentario';
UPDATE usuarios SET rol = 'Gerente' WHERE rol = 'Supervisor';
UPDATE usuarios SET rol = 'Contador' WHERE rol = 'Usuario';

-- Asignar rol por defecto a cualquier rol desconocido
UPDATE usuarios 
SET rol = 'AdministradorDocumentos'
WHERE rol NOT IN ('Administrador', 'AdministradorDocumentos', 'Contador', 'Gerente');

COMMIT;
```

### 2. Verificar Usuarios

```sql
-- Verificar que todos los usuarios tengan roles válidos
SELECT rol, COUNT(*) as cantidad
FROM usuarios
GROUP BY rol
ORDER BY rol;
```

### 3. Reiniciar Backend

```bash
cd backend
dotnet run
```

### 4. Verificar Frontend

- Iniciar sesión y verificar que los roles se muestren correctamente
- Crear un nuevo usuario y verificar que solo aparezcan los 4 roles válidos
- Verificar la pantalla de gestión de permisos

## Matriz de Permisos Final

| Rol | ver_documento | subir_documento | editar_metadatos | borrar_documento |
|-----|---------------|-----------------|------------------|------------------|
| Administrador de Sistema | ✓ | - | - | - |
| Administrador de Documentos | ✓ | ✓ | ✓ | ✓ |
| Contador | ✓ | ✓ | - | - |
| Gerente | ✓ | - | - | - |

## Notas Importantes

- Los usuarios con roles antiguos serán migrados automáticamente al ejecutar el script SQL
- El rol por defecto para nuevos usuarios es **Contador**
- Si necesitas cambiar la migración de roles antiguos, edita `migrate_roles_cleanup.sql` antes de ejecutarlo
