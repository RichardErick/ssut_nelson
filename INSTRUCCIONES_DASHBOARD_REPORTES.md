# Instrucciones para Aplicar el Nuevo Dashboard de Reportes

**Fecha**: 4 de marzo de 2026  
**Estado**: ✅ Listo para Aplicar

## Archivos Creados

1. ✅ `frontend/lib/widgets/charts/line_chart_widget.dart` - Gráfico de líneas
2. ✅ `frontend/lib/widgets/charts/bar_chart_widget.dart` - Gráfico de barras
3. ✅ `frontend/lib/widgets/charts/pie_chart_widget.dart` - Gráfico de pastel
4. ✅ `frontend/lib/screens/reportes/reportes_screen_new.dart` - Nueva pantalla de reportes
5. ✅ `frontend/pubspec.yaml` - Actualizado con `fl_chart: ^0.69.0`

## Pasos para Aplicar

### 1. Instalar Dependencias

Abre una terminal en la carpeta `frontend` y ejecuta:

```bash
flutter pub get
```

Si hay problemas, intenta:

```bash
flutter clean
flutter pub get
```

### 2. Reemplazar la Pantalla de Reportes

Tienes dos opciones:

#### Opción A: Reemplazar el archivo actual (Recomendado)

1. Renombra el archivo actual como respaldo:
   ```
   frontend/lib/screens/reportes/reportes_screen.dart 
   → 
   frontend/lib/screens/reportes/reportes_screen_old.dart
   ```

2. Renombra el nuevo archivo:
   ```
   frontend/lib/screens/reportes/reportes_screen_new.dart 
   → 
   frontend/lib/screens/reportes/reportes_screen.dart
   ```

3. Actualiza la clase en el nuevo archivo:
   - Cambia `class ReportesScreenNew` por `class ReportesScreen`
   - Cambia `_ReportesScreenNewState` por `_ReportesScreenState`

#### Opción B: Probar primero la nueva pantalla

1. En `frontend/lib/screens/home_screen.dart`, busca donde se usa `ReportesScreen`

2. Cambia el import:
   ```dart
   // Antes
   import 'screens/reportes/reportes_screen.dart';
   
   // Después
   import 'screens/reportes/reportes_screen_new.dart';
   ```

3. Cambia la instancia:
   ```dart
   // Antes
   ReportesScreen(selectedIndex: _selectedIndex, reportesIndex: 3)
   
   // Después
   ReportesScreenNew(selectedIndex: _selectedIndex, reportesIndex: 3)
   ```

### 3. Verificar Imports

Asegúrate de que todos los imports estén correctos en los archivos de gráficos:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
```

### 4. Ejecutar la Aplicación

```bash
flutter run -d chrome
```

O si usas otro dispositivo:

```bash
flutter run
```

## Características del Nuevo Dashboard

### 📊 Gráficos Interactivos

1. **Gráfico de Líneas**: Muestra movimientos por día
   - Animación suave al cargar
   - Tooltips al pasar el mouse
   - Área sombreada bajo la línea

2. **Gráfico de Barras Vertical**: Documentos por tipo
   - Barras con gradiente
   - Animación de crecimiento
   - Tooltips informativos

3. **Gráfico de Pastel**: Distribución por estado
   - Colores diferenciados
   - Porcentajes calculados automáticamente
   - Leyenda lateral

4. **Gráfico de Barras Horizontal**: Documentos por área
   - Barras con gradiente
   - Animación de izquierda a derecha
   - Valores al final de cada barra

### 🎨 Diseño Moderno

- Cards con sombras suaves
- Bordes redondeados (20px)
- Espaciado generoso
- Colores vibrantes pero profesionales
- Iconos modernos
- Tipografía clara (Google Fonts)

### 📱 Responsive

- Desktop (>1200px): 4 KPIs por fila, gráficos lado a lado
- Tablet (800-1200px): 2 KPIs por fila, gráficos lado a lado
- Móvil (<800px): 1 KPI por fila, gráficos apilados

### 🔄 Filtros de Período

- Hoy
- Semana
- Mes (por defecto)
- Año

### ✨ Animaciones

- Cards con entrada escalonada
- Números con animación de conteo
- Gráficos con transiciones suaves
- Barras con animación de crecimiento

## Solución de Problemas

### Error: "Package fl_chart not found"

```bash
cd frontend
flutter pub get
```

### Error: "Cannot find widget charts"

Verifica que los archivos estén en:
- `frontend/lib/widgets/charts/line_chart_widget.dart`
- `frontend/lib/widgets/charts/bar_chart_widget.dart`
- `frontend/lib/widgets/charts/pie_chart_widget.dart`

### Error de compilación

```bash
flutter clean
flutter pub get
flutter run
```

### Los gráficos no se muestran

Verifica que `_estadisticas` tenga datos:
```dart
print(_estadisticas);
```

## Personalización

### Cambiar Colores

En `reportes_screen_new.dart`, busca:

```dart
// KPI Cards
_buildKPICard('Total Documentos', ..., Colors.blue, ...),
_buildKPICard('Documentos Activos', ..., Colors.green, ...),
_buildKPICard('En Préstamo', ..., Colors.orange, ...),
_buildKPICard('Movimientos', ..., Colors.purple, ...),
```

### Cambiar Período por Defecto

```dart
String _periodoSeleccionado = 'mes'; // Cambia a 'hoy', 'semana', o 'año'
```

### Ajustar Altura de Gráficos

```dart
SizedBox(
  height: 250, // Cambia este valor
  child: MovimientosLineChart(...),
),
```

## Próximos Pasos Opcionales

1. Agregar exportación de gráficos a imagen
2. Agregar más filtros (por área, por tipo)
3. Agregar comparación de períodos
4. Agregar gráficos de tendencias
5. Agregar alertas visuales

## Notas Técnicas

- La librería `fl_chart` es muy eficiente y no afecta el rendimiento
- Los gráficos son completamente responsivos
- Las animaciones se pueden desactivar cambiando `duration` a `Duration.zero`
- Los tooltips funcionan automáticamente en web y desktop

## Resultado Esperado

El dashboard mostrará:
- 4 KPIs principales con tendencias
- Gráfico de líneas de movimientos por día
- Gráfico de barras de documentos por tipo
- Gráfico de pastel de distribución por estado
- Gráfico de barras horizontal de documentos por área

Todo con animaciones suaves, colores modernos y diseño profesional similar al video de referencia.
