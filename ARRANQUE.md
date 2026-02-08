# Cómo arrancar el proyecto

El **backend** debe estar en ejecución **antes** de usar la app (login, auditoría, etc.). Si no, verás "No se pudo conectar con el servidor".

**Solo puede haber un backend** escuchando en el puerto 5000. Si abres un segundo `dotnet run` en otra terminal, verás *"address already in use"*: cierra antes el primero (Ctrl+C en esa terminal o los comandos de abajo).

## Opción rápida: un solo archivo

En la **raíz del proyecto** (donde están las carpetas `backend` y `frontend`), ejecuta:

```cmd
arrancar_todo.bat
```

Se abrirán **dos ventanas**: una con el backend (puerto 5000) y otra con el frontend (Flutter en Chrome). **Ejecuta el .bat solo una vez**; si lo ejecutas varias veces se abrirán 4 o más ventanas y pueden aparecer errores de conexión.

**Si ves "ERR_CONNECTION_REFUSED" o "Failed to load resource" en Chrome:** suele ser porque se cerró la ventana "Frontend - SSUT" (el servidor de Flutter se apagó) pero la pestaña del navegador sigue intentando cargar. Cierra esa pestaña, deja abierta la ventana del Frontend y espera a que compile; o cierra todas las ventanas y ejecuta `arrancar_todo.bat` de nuevo **una sola vez**.

---

## Orden recomendado (manual)

### 1. Terminal 1: Backend (solo una vez)

```powershell
cd backend
dotnet run
```

Espera a ver: **Now listening on: http://localhost:5000**. **No cierres esta ventana** ni ejecutes otro `dotnet run` en otra terminal.

### 2. Terminal 2: Frontend (Flutter web)

```powershell
cd frontend
flutter run -d chrome
```

Luego abre la app en el navegador e inicia sesión (por ejemplo `doc_admin` / `admin`).

---

## Si sale "address already in use" (puerto 5000 en uso)

Ya hay un backend en marcha. Opciones:

1. **Usar ese backend** – No abras otro; la app debe usar el que ya está en el 5000.
2. **Cerrar el que está y arrancar uno nuevo** – En la terminal donde está corriendo el backend, pulsa **Ctrl+C**. Si ya cerraste esa ventana, en **PowerShell** (desde cualquier carpeta):

```powershell
Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue | Stop-Process -Force
```

Luego en la carpeta `backend`: `dotnet run`.

> En PowerShell **no uses** `taskkill ... 2>nul`; da error. Usa el comando de arriba o CMD (ver siguiente sección).

---

## Si el backend no compila (Access denied al .exe)

El proceso anterior puede seguir en memoria. En **PowerShell** (dentro de `backend`):

```powershell
Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
dotnet clean
dotnet run
```

O desde **CMD** (no PowerShell):

```cmd
cd backend
taskkill /IM SistemaGestionDocumental.exe /F
timeout /t 2 /nobreak
dotnet clean
dotnet run
```

---

## Comprobar que el backend responde

En el navegador abre: [http://localhost:5000/swagger](http://localhost:5000/swagger)  
Si carga Swagger, el backend está bien. Si no carga, inicia el backend en la terminal 1.

---

## Si no tienes `run_backend.bat` en tu carpeta

Los scripts `run_backend.bat` y `run_backend.ps1` están en el repo (carpeta `backend`). Si trabajas desde otra copia del proyecto (por ejemplo `D:\carpetafin\...`) y no están ahí, puedes:

- Copiarlos desde la copia que tenga el repo, o  
- Usar siempre los comandos de PowerShell o CMD de las secciones anteriores (cerrar proceso, `dotnet clean`, `dotnet run`).
