CREATE OR REPLACE TRIGGER trg_bi_producto_inv_socio
BEFORE INSERT ON producto_inversion_socio
FOR EACH ROW
DECLARE
    v_max_id NUMBER;
BEGIN
    -- 1. Validación de Ahorro Mínimo (Estipulado en $10.000)
    IF :NEW.ahorro_minimo_mensual < 10000 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ahorro minimo mensual debe ser igual o mayor a $10,000.');
    END IF;

    -- 2. Validación de Día de Pago (Entre 1 y 30)
    IF :NEW.dia_pago_mensual NOT BETWEEN 1 AND 30 THEN
        RAISE_APPLICATION_ERROR(-20002, 'DIA INVALIDO. DEBE SEGUIR FORMATO 1 - 30.');
    END IF;

    -- 3. Generación del NRO_SOLIC_PROD
    IF :NEW.nro_solic_prod IS NULL THEN
        SELECT NVL(MAX(nro_solic_prod), :NEW.cod_prod_inv * 10000) 
        INTO v_max_id
        FROM producto_inversion_socio
        WHERE cod_prod_inv = :NEW.cod_prod_inv;
        
        :NEW.nro_solic_prod := v_max_id + 1;
    END IF;

    -- 4. Inicialización de valores por defecto
    :NEW.monto_total_ahorrado := 0;
    IF :NEW.fecha_solic_prod IS NULL THEN
        :NEW.fecha_solic_prod := SYSDATE;
    END IF;
END;