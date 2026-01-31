# Cómo quitar los errores de conflicto de Git

Los errores tipo `'HEAD' isn't a type` o `Expected '>' after this` aparecen porque en el código quedaron **marcadores de conflicto de Git** que no son Dart válido.

---

## Si `documentos_list_screen.dart` sigue con errores (solución segura)

Si después del script siguen saliendo errores en **documentos_list_screen.dart** (<<<<<<< HEAD, Expected '>', _searchController isn't defined, etc.):

**Tú (programador):** Envía a Brayan tu archivo limpio:
- `frontend/lib/screens/documentos/documentos_list_screen.dart`

**Brayan:** Reemplaza su archivo con el tuyo:
1. Copia el archivo que te enviaron.
2. Pégalo aquí (sobrescribiendo):  
   `C:\Users\Brayan Cortez\Desktop\sistema seguro\frontend\lib\screens\documentos\documentos_list_screen.dart`
3. Luego en la raíz del proyecto:
   ```powershell
   cd "C:\Users\Brayan Cortez\Desktop\sistema seguro"
   git add frontend/lib/screens/documentos/documentos_list_screen.dart
   git commit -m "Resueltos conflictos"
   ```
4. Ejecuta: `flutter run -d chrome`

---

## Si eres el programador y tu amigo es el cliente (sin scripts)

**Tú (programador):**

1. En tu proyecto (donde no hay conflictos) tienes ya limpios estos archivos:
   - `frontend/lib/screens/home_screen.dart`
   - `frontend/lib/screens/notifications_screen.dart`
   - `frontend/lib/screens/documentos/documentos_list_screen.dart`
2. Envíale a tu amigo esos **tres archivos** (por WhatsApp, correo, Google Drive, USB, etc.).
3. Dile que los copie en su carpeta del proyecto **reemplazando** los que tiene:
   - `home_screen.dart` y `notifications_screen.dart` → en `...\sistema seguro\frontend\lib\screens\`
   - `documentos_list_screen.dart` → en `...\sistema seguro\frontend\lib\screens\documentos\`

**Tu amigo (cliente), después de pegar los archivos:**

1. Abre PowerShell en la carpeta del proyecto:
   ```powershell
   cd "C:\Users\Brayan Cortez\Desktop\sistema seguro"
   ```
2. Ejecuta (una línea por vez):
   ```powershell
   git add frontend/lib/screens/home_screen.dart frontend/lib/screens/notifications_screen.dart frontend/lib/screens/documentos/documentos_list_screen.dart
   git commit -m "Resueltos conflictos"
   ```
3. Listo. Ya puede hacer `git pull --no-edit` si lo necesita.

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
git add frontend/lib/screens/home_screen.dart frontend/lib/screens/notifications_screen.dart frontend/lib/screens/documentos/documentos_list_screen.dart
git commit -m "Resueltos conflictos de merge"
```

**Si estás dentro de la carpeta `frontend`**, usa estas rutas (sin `frontend/`):

```powershell
git add lib/screens/home_screen.dart lib/screens/notifications_screen.dart lib/screens/documentos/documentos_list_screen.dart
git commit -m "Resueltos conflictos de merge"
```

**Nota:** Si también salen errores en `documentos_list_screen.dart` (por ejemplo `<<<<<<< HEAD` o "Expected '>' after this"), el script ya incluye ese archivo. Vuelve a ejecutar el script desde `frontend` y luego el `git add` de los tres archivos.

Luego ya puedes hacer `git pull` si hace falta.

---

## Evitar que se abra el editor al hacer pull (merge)

Si al hacer `git pull` te sale un mensaje pidiendo "Please enter a commit message" (vim o otro editor), puedes evitarlo usando:

```powershell
git pull --no-edit
```

Así Git usa el mensaje de merge por defecto y no abre el editor.

Para que al hacer `git pull` nunca se abra el editor, Brayan puede crear un alias (una sola vez):

```powershell
git config --global alias.pulln "pull --no-edit"
```

Después, en lugar de `git pull`, que use: **`git pulln`**

---

## Opción manual

1. **Abre** en tu editor:
   - `lib/screens/home_screen.dart`
   - `lib/screens/notifications_screen.dart`
   - `lib/screens/documentos/documentos_list_screen.dart`

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

Copia el contenido actual de `home_screen.dart`, `notifications_screen.dart` y `documentos_list_screen.dart` desde este mismo proyecto (la copia que no tiene conflictos) y pégalo en tu carpeta: `home_screen.dart` y `notifications_screen.dart` en `frontend\lib\screens\`, y `documentos_list_screen.dart` en `frontend\lib\screens\documentos\`, sobrescribiendo los archivos.

## Nota

Si estás en otro equipo o carpeta (por ejemplo "sistema seguro"), haz un **pull** desde el repo y resuelve los conflictos en Git, o copia los tres archivos (home_screen, notifications_screen, documentos_list_screen) desde el repo que ya está limpio.
