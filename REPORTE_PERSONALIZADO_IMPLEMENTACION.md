# Reporte Personalizado - Implementación Completa

**Fecha**: 4 de marzo de 2026  
**Estado**: ✅ Completado

## Descripción

Se ha implementado un **Generador de Reportes Personalizados** que permite al usuario:

1. ✅ Seleccionar qué columnas/atributos desea ver (con checkboxes)
2. ✅ Ver la tabla en tiempo real según las columnas seleccionadas
3. ✅ Aplicar filtros de búsqueda y estado
4. ✅ Exportar a PDF y CSV/Excel
5. ✅ Interfaz moderna con panel lateral de configuración

## Características Principales

### 📋 Selección de Columnas

El usuario puede seleccionar entre 13 columnas disponibles:

- ✅ Código
- ✅ Nº Correlativo
- ✅ Tipo Documento
- ✅ Área Origen
- ✅ Gestión
- ✅ Fecha Documento
- ✅ Descripción
- ✅ Responsable
- ✅ Ubicación Física
- ✅ Estado
- ✅ Carpeta
- ✅ Nivel Confidencialidad
- ✅ Fecha Registro

### 🔍 Filtros Disponibles

- **Búsqueda por texto**: Busca en código, correlativo, descripción y tipo
- **Filtro por estado**: Activo, Prestado, Archivado
- **Contador de registros**: Muestra cuántos registros coinciden

### 📊 Exportación

- **PDF**: Tabla formateada en formato horizontal (landscape)
- **CSV/Excel**: Archivo CSV compatible con Excel

### 🎨 Diseño

```
┌─────────────────────────────────────────────────────────────┐
│  ← Reporte Personalizado              📄 PDF  📊 Excel     │
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│ Configuración│  [Buscar...] 🔍 Filtros    125 registros   │
│              │                                              │
│ Columnas:    │  ┌────────────────────────────────────────┐ │
│ ☑ Código     │  │ Código │ Nº Corr │ Tipo │ Estado │... │ │
│ ☑ Nº Corr    │  ├────────────────────────────────────────┤ │
│ ☑ Tipo Doc   │  │ CI-001 │ 0001    │ CI   │ Activo │... │ │
│ ☐ Área       │  │ CE-002 │ 0002    │ CE   │ Prest. │... │ │
│ ☑ Gestión    │  │ OF-003 │ 0003    │ OF   │ Activo │... │ │
│ ☐ Fecha      │  │ ...                                    │ │
│ ☐ Descrip.   │  └────────────────────────────────────────┘ │
│ ☐ Respons.   │                                              │
│ ☐ Ubicación  │                                              │
│ ☑ Estado     │                                              │
│ ☐ Carpeta    │                                              │
│ ☐ Nivel Conf │                                              │
│ ☐ Fecha Reg  │                                              │
│              │                                              │
│ [Todas]      │                                              │
│ [Ninguna]    │                                              │
│              │                                              │
│ [Generar     │                                              │
│  Reporte]    │                                              │
└──────────────┴──────────────────────────────────────────────┘
```

## Cómo Usar

### 1. Acceder a la Pantalla

Opción A: Agregar botón en la pantalla de reportes actual:

```dart
// En reportes_screen.dart o reportes_screen_new.dart
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportePersonalizadoScreen(),
      ),
    );
  },
  child: const Icon(Icons.add_chart_rounded),
  tooltip: 'Reporte Personalizado',
)
```

Opción B: Agregar en el menú principal:

```dart
// En home_screen.dart, agregar en el drawer o menú
ListTile(
  leading: const Icon(Icons.table_chart_rounded),
  title: const Text('Reporte Personalizado'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportePersonalizadoScreen(),
      ),
    );
  },
)
```

### 2. Generar Reporte

1. Selecciona las columnas que deseas ver (checkboxes)
2. Presiona "Generar Reporte"
3. Espera a que carguen los datos
4. La tabla se mostrará con las columnas seleccionadas

### 3. Filtrar Resultados

1. Usa la barra de búsqueda para filtrar por texto
2. Presiona el botón de filtros para opciones avanzadas
3. Selecciona el estado (Activo, Prestado, Archivado)
4. Los resultados se actualizan en tiempo real

### 4. Exportar

1. Presiona el icono 📄 para exportar a PDF
2. Presiona el icono 📊 para exportar a CSV/Excel
3. El archivo se descargará automáticamente

## Flujo de Trabajo

```
1. Usuario abre "Reporte Personalizado"
   ↓
2. Selecciona columnas con checkboxes
   ↓
3. Presiona "Generar Reporte"
   ↓
4. Sistema carga todos los documentos
   ↓
5. Tabla se muestra con columnas seleccionadas
   ↓
6. Usuario aplica filtros (opcional)
   ↓
7. Usuario exporta a PDF o Excel
   ↓
8. Archivo se descarga
```

## Personalización

### Agregar Nuevas Columnas

En `reporte_personalizado_screen.dart`, agrega en `_columnasDisponibles`:

```dart
'nuevaColumna': ColumnConfig('Nueva Columna', false, 150),
```

Y en `_getColumnValue`:

```dart
case 'nuevaColumna':
  return doc.nuevaColumna ?? '-';
```

### Cambiar Columnas por Defecto

Cambia el segundo parámetro de `ColumnConfig`:

```dart
'codigo': ColumnConfig('Código', true, 120),  // true = seleccionado por defecto
'descripcion': ColumnConfig('Descripción', false, 200),  // false = no seleccionado
```

### Agregar Más Filtros

En `_buildFilterBar`, agrega más dropdowns o campos:

```dart
DropdownButtonFormField<String>(
  value: _filtroTipo,
  decoration: InputDecoration(labelText: 'Tipo'),
  items: [...],
  onChanged: (value) {
    setState(() {
      _filtroTipo = value;
      _aplicarFiltros();
    });
  },
)
```

## Ventajas

✅ **Flexible**: El usuario elige qué ver  
✅ **Rápido**: Tabla se actualiza en tiempo real  
✅ **Exportable**: PDF y Excel listos para usar  
✅ **Filtrable**: Búsqueda y filtros avanzados  
✅ **Responsive**: Se adapta a diferentes tamaños  
✅ **Moderno**: Diseño limpio y profesional  

## Comparación con Video de Referencia

| Característica | Video | Implementado |
|----------------|-------|--------------|
| Selección de columnas | ✅ | ✅ |
| Tabla en tiempo real | ✅ | ✅ |
| Filtros | ✅ | ✅ |
| Exportar PDF | ✅ | ✅ |
| Exportar Excel | ✅ | ✅ |
| Panel lateral | ✅ | ✅ |
| Búsqueda | ✅ | ✅ |
| Contador de registros | ✅ | ✅ |

## Próximas Mejoras Opcionales

1. Guardar configuraciones de reportes favoritos
2. Agregar más formatos de exportación (Word, JSON)
3. Permitir ordenar columnas arrastrando
4. Agregar gráficos basados en los datos filtrados
5. Programar reportes automáticos por email
6. Agregar filtros de rango de fechas
7. Permitir agrupar por columnas

## Notas Técnicas

- La tabla usa `DataTable` de Flutter para mejor rendimiento
- Los filtros se aplican en memoria (rápido para <10,000 registros)
- La exportación PDF usa orientación horizontal para más columnas
- El CSV es compatible con Excel y Google Sheets
- La descarga funciona en web usando `universal_html`

## Resultado Final

Una pantalla completa de generación de reportes personalizados que permite:
- Seleccionar columnas dinámicamente
- Ver resultados en tiempo real
- Filtrar y buscar
- Exportar a múltiples formatos

¡Exactamente como en el video de referencia! 🎉
