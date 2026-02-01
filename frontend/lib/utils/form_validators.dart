import 'package:flutter/material.dart';

/// Mensajes de validación en español para que el usuario entienda qué corregir.
class FormValidators {
  FormValidators._();

  static const String requerido = 'Este campo es obligatorio';
  static const String nombreMinimo =
      'El nombre debe tener al menos 5 caracteres';
  static const String usuarioMinimo =
      'El usuario debe tener al menos 4 caracteres';
  static const String usuarioCaracteres = 'Use solo letras, números y punto';
  static const String emailInvalido = 'Ingrese un correo electrónico válido';
  static const String passwordMinimo =
      'La contraseña debe tener al menos 6 caracteres';
  static const String seleccioneOpcion = 'Seleccione una opción';
  static const String anioInvalido = 'Ingrese un año válido (ej. 2025)';
  static const String anioRango = 'El año debe estar entre 2020 y 2030';
  static const String rangoInicioMenor =
      'El inicio debe ser menor o igual al fin';
  static const String rangoAmbos = 'Complete ambos rangos o deje ambos vacíos';

  /// Valida que no esté vacío.
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return requerido;
    return null;
  }

  /// Valida nombre completo (mínimo 5 caracteres).
  static String? nombre(String? value) {
    if (value == null || value.trim().isEmpty) return requerido;
    if (value.trim().length < 5) return nombreMinimo;
    return null;
  }

  /// Valida usuario (mínimo 4, solo alfanumérico y punto).
  static String? usuario(String? value) {
    if (value == null || value.trim().isEmpty) return requerido;
    if (value.trim().length < 4) return usuarioMinimo;
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim()))
      return usuarioCaracteres;
    return null;
  }

  /// Valida correo electrónico.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return requerido;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim()))
      return emailInvalido;
    return null;
  }

  /// Valida contraseña (mínimo 6 caracteres).
  static String? password(String? value) {
    if (value == null || value.isEmpty) return requerido;
    if (value.length < 6) return passwordMinimo;
    return null;
  }

  /// Valida año (número entre 2020 y 2030).
  static String? anio(String? value) {
    if (value == null || value.trim().isEmpty) return requerido;
    final year = int.tryParse(value.trim());
    if (year == null) return anioInvalido;
    if (year < 2020 || year > 2030) return anioRango;
    return null;
  }
}

/// Estilo de error para todos los formularios: borde rojo y texto rojo debajo.
class FormDecorationHelper {
  FormDecorationHelper._();

  static OutlineInputBorder errorBorder({double radius = 12}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
    );
  }

  static OutlineInputBorder focusedErrorBorder({double radius = 12}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: Colors.red.shade600, width: 2),
    );
  }

  static TextStyle errorStyle() {
    return TextStyle(color: Colors.red.shade700, fontSize: 13);
  }

  /// Añade a un InputDecoration existente los bordes y estilo de error.
  static InputDecoration mergeErrorStyle(
    InputDecoration decoration, {
    double radius = 12,
  }) {
    return decoration.copyWith(
      errorBorder: errorBorder(radius: radius),
      focusedErrorBorder: focusedErrorBorder(radius: radius),
      errorStyle: errorStyle(),
    );
  }
}
