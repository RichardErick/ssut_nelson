# Guía de Instalación - Sistema de Gestión Documental SSUT

## Requisitos Previos

### Backend
- .NET 8.0 SDK o superior
- PostgreSQL 14 o superior
- Visual Studio 2022, VS Code o Rider

### Frontend
- Flutter SDK 3.0 o superior
- Dart SDK 3.0 o superior
- Android Studio / VS Code con extensiones de Flutter

## Instalación del Backend

1. **Navegar al directorio del backend:**
```bash
cd backend
```

2. **Restaurar dependencias:**
```bash
dotnet restore
```

3. **Configurar la base de datos:**
   - Crear la base de datos PostgreSQL:
   ```sql
   CREATE DATABASE ssut_gestion_documental;
   ```
   
   - Ejecutar los scripts SQL:
   ```bash
   psql -U postgres -d ssut_gestion_documental -f ../database/schema.sql
   psql -U postgres -d ssut_gestion_documental -f ../database/seed_data.sql
   ```

4. **Configurar la cadena de conexión:**
   - Editar `appsettings.json` o `appsettings.Development.json`
   - Actualizar la cadena de conexión con tus credenciales de PostgreSQL

5. **Ejecutar el proyecto:**
```bash
dotnet run
```

El API estará disponible en `https://localhost:7000` o `http://localhost:5000`

## Instalación del Frontend

1. **Navegar al directorio del frontend:**
```bash
cd frontend
```

2. **Obtener dependencias:**
```bash
flutter pub get
```

3. **Configurar la URL del API:**
   - Editar `lib/main.dart`
   - Actualizar `baseUrl` en `ApiService` con la URL de tu backend

4. **Ejecutar el proyecto:**
```bash
# Para web
flutter run -d chrome

# Para Android
flutter run

# Para iOS (solo en macOS)
flutter run -d ios
```

## Configuración de CORS

Si el frontend se ejecuta en un puerto diferente, asegúrate de actualizar la configuración de CORS en `backend/Program.cs`:

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterApp",
        policy =>
        {
            policy.WithOrigins("http://localhost:3000", "http://localhost:8080", "http://localhost:50000")
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        });
});
```

## Verificación

1. **Backend:** Abre `https://localhost:7000/swagger` para ver la documentación del API
2. **Frontend:** La aplicación debería iniciar y mostrar la pantalla de login

## Solución de Problemas

### Error de conexión a la base de datos
- Verifica que PostgreSQL esté ejecutándose
- Confirma que la cadena de conexión sea correcta
- Asegúrate de que la base de datos exista

### Error de CORS en el frontend
- Verifica que la URL del backend en `main.dart` sea correcta
- Asegúrate de que el backend esté ejecutándose
- Revisa la configuración de CORS en `Program.cs`

### Dependencias faltantes en Flutter
```bash
flutter pub get
flutter clean
flutter pub get
```

## Próximos Pasos

1. Implementar autenticación real (actualmente es simulada)
2. Agregar validaciones adicionales
3. Implementar generación de reportes PDF
4. Agregar más funcionalidades según los requisitos

