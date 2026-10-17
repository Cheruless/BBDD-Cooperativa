/*
DROP SEQUENCE SEQ_CREDITO;
CREATE SEQUENCE SEQ_CREDITO START WITH 3011 INCREMENT BY 1;
se utiliza ya que el número iba a chocar con el 3010, porque copmenzaba desde el 1 y estaban ocupados hasta el 3010

ALTER TABLE cuota_credito_socio ADD nro_pagos_parciales NUMBER(2) DEFAULT 0;
*/

CREATE OR REPLACE PACKAGE pkg_credito IS
    PROCEDURE sp_registra_credito(p_nro_socio NUMBER, p_cod_credito NUMBER,
                                  p_monto NUMBER, p_cuotas NUMBER, p_dia_pago NUMBER);
    PROCEDURE sp_registra_pago(p_nro_solic NUMBER, p_nro_cuota NUMBER, p_monto NUMBER);
    PROCEDURE sp_registra_error(p_sentencia VARCHAR2, p_descrip VARCHAR2);

    FUNCTION fn_creditos_con_saldo(p_nro_socio NUMBER) RETURN NUMBER;
    FUNCTION fn_calcula_cuota(p_monto NUMBER, p_cuotas NUMBER) RETURN NUMBER;
    FUNCTION fn_calcula_mora(p_saldo NUMBER, p_dias_atraso NUMBER) RETURN NUMBER;
    FUNCTION fn_tasa_vigente(p_cod_credito NUMBER) RETURN NUMBER;
END pkg_credito;

CREATE OR REPLACE PACKAGE BODY pkg_credito IS

--se crea una función de créditos existentes con el saldo por pagar mayor que 0, 
--ya que fue la forma en que decidimos que iban a estar los 2 créditos simultáneos
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

--procedure para guardar errores, con su numero identificador, su nombre y descripcion
    PROCEDURE sp_registra_error(p_sentencia VARCHAR2, p_descrip VARCHAR2) IS
    BEGIN
        INSERT INTO error_proceso (correl_error, sentencia_error, descrip_error)
        VALUES (SEQ_ERROR.NEXTVAL,
                SUBSTR(p_sentencia, 1, 120),
                SUBSTR(p_descrip, 1, 255));
    END sp_registra_error;

--función que calcula la cantidad de cuotas por el monto total
    FUNCTION fn_calcula_cuota(p_monto NUMBER, p_cuotas NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN ROUND(p_monto / p_cuotas);
    END fn_calcula_cuota;

--funcion que calcula el MORA QUE ESCOGIMOS como coherente respecto al caso, no se utiliza la tabla MULTA_MORA por decisión UNÁNIME
    FUNCTION fn_calcula_mora(p_saldo NUMBER, p_dias_atraso NUMBER) RETURN NUMBER IS
    BEGIN
        IF p_dias_atraso > 0 THEN
            RETURN ROUND(p_saldo * 0.03);
        END IF;
        RETURN 0;
    END fn_calcula_mora;

--función para la tasa anual que pide la cooperativa, esta no se ha usado en ningún procedimiento (de momento, 16/10/2026)
    FUNCTION fn_tasa_vigente(p_cod_credito NUMBER) RETURN NUMBER IS
        v_tasa NUMBER(4,2);
    BEGIN
        SELECT tasa_interes_anual INTO v_tasa
        FROM credito
        WHERE cod_credito = p_cod_credito;
        RETURN v_tasa;
    END fn_tasa_vigente;

--Procedimiento para el registro de una solicitud de crédito, con la función pre operación, para la validación de los 2 créditos simultáneos
    PROCEDURE sp_registra_credito(p_nro_socio NUMBER, p_cod_credito NUMBER,
                                  p_monto NUMBER, p_cuotas NUMBER, p_dia_pago NUMBER) IS
        v_nro_solic   NUMBER(10);
        v_valor_cuota NUMBER(10);
        v_dia         NUMBER(2);
        v_fecha       DATE;
    BEGIN
    --se hace un savepoint, ya que: si falla algo x, por ejemplo la cuota 2 da error, no deje pasar el crédito sin cuotas completas
        SAVEPOINT sp_antes_credito;

        IF fn_creditos_con_saldo(p_nro_socio) >= 2 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El socio ya tiene 2 créditos simultáneos');
        END IF;

--se agrega el identificador del crédito, y se calcula la cantidad de cuotas para el cancelar el monto total
        v_nro_solic   := SEQ_CREDITO.NEXTVAL;
        v_valor_cuota := fn_calcula_cuota(p_monto, p_cuotas);

        INSERT INTO credito_socio
            (nro_solic_credito, nro_socio, fecha_solic_cred, fecha_otorga_cred,
             monto_solicitado, monto_total_credito, total_cuotas_credito, cod_credito)
        VALUES
            (v_nro_solic, p_nro_socio, SYSDATE, SYSDATE,
             p_monto, p_monto, p_cuotas, p_cod_credito);

--Ciclo for para recorrer la cantidad de cuotas por crédito, si son 3 cuotas, se da las 3 vueltas
        FOR i IN 1..p_cuotas LOOP
            v_dia := p_dia_pago;

--Validación del día 28 de febrero, en caso de que el socio quiera pagar al final del mes, y este sea el día 30,
--ya que febrero no contempla ese día, se considera como el día final de febrero, o sea, el 28
            IF TO_CHAR(ADD_MONTHS(SYSDATE, i), 'MM') = '02' AND v_dia > 28 THEN
                v_dia := 28;
            END IF;

--ADD_MONTHS(SYSDATE, i) toma la fecha de hoy y le suma i meses. Si hoy es 16/10/2026 y i es 1, da 16/11/2026,
--LPAD(v_dia, 2, '0') toma el día y lo deja con dos dígitos. Si v_dia es 15, queda '15'. Si fuera 5, quedaría '05', que es lo que necesita el formato
            v_fecha := TO_DATE(TO_CHAR(ADD_MONTHS(SYSDATE, i), 'YYYYMM')
                               || LPAD(v_dia, 2, '0'), 'YYYYMMDD');

--Se insertan los datos en la cuota del crédito con la cantidad de estas y los parámetros en 0
            INSERT INTO cuota_credito_socio
                (nro_solic_credito, nro_cuota, fecha_venc_cuota,
                 valor_cuota, monto_pagado, saldo_por_pagar, nro_pagos_parciales)
            VALUES
                (v_nro_solic, i, v_fecha,
                 v_valor_cuota, 0, v_valor_cuota, 0);
        END LOOP;

--Una excepción por cualquier caso que ocurra, que no tenga un manejo específico y el raise lo repite
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_antes_credito;
            sp_registra_error('sp_registra_credito', SQLERRM);
            RAISE;
    END sp_registra_credito;

--Procedimiento para registrar el pago de las cuotas 
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
    --Nuevamente un savepoint en caso de que el segundo UPDATE (cuota actual con su pago, saldo y conteo), 
    --se queda solo el primero (en el caso de que se hayan hecho los 5 pagos parciales, suma el saldo y el 3% de interés moratorio), 
    --pero no se registra, se deshace el primer update, porque o van juntos o no va ninguno, la plata se devuelve a la primera 
    --para que no quede cobrado a medias
        SAVEPOINT sp_antes_pago;

        SELECT valor_cuota, fecha_venc_cuota,
               NVL(monto_pagado, 0), NVL(nro_pagos_parciales, 0)
        INTO v_valor_cuota, v_fecha_venc, v_pagado_antes, v_parc_antes
        FROM cuota_credito_socio
        WHERE nro_solic_credito = p_nro_solic
          AND nro_cuota = p_nro_cuota;

--valor pendiente: es lo que se debía antes del pago, es el valor de la cuota menos el que ya pagó antes
--y el total pagado: es lo pagado después del pago, es el valor que ya había pagado antes y el monto a pagar
        v_pendiente := v_valor_cuota - v_pagado_antes; --si debía 100k y pagó (-) 30k, le queda pendiente 70k
        v_total_pag := v_pagado_antes + p_monto; --llevaba pagado 30k, paga otra de 20k y lleva 50k pagado

--si lo que ya pagó, supera el valor de la cuota, entonces el saldo es 0, por ejemplo,
--de la cuota de 100k, paga 120k, queda en 0 ese saldo, porque no puede quedar en negativo
        IF v_total_pag > v_valor_cuota THEN
            v_saldo := 0;
        ELSE
        --en cambio, si no supera el valor, falta el saldo, 
        --o sea la cuota menos lo que pagó 100k - 50k le queda 50k por pagar
            v_saldo := v_valor_cuota - v_total_pag;
        END IF;

--si se atrasa a hoy con su fecha de vencimiento y su saldo pendiente
--caclula los días atrasados a la fecha
--calcula el saldo pendiente y el 3% moratorio
--y los suma, para el cobro
        IF SYSDATE > v_fecha_venc AND v_pendiente > 0 THEN
            v_dias_atraso := TRUNC(SYSDATE - v_fecha_venc);
            v_mora        := fn_calcula_mora(v_saldo, v_dias_atraso);
            v_saldo       := v_saldo + v_mora;
        END IF;

--si el saldo a pagar es mayor a 0, se cuenta como pago parcial + 1
        IF v_saldo > 0 THEN
            v_parc := v_parc_antes + 1;
        ELSE
        --si la cuota la pagó completa, no agrega un pago parcial
            v_parc := v_parc_antes;
        END IF;

--si el pago parcial quedó en mayor o igual a 5 pero sigue quedando por pagar, 
--se cobra este saldo más el 3% moratorio
        IF v_parc_antes >= 5 AND v_saldo > 0 THEN
            v_pasa := ROUND(v_saldo * 1.03);


          --actualiza la cuota con los datos nuevos que llegan  
            UPDATE cuota_credito_socio
            --sube el monto de la cuota siguiente que viene de la cuota anterior, el saldo más el 3%
            SET valor_cuota         = valor_cuota + v_pasa,
            --sube el saldo de la cuota siguiente en el mismo monto, con el saldo en 0 para que no esté vacío
                saldo_por_pagar     = NVL(saldo_por_pagar, 0) + v_pasa,
            --marca la cuota siguiente con 5 pagos parciales, para que también
            --se le aplique el 3% en sus propios pagos (de ahí en adelante)
                nro_pagos_parciales = 5
            --donde la cuota sea la siguiente y no la actual
            WHERE nro_solic_credito = p_nro_solic
              AND nro_cuota = p_nro_cuota + 1;

--si la cuota actual es la última del crédito o no encontró cuota siguiente, el rowcount es 0
--se cierra en la cuota actual y pasa a la siguiente
--por ejempplo, la cuota 3 de un crédito de 3 cuotas, busca la cuota 4,
--no la encuentra, ROWCOUNT es 0, y el saldo se queda en la cuota 3.
            IF SQL%ROWCOUNT > 0 THEN
                v_saldo := 0;
            END IF;
        END IF;

    --UPDATE guarda el pago en la cuota actual que el socio está pagando
        UPDATE cuota_credito_socio
        --lo que lleva pagado, incluyendo este pago
        SET monto_pagado        = v_total_pag,
        --lo que todavía le falta pagar de esta cuota
            saldo_por_pagar     = v_saldo,
            --cuantos pagos parcaiales hizo sin completar la cuota
            nro_pagos_parciales = v_parc,
            --el día que se hizo el pago
            fecha_pago_cuota    = SYSDATE
        WHERE nro_solic_credito = p_nro_solic
          AND nro_cuota = p_nro_cuota;


--En el WHEN NO_DATA_FOUND, el rollback no tiene nada que deshacer,
--porque el error ocurre en el SELECT, antes de cualquier cambio.
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
