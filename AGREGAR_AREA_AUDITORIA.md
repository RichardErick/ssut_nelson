# Agregar Área de Auditoría

## Fecha
Marzo 4, 2026

## Objetivo
Agregar "Auditoría" como una opción en el área destino cuando se registra un préstamo de documento.

## Cambios Realizados

### 1. Script SQL para Agregar Área

**Archivo**: `database/add_auditoria_area.sql`

Este script agrega el área de "Auditoría" a la base de datos:

```sql
INSERT INTO areas (nombre, codigo, descripcion, activo) 
VALUES ('Auditoría', 'AUD', 'Área de auditoría y control', true)
ON CONFLICT (codigo) DO NOTHING;
```

### 2. Actualización del Formulario de Préstamo

**Archivo**: `frontend/lib/screens/movimientos/prestamo_form_screen.dart`

Se agregó un comentario explícito para asegurar que "Auditoría" aparezca en la lista de áreas destino.

## Aplicar Cambios

### Paso 1: Agregar Área en la Base de Datos

Ejecuta el script SQL en PostgreSQL:

```bash
psql -U postgres -d ssut_gestion_documental -f database/add_auditoria_area.sql
```

O desde pgAdmin:
1. Abre pgAdmin
2. Conecta a la base de datos `ssut_gestion_documental`
3. Abre Query Tool
4. Copia y pega el contenido de `database/add_auditoria_area.sql`
5. Ejecuta (F5)

### Paso 2: Verificar en la Aplicación

1. Abre la aplicación Flutter
2. Ve a "Movimientos" → "Registrar préstamo"
3. En el dropdown "Área destino" deberías ver:
   - Sin especificar
   - Administración de Documentos
   - Contabilidad
   - **Auditoría** ← Nueva opción
   - Dirección General
   - Secretaría

## Áreas Disponibles

Después de aplicar los cambios, las áreas disponibles en el dropdown serán:

| Área | Código | Descripción |
|------|--------|-------------|
| Administración de Documentos | ADM | Área de administración general |
| Contabilidad | CONT | Área de contabilidad y finanzas |
| **Auditoría** | **AUD** | **Área de auditoría y control** |
| Dirección General | DIR | Dirección general de la institución |
| Secretaría | SEC | Secretaría administrativa |

**Nota**: Las áreas "Recursos Humanos" y "Archivo" están ocultas intencionalmente en el formulario de préstamo.

## Uso

Cuando un usuario registra un préstamo:

1. Selecciona el documento a prestar
2. Selecciona el usuario responsable
3. Define la fecha límite de devolución
4. **Selecciona "Auditoría" como área destino** (opcional)
5. Agrega observaciones (opcional)
6. Registra el préstamo

El área destino queda registrada en la tabla `movimientos` en el campo `area_destino_id`.

## Verificación

Para verificar que el área se agregó correctamente:

```sql
SELECT * FROM areas WHERE codigo = 'AUD';
```

Debería retornar:

```
id | nombre    | codigo | descripcion                | activo
---+-----------+--------+----------------------------+--------
 6 | Auditoría | AUD    | Área de auditoría y control| true
```

## Notas Adicionales

- El área destino es **opcional** en el formulario de préstamo
- Si no se selecciona, el campo `area_destino_id` quedará como `NULL`
- El área destino no afecta la lógica de validación de préstamos
- Es solo información adicional para tracking y reportes
