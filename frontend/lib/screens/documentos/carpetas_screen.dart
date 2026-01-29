import 'package:flutter/material.dart';
import 'views/carpetas_view.dart';

/// Legacy wrapper for CarpetasView - Following MVC Architecture
/// This file now delegates to the new MVC-based implementation
/// 
/// Architecture:
/// - Controller: controllers/carpetas_controller.dart (Business Logic)
/// - View: views/carpetas_view.dart (UI Only)
/// 
/// This wrapper maintains backward compatibility with existing navigation
class CarpetasScreen extends StatelessWidget {
  const CarpetasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CarpetasView();
  }
}
