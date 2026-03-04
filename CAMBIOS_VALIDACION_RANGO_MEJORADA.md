# Cambios: Validación de Rango Mejorada y Duplicados por Carpeta

## Fecha
Marzo 4, 2026

## Problema Reportado

### Problema 1: Validación de Rango
El usuario reportó que al intentar crear un documento en una carpeta de "Comprobantes de Egreso" con rango 10-30, el sistema no permitía ingresar el número "10" y mostraba un error confuso.

### Problema 2: Validación de Duplicados Global
El usuario intentó crear un documento con número "10" en una carpeta con rango 10-30, pero el sistema rechazó con el error:
```
"Ya existe un documento con el número de comprobante 0001 en la gestión 2026."
```

Esto ocurría porque la validación de duplicados era GLOBAL (toda la gestión) en lugar de ser POR CARPETA. Esto impedía usar el mismo número correlativo en diferentes carpetas de la misma gestión.

## Análisis del Problema

### Problema 1: Orden de Validaciones Incorrecto
El código original validaba en este orden:
1. Validar capacidad de carpeta
2. Formatear número correlativo
3. Validar rango de la carpeta
4. Validar duplicados

Esto causaba que:
- El número se formateara antes de validar el rango
- Las validaciones estaban dispersas y repetían consultas a la base de datos

### Problema 2: Mensaje de Error No Claro
El mensaje original era técnico:
```
"El número de comprobante debe estar dentro del rango de la carpeta: 10 - 30. 
Por favor ingrese un número entre 10 y 30."
```

El usuario solicitó un mensaje más amigable que explique claramente el rango de la carpeta.

### Problema 3: Validación de Duplicados Global (CRÍTICO)
La validación de duplicados verificaba si existía un documento con el mismo número correlativo en TODA LA GESTIÓN:

```csharp
var correlativoDuplicado = await _context.Documentos
    .AnyAsync(d => d.Gestion == gestion && d.NumeroCorrelativo == correlativoFormateado);
```

Esto impedía:
- Usar el número "10" en la carpeta "Comprobante de Egreso (10-30)" si ya existía un "0001" en otra carpeta
- Tener números correlativos independientes por carpeta
- Que cada carpeta maneje su propio rango de números

**Ejemplo del problema**:
- Carpeta A (Ingreso): tiene documento con número 0001
- Carpeta B (Egreso, rango 10-30): usuario intenta crear documento con número 10
- Sistema rechaza: "Ya existe un documento con el número de comprobante 0001 en la gestión 2026"
- ❌ El error es confuso (habla de 0001 cuando el usuario ingresó 10)
- ❌ No tiene sentido validar contra otra carpeta

## Solución Implementada

### 1. Reorganización de la Lógica de Validación

**Archivo**: `backend/Controllers/DocumentosController.cs`

**Nuevo orden de validaciones**:
1. Obtener información de la carpeta (una sola consulta)
2. Determinar el número correlativo:
   - Si el usuario no ingresó número → generar automáticamente
   - Si el usuario ingresó número → validar que esté en el rango ANTES de formatear
3. Formatear el número
4. Validar duplicados POR CARPETA (no globalmente)
5. Validar capacidad de la carpeta

### 2. Validación de Duplicados por Carpeta (CAMBIO CRÍTICO)

**Antes** (validación global):
```csharp
var correlativoDuplicado = await _context.Documentos
    .AnyAsync(d => d.Gestion == gestion && d.NumeroCorrelativo == correlativoFormateado);
```

**Después** (validación por carpeta):
```csharp
var correlativoDuplicado = carpetaId.HasValue
    ? await _context.Documentos.AnyAsync(d => 
        d.CarpetaId == carpetaId.Value && 
        d.Gestion == gestion && 
        d.NumeroCorrelativo == correlativoFormateado)
    : await _context.Documentos.AnyAsync(d => 
        d.Gestion == gestion && 
        d.NumeroCorrelativo == correlativoFormateado);
```

**Ventajas**:
- ✅ Cada carpeta puede tener su propio rango de números
- ✅ El número "10" puede existir en múltiples carpetas
- ✅ Validación lógica: solo verifica duplicados dentro de la misma carpeta
- ✅ Mensaje de error más claro y específico

### 3. Optimización de Consultas
- Antes: 3 consultas a la base de datos para obtener información de la carpeta
- Ahora: 1 consulta que se reutiliza en todas las validaciones

### 4. Mensaje de Error Mejorado
```
"Tu carpeta tiene rango del 10 al 30, por lo que debes ingresar números desde el 10 al 30."
```

Este mensaje es:
- ✅ Más amigable y conversacional
- ✅ Explica claramente el rango de la carpeta
- ✅ Indica qué debe hacer el usuario

### 5. Actualización del Método Update
También se actualizó el método `Update` para que use la misma lógica de validación por carpeta.

## Código Modificado

### Cambio 1: Validación de Duplicados por Carpeta (Create)

**Antes** (validación global):
```csharp
// Validar que el número de comprobante (correlativo) no se repita en la misma gestión
var correlativoDuplicado = await _context.Documentos
    .AnyAsync(d => d.Gestion == gestion && d.NumeroCorrelativo == correlativoFormateado);
if (correlativoDuplicado)
{
    return BadRequest(new
    {
        message = $"Ya existe un documento con el número de comprobante {correlativoFormateado} en la gestión {gestion}."
    });
}
```

**Después** (validación por carpeta):
```csharp
// Validar que el número de comprobante (correlativo) no se repita en la misma carpeta y gestión
// Si no hay carpeta, validar globalmente en la gestión
var correlativoDuplicado = carpetaId.HasValue
    ? await _context.Documentos.AnyAsync(d => 
        d.CarpetaId == carpetaId.Value && 
        d.Gestion == gestion && 
        d.NumeroCorrelativo == correlativoFormateado)
    : await _context.Documentos.AnyAsync(d => 
        d.Gestion == gestion && 
        d.NumeroCorrelativo == correlativoFormateado);
        
if (correlativoDuplicado)
{
    var mensajeDuplicado = carpetaId.HasValue
        ? $"Ya existe un documento con el número de comprobante {correlativoFormateado} en esta carpeta para la gestión {gestion}."
        : $"Ya existe un documento con el número de comprobante {correlativoFormateado} en la gestión {gestion}.";
        
    return BadRequest(new { message = mensajeDuplicado });
}
```

### Cambio 2: Validación de Duplicados por Carpeta (Update)

**Antes** (validación global):
```csharp
// Validar que el número de comprobante no se repita en la misma gestión (excluyendo el propio documento)
var correlativoDuplicado = await _context.Documentos
    .AnyAsync(d =>
        d.Id != id &&
        d.Gestion == nuevaGestion &&
        d.NumeroCorrelativo == nuevoCorrelativo);
if (correlativoDuplicado)
{
    return BadRequest(new
    {
        message = $"Ya existe un documento con el número de comprobante {nuevoCorrelativo} en la gestión {nuevaGestion}."
    });
}
```

**Después** (validación por carpeta):
```csharp
// Validar que el número de comprobante no se repita en la misma carpeta y gestión (excluyendo el propio documento)
// Si no hay carpeta, validar globalmente en la gestión
var correlativoDuplicado = documento.CarpetaId.HasValue
    ? await _context.Documentos.AnyAsync(d =>
        d.Id != id &&
        d.CarpetaId == documento.CarpetaId.Value &&
        d.Gestion == nuevaGestion &&
        d.NumeroCorrelativo == nuevoCorrelativo)
    : await _context.Documentos.AnyAsync(d =>
        d.Id != id &&
        d.Gestion == nuevaGestion &&
        d.NumeroCorrelativo == nuevoCorrelativo);
        
if (correlativoDuplicado)
{
    var mensajeDuplicado = documento.CarpetaId.HasValue
        ? $"Ya existe un documento con el número de comprobante {nuevoCorrelativo} en esta carpeta para la gestión {nuevaGestion}."
        : $"Ya existe un documento con el número de comprobante {nuevoCorrelativo} en la gestión {nuevaGestion}.";
        
    return BadRequest(new { message = mensajeDuplicado });
}
```

### Cambio 3: Reorganización de Validaciones (Create)

**Antes**:
// Validar capacidad de la carpeta según su rango configurado (si aplica)
if (carpetaId.HasValue)
{
    var carpetaCapacidad = await _context.Carpetas
        .FirstOrDefaultAsync(c => c.Id == carpetaId.Value);
    // ... validaciones
}

string correlativoFormateado;
try
{
    correlativoFormateado = (forzarCorrelativoAuto || string.IsNullOrWhiteSpace(correlativoDigits))
        ? (await ObtenerSiguienteCorrelativoAsync(carpetaId, gestion)).PadLeft(4, '0')
        : (correlativoDigits.Length >= 4 ? correlativoDigits : correlativoDigits.PadLeft(4, '0'));
}
catch (InvalidOperationException ex)
{
    return BadRequest(new { message = ex.Message });
}

// Validar que el número correlativo esté dentro del rango de la carpeta
if (carpetaId.HasValue && !string.IsNullOrWhiteSpace(correlativoDigits))
{
    var carpetaRango = await _context.Carpetas
        .FirstOrDefaultAsync(c => c.Id == carpetaId.Value);
    // ... validaciones de rango
}

// Validar duplicados
var correlativoDuplicado = await _context.Documentos
    .AnyAsync(d => d.Gestion == gestion && d.NumeroCorrelativo == correlativoFormateado);
```

### Después
```csharp
// Obtener información de la carpeta si existe (UNA SOLA VEZ)
Carpeta? carpetaInfo = null;
if (carpetaId.HasValue)
{
    carpetaInfo = await _context.Carpetas
        .FirstOrDefaultAsync(c => c.Id == carpetaId.Value);
}

// Determinar el número correlativo a usar
string correlativoFormateado;

// Si el usuario no ingresó número, generar automáticamente
if (forzarCorrelativoAuto || string.IsNullOrWhiteSpace(correlativoDigits))
{
    try
    {
        var siguienteNumero = await ObtenerSiguienteCorrelativoAsync(carpetaId, gestion);
        correlativoFormateado = siguienteNumero.PadLeft(4, '0');
    }
    catch (InvalidOperationException ex)
    {
        return BadRequest(new { message = ex.Message });
    }
}
else
{
    // Usuario ingresó un número manualmente
    // Validar que esté dentro del rango de la carpeta (ANTES de formatear)
    if (carpetaInfo != null &&
        carpetaInfo.RangoInicio.HasValue &&
        carpetaInfo.RangoFin.HasValue)
    {
        if (int.TryParse(correlativoDigits, out var numeroIngresado))
        {
            if (numeroIngresado < carpetaInfo.RangoInicio.Value || 
                numeroIngresado > carpetaInfo.RangoFin.Value)
            {
                return BadRequest(new
                {
                    message = $"Tu carpeta tiene rango del {carpetaInfo.RangoInicio} al {carpetaInfo.RangoFin}, por lo que debes ingresar números desde el {carpetaInfo.RangoInicio} al {carpetaInfo.RangoFin}."
                });
            }
        }
    }
    
    // Formatear el número ingresado
    correlativoFormateado = correlativoDigits.Length >= 4 ? correlativoDigits : correlativoDigits.PadLeft(4, '0');
}

// Validar duplicados
var correlativoDuplicado = await _context.Documentos
    .AnyAsync(d => d.Gestion == gestion && d.NumeroCorrelativo == correlativoFormateado);
if (correlativoDuplicado)
{
    return BadRequest(new
    {
        message = $"Ya existe un documento con el número de comprobante {correlativoFormateado} en la gestión {gestion}."
    });
}

// Validar capacidad de la carpeta (reutilizando carpetaInfo)
if (carpetaInfo != null &&
    carpetaInfo.RangoInicio.HasValue &&
    carpetaInfo.RangoFin.HasValue)
{
    var capacidad = carpetaInfo.RangoFin.Value - carpetaInfo.RangoInicio.Value + 1;
    if (capacidad <= 0)
        return BadRequest(new { message = $"El rango configurado para la carpeta ({carpetaInfo.RangoInicio}-{carpetaInfo.RangoFin}) no es válido." });

    var countEnCarpeta = await ContarDocumentosEnCarpetaAsync(carpetaId!.Value, gestion);
    if (countEnCarpeta >= capacidad)
        return BadRequest(new
        {
            message = $"La carpeta ya alcanzó el máximo de {capacidad} documentos para su rango {carpetaInfo.RangoInicio}-{carpetaInfo.RangoFin}."
        });
}
```

## Mejoras Implementadas

### 1. Rendimiento
- ✅ Reducción de 3 consultas a 1 consulta a la base de datos
- ✅ Reutilización de la información de la carpeta en todas las validaciones

### 2. Claridad del Código
- ✅ Lógica más lineal y fácil de seguir
- ✅ Validaciones en orden lógico
- ✅ Comentarios explicativos

### 3. Experiencia del Usuario
- ✅ Mensaje de error más amigable y claro
- ✅ Explica el rango de la carpeta
- ✅ Indica qué debe hacer el usuario
- ✅ Mensajes específicos según el contexto (con/sin carpeta)

### 4. Corrección de Bugs
- ✅ Validación de rango ANTES de formatear el número
- ✅ Previene errores de validación con números formateados
- ✅ **Validación de duplicados POR CARPETA** (no global)
- ✅ Permite usar el mismo número en diferentes carpetas

### 5. Lógica de Negocio Correcta
- ✅ Cada carpeta maneja su propio rango de números
- ✅ No hay conflictos entre carpetas diferentes
- ✅ Validación lógica y coherente con el modelo de negocio

## Comportamiento Esperado

### Escenario 1: Carpeta con Rango 10-30

| Acción del Usuario | Resultado | Mensaje |
|-------------------|-----------|---------|
| Ingresa "10" | ✅ Creado con número 0010 | - |
| Ingresa "15" | ✅ Creado con número 0015 | - |
| Ingresa "5" | ❌ Error | "Tu carpeta tiene rango del 10 al 30..." |
| Ingresa "35" | ❌ Error | "Tu carpeta tiene rango del 10 al 30..." |
| Deja vacío | ✅ Sistema asigna siguiente disponible | - |
| Ingresa "10" (duplicado en misma carpeta) | ❌ Error | "Ya existe un documento con el número de comprobante 0010 en esta carpeta..." |

### Escenario 2: Múltiples Carpetas (NUEVO COMPORTAMIENTO)

**Carpeta A (Comprobante de Ingreso)**:
- Documento 1: número 0001 ✅
- Documento 2: número 0002 ✅

**Carpeta B (Comprobante de Egreso, rango 10-30)**:
- Documento 1: número 0010 ✅ (AHORA FUNCIONA - antes daba error)
- Documento 2: número 0015 ✅
- Documento 3: número 0010 ❌ (duplicado en misma carpeta)

**Antes**: No se podía crear el documento con número 10 en Carpeta B porque ya existía el 0001 en Carpeta A
**Ahora**: Se puede crear porque la validación es por carpeta, no global

## Archivos Modificados

1. `backend/Controllers/DocumentosController.cs`
   - Método `Create` (líneas ~320-380)
     - Reorganización de validaciones
     - Optimización de consultas
     - Mensaje de error mejorado
     - **Validación de duplicados por carpeta**
   - Método `Update` (líneas ~540-580)
     - **Validación de duplicados por carpeta**
     - Mensajes de error específicos

2. `SOLUCION_VALIDACION_RANGO_CARPETAS.md`
   - Actualización de documentación
   - Nuevos ejemplos de uso
   - Mensajes de error actualizados

3. `CAMBIOS_VALIDACION_RANGO_MEJORADA.md`
   - Documentación completa de cambios
   - Explicación del problema de validación global
   - Ejemplos de comportamiento antes/después

## Pruebas Recomendadas

### Pruebas Básicas
1. ✅ Crear documento con número dentro del rango (ej: 10)
2. ✅ Crear documento con número fuera del rango (ej: 5, 35)
3. ✅ Crear documento sin número (automático)
4. ✅ Crear documento con número duplicado en la misma carpeta
5. ✅ Verificar que el mensaje de error sea claro

### Pruebas de Validación por Carpeta (CRÍTICO)
6. ✅ Crear documento con número "10" en Carpeta A
7. ✅ Crear documento con número "10" en Carpeta B (debe funcionar)
8. ✅ Intentar crear otro documento con número "10" en Carpeta A (debe fallar)
9. ✅ Verificar que el mensaje de error mencione "en esta carpeta"

### Pruebas de Rango
10. ✅ Carpeta con rango 10-30: crear documento con número 10 (debe funcionar)
11. ✅ Carpeta con rango 10-30: crear documento con número 5 (debe fallar con mensaje claro)
12. ✅ Carpeta sin rango: crear documento con cualquier número (debe funcionar)

## Aplicar Cambios

1. Detener el backend si está corriendo
2. Reiniciar el backend:
   ```bash
   cd backend
   dotnet run
   ```
3. Probar creando documentos en carpetas con rango

## Notas Adicionales

- El cambio es compatible con carpetas sin rango
- No afecta la funcionalidad existente de carpetas generales
- Mantiene la validación de duplicados (ahora por carpeta)
- Mantiene la validación de capacidad de carpeta
- **CAMBIO IMPORTANTE**: Ahora cada carpeta puede tener números correlativos independientes
- **BENEFICIO**: Permite usar el mismo número en diferentes carpetas (ej: 0010 en Ingreso y 0010 en Egreso)
- **VALIDACIÓN**: Solo previene duplicados dentro de la misma carpeta

## Impacto en el Sistema

### Positivo
- ✅ Resuelve el problema reportado por el usuario
- ✅ Lógica de negocio más coherente
- ✅ Mejor experiencia de usuario
- ✅ Mensajes de error más claros
- ✅ Mejor rendimiento (menos consultas)

### Consideraciones
- ⚠️ Si había documentos con números duplicados entre carpetas, ahora es válido
- ⚠️ El código único del documento sigue siendo único globalmente (TIPO-AREA-GESTION-CORRELATIVO)
- ⚠️ La validación de duplicados ahora es por carpeta, no global
