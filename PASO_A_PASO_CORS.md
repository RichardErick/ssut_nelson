# SOLUCIÓN DEFINITIVA AL ERROR CORS

## El Problema

Chrome bloquea con: `Access to XMLHttpRequest ... has been blocked by CORS policy`

**Causa:** El backend que está corriendo NO tiene el código actualizado con la configuración CORS.

---

## SOLUCIÓN EN 5 PASOS (NO SE PUEDE SALTAR NINGUNO)

### PASO 1: Cerrar TODO

Cierra **TODAS** las ventanas de CMD/PowerShell/Terminal que tengan el backend o frontend.

Si no estás seguro, abre **Task Manager** (Ctrl+Shift+Esc), busca `SistemaGestionDocumental.exe` y ciérralo.

O en PowerShell:
```powershell
Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

### PASO 2: Actualizar el código

Ve a **D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion** (o donde tengas el proyecto):

```powershell
cd D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion
git pull origin main
```

**IMPORTANTE:** Si git pull dice "Already up to date" pero sigues con error CORS, significa que:
- O no estás en la carpeta correcta
- O hay conflictos locales

Si hay conflictos, haz:
```powershell
git stash
git pull origin main
```

---

### PASO 3: Verificar que Program.cs está actualizado

Abre `backend\Program.cs` y busca (alrededor de línea 50-62):

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApp",
        policy =>
        {
            policy.SetIsOriginAllowed(_ => true)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials()
```

**Si NO ves eso:** El git pull no funcionó. Copia manualmente:

```powershell
# Desde donde esté actualizado (por ejemplo Desktop):
Copy-Item "C:\Users\ERICK\Desktop\tareas bro\Sistema_info_web_gestion\backend\Program.cs" `
          "D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion\backend\Program.cs" -Force
```

---

### PASO 4: Arrancar con el script

Desde la **raíz del proyecto** (donde están las carpetas backend y frontend):

**Opción A - Script .bat (más simple):**
```cmd
ARRANCAR_SIMPLE.bat
```

**Opción B - arrancar_todo.bat:**
```cmd
arrancar_todo.bat
```

**Ambos hacen lo mismo:** cierran backend anterior, limpian, arrancan backend (12s espera) y frontend.

---

### PASO 5: Probar

1. Espera a que en la ventana "Backend - SSUT" veas:
   ```
   Now listening on: http://localhost:5000
   ```

2. Espera a que Chrome abra automáticamente con la app.

3. En la pantalla de login, haz clic en **"Comprobar conexión"**.
   - Si sale verde "Servidor alcanzable" → OK, el backend responde.
   - Si sale naranja "No se pudo conectar" → el backend no arrancó.

4. Intenta login con `doc_admin` / `admin`.

---

## Si SIGUE saliendo error CORS después de todo esto

Significa que **estás ejecutando un backend diferente** del que crees. Haz esto:

1. Abre Task Manager (Ctrl+Shift+Esc)
2. Busca "SistemaGestionDocumental" en la pestaña Detalles
3. Clic derecho → "Open file location"
4. **Esa** es la carpeta del backend que está corriendo.
5. Verifica que sea `D:\carpetafin\...` (o donde hiciste git pull)
6. Si es otra carpeta, ciérralo y arranca desde la carpeta correcta.

---

## Última opción: Compilar manualmente

Si los scripts no funcionan:

```powershell
# 1. Cerrar
Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Ir a backend
cd D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion\backend

# 3. Limpiar
dotnet clean

# 4. Compilar y ver output
dotnet build

# 5. Si build es exitoso, ejecutar
dotnet run
```

Deja esa ventana abierta. En OTRA terminal:

```powershell
cd D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion\frontend
flutter run -d chrome
```

---

## Comprobación final

En Chrome, abre la consola (F12) y busca:

- ❌ Si ves: `Access to XMLHttpRequest ... blocked by CORS policy` → El backend NO está actualizado o no es el que crees.
- ✅ Si ves: Peticiones a `/api/auth/login` que responden (aunque sea 401) → CORS funciona, el problema es otro.

---

## Contacto de emergencia

Si después de TODO esto sigue sin funcionar, comparte:
1. El output completo de `git pull origin main`
2. Las primeras 100 líneas de `backend\Program.cs`
3. El output de la ventana "Backend - SSUT" cuando arranca
