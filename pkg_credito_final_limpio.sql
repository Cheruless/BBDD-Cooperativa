CREATE OR REPLACE PACKAGE pkg_credito IS
    PROCEDURE sp_registra_credito(p_nro_socio NUMBER, p_cod_credito NUMBER,
                                  p_monto NUMBER, p_cuotas NUMBER, p_dia_pago NUMBER);
    PROCEDURE sp_registra_pago(p_nro_solic NUMBER, p_nro_cuota NUMBER, p_monto NUMBER);

    FUNCTION fn_calcula_cuota(p_monto NUMBER, p_cuotas NUMBER) RETURN NUMBER;
    FUNCTION fn_calcula_mora(p_saldo NUMBER, p_dias_atraso NUMBER) RETURN NUMBER;
    FUNCTION fn_tasa_vigente(p_cod_credito NUMBER) RETURN NUMBER;
END pkg_credito;
/

CREATE OR REPLACE PACKAGE BODY pkg_credito IS

    FUNCTION fn_creditos_con_saldo(p_nro_socio NUMBER) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT COUNT(DISTINCT c.nro_solic_credito)
        INTO v_total
        FROM credito_socio c
        JOIN cuota_credito_socio q ON q.nro_solic_credito = c.nro_solic_credito
        WHERE c.nro_socio = p_nro_socio
          AND q.saldo_por_pagar > 0;
        RETURN v_total;
    END fn_creditos_con_saldo;

    PROCEDURE sp_registra_error(p_sentencia VARCHAR2, p_descrip VARCHAR2) IS
    BEGIN
        INSERT INTO error_proceso (correl_error, sentencia_error, descrip_error)
        VALUES (SEQ_ERROR.NEXTVAL,
                SUBSTR(p_sentencia, 1, 120),
                SUBSTR(p_descrip, 1, 255));
    END sp_registra_error;

    FUNCTION fn_calcula_cuota(p_monto NUMBER, p_cuotas NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN ROUND(p_monto / p_cuotas);
    END fn_calcula_cuota;

    FUNCTION fn_calcula_mora(p_saldo NUMBER, p_dias_atraso NUMBER) RETURN NUMBER IS
    BEGIN
        IF p_dias_atraso > 0 THEN
            RETURN ROUND(p_saldo * 0.03);
        END IF;
        RETURN 0;
    END fn_calcula_mora;

    FUNCTION fn_tasa_vigente(p_cod_credito NUMBER) RETURN NUMBER IS
        v_tasa NUMBER(4,2);
    BEGIN
        SELECT tasa_interes_anual INTO v_tasa
        FROM credito
        WHERE cod_credito = p_cod_credito;
        RETURN v_tasa;
    END fn_tasa_vigente;

    PROCEDURE sp_registra_credito(p_nro_socio NUMBER, p_cod_credito NUMBER,
                                  p_monto NUMBER, p_cuotas NUMBER, p_dia_pago NUMBER) IS
        v_nro_solic   NUMBER(10);
        v_valor_cuota NUMBER(10);
        v_dia         NUMBER(2);
        v_fecha       DATE;
    BEGIN
        SAVEPOINT sp_antes_credito;

        IF fn_creditos_con_saldo(p_nro_socio) >= 2 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El socio ya tiene 2 créditos simultáneos');
        END IF;

        v_nro_solic   := SEQ_CREDITO.NEXTVAL;
        v_valor_cuota := fn_calcula_cuota(p_monto, p_cuotas);

        INSERT INTO credito_socio
            (nro_solic_credito, nro_socio, fecha_solic_cred, fecha_otorga_cred,
             monto_solicitado, monto_total_credito, total_cuotas_credito, cod_credito)
        VALUES
            (v_nro_solic, p_nro_socio, SYSDATE, SYSDATE,
             p_monto, p_monto, p_cuotas, p_cod_credito);

        FOR i IN 1..p_cuotas LOOP
            v_dia := p_dia_pago;

            IF TO_CHAR(ADD_MONTHS(SYSDATE, i), 'MM') = '02' AND v_dia > 28 THEN
                v_dia := 28;
            END IF;

            v_fecha := TO_DATE(TO_CHAR(ADD_MONTHS(SYSDATE, i), 'YYYYMM')
                               || LPAD(v_dia, 2, '0'), 'YYYYMMDD');

            INSERT INTO cuota_credito_socio
                (nro_solic_credito, nro_cuota, fecha_venc_cuota,
                 valor_cuota, monto_pagado, saldo_por_pagar, nro_pagos_parciales)
            VALUES
                (v_nro_solic, i, v_fecha,
                 v_valor_cuota, 0, v_valor_cuota, 0);
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_antes_credito;
            sp_registra_error('sp_registra_credito', SQLERRM);
            RAISE;
    END sp_registra_credito;

    PROCEDURE sp_registra_pago(p_nro_solic NUMBER, p_nro_cuota NUMBER, p_monto NUMBER) IS
        v_valor_cuota  NUMBER(10);
        v_fecha_venc   DATE;
        v_pagado_antes NUMBER(10);
        v_parc_antes   NUMBER(2);
        v_total_pag    NUMBER(10);
        v_pendiente    NUMBER(10);
        v_saldo        NUMBER(10);
        v_parc         NUMBER(2);
        v_dias_atraso  NUMBER(5);
        v_mora         NUMBER(10);
        v_pasa         NUMBER(10);
    BEGIN
        SAVEPOINT sp_antes_pago;

        SELECT valor_cuota, fecha_venc_cuota,
               NVL(monto_pagado, 0), NVL(nro_pagos_parciales, 0)
        INTO v_valor_cuota, v_fecha_venc, v_pagado_antes, v_parc_antes
        FROM cuota_credito_socio
        WHERE nro_solic_credito = p_nro_solic
          AND nro_cuota = p_nro_cuota;

        v_pendiente := v_valor_cuota - v_pagado_antes;
        v_total_pag := v_pagado_antes + p_monto;

        IF v_total_pag > v_valor_cuota THEN
            v_saldo := 0;
        ELSE
            v_saldo := v_valor_cuota - v_total_pag;
        END IF;

        IF SYSDATE > v_fecha_venc AND v_pendiente > 0 THEN
            v_dias_atraso := TRUNC(SYSDATE - v_fecha_venc);
            v_mora        := fn_calcula_mora(v_saldo, v_dias_atraso);
            v_saldo       := v_saldo + v_mora;
        END IF;

        IF v_saldo > 0 THEN
            v_parc := v_parc_antes + 1;
        ELSE
            v_parc := v_parc_antes;
        END IF;

        IF v_parc_antes >= 5 AND v_saldo > 0 THEN
            v_pasa := ROUND(v_saldo * 1.03);

            UPDATE cuota_credito_socio
            SET valor_cuota     = valor_cuota + v_pasa,
                saldo_por_pagar = NVL(saldo_por_pagar, 0) + v_pasa
            WHERE nro_solic_credito = p_nro_solic
              AND nro_cuota = p_nro_cuota + 1;

            IF SQL%ROWCOUNT > 0 THEN
                v_saldo := 0;
            END IF;
        END IF;

        UPDATE cuota_credito_socio
        SET monto_pagado        = v_total_pag,
            saldo_por_pagar     = v_saldo,
            nro_pagos_parciales = v_parc,
            fecha_pago_cuota    = SYSDATE
        WHERE nro_solic_credito = p_nro_solic
          AND nro_cuota = p_nro_cuota;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK TO sp_antes_pago;
            sp_registra_error('sp_registra_pago', 'No existe la cuota indicada');
            RAISE_APPLICATION_ERROR(-20001, 'No existe la cuota indicada para esa solicitud');
        WHEN OTHERS THEN
            ROLLBACK TO sp_antes_pago;
            sp_registra_error('sp_registra_pago', SQLERRM);
            RAISE;
    END sp_registra_pago;

END pkg_credito;
/
