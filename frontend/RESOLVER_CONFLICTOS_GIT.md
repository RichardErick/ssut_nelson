# Cómo quitar los errores de conflicto de Git

Los errores tipo `'HEAD' isn't a type` o `Expected '>' after this` aparecen porque en el código quedaron **marcadores de conflicto de Git** que no son Dart válido.

---

## Si eres el programador y tu amigo es el cliente (sin scripts)

**Tú (programador):**

1. En tu proyecto (donde no hay conflictos) tienes ya limpios estos archivos:
   - `frontend/lib/screens/home_screen.dart`
   - `frontend/lib/screens/notifications_screen.dart`
2. Envíale a tu amigo esos **dos archivos** (por WhatsApp, correo, Google Drive, USB, o subiéndolos al repo y que haga pull).
3. Dile que los copie en su carpeta del proyecto **reemplazando** los que tiene:
   - En su PC: `C:\Users\Brayan Cortez\Desktop\sistema seguro\frontend\lib\screens\`
   - Que pegue ahí `home_screen.dart` y `notifications_screen.dart` (y que acepte sobrescribir).

**Tu amigo (cliente), después de pegar los archivos:**

1. Abre PowerShell en la carpeta del proyecto:
   ```powershell
   cd "C:\Users\Brayan Cortez\Desktop\sistema seguro"
   ```
2. Ejecuta solo estas dos líneas (una por una):
   ```powershell
   git add frontend/lib/screens/home_screen.dart frontend/lib/screens/notifications_screen.dart
   git commit -m "Resueltos conflictos"
   ```
3. Listo. Ya puede hacer `git pull` si lo necesita.

No hace falta descargar ni ejecutar ningún script en su computadora.

---

## Opción rápida: script automático (si el cliente puede ejecutarlo)

### Opción A – Desde la carpeta **frontend**

1. Abre PowerShell.
2. Ve a la carpeta frontend:
   ```powershell
   cd "C:\Users\Brayan Cortez\Desktop\sistema seguro\frontend"
   ```
3. Ejecuta el script (importante: **punto, barra invertida y nombre del archivo**, sin espacios):
   ```powershell
   .\quitar_conflictos_git.ps1
   ```
   Si sale error de "scripts deshabilitados", usa:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\quitar_conflictos_git.ps1
   ```

### Opción B – Desde la carpeta del proyecto (raíz)

1. Copia el archivo **`quitar_conflictos_git.ps1`** que está en la **raíz del repo** (junto a la carpeta `frontend`) a la raíz de "sistema seguro" (si no lo tienes, cópialo desde `frontend\quitar_conflictos_git.ps1` y en el script usa la opción A).
2. En PowerShell, desde la raíz del proyecto:
   ```powershell
   cd "C:\Users\Brayan Cortez\Desktop\sistema seguro"
   .\quitar_conflictos_git.ps1
   ```

### Después del script

Cuando diga "Resuelto", ejecuta **desde la raíz del proyecto** (`sistema seguro`):

```powershell
cd "C:\Users\Brayan Cortez\Desktop\sistema seguro"
git add frontend/lib/screens/home_screen.dart frontend/lib/screens/notifications_screen.dart
git commit -m "Resueltos conflictos de merge"
```

**Si estás dentro de la carpeta `frontend`**, usa estas rutas (sin `frontend/`):

```powershell
git add lib/screens/home_screen.dart lib/screens/notifications_screen.dart
git commit -m "Resueltos conflictos de merge"
```

Luego ya puedes hacer `git pull` si hace falta.

---

## Opción manual

1. **Abre** en tu editor:
   - `lib/screens/home_screen.dart`
   - `lib/screens/notifications_screen.dart`

2. **Busca** en cada archivo (Ctrl+F):
   - `<<<<<<< `
   - `=======`
   - `>>>>>>> `

3. **En cada conflicto** verás algo así:
   ```
   <<<<<<< HEAD
   (código versión A)
   =======
   (código versión B)
   >>>>>>> 15e9afe3caae8906b3b40cf95a234a6070fd9b2d
   ```
   - Borra la línea `<<<<<<< HEAD`
   - Borra la línea `=======`
   - Borra la línea `>>>>>>> 15e9afe3...`
   - **Deja solo una de las dos versiones** (A o B). Si quieres menú con Notificaciones, Mi perfil y Gestión de Permisos para admin documentos, quédate con la **primera** (versión A / HEAD).

4. **Guarda** y vuelve a ejecutar: `flutter run -d chrome`

## Si prefieres reemplazar todo el archivo

Copia el contenido actual de `home_screen.dart` y `notifications_screen.dart` desde este mismo proyecto (la copia que no tiene conflictos) y pégalo en tu carpeta donde estás compilando (por ejemplo `C:\Users\Brayan Cortez\Desktop\sistema seguro\frontend\lib\screens\`), sobrescribiendo los archivos.

## Nota

Si estás en otro equipo o carpeta (por ejemplo "sistema seguro"), haz un **pull** desde el repo y resuelve los conflictos en Git, o copia estos dos archivos desde el repo que ya está limpio.
