@echo off
echo Limpiando archivos de documentacion innecesarios...

REM Borrar archivos de soluciones antiguas
del /Q AGREGAR_AREA_AUDITORIA.md 2>nul
del /Q CAMBIOS_VALIDACION_RANGO_MEJORADA.md 2>nul
del /Q DASHBOARD_REPORTES_RESUMEN.md 2>nul
del /Q DEBUG_NAVEGACION_JERARQUICA.md 2>nul
del /Q FUNCIONALIDAD_COMPARTIR_DOCUMENTO.md 2>nul
del /Q FUNCIONALIDAD_DESCARGAR_QR.md 2>nul
del /Q INSTRUCCIONES_DASHBOARD_REPORTES.md 2>nul
del /Q INVESTIGACION_CAMBIO_USUARIO.md 2>nul
del /Q MEJORA_PANTALLA_REPORTES_DASHBOARD.md 2>nul
del /Q MEJORA_VISUALIZACION_PDF.md 2>nul
del /Q MEJORAS_DISENO.md 2>nul
del /Q MEJORAS_MANEJO_ERRORES.md 2>nul
del /Q MEJORAS_REPORTE_PERSONALIZADO_AVANZADO.md 2>nul
del /Q PASO_A_PASO_CORS.md 2>nul
del /Q REPORTE_PERSONALIZADO_IMPLEMENTACION.md 2>nul
del /Q RESUMEN_CAMBIOS_VALIDACION.md 2>nul
del /Q RESUMEN_FUNCIONALIDAD_ACTUAL.md 2>nul
del /Q RESUMEN_MEJORAS_REPORTES_FINAL.md 2>nul
del /Q SOLUCION_ACTUALIZACION_AUTOMATICA_Y_MEJORAS.md 2>nul
del /Q SOLUCION_CORS.md 2>nul
del /Q SOLUCION_ERROR_DOCUMENTO_404.md 2>nul
del /Q SOLUCION_ERRORES_COMPILACION_FINAL.md 2>nul
del /Q SOLUCION_NAVEGACION_JERARQUICA.md 2>nul
del /Q SOLUCION_PERMISOS_ADMIN.md 2>nul
del /Q SOLUCION_QR_FINAL.md 2>nul
del /Q SOLUCION_QR_IMAGEN_REAL.md 2>nul
del /Q SOLUCION_QR_INDEPENDIENTE_PUERTO.md 2>nul
del /Q SOLUCION_QR_MEJORADA.md 2>nul
del /Q SOLUCION_QR_SCANNER.md 2>nul
del /Q SOLUCION_QR_SIMPLIFICADA_FINAL.md 2>nul
del /Q SOLUCION_VALIDACION_DUPLICADOS_SUBCARPETAS.md 2>nul
del /Q SOLUCION_VALIDACION_RANGO_CARPETAS.md 2>nul
del /Q CORRECCION_FLUTTER.md 2>nul
del /Q CORRECCION_NAVEGACION_Y_OVERFLOW.md 2>nul
del /Q .refactor_plan.md 2>nul

echo.
echo Archivos borrados exitosamente!
echo.
echo Archivos que se mantienen:
echo - README.md (documentacion principal)
echo - INSTALLATION.md (instrucciones de instalacion)
echo - PROJECT_STRUCTURE.md (estructura del proyecto)
echo - DOCUMENTACION_TECNICA_SISTEMA.md (documentacion tecnica)
echo - ARRANQUE.md (instrucciones de arranque)
echo - RESUMEN_COMPLETO_MEJORAS_REPORTES.md (resumen de reportes)
echo - SOLUCION_EXPORTACION_REPORTES.md (solucion exportacion)
echo - SOLUCION_NUMERACION_INDEPENDIENTE_CARPETAS.md (solucion numeracion)
echo - CAMBIOS_SPRINT_MARZO_2026.md (cambios del sprint)
echo - VERIFICACION_SPRINT1_Y_SPRINT2.md (verificacion sprints)
echo - RECUPERACION_CONTRASENA.md (recuperacion de contrasena)
echo - GITHUB_SSUT_NELSON.md (info de github)
echo.
pause
