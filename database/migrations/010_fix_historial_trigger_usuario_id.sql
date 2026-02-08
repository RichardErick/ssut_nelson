-- Corrige el trigger que insertaba usuario_id = fecha_actualizacion::integer (inválido),
-- lo que provocaba violación de FK al actualizar documentos (ej. al eliminar un usuario).
-- Ahora usa usuario_id = NULL en el historial cuando no hay usuario en contexto.
CREATE OR REPLACE FUNCTION registrar_historial_documento()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO historial_documento (
            documento_id, usuario_id, tipo_cambio,
            estado_anterior, estado_nuevo,
            area_anterior_id, area_nueva_id,
            observacion
        ) VALUES (
            NEW.id, NULL, 'ACTUALIZACION',
            OLD.estado, NEW.estado,
            OLD.area_actual_id, NEW.area_actual_id,
            'Actualización automática de documento'
        );
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO historial_documento (
            documento_id, usuario_id, tipo_cambio, estado_nuevo, area_nueva_id
        ) VALUES (
            NEW.id, NULL, 'CREACION', NEW.estado, NEW.area_actual_id
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
