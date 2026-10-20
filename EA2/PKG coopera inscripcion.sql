CREATE OR REPLACE PACKAGE pkg_coopera_inscripcion AS 

    -- 1. Recibe los datos crudos desde la UI (APEX) e inserta en la GTT
    PROCEDURE prc_recopilar_datos(
        p_run_dv          IN VARCHAR2,
        p_pnombre         IN VARCHAR2,
        p_snombre         IN VARCHAR2,
        p_appaterno       IN VARCHAR2,
        p_apmaterno       IN VARCHAR2,
        p_fecha_nac       IN VARCHAR2, -- Asumo formato 'YYYY-MM-DD' o 'YYYYMMDD' según tu BD
        p_direccion       IN VARCHAR2,
            -- Vienen de LOV
        p_cod_comuna      IN NUMBER,
        p_cod_region      IN NUMBER,
        p_cod_tipo_socio  IN NUMBER,
        p_cod_prof_ofic   IN NUMBER,
        p_cod_prod_solic  IN NUMBER,
        p_ahorro_min_men  IN NUMBER,
        p_dia_pago_men    IN NUMBER
    );
    
    -- 2. Lee la GTT, valida las reglas e inscribe en las tablas definitivas
    PROCEDURE prc_procesar_clientes;

END pkg_coopera_inscripcion;

CREATE OR REPLACE PACKAGE BODY pkg_coopera_inscripcion AS

    -------------------------------------------------------------------
    -- PROCEDIMIENTOS Y FUNCIONES PRIVADAS
    -------------------------------------------------------------------
    
    /*
        An autonomous transaction is an independent transaction started 
        by another transaction that is usually referred to as the main transaction.
        In other words, an autonomous transaction may issue various DML
        statements and commit or roll them back, without committing or rolling
        back the DML statements issued by the main transaction.
            - Oracle PL/SQL by Example, Sixth Edition
                Benjamin Rosenzweig and Elena Rakhimov
                isbn: 9780138062897
    */
    PROCEDURE prc_log_error(p_descrip IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO error_proceso (correl_error, descrip_error)
        VALUES (SEQ_ERROR.NEXTVAL, SUBSTR(p_descrip, 1, 255));
        COMMIT;
    END prc_log_error;

    FUNCTION fn_limpiar_texto(p_texto VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_texto IS NULL THEN RETURN NULL; END IF;
        RETURN UPPER(TRIM(TRANSLATE(p_texto, 'a1234567890 ', 'a')));
    END fn_limpiar_texto;

    -------------------------------------------------------------------
    -- PROCEDIMIENTOS PÚBLICOS
    -------------------------------------------------------------------

    -- PROCEDIMIENTO 1: Alimentar la GTT
    PROCEDURE prc_recopilar_datos(
        p_run_dv          IN VARCHAR2,
        p_pnombre         IN VARCHAR2,
        p_snombre         IN VARCHAR2,
        p_appaterno       IN VARCHAR2,
        p_apmaterno       IN VARCHAR2,
        p_fecha_nac       IN VARCHAR2,
        p_direccion       IN VARCHAR2,
        p_cod_comuna      IN NUMBER,
        p_cod_region      IN NUMBER,
        p_cod_tipo_socio  IN NUMBER,
        p_cod_prof_ofic   IN NUMBER,
        p_cod_prod_solic  IN NUMBER,
        p_ahorro_min_men  IN NUMBER,
        p_dia_pago_men    IN NUMBER
    ) AS
    BEGIN
        INSERT INTO gtt_clientes (
            run_dv, pnombre, snombre, appaterno, apmaterno, fecha_nac,
            direccion, cod_comuna, cod_region, cod_tipo_socio, cod_prof_ofic,
            cod_prod_solic, ahorro_min_men, dia_pago_men
        ) VALUES (
            p_run_dv, p_pnombre, p_snombre, p_appaterno, p_apmaterno, p_fecha_nac,
            p_direccion, p_cod_comuna, p_cod_region, p_cod_tipo_socio, p_cod_prof_ofic,
            p_cod_prod_solic, p_ahorro_min_men, p_dia_pago_men
        );
    END prc_recopilar_datos;

    -- PROCEDIMIENTO 2: Procesamiento masivo desde la GTT
    PROCEDURE prc_procesar_clientes AS
        CURSOR cur_clientes IS SELECT * FROM gtt_clientes;
        
        v_numrun NUMBER(10);
        v_dvrun VARCHAR2(1);
        v_pnombre VARCHAR2(50);
        v_snombre VARCHAR2(50);
        v_appaterno VARCHAR2(50);
        v_apmaterno VARCHAR2(50);
        v_edad NUMBER;
        v_nro_socio NUMBER;
        v_pivote NUMBER;
    BEGIN
        FOR rec IN cur_clientes LOOP
            BEGIN
                -- 1. Descomposición y validación del RUN
                v_pivote := INSTR(rec.run_dv, '-');
                IF v_pivote = 0 THEN
                    RAISE_APPLICATION_ERROR(-20001, 'RUN sin guion.');
                END IF;
                
                v_numrun := TO_NUMBER(REPLACE(SUBSTR(rec.run_dv, 1, v_pivote-1), '.', ''));
                v_dvrun  := UPPER(SUBSTR(rec.run_dv, v_pivote+1));
                
                // FALTA VALIDAR QUE DIGITO VERIFICADOR SEA 0-9 O K
                
                IF LENGTH(v_numrun) NOT BETWEEN 7 AND 8 THEN
                    RAISE_APPLICATION_ERROR(-20002, 'Largo numérico de RUN inválido.');
                END IF;

                -- 2. Limpieza de strings
                v_pnombre   := fn_limpiar_texto(rec.pnombre);
                v_appaterno := fn_limpiar_texto(rec.appaterno);
                v_snombre   := fn_limpiar_texto(rec.snombre);
                v_apmaterno := fn_limpiar_texto(rec.apmaterno);
                
                IF v_pnombre IS NULL OR v_appaterno IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20003, 'Nombre o apellido vacío o con formato numérico.');
                END IF;

                -- 3. Validación de edad
                -- Nota: Asegúrate del formato de fecha. Aquí asumo YYYYMMDD limpio o YYYY-MM-DD
                v_nac_date := TO_DATE(REPLACE(rec.fecha_nac, '-', ''), 'YYYYMMDD');
                v_edad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_nac_date) / 12);
                
                IF v_edad < 18 THEN
                    RAISE_APPLICATION_ERROR(-20004, 'Cliente menor de edad.');
                END IF;

                -- 4. Inserción a maestro SOCIO
                -- Ya no necesitamos buscar en la tabla COMUNA/REGION porque tenemos los IDs
                INSERT INTO socio (
                    numrun, dvrun, pnombre, snombre, appaterno, apmaterno, 
                    fecha_nacimiento, fecha_inscripcion, direccion, 
                    cod_region, cod_comuna, cod_prof_ofic, cod_tipo_socio
                ) VALUES (
                    v_numrun, v_dvrun, v_pnombre, fn_limpiar_texto(rec.snombre), 
                    v_appaterno, fn_limpiar_texto(rec.apmaterno),
                    v_nac_date, SYSDATE, rec.direccion,
                    rec.cod_region, rec.cod_comuna, rec.cod_prof_ofic, rec.cod_tipo_socio
                ) RETURNING nro_socio INTO v_nro_socio;

                -- 5. Inserción a PRODUCTO_INVERSION_SOCIO
                INSERT INTO producto_inversion_socio (
                    nro_socio, ahorro_minimo_mensual, dia_pago_mensual, cod_prod_inv
                ) VALUES (
                    v_nro_socio, rec.ahorro_min_men, rec.dia_pago_men, rec.cod_prod_solic
                );

            EXCEPTION
                -- Si falla un registro, se graba en el log y el ciclo FOR sigue con el siguiente
                WHEN OTHERS THEN
                    prc_log_error('Error RUN ' || rec.run_dv || ': ' || SQLERRM);
            END;
        END LOOP;
        
        COMMIT;
    END prc_procesar_clientes;

END pkg_coopera_inscripcion;