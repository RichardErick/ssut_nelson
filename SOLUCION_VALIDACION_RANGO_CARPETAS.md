# Solución: Validación de Rango en Carpetas

## Problema
Al crear un documento en una carpeta con rango (ej: 10-30), el sistema no permitía ingresar números manuales y forzaba números sucesivos automáticos. Además, no validaba que el número ingresado estuviera dentro del rango de la carpeta.

## Solución Implementada

### 1. Permitir Números Manuales en Carpetas con Rango

**Archivo**: `backend/Controllers/DocumentosController.cs`

**Cambio en método `ResolverCarpetaDestinoAsync`**:
```csharp
// ANTES
if (esSubcarpetaRango)
{
    var count = await ContarDocumentosEnCarpetaAsync(carpeta.Id, gestion, excludeDocumentoId);
    if (count >= TamanoRango)
        return new CarpetaResolucion(null, true, $"La carpeta ya alcanzo el maximo...");

    return new CarpetaResolucion(carpeta.Id, true, null);  // ForzarCorrelativoAuto = true
}

// DESPUÉS
if (esSubcarpetaRango)
{
    var count = await ContarDocumentosEnCarpetaAsync(carpeta.Id, gestion, excludeDocumentoId);
    if (count >= TamanoRango)
        return new CarpetaResolucion(null, false, $"La carpeta ya alcanzo el maximo...");

    // Permitir que el usuario ingrese el número correlativo manualmente
    return new CarpetaResolucion(carpeta.Id, false, null);  // ForzarCorrelativoAuto = false
}
```

### 2. Validar que el Número esté Dentro del Rango

**Archivo**: `backend/Controllers/DocumentosController.cs`

**Nueva validación en método `Create`** (después de formatear el correlativo):
```csharp
// Validar que el número correlativo esté dentro del rango de la carpeta (si tiene rango configurado)
if (carpetaId.HasValue && !string.IsNullOrWhiteSpace(correlativoDigits))
{
    var carpetaRango = await _context.Carpetas
        .FirstOrDefaultAsync(c => c.Id == carpetaId.Value);

    if (carpetaRango != null &&
        carpetaRango.RangoInicio.HasValue &&
        carpetaRango.RangoFin.HasValue)
    {
        if (int.TryParse(correlativoFormateado, out var numeroIngresado))
        {
            if (numeroIngresado < carpetaRango.RangoInicio.Value || 
                numeroIngresado > carpetaRango.RangoFin.Value)
            {
                return BadRequest(new
                {
                    message = $"El número de comprobante debe estar dentro del rango de la carpeta: {carpetaRango.RangoInicio} - {carpetaRango.RangoFin}. Por favor ingrese un número entre {carpetaRango.RangoInicio} y {carpetaRango.RangoFin}."
                });
            }
        }
    }
}
```

## Comportamiento Actual

### Carpeta con Rango 10-30

1. **Usuario ingresa número manual (ej: 10)**:
   - ✅ Se valida que esté entre 10 y 30
   - ✅ Si está en el rango, se crea el documento
   - ❌ Si está fuera del rango (ej: 5 o 35), muestra error: "Tu carpeta tiene rango del 10 al 30, por lo que debes ingresar números desde el 10 al 30"

2. **Usuario deja el campo vacío**:
   - ✅ El sistema genera automáticamente el siguiente número disponible dentro del rango

3. **Usuario intenta crear más documentos de los permitidos**:
   - ❌ Muestra error: "La carpeta ya alcanzó el máximo de 21 documentos para su rango 10-30"

## Mensajes de Error

### Error: Número Fuera de Rango
```
Tu carpeta tiene rango del 10 al 30, por lo que debes ingresar números desde el 10 al 30.
```

### Error: Carpeta Llena
```
La carpeta ya alcanzó el máximo de 21 documentos para su rango 10-30.
```

### Error: Número Duplicado
```
Ya existe un documento con el número de comprobante 0010 en la gestión 2026.
```

## Ejemplo de Uso

### Carpeta: Comprobante de Egreso (Rango 10-30)

1. **Primer documento**: Usuario ingresa "10" → ✅ Creado con número 0010
2. **Segundo documento**: Usuario ingresa "15" → ✅ Creado con número 0015
3. **Tercer documento**: Usuario ingresa "5" → ❌ Error: "Tu carpeta tiene rango del 10 al 30..."
4. **Cuarto documento**: Usuario deja vacío → ✅ Sistema asigna siguiente disponible (ej: 0011)
5. **Quinto documento**: Usuario ingresa "10" → ❌ Error: "Ya existe un documento con el número de comprobante 0010..."

## Ventajas

1. ✅ **Flexibilidad**: Usuario puede ingresar cualquier número dentro del rango
2. ✅ **Validación clara**: Mensajes específicos indican el rango permitido
3. ✅ **Automático opcional**: Si deja vacío, el sistema asigna el siguiente
4. ✅ **Prevención de errores**: No permite números fuera del rango
5. ✅ **Sin duplicados**: Valida que no exista el mismo número en la gestión
6. ✅ **Mensaje amigable**: Explica claramente el rango de la carpeta

## Aplicar Cambios

1. Detener el backend si está corriendo
2. Reiniciar el backend:
   ```bash
   cd backend
   dotnet run
   ```
3. Probar creando documentos en carpetas con rango

## Fecha
Marzo 2026
