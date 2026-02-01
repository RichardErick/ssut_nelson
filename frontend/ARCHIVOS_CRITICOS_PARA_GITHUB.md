# Archivos críticos que deben estar en GitHub

Para que tu amigo (o cualquier clon del repo) no tenga **pantalla en blanco** ni errores de compilación, estos archivos **tienen que estar subidos y actualizados** en el repositorio.

## 1. Providers (obligatorios)

- `frontend/lib/providers/auth_provider.dart`
- `frontend/lib/providers/data_provider.dart`  ← **Si falta, la app no compila o falla al iniciar**
- `frontend/lib/providers/theme_provider.dart`

## 2. Punto de entrada y pantallas iniciales

- `frontend/lib/main.dart`
- `frontend/lib/screens/splash_screen.dart`
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/screens/home_screen.dart`

## 3. Pantallas de documentos (donde quitamos DataProvider del detalle)

- `frontend/lib/screens/documentos/documento_detail_screen.dart`  ← Sin import de DataProvider
- `frontend/lib/screens/documentos/documentos_list_screen.dart`
- `frontend/lib/screens/admin/roles_permissions_screen.dart`

## 4. Servicios

- `frontend/lib/services/carpeta_service.dart`
- Resto de servicios en `frontend/lib/services/` (api_service, documento_service, etc.)

## Cómo subir todos los cambios (tú, en tu máquina)

En la **raíz del proyecto** (`Sistema_info_web_gestion`):

```bash
git status
git add .
git commit -m "Sync: providers, pantallas, servicios y manejo de errores en main"
git push origin main
```

Luego tu amigo hace:

```bash
git pull origin main
cd frontend
flutter clean
flutter pub get
flutter run -d chrome
```

## Si tu amigo sigue con pantalla en blanco

1. Que abra la **consola del navegador** (F12 → pestaña Console) y mire si sale algún error en rojo.
2. Con el cambio en `main.dart`, si hay un error al construir la app debería verse un mensaje en pantalla en lugar de quedar en blanco.
3. Que confirme que tiene **todos** los archivos de la lista (sobre todo `data_provider.dart` y `main.dart`).
