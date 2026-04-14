import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/tema_aplicacion.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get esModoOscuro => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _cargarModoTema();
  }

  Future<void> _cargarModoTema() async {
    _prefs = await SharedPreferences.getInstance();
    final esOscuro = _prefs?.getBool('esModoOscuro') ?? false;
    _themeMode = esOscuro ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> cambiarTema() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _prefs?.setBool('esModoOscuro', _themeMode == ThemeMode.dark);
    notifyListeners();
  }
}
