/**
 * SCRIPT GENERADOR DE DIAGRAMA DE BASE DE DATOS - SSUT
 * ==========================================
 * INSTRUCCIONES:
 * 1. Abre StarUML
 * 2. Ve al menu: Tools > Scripts > Run Script...
 * 3. Selecciona este archivo: generar_db_ssut.js
 * 4. El diagrama de clases (representando las tablas) se creará automáticamente.
 * ==========================================
 */

var proyecto = app.project.getProject();

var modeloRaiz = app.factory.createModel({
    id: 'UMLModel',
    parent: proyecto,
    field: 'ownedElements'
});
modeloRaiz.name = 'Esquema Base de Datos (SSUT)';

var diagrama = app.factory.createModel({
    id: 'UMLClassDiagram',
    parent: modeloRaiz,
    field: 'ownedElements'
});
diagrama.name = 'Diagrama de Tablas';

function crearTabla(nombre, columnas, x, y) {
    var clase = app.factory.createModel({
        id: 'UMLClass',
        parent: modeloRaiz,
        field: 'ownedElements'
    });
    clase.name = nombre;
    clase.stereotype = "table";

    columnas.forEach(function (col) {
        var attr = app.factory.createModel({
            id: 'UMLAttribute',
            parent: clase,
            field: 'attributes'
        });
        attr.name = col.nombre;
        attr.type = col.tipo;
        if (col.pk) {
            attr.stereotype = "PK";
            attr.isID = true;
        } else if (col.fk) {
            attr.stereotype = "FK";
        }
    });

    var view = app.factory.createView({
        id: 'UMLClassView',
        parent: diagrama,
        model: clase
    });
    view.left = x;
    view.top = y;
    view.width = 200;

    return { model: clase, view: view };
}

function crearRelacion(origen, destino, nombre) {
    var assoc = app.factory.createModel({
        id: 'UMLAssociation',
        parent: origen.model,
        field: 'ownedElements'
    });
    assoc.name = nombre;
    assoc.end1.reference = origen.model;
    assoc.end2.reference = destino.model;
    assoc.end2.navigable = true;

    var assocView = app.factory.createView({
        id: 'UMLAssociationView',
        parent: diagrama,
        model: assoc
    });
    assocView.tail = origen.view;
    assocView.head = destino.view;
}

// ==========================
// CREACIÓN DE LAS TABLAS
// ==========================

var tAreas = crearTabla("areas", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "uuid", tipo: "UUID" },
    { nombre: "nombre", tipo: "VARCHAR" },
    { nombre: "codigo", tipo: "VARCHAR" },
    { nombre: "activo", tipo: "BOOLEAN" }
], 50, 50);

var tTiposDocumento = crearTabla("tipos_documento", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "nombre", tipo: "VARCHAR" },
    { nombre: "codigo", tipo: "VARCHAR" },
    { nombre: "requiere_aprobacion", tipo: "BOOLEAN" }
], 350, 50);

var tUsuarios = crearTabla("usuarios", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "nombre_usuario", tipo: "VARCHAR" },
    { nombre: "email", tipo: "VARCHAR" },
    { nombre: "password_hash", tipo: "VARCHAR" },
    { nombre: "rol", tipo: "VARCHAR" },
    { nombre: "area_id", tipo: "INTEGER", fk: true },
    { nombre: "activo", tipo: "BOOLEAN" }
], 50, 250);

var tCarpetas = crearTabla("carpetas", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "nombre", tipo: "VARCHAR" },
    { nombre: "codigo", tipo: "VARCHAR" },
    { nombre: "gestion", tipo: "VARCHAR" },
    { nombre: "carpeta_padre_id", tipo: "INTEGER", fk: true }
], 650, 50);

var tDocumentos = crearTabla("documentos", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "codigo", tipo: "VARCHAR" },
    { nombre: "numero_correlativo", tipo: "VARCHAR" },
    { nombre: "tipo_documento_id", tipo: "INTEGER", fk: true },
    { nombre: "area_origen_id", tipo: "INTEGER", fk: true },
    { nombre: "area_actual_id", tipo: "INTEGER", fk: true },
    { nombre: "carpeta_id", tipo: "INTEGER", fk: true },
    { nombre: "fecha_documento", tipo: "DATE" },
    { nombre: "responsable_id", tipo: "INTEGER", fk: true },
    { nombre: "estado", tipo: "VARCHAR" }
], 350, 300);

var tMovimientos = crearTabla("movimientos", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "documento_id", tipo: "INTEGER", fk: true },
    { nombre: "tipo_movimiento", tipo: "VARCHAR" },
    { nombre: "area_origen_id", tipo: "INTEGER", fk: true },
    { nombre: "area_destino_id", tipo: "INTEGER", fk: true },
    { nombre: "usuario_id", tipo: "INTEGER", fk: true },
    { nombre: "estado", tipo: "VARCHAR" },
    { nombre: "fecha_movimiento", tipo: "TIMESTAMP" }
], 650, 300);

var tAnexos = crearTabla("anexos", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "documento_id", tipo: "INTEGER", fk: true },
    { nombre: "nombre_archivo", tipo: "VARCHAR" },
    { nombre: "url_archivo", tipo: "VARCHAR" },
    { nombre: "activo", tipo: "BOOLEAN" }
], 350, 600);

var tPalabrasClave = crearTabla("palabras_clave", [
    { nombre: "id", tipo: "SERIAL", pk: true },
    { nombre: "palabra", tipo: "VARCHAR" }
], 50, 500);

var tDocPalabras = crearTabla("documento_palabras_clave", [
    { nombre: "documento_id", tipo: "INTEGER", pk: true, fk: true },
    { nombre: "palabra_clave_id", tipo: "INTEGER", pk: true, fk: true }
], 50, 650);

// ==========================
// CREACIÓN DE REFERENCIAS (ASOCIACIONES)
// ==========================
crearRelacion(tUsuarios, tAreas, "pertenece_a");
crearRelacion(tDocumentos, tTiposDocumento, "es_tipo");
crearRelacion(tDocumentos, tAreas, "area_origen/actual");
crearRelacion(tDocumentos, tUsuarios, "responsable");
crearRelacion(tDocumentos, tCarpetas, "en_carpeta");
crearRelacion(tMovimientos, tDocumentos, "sobre_documento");
crearRelacion(tMovimientos, tAreas, "de_para_area");
crearRelacion(tMovimientos, tUsuarios, "realizado_por");
crearRelacion(tAnexos, tDocumentos, "anexo_de");
crearRelacion(tDocPalabras, tDocumentos, "ref_doc");
crearRelacion(tDocPalabras, tPalabrasClave, "ref_palabra");

app.dialogs.showInfoDialog('¡Listo! Se ha generado el diagrama de las tablas de SSUT en StarUML.\nRevisa el Model Explorer para ver las clases.');
