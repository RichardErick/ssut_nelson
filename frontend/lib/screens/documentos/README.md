# 📁 Screens/Documentos - MVC Architecture

This folder follows the **MVC (Model-View-Controller)** pattern for better code organization and maintainability.

## 📂 Folder Structure

```
screens/documentos/
├── controllers/              # Business Logic & State Management
│   ├── carpetas_controller.dart
│   ├── documento_controller.dart
│   └── documento_search_controller.dart
│
├── views/                    # UI Components Only (Presentation Layer)
│   ├── carpetas_view.dart
│   ├── carpeta_form_view.dart
│   ├── documentos_list_view.dart
│   ├── documento_detail_view.dart
│   ├── documento_form_view.dart
│   └── documento_search_view.dart
│
├── models/                   # (Optional) View Models specific to this module
│   └── carpeta_view_model.dart
│
└── Legacy Files (to be migrated)
    ├── carpetas_screen.dart
    ├── carpeta_form_screen.dart
    ├── documentos_list_screen.dart
    ├── documento_detail_screen.dart
    ├── documento_form_screen.dart
    └── documento_search_screen.dart
```

## 🏗️ Architecture Pattern

### **Controllers** (`controllers/`)
- **Responsibility**: Business logic, state management, API calls
- **Contains**: Data fetching, validation, state updates
- **Extends**: `ChangeNotifier` for reactive updates
- **Examples**: 
  - Load carpetas from API
  - Delete carpeta
  - Manage loading states

### **Views** (`views/`)
- **Responsibility**: UI rendering only
- **Contains**: Widgets, layouts, user interactions
- **Listens to**: Controllers via `AnimatedBuilder` or `Consumer`
- **Examples**:
  - Display carpetas list
  - Show loading spinners
  - Render forms

### **Models** (Global `lib/models/` or local `models/`)
- **Responsibility**: Data structures
- **Contains**: Data classes, serialization
- **Examples**: `Carpeta`, `Documento`, `Usuario`

## 🔄 Migration Status

| Original Screen | Controller | View | Status |
|----------------|------------|------|--------|
| `carpetas_screen.dart` | `carpetas_controller.dart` | `carpetas_view.dart` | ✅ Migrated |
| `carpeta_form_screen.dart` | - | `carpeta_form_view.dart` | 🔄 Pending |
| `documentos_list_screen.dart` | `documento_controller.dart` | `documentos_list_view.dart` | 🔄 Pending |
| `documento_detail_screen.dart` | `documento_controller.dart` | `documento_detail_view.dart` | 🔄 Pending |
| `documento_form_screen.dart` | `documento_controller.dart` | `documento_form_view.dart` | 🔄 Pending |
| `documento_search_screen.dart` | `documento_search_controller.dart` | `documento_search_view.dart` | 🔄 Pending |

## 📋 How to Use

### Example: Using CarpetasView with Controller

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/carpetas_view.dart';
import '../../services/carpeta_service.dart';

// In your navigation or route
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const CarpetasView(),
  ),
);
```

The `CarpetasView` automatically creates its own `CarpetasController` using the `CarpetaService` from the Provider context.

## 🎯 Benefits of MVC

1. **Separation of Concerns**: UI is separate from business logic
2. **Testability**: Controllers can be tested independently
3. **Reusability**: Same controller can be used with different views
4. **Maintainability**: Easier to understand and modify code
5. **Scalability**: Better structure for growing applications

## 🚀 Next Steps

1. ✅ Migrate `carpetas_screen.dart` → `carpetas_view.dart` + `carpetas_controller.dart`
2. 🔄 Migrate remaining screens following the same pattern
3. 🔄 Update navigation to use new views
4. 🔄 Remove legacy screen files after migration complete
