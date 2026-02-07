# Cómo arrancar el proyecto

El **backend** debe estar en ejecución **antes** de usar la app (login, auditoría, etc.). Si no, verás "No se pudo conectar con el servidor".

## Orden recomendado

### 1. Terminal 1: Backend

```powershell
cd backend
dotnet run
```

Espera a ver: **Now listening on: http://localhost:5000**. No cierres esta ventana.

### 2. Terminal 2: Frontend (Flutter web)

```powershell
cd frontend
flutter run -d chrome
```

Luego abre la app en el navegador e inicia sesión (por ejemplo `doc_admin` / `admin`).

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
