@echo off
echo =====================================================
echo Aplicando cambios de bloqueo progresivo en la BD
echo =====================================================
echo.
echo Este script agregara la columna 'bloqueos_acumulados' a la tabla usuarios.
echo.
pause

echo.
echo Ejecutando script SQL...
echo.

REM Usar la ruta completa de psql desde PostgreSQL 17
set PGPASSWORD=admin
"C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d ssut_gestion_documental -f add_bloqueos_acumulados.sql

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =====================================================
    echo ¡Cambios aplicados exitosamente!
    echo =====================================================
    echo.
    echo La columna 'bloqueos_acumulados' ha sido agregada a la tabla usuarios.
    echo Ahora el sistema implementará bloqueo progresivo:
    echo   - 1er bloqueo: 10 minutos
    echo   - 2do bloqueo: 20 minutos
    echo   - 3er bloqueo: 40 minutos
    echo   - Y así sucesivamente...
) else (
    echo.
    echo =====================================================
    echo ERROR: No se pudo ejecutar el script SQL.
    echo =====================================================
    echo.
    echo Verifique que:
    echo   1. PostgreSQL esta en ejecucion
    echo   2. La base de datos 'ssut_gestion_documental' existe
    echo   3. Las credenciales son correctas (usuario: postgres, password: admin)
    echo.
    echo Puede ejecutar manualmente desde pgAdmin:
    echo   - Abrir pgAdmin
    echo   - Conectarse a ssut_gestion_documental
    echo   - Abrir Query Tool
    echo   - Copiar y ejecutar el contenido de add_bloqueos_acumulados.sql
)

echo.
pause
