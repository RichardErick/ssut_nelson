# Cómo hacer git pull / push (Git)

## Push rechazado: "Updates were rejected... fetch first"

Si al hacer **git push** te sale:
- *"Updates were rejected because the remote contains work that you do not have locally"*
- *"If you want to integrate the remote changes, use 'git pull' before pushing again"*

**Pasos (Brayan / quien tenga el repo clonado):**

```powershell
cd "C:\Users\Brayan Cortez\Desktop\SSUT\Sistema_info_web_gest\Sistema_info_web_gestion"

# 1. Traer los cambios del remoto y mezclar con tu commit local
git pull origin main

# Si pide mensaje de merge, guarda y cierra el editor (en VS Code: guardar y cerrar el archivo).

# 2. Subir todo (tus cambios + los del remoto ya mezclados)
git push origin main
```

Si **git pull** muestra **conflictos** (Conflict in ...):
1. Abre los archivos que indique.
2. Busca las marcas `<<<<<<<`, `=======`, `>>>>>>>` y deja la versión correcta (o combina a mano).
3. Guarda, luego:
```powershell
git add .
git commit -m "Resolviendo conflictos de merge"
git push origin main
```

---

## Cambios locales que bloquean el merge (pull)

Si ves errores como:
- *"Your local changes would be overwritten by merge"*
- *"The following untracked working tree files would be overwritten by merge"*

sigue **una** de estas opciones.

---

## Opción A: Quiero quedarme con lo que hay en el repositorio (descartar mis cambios locales)

Abre PowerShell **en la raíz del proyecto** (carpeta `Sistema_info_web_gestion`, no dentro de `frontend`):

```powershell
cd "C:\Users\Brayan Cortez\Desktop\SSUT\Sistema_info_web_gest\Sistema_info_web_gestion"

# 1. Descartar cambios en los archivos que bloquean el merge
git checkout -- frontend/lib/providers/auth_provider.dart
git checkout -- frontend/lib/screens/admin/roles_permissions_screen.dart
git checkout -- frontend/lib/screens/documentos/documento_detail_screen.dart
git checkout -- frontend/lib/screens/login_screen.dart
git checkout -- frontend/lib/services/carpeta_service.dart

# 2. Quitar el archivo sin seguimiento para que el repo pueda traer su versión
Remove-Item -Path "frontend\lib\providers\data_provider.dart" -Force -ErrorAction SilentlyContinue

# 3. Ahora sí hacer pull
git pull origin main
```

---

## Opción B: Quiero guardar mis cambios locales y luego actualizar

Si tienes cambios que quieres conservar (y luego mezclar con lo del repo):

```powershell
cd "C:\Users\Brayan Cortez\Desktop\SSUT\Sistema_info_web_gest\Sistema_info_web_gestion"

# 1. Guardar tus cambios en la "stash"
git stash push -u -m "mis cambios antes del pull"

# 2. Quitar el archivo sin seguimiento (el repo traerá data_provider.dart)
Remove-Item -Path "frontend\lib\providers\data_provider.dart" -Force -ErrorAction SilentlyContinue

# 3. Actualizar desde el repo
git pull origin main

# 4. Recuperar tus cambios (pueden salir conflictos que tendrás que resolver)
git stash pop
```

Si al hacer `git stash pop` te dice que hay conflictos, abre los archivos que indique, resuélvelos y luego:

```powershell
git add .
git stash drop
```

---

## Opción C: Solo el archivo "data_provider.dart" me da problema

Si lo único que te bloquea es el mensaje de *"untracked working tree files would be overwritten"* por `data_provider.dart`:

```powershell
cd "C:\Users\Brayan Cortez\Desktop\SSUT\Sistema_info_web_gest\Sistema_info_web_gestion"

# Quitar tu copia local para que el pull traiga la del repo
Remove-Item -Path "frontend\lib\providers\data_provider.dart" -Force -ErrorAction SilentlyContinue

git pull origin main
```

Si además tienes cambios en otros archivos, primero haz **commit** o **stash** de esos cambios (como en la Opción B), y después el `Remove-Item` y el `git pull`.

---

## Resumen rápido

- **Solo quiero la versión del repo** → Opción A.
- **Quiero guardar mis cambios y luego actualizar** → Opción B.
- **Solo me bloquea data_provider.dart** → Opción C (y si hace falta, stash/commit del resto).

Después de cualquier opción, en la carpeta `frontend` ejecuta:

```powershell
cd frontend
flutter clean
flutter pub get
flutter run -d chrome
```
