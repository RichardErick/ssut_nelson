# Resolver conflictos de merge (git pull)

Cuando `git pull` dice **CONFLICT (content)** en algunos archivos:

1. Abre cada archivo que indique Git (ej. `frontend/COMO_HACER_GIT_PULL.md`, `frontend/lib/main.dart`, `frontend/lib/screens/notifications_screen.dart`).

2. Busca las marcas de conflicto:
   - `<<<<<<< HEAD` — inicio de **tu versión** (local)
   - `=======` — separador
   - `>>>>>>> origin/main` (o un hash) — fin de la **versión del repo**

3. Decide qué quedarse:
   - **Solo tu versión:** borra desde `=======` hasta `>>>>>>> ...` (inclusive) y borra la línea `<<<<<<< HEAD`.
   - **Solo la del repo:** borra desde `<<<<<<< HEAD` hasta `=======` (inclusive) y borra la línea `>>>>>>> ...`.
   - **Combinar:** deja el código que quieras de cada lado y borra **todas** las marcas (`<<<<<<<`, `=======`, `>>>>>>>`).

4. Guarda los archivos.

5. En la raíz del proyecto:
   ```powershell
   git add frontend/COMO_HACER_GIT_PULL.md frontend/lib/main.dart frontend/lib/screens/notifications_screen.dart
   git commit -m "Resolviendo conflictos de merge"
   ```

---

## Opción rápida: quedarse con la versión del repo

Si quieres descartar tus cambios en esos archivos y dejar la versión de GitHub:

```powershell
git checkout --theirs frontend/COMO_HACER_GIT_PULL.md
git checkout --theirs frontend/lib/main.dart
git checkout --theirs frontend/lib/screens/notifications_screen.dart
git add frontend/COMO_HACER_GIT_PULL.md frontend/lib/main.dart frontend/lib/screens/notifications_screen.dart
git commit -m "Resolviendo conflictos: versión de origin/main"
```
