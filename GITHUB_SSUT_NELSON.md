# Repositorio GitHub: ssut_nelson

Este proyecto está vinculado al repositorio **https://github.com/RichardErick/ssut_nelson.git**.

## Lo que ya está hecho (en tu máquina)

1. **Remote cambiado**: `origin` apunta a `https://github.com/RichardErick/ssut_nelson.git`
2. **Commit creado**: todos los cambios están en un commit en la rama `main`

## Lo que debes hacer tú (cuando tengas internet)

Desde la carpeta del proyecto ejecuta:

```bash
git push -u origin main
```

Si GitHub pide autenticación, usa tu usuario y un **Personal Access Token** (no la contraseña de la cuenta).  
Crear token: GitHub → Settings → Developer settings → Personal access tokens.

---

## Si tu amigo ya tiene el proyecto abierto y solo quiere conectarse a tu repo

En la carpeta del proyecto que ya tiene abierta:

1. **Abrir terminal** en esa carpeta (PowerShell o CMD, o terminal integrada del editor).

2. **Ver si ya es un repositorio Git**  
   Ejecutar: `git status`  
   - Si dice "not a git repository", ir al paso 3A.  
   - Si no da error, ya es repo; ir al paso 3B.

3. **Conectar al repositorio**

   **3A – Todavía no es un repo Git**  
   ```bash
   git init
   git remote add origin https://github.com/RichardErick/ssut_nelson.git
   git fetch origin
   git branch -M main
   git reset --hard origin/main
   ```  
   Así la carpeta queda enlazada a tu repo y con el mismo código que hay en GitHub (se descartan cambios locales si los había).

   **3B – Ya es un repo Git**  
   ```bash
   git remote set-url origin https://github.com/RichardErick/ssut_nelson.git
   git fetch origin
   git branch -M main
   git reset --hard origin/main
   ```  
   (Si antes tenía otro `origin`, con esto lo reemplaza por tu repo.)

4. **A partir de ahora, para actualizar** (cuando tú subas cambios):  
   En la misma carpeta del proyecto:
   ```bash
   git pull
   ```

   **Nota:** Si tu amigo tiene cambios propios que no quiere perder, en lugar de `git reset --hard origin/main` puede hacer `git pull origin main --allow-unrelated-histories` y resolver conflictos si aparecen. Si lo que quiere es solo quedar igual que tu repo, `git reset --hard origin/main` es lo más simple.

---

## Cómo debe configurar tu amigo GitHub para bajar el proyecto (desde cero)

### 1. Instalar Git (si no lo tiene)

- Descargar: **https://git-scm.com/download/win**
- Instalar con las opciones por defecto.
- Abrir **PowerShell** o **Símbolo del sistema** y comprobar:
  ```bash
  git --version
  ```

### 2. No necesita cuenta de GitHub para solo descargar

Si el repositorio es **público**, tu amigo puede clonar sin tener cuenta ni configurar nada en GitHub. Solo ejecuta el comando de clonar (paso 3).

Si en el futuro tú le pides que haga `git pull` y le pide usuario/contraseña, puede crear una cuenta en **https://github.com** (gratis) y usar un **Personal Access Token** como contraseña. Por ahora, para la primera descarga, no es obligatorio.

### 3. Descargar el proyecto (clonar)

Abrir una carpeta donde quiera tener el proyecto (por ejemplo `Escritorio` o `Documentos`) y ejecutar:

```bash
git clone https://github.com/RichardErick/ssut_nelson.git
cd ssut_nelson
```

Se creará la carpeta **ssut_nelson** con todo el código del proyecto.

### 4. Después de clonar: configurar el proyecto

- **Backend**: editar `backend/appsettings.Development.json` (o `appsettings.json`) y poner su cadena de conexión a la base de datos. Ver detalles en `backend/CONEXION_BD.md`.
- **Base de datos**: ejecutar los scripts SQL en orden en la carpeta `database/migrations/` (incluida `007_add_solicitud_rechazada.sql` si corresponde).
- **Frontend**: abrir una terminal en la carpeta del proyecto y ejecutar:
  ```bash
  cd frontend
  flutter pub get
  ```

---

## Para tu amigo: resumen rápido

Tu amigo **no** debe copiar archivos a mano. Solo tiene que clonar el repo una vez y luego usar `git pull` para actualizarse.

### Primera vez (clonar)

```bash
git clone https://github.com/RichardErick/ssut_nelson.git
cd ssut_nelson
```

Luego configurar BD (ver `backend/CONEXION_BD.md`), ejecutar migraciones y en `frontend` hacer `flutter pub get`.

### Cada vez que tú subas cambios (actualizar)

Tu amigo solo ejecuta en la carpeta del proyecto:

```bash
git pull
```

Y ya tendrá la última versión. Luego puede volver a ejecutar el backend y/o Flutter según necesite.

---

## Resumen

| Quién   | Acción                          |
|--------|-----------------------------------|
| **Tú** | `git push -u origin main` (una vez con internet) |
| **Amigo (primera vez)** | `git clone https://github.com/RichardErick/ssut_nelson.git` y configurar BD + Flutter |
| **Amigo (después)**    | `git pull` cada vez que tú subas cambios |
