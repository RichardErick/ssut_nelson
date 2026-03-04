# Solución: Validación de Duplicados en Carpetas con Subcarpetas

## Fecha
Marzo 4, 2026

## Problema Reportado

El usuario reportó dos problemas relacionados:

### Problema 1: Documentos No Aparecen en la Carpeta
Cuando se crea un documento en "Comprobante de Egreso", el contador muestra "1 documento" pero al abrir la carpeta no aparece ningún documento.

**Causa**: El sistema automáticamente asigna el documento a una subcarpeta con rango (ej: "10-40"), pero la búsqueda solo buscaba en la carpeta principal, no en las subcarpetas.

### Problema 2: Validación de Duplicados No Funciona
El usuario puede crear dos documentos con el mismo número (ej: "12") en la misma carpeta "Comprobante de Egreso".

**Causa**: La validación de duplicados solo verificaba en la carpeta exacta, pero como el sistema crea subcarpetas automáticamente, los documentos terminan en subcarpetas diferentes y la validación no los detecta como duplicados.

## Solución Implementada

### 1. Búsqueda Incluye Subcarpetas

**Archivo**: `backend/Controllers/DocumentosController.cs`
**Método**: `Buscar` (POST /api/documentos/buscar)

Cuando se busca en una carpeta "general" (como "Comprobante de Egreso"), ahora incluye automáticamente los documentos de todas sus subcarpetas.

```csharp
if (filtros.CarpetaId.HasValue)
{
    // Verificar si la carpeta es una carpeta "general" (Comprobante de Egreso)
    var carpeta = await _context.Carpetas
        .FirstOrDefaultAsync(c => c.Id == filtros.CarpetaId.Value);
    
    if (carpeta != null && 
        carpeta.CarpetaPadreId == null && 
        string.Equals(carpeta.Nombre, NombreCarpetaGeneral, StringComparison.OrdinalIgnoreCase))
    {
        // Es una carpeta general, incluir documentos de sus subcarpetas también
        var subcarpetasIds = await _context.Carpetas
            .Where(c => c.CarpetaPadreId == filtros.CarpetaId.Value && c.Activo)
            .Select(c => c.Id)
            .ToListAsync();
        
        // Incluir la carpeta principal y todas sus subcarpetas
        var carpetasIds = new List<int> { filtros.CarpetaId.Value };
        carpetasIds.AddRange(subcarpetasIds);
        
        query = query.Where(d => d.CarpetaId.HasValue && carpetasIds.Contains(d.CarpetaId.Value));
    }
    else
    {
        // Carpeta normal, buscar solo en esa carpeta
        query = query.Where(d => d.CarpetaId == filtros.CarpetaId.Value);
    }
}
```

### 2. Validación de Duplicados Incluye Subcarpetas

**Archivo**: `backend/Controllers/DocumentosController.cs`
**Métodos**: `Create` y `Update`

Cuando se valida si existe un número correlativo duplicado en una carpeta "general", ahora verifica en la carpeta principal Y en todas sus subcarpetas.

```csharp
if (carpetaId.HasValue)
{
    // Verificar si es una carpeta "general" que tiene subcarpetas
    var esCarpetaGeneral = carpetaInfo != null && 
        carpetaInfo.CarpetaPadreId == null && 
        string.Equals(carpetaInfo.Nombre, NombreCarpetaGeneral, StringComparison.OrdinalIgnoreCase);
    
    if (esCarpetaGeneral)
    {
        // Obtener IDs de todas las subcarpetas
        var subcarpetasIds = await _context.Carpetas
            .Where(c => c.CarpetaPadreId == carpetaId.Value && c.Activo)
            .Select(c => c.Id)
            .ToListAsync();
        
        // Incluir la carpeta principal y todas sus subcarpetas
        var carpetasIds = new List<int> { carpetaId.Value };
        carpetasIds.AddRange(subcarpetasIds);
        
        // Validar en todas las carpetas (principal + subcarpetas)
        correlativoDuplicado = await _context.Documentos
            .AnyAsync(d => 
                d.CarpetaId.HasValue && 
                carpetasIds.Contains(d.CarpetaId.Value) && 
                d.Gestion == gestion && 
                d.NumeroCorrelativo == correlativoFormateado);
    }
    else
    {
        // Carpeta normal, validar solo en esa carpeta
        correlativoDuplicado = await _context.Documentos
            .AnyAsync(d => 
                d.CarpetaId == carpetaId.Value && 
                d.Gestion == gestion && 
                d.NumeroCorrelativo == correlativoFormateado);
    }
}
```

## Comportamiento Esperado

### Escenario 1: Crear Documento en Comprobante de Egreso

1. Usuario crea documento con número "12" en "Comprobante de Egreso"
2. Sistema asigna el documento a subcarpeta "10-40" (carpetaId: 9)
3. Usuario abre carpeta "Comprobante de Egreso" (carpetaId: 8)
4. ✅ El documento aparece en la lista (incluye subcarpetas)

### Escenario 2: Intentar Crear Documento Duplicado

1. Usuario crea documento con número "12" en "Comprobante de Egreso"
2. Sistema asigna a subcarpeta "10-40" ✅
3. Usuario intenta crear otro documento con número "12" en "Comprobante de Egreso"
4. ❌ Sistema rechaza: "Ya existe un documento con el número de comprobante 0012 en esta carpeta para la gestión 2026"
5. Validación funciona aunque los documentos estén en subcarpetas diferentes

### Escenario 3: Carpetas de Ingreso (Sin Subcarpetas)

1. Usuario crea documento con número "5" en "Comprobante de Ingreso"
2. Sistema asigna directamente a esa carpeta (no crea subcarpetas)
3. Usuario intenta crear otro documento con número "5"
4. ❌ Sistema rechaza: "Ya existe un documento con el número de comprobante 0005 en esta carpeta..."
5. Validación funciona normalmente

## Archivos Modificados

1. **backend/Controllers/DocumentosController.cs**
   - Método `Buscar`: Incluye subcarpetas en búsqueda
   - Método `Create`: Validación de duplicados incluye subcarpetas
   - Método `Update`: Validación de duplicados incluye subcarpetas

## Ventajas

1. ✅ Los documentos aparecen correctamente al abrir la carpeta principal
2. ✅ La validación de duplicados funciona correctamente
3. ✅ Previene crear documentos con números duplicados
4. ✅ Funciona tanto para carpetas con subcarpetas como sin subcarpetas
5. ✅ Mensaje de error claro cuando hay duplicados

## Aplicar Cambios

1. Detener el backend si está corriendo
2. Reiniciar el backend:
   ```bash
   cd backend
   dotnet run
   ```

## Pruebas Recomendadas

### Prueba 1: Ver Documentos en Carpeta con Subcarpetas
1. ✅ Crear documento en "Comprobante de Egreso"
2. ✅ Abrir carpeta "Comprobante de Egreso"
3. ✅ Verificar que el documento aparece en la lista

### Prueba 2: Validación de Duplicados
1. ✅ Crear documento con número "12" en "Comprobante de Egreso"
2. ✅ Intentar crear otro documento con número "12"
3. ✅ Verificar que muestra error: "Ya existe un documento con el número de comprobante 0012..."

### Prueba 3: Carpetas Sin Subcarpetas
1. ✅ Crear documento con número "5" en "Comprobante de Ingreso"
2. ✅ Intentar crear otro documento con número "5"
3. ✅ Verificar que muestra error de duplicado

## Notas Adicionales

- La lógica solo aplica a carpetas "generales" llamadas "Comprobante de Egreso"
- Carpetas normales (como "Comprobante de Ingreso") funcionan como antes
- La validación es consistente en Create y Update
- El mensaje de error es claro y específico
