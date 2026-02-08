# Solución al error CORS

## Síntoma

Al intentar login aparece en la consola del navegador:

```
Access to XMLHttpRequest at 'http://localhost:5000/api/auth/login' from origin 'http://localhost:XXXXX' 
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

## Causa

El backend que está corriendo **NO tiene la configuración CORS actualizada**. Esto pasa cuando:
- No se hizo `git pull` para actualizar el código
- Se hizo `git pull` pero el backend sigue corriendo con la versión vieja

## Solución paso a paso

### Opción A: Script automático (recomendado)

1. Abre **PowerShell** en la raíz del proyecto (donde están las carpetas `backend` y `frontend`)

2. Si nunca ejecutaste scripts de PowerShell, primero:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

3. Ejecuta el script de verificación:
   ```powershell
   .\verificar_y_arrancar.ps1
   ```

   El script:
   - ✓ Verifica que Program.cs tenga CORS
   - ✓ Cierra backends anteriores
   - ✓ Limpia compilación
   - ✓ Inicia backend y frontend en ventanas separadas

4. Si el script dice "FALTA configuración CORS", haz:
   ```powershell
   git pull origin main
   ```
   Y ejecuta el script de nuevo.

---

### Opción B: Manual

1. **Actualiza el código**
   ```powershell
   cd D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion
   git pull origin main
   ```

2. **Cierra TODOS los backends** (Ctrl+C en las ventanas donde estén corriendo, o):
   ```powershell
   Get-Process -Name "SistemaGestionDocumental" -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

3. **Limpia y compila**
   ```powershell
   cd backend
   dotnet clean
   dotnet run
   ```

4. **Espera a ver** `Now listening on: http://localhost:5000`

5. **En OTRA terminal**, inicia el frontend:
   ```powershell
   cd frontend
   flutter run -d chrome
   ```

6. **Prueba el login** con `doc_admin` / `admin`

---

## Verificar que el código está actualizado

El archivo `backend\Program.cs` debe contener (alrededor de la línea 50-62):

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
            .WithExposedHeaders("Content-Disposition", "Content-Length");
        });
});
```

Y más abajo (línea 153):

```csharp
app.UseCors("AllowFlutterApp");
```

Si NO ves eso, **no se hizo el git pull correctamente** o estás viendo otro archivo. Haz `git pull` de nuevo.

---

## Si sigue fallando

1. **Verifica que hiciste git pull** en la carpeta correcta:
   - Si trabajas desde `D:\carpetafin\...`, haz pull ahí
   - Si trabajas desde `C:\Users\...\Desktop\...`, haz pull ahí

2. **Asegúrate de que el backend que está corriendo** es el que acabas de arrancar:
   - Cierra TODAS las ventanas de CMD/PowerShell
   - Abre Task Manager (Ctrl+Shift+Esc)
   - Busca "SistemaGestionDocumental" y ciérralo
   - Ejecuta `verificar_y_arrancar.ps1` de nuevo

3. **Verifica el puerto**:
   - El backend debe estar en `http://localhost:5000`
   - Si ves otro puerto (5001, 5002, etc.), el backend no está configurado bien

4. **Última opción**: Copia manualmente `Program.cs` desde el repo actualizado:
   ```powershell
   # Desde la carpeta que esté al día con GitHub:
   Copy-Item "C:\Users\ERICK\Desktop\tareas bro\Sistema_info_web_gestion\backend\Program.cs" `
             "D:\carpetafin\Sistema_info_web_gestion\Sistema_info_web_gestion\backend\Program.cs" -Force
   ```
   Luego: cerrar backend, `dotnet clean`, `dotnet run`.
