/**
 * SCRIPT GENERADOR DE DIAGRAMAS MVVM - SSUT
 * ==========================================
 * INSTRUCCIONES:
 * 1. Abre StarUML
 * 2. Ve al menu: Tools > Scripts > Run Script...
 * 3. Selecciona este archivo: generar_diagramas_ssut.js
 * 4. Espera unos segundos y los diagramas se crean solos
 * ==========================================
 */

// ---- FUNCION PRINCIPAL ----
function crearDiagramaSecuencia(modelo, nombreInteraccion, participantes, mensajes, xBase, yBase) {
    // Crear la Colaboracion contenedora
    var interaccion = app.factory.createModel({
        id: 'UMLInteraction',
        parent: modelo,
        field: 'ownedElements'
    });
    interaccion.name = nombreInteraccion;

    // Crear el diagrama de secuencia (el lienzo)
    var diagrama = app.factory.createModel({
        id: 'UMLSequenceDiagram',
        parent: interaccion,
        field: 'ownedElements'
    });
    diagrama.name = 'Diagrama: ' + nombreInteraccion;

    // Crear lifelines (participantes) con sus vistas
    var lifelineViews = [];
    var lifelineModels = [];
    var xPos = xBase;

    participantes.forEach(function (nombre, idx) {
        // Modelo del lifeline
        var lifelineModel = app.factory.createModel({
            id: 'UMLLifeline',
            parent: interaccion,
            field: 'participants'
        });
        lifelineModel.name = nombre;
        lifelineModels.push(lifelineModel);

        // Vista del lifeline en el diagrama
        var lifelineView = app.factory.createView({
            id: 'UMLSeqLifelineView',
            parent: diagrama,
            model: lifelineModel
        });
        lifelineView.left = xPos;
        lifelineView.top = yBase;
        lifelineView.width = 130;
        lifelineView.height = mensajes.length * 60 + 100;
        lifelineViews.push(lifelineView);

        xPos += 200;
    });

    // Crear mensajes con sus vistas (flechas)
    var yPos = yBase + 80;
    mensajes.forEach(function (msg) {
        var origenIdx = msg.desde;
        var destinoIdx = msg.hasta;
        var nombre = msg.nombre;
        var esRespuesta = msg.respuesta || false;

        // Modelo del mensaje
        var mensajeModel = app.factory.createModel({
            id: 'UMLMessage',
            parent: interaccion,
            field: 'messages'
        });
        mensajeModel.name = nombre;
        mensajeModel.source = lifelineModels[origenIdx];
        mensajeModel.target = lifelineModels[destinoIdx];
        if (esRespuesta) {
            mensajeModel.messageSort = 'reply';
        }

        // Vista del mensaje (flecha)
        var mensajeView = app.factory.createView({
            id: 'UMLSeqMessageView',
            parent: diagrama,
            model: mensajeModel
        });
        mensajeView.tail = lifelineViews[origenIdx];
        mensajeView.head = lifelineViews[destinoIdx];

        yPos += 60;
    });

    return diagrama;
}

// ---- INICIO DEL SCRIPT ----
var proyecto = app.project.getProject();

// Crear modelo raiz
var modeloRaiz = app.factory.createModel({
    id: 'UMLModel',
    parent: proyecto,
    field: 'ownedElements'
});
modeloRaiz.name = 'MVVM - Sprints 1 y 2 (SSUT)';

// ================================
// HU-01: Registro de Usuarios
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-01: Registro de Usuarios',
    [
        'Vista:\nPantalla Registro',
        'Controlador:\nUsuariosVM',
        'API C#:\nSistema Central',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Enviar datos del formulario' },
        { desde: 1, hasta: 1, nombre: '   Validar campos obligatorios' },
        { desde: 1, hasta: 2, nombre: '2. Solicitar creacion de usuario' },
        { desde: 2, hasta: 2, nombre: '   Cifrar contrasena (Hash)' },
        { desde: 2, hasta: 3, nombre: '3. Guardar nuevo usuario' },
        { desde: 3, hasta: 2, nombre: '4. Registro guardado con ID', respuesta: true },
        { desde: 2, hasta: 1, nombre: '5. Confirmacion exitosa', respuesta: true },
        { desde: 1, hasta: 0, nombre: '6. Mostrar: Usuario registrado!', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-02: Inicio de Sesión
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-02: Inicio de Sesion',
    [
        'Vista:\nPantalla Login',
        'Controlador:\nAuthVM',
        'API C#:\nSistema Validacion',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Ingresar correo y contrasena' },
        { desde: 1, hasta: 2, nombre: '2. Validar credenciales' },
        { desde: 2, hasta: 3, nombre: '3. Buscar usuario por correo' },
        { desde: 3, hasta: 2, nombre: '4. Devolver datos y hash', respuesta: true },
        { desde: 2, hasta: 2, nombre: '   Verificar contrasena (Hash)' },
        { desde: 2, hasta: 2, nombre: '   Generar pase JWT' },
        { desde: 2, hasta: 1, nombre: '5. Acceso concedido + Permisos', respuesta: true },
        { desde: 1, hasta: 0, nombre: '6. Redirigir a pantalla principal', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-03: Gestión de Roles
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-03: Gestion de Roles',
    [
        'Vista:\nPantalla Roles',
        'Controlador:\nRolesVM',
        'API C#:\nSistema Control',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Crear / Editar rol' },
        { desde: 1, hasta: 2, nombre: '2. Guardar datos del rol' },
        { desde: 2, hasta: 3, nombre: '3. INSERT/UPDATE en tabla roles' },
        { desde: 3, hasta: 2, nombre: '4. Rol guardado', respuesta: true },
        { desde: 2, hasta: 1, nombre: '5. Confirmacion OK', respuesta: true },
        { desde: 1, hasta: 0, nombre: '6. Mostrar roles actualizados', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-04: Gestión de Permisos
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-04: Gestion de Permisos',
    [
        'Vista:\nPantalla Permisos',
        'Controlador:\nPermisosVM',
        'API C#:\nSistema Control',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Asignar permiso a un rol' },
        { desde: 1, hasta: 2, nombre: '2. Registrar nueva regla' },
        { desde: 2, hasta: 3, nombre: '3. INSERT en tabla rol_permisos' },
        { desde: 3, hasta: 2, nombre: '4. Regla guardada', respuesta: true },
        { desde: 2, hasta: 1, nombre: '5. Operacion exitosa', respuesta: true },
        { desde: 1, hasta: 0, nombre: '6. Mostrar permisos actualizados', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-05: CRUD de Documentos
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-05: Registro de Documentos',
    [
        'Vista:\nFormulario Documento',
        'Controlador:\nDocumentosVM',
        'API C#:\nGestion Docs',
        'Almacen:\nArchivos PDF',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Guardar documento y PDF' },
        { desde: 1, hasta: 1, nombre: '   Validar campos requeridos' },
        { desde: 1, hasta: 2, nombre: '2. Enviar datos y archivo' },
        { desde: 2, hasta: 3, nombre: '3. Guardar PDF en disco' },
        { desde: 2, hasta: 4, nombre: '4. Registrar metadatos' },
        { desde: 4, hasta: 2, nombre: '5. Documento guardado con ID', respuesta: true },
        { desde: 2, hasta: 1, nombre: '6. Registro exitoso', respuesta: true },
        { desde: 1, hasta: 0, nombre: '7. Mostrar: Documento guardado!', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-06: Generación QR
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-06: Generacion de Codigo QR',
    [
        'Vista:\nFicha Documento',
        'Controlador:\nDetalleVM',
        'API C#:\nGenerador QR',
        'Libreria:\nCreador Imagen',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Abrir ficha del documento' },
        { desde: 1, hasta: 2, nombre: '2. Pedir generacion del QR' },
        { desde: 2, hasta: 4, nombre: '3. Consultar identificador UUID' },
        { desde: 4, hasta: 2, nombre: '4. UUID encontrado', respuesta: true },
        { desde: 2, hasta: 3, nombre: '5. Convertir URL+UUID en imagen' },
        { desde: 3, hasta: 2, nombre: '6. Imagen QR generada', respuesta: true },
        { desde: 2, hasta: 1, nombre: '7. Enviar imagen del QR', respuesta: true },
        { desde: 1, hasta: 0, nombre: '8. Mostrar QR en pantalla', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-07: Clasificar Documentos
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-07: Clasificar en Carpetas',
    [
        'Vista:\nPantalla Carpetas',
        'Controlador:\nCarpetasVM',
        'API C#:\nOrganizador',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Crear nueva carpeta' },
        { desde: 1, hasta: 2, nombre: '2. Solicitar creacion de carpeta' },
        { desde: 2, hasta: 3, nombre: '3. Guardar carpeta y gestion' },
        { desde: 3, hasta: 2, nombre: '4. Carpeta creada con ID', respuesta: true },
        { desde: 2, hasta: 1, nombre: '5. Datos de la carpeta', respuesta: true },
        { desde: 1, hasta: 1, nombre: '   Organizar arbol jerarquico' },
        { desde: 1, hasta: 0, nombre: '6. Mostrar arbol actualizado', respuesta: true }
    ],
    50, 50
);

// ================================
// HU-08: Búsqueda Avanzada
// ================================
crearDiagramaSecuencia(
    modeloRaiz,
    'HU-08: Busqueda Avanzada',
    [
        'Vista:\nBuscador',
        'Controlador:\nDocumentosVM',
        'API C#:\nSistema Busqueda',
        'Base de Datos:\nPostgreSQL'
    ],
    [
        { desde: 0, hasta: 1, nombre: '1. Escribir filtros de busqueda' },
        { desde: 1, hasta: 2, nombre: '2. Solicitar busqueda filtrada' },
        { desde: 2, hasta: 3, nombre: '3. Buscar documentos que coincidan' },
        { desde: 3, hasta: 2, nombre: '4. Lista de resultados', respuesta: true },
        { desde: 2, hasta: 1, nombre: '5. Resultados de busqueda', respuesta: true },
        { desde: 1, hasta: 1, nombre: '   Ordenar por relevancia' },
        { desde: 1, hasta: 0, nombre: '6. Mostrar lista de resultados', respuesta: true }
    ],
    50, 50
);

// ---- FIN ----
app.dialogs.showInfoDialog('¡Listo! Se generaron los 8 diagramas MVVM.\nBusca la carpeta "MVVM - Sprints 1 y 2 (SSUT)" en el Model Explorer.');
