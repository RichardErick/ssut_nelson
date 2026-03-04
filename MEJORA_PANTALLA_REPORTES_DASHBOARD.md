# Mejora de Pantalla de Reportes - Dashboard Moderno

**Fecha**: 4 de marzo de 2026  
**Estado**: 🚧 En Implementación

## Objetivo

Transformar la pantalla de reportes actual en un dashboard moderno con gráficos interactivos, similar al estilo mostrado en el video de referencia.

## Cambios Propuestos

### 1. Agregar Librería de Gráficos

**Paquete**: `fl_chart: ^0.69.0`

Esta es una de las mejores librerías de gráficos para Flutter, con soporte para:
- Gráficos de líneas
- Gráficos de barras
- Gráficos de pastel (pie charts)
- Gráficos de área
- Animaciones suaves

### 2. Diseño del Dashboard

#### Sección Superior - KPIs (Indicadores Clave)
- Total de documentos (con tendencia)
- Documentos activos
- Documentos en préstamo
- Movimientos del mes

#### Sección Media - Gráficos Principales
1. **Gráfico de Líneas**: Movimientos por día (últimos 30 días)
2. **Gráfico de Barras**: Documentos por tipo
3. **Gráfico de Barras Horizontales**: Documentos por área
4. **Gráfico de Pastel**: Distribución de estados (Activo, Prestado, Archivado)

#### Sección Inferior - Reportes Detallados
- Tabla de movimientos recientes
- Tabla de documentos prestados
- Botones de exportación a PDF

### 3. Características Visuales

- **Colores**: Paleta moderna con gradientes
- **Animaciones**: Transiciones suaves al cargar datos
- **Responsive**: Adaptable a diferentes tamaños de pantalla
- **Interactividad**: Tooltips al pasar el mouse sobre los gráficos
- **Filtros**: Selector de período (Hoy, Semana, Mes, Año)

## Pasos de Implementación

### Paso 1: Instalar Dependencia
```bash
cd frontend
flutter pub add fl_chart
```

### Paso 2: Crear Widgets de Gráficos
- `widgets/charts/line_chart_widget.dart` - Gráfico de líneas
- `widgets/charts/bar_chart_widget.dart` - Gráfico de barras
- `widgets/charts/pie_chart_widget.dart` - Gráfico de pastel

### Paso 3: Actualizar ReportesScreen
- Reorganizar layout con gráficos
- Agregar filtros de período
- Mejorar animaciones y transiciones

### Paso 4: Actualizar Backend (si es necesario)
- Endpoint para datos de gráfico de líneas (movimientos por día)
- Endpoint para distribución de estados

## Estructura de Datos Necesaria

```dart
// Para gráfico de líneas (movimientos por día)
{
  "movimientosPorDia": [
    {"fecha": "2026-03-01", "cantidad": 5},
    {"fecha": "2026-03-02", "cantidad": 8},
    // ...
  ]
}

// Para gráfico de pastel (distribución de estados)
{
  "distribucionEstados": {
    "Activo": 150,
    "Prestado": 25,
    "Archivado": 10
  }
}
```

## Inspiración del Diseño

Basado en el video de referencia, el dashboard tendrá:
- Cards con sombras suaves y bordes redondeados
- Gráficos con colores vibrantes pero profesionales
- Espaciado generoso entre elementos
- Tipografía clara y jerarquizada
- Iconos modernos y consistentes

## Próximos Pasos

1. ✅ Agregar `fl_chart` al pubspec.yaml
2. ⏳ Instalar la dependencia
3. ⏳ Crear widgets de gráficos
4. ⏳ Actualizar ReportesScreen
5. ⏳ Probar y ajustar diseño
6. ⏳ Agregar endpoints de backend si es necesario

## Notas

- La librería `fl_chart` es muy popular y bien mantenida
- Tiene excelente documentación y ejemplos
- Soporta animaciones y gestos táctiles
- Es compatible con web, móvil y desktop
