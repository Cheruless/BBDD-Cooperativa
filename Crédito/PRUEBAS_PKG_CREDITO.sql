/*
   PRUEBAS pkg_credito
   Socio 1: límite de 2 créditos y pagos.
   Socio 2: regla del 3% (5 pagos parciales).
   Si se ejecuta más de una vez, el socio 1 ya tendrá 2 créditos con saldo
   y la creación de la sección 2 dará ORA-20002. Eso es esperado y el bloque
   lo captura para que el script siga.
*/

SET SERVEROUTPUT ON;


/* ---------- 1) FUNCIONES ---------- */

SELECT pkg_credito.fn_calcula_cuota(300000, 3) AS cuota FROM dual;
-- Esperado: 100000

SELECT pkg_credito.fn_calcula_mora(90000, 45) AS mora_atraso FROM dual;
-- Esperado: 2700

SELECT pkg_credito.fn_calcula_mora(90000, 0) AS mora_sin_atraso FROM dual;
-- Esperado: 0

SELECT pkg_credito.fn_tasa_vigente(1) AS tasa FROM dual;
-- Esperado: la tasa del producto 1 (ej. 0,5). Solo se consulta.


/* ---------- 2) CREAR CRÉDITOS DEL SOCIO 1 ---------- */

BEGIN
    pkg_credito.sp_registra_credito(1, 1, 300000, 3, 15);
    DBMS_OUTPUT.PUT_LINE('Crédito 1 creado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('No creado: ' || SQLERRM);
END;
/

BEGIN
    pkg_credito.sp_registra_credito(1, 1, 300000, 3, 15);
    DBMS_OUTPUT.PUT_LINE('Crédito 2 creado');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('No creado: ' || SQLERRM);
END;
/
-- Esperado en una base limpia para el socio 1: ambos créditos creados.
-- Si ya existían 2 créditos con saldo: "No creado: ORA-20002".

SELECT nro_solic_credito, monto_solicitado, total_cuotas_credito
FROM credito_socio
WHERE nro_socio = 1
ORDER BY nro_solic_credito DESC;

SELECT nro_cuota, valor_cuota, monto_pagado, saldo_por_pagar, fecha_venc_cuota
FROM cuota_credito_socio
WHERE nro_solic_credito = (SELECT MAX(nro_solic_credito)
                           FROM credito_socio WHERE nro_socio = 1)
ORDER BY nro_cuota;
-- Esperado: 3 cuotas de 100.000, saldo 100.000, sin pagos.


/* ---------- 3) LÍMITE DE 2 CRÉDITOS ---------- */

BEGIN
    pkg_credito.sp_registra_credito(1, 1, 300000, 3, 15);
    DBMS_OUTPUT.PUT_LINE('ERROR: el tercer crédito NO debió crearse');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('OK, error esperado: ' || SQLERRM);
END;
/
-- Esperado: ORA-20002 "El socio ya tiene 2 créditos simultáneos"

SELECT COUNT(*) AS creditos_socio_1
FROM credito_socio
WHERE nro_socio = 1;
-- Esperado: 2


/* ---------- 4) PAGO SIN ATRASO ---------- */

DECLARE
    v_solic NUMBER(10);
BEGIN
    SELECT MAX(nro_solic_credito) INTO v_solic
    FROM credito_socio WHERE nro_socio = 1;

    -- Pago de 50.000: se aplica a la primera cuota con saldo (la 1).
    pkg_credito.sp_registra_pago(v_solic, 50000);
    DBMS_OUTPUT.PUT_LINE('Pago 50.000 registrado al crédito ' || v_solic);
END;
/

SELECT nro_cuota, monto_pagado, saldo_por_pagar, nro_pagos_parciales, fecha_pago_cuota
FROM cuota_credito_socio
WHERE nro_solic_credito = (SELECT MAX(nro_solic_credito)
                           FROM credito_socio WHERE nro_socio = 1)
ORDER BY nro_cuota;
-- Esperado: cuota 1 con monto_pagado 50.000, saldo 50.000, 1 pago parcial, fecha de pago hoy.
--tiene 3 horas de diferencia realmente, ya que el servidor o no la toma, o es la hora de eeuu.
--por ejemplo, hice la prueba a las 23:40 el 19/10 Chile, Horario Invierno. 
--En el select para la hora salía que eran las 02:40 el 20/10


/* ---------- 5) PAGO FUERA DE PLAZO (MORA) ---------- */

-- Forzar que la cuota 1 venció el 01/09/2026 (solo para la prueba).
UPDATE cuota_credito_socio
SET fecha_venc_cuota = DATE '2026-09-01'
WHERE nro_solic_credito = (SELECT MAX(nro_solic_credito)
                           FROM credito_socio WHERE nro_socio = 1)
  AND nro_cuota = 1;

DECLARE
    v_solic NUMBER(10);
BEGIN
    SELECT MAX(nro_solic_credito) INTO v_solic
    FROM credito_socio WHERE nro_socio = 1;

    pkg_credito.sp_registra_pago(v_solic, 10000);
    DBMS_OUTPUT.PUT_LINE('Pago fuera de plazo registrado');
END;
/

SELECT nro_cuota, monto_pagado, saldo_por_pagar, nro_pagos_parciales
FROM cuota_credito_socio
WHERE nro_solic_credito = (SELECT MAX(nro_solic_credito)
                           FROM credito_socio WHERE nro_socio = 1)
ORDER BY nro_cuota;
-- Esperado: cuota 1 con monto_pagado 60.000.
--   Saldo: quedan 40.000; con atraso se suma 3% = 1.200, total 41.200.
--   Si el día de la prueba da otros días de atraso, la mora no cambia (es 3% fijo).
--   Pagos parciales: 2.


/* ---------- 6) REGLA DEL 3% (5 PAGOS PARCIALES) ---------- */

SELECT COUNT(*) AS creditos_socio_2
FROM credito_socio
WHERE nro_socio = 2;
-- Esperado: 0. Si no es 0, revisa antes de seguir.

BEGIN
    pkg_credito.sp_registra_credito(2, 1, 300000, 3, 15);
END;
/

-- Cinco pagos parciales de 10.000 (la cuota 1 aún no vence, no hay mora).
DECLARE
    v_solic NUMBER(10);
BEGIN
    SELECT MAX(nro_solic_credito) INTO v_solic
    FROM credito_socio WHERE nro_socio = 2;

    FOR i IN 1..5 LOOP
        pkg_credito.sp_registra_pago(v_solic, 10000);
    END LOOP;
END;
/

SELECT nro_cuota, valor_cuota, monto_pagado, saldo_por_pagar, nro_pagos_parciales
FROM cuota_credito_socio
WHERE nro_solic_credito = (SELECT MAX(nro_solic_credito)
                           FROM credito_socio WHERE nro_socio = 2)
ORDER BY nro_cuota;
-- Esperado: cuota 1 con monto_pagado 50.000, saldo 50.000, nro_pagos_parciales 5.

-- Sexto pago parcial: el saldo + 3% pasa a la cuota 2.
DECLARE
    v_solic NUMBER(10);
BEGIN
    SELECT MAX(nro_solic_credito) INTO v_solic
    FROM credito_socio WHERE nro_socio = 2;

    pkg_credito.sp_registra_pago(v_solic, 10000);
END;
/

SELECT nro_cuota, valor_cuota, monto_pagado, saldo_por_pagar, nro_pagos_parciales
FROM cuota_credito_socio
WHERE nro_solic_credito = (SELECT MAX(nro_solic_credito)
                           FROM credito_socio WHERE nro_socio = 2)
ORDER BY nro_cuota;
-- Esperado:
--   Cuota 1: monto_pagado 60.000, saldo 0, nro_pagos_parciales 6.
--   Cuota 2: valor_cuota 141.200, saldo_por_pagar 141.200, nro_pagos_parciales 5.


/* ---------- 7) ERRORES ESPERADOS ---------- */

-- 7a) Pago mayor al saldo de la cuota (ORA-20004).
DECLARE
    v_solic NUMBER(10);
BEGIN
    SELECT MAX(nro_solic_credito) INTO v_solic
    FROM credito_socio WHERE nro_socio = 2;

    pkg_credito.sp_registra_pago(v_solic, 200000);
    DBMS_OUTPUT.PUT_LINE('ERROR: el pago mayor al saldo NO debió aceptarse');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('OK, error esperado: ' || SQLERRM);
END;
/
-- Esperado: ORA-20004 "El monto supera el saldo de la cuota 1 ..."

-- 7b) Crédito sin cuotas pendientes (ORA-20003).
BEGIN
    pkg_credito.sp_registra_pago(999999, 1000);
    DBMS_OUTPUT.PUT_LINE('ERROR: no debió aceptarse');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('OK, error esperado: ' || SQLERRM);
END;
/
-- Esperado: ORA-20003 "El crédito no tiene cuotas pendientes"

-- 7c) Registro de errores.
SELECT correl_error, sentencia_error, descrip_error
FROM error_proceso
ORDER BY correl_error DESC;


EXEC pkg_credito.sp_genera_pago_mensual('10/2026');
--revisar tabla pago_mensual_credito
SELECT nro_solic_credito, nro_cuota_mes, valor_cuota_mes, fecha_venc_cuota_mes,
       saldo_pago_mes_ant, dias_atraso_pago_mes_ant, multa_atraso_pago_mes_ant,
       valor_total_cuota_mes
FROM pago_mensual_credito
WHERE nro_solic_credito IN (3013, 3014);



/* ==========================================================================
   LIMPIEZA (opcional): solo si NO se ha hecho COMMIT desde el inicio.
   ========================================================================== */
-- ROLLBACK;


/*

     CUOTA
----------
    100000


MORA_ATRASO
-----------
       2700


MORA_SIN_ATRASO
---------------
              0


      TASA
----------
,5        

Crédito 1 creado

Procedimiento PL/SQL terminado correctamente.
No creado: ORA-20002: El socio ya tiene 2 créditos simultáneos

Procedimiento PL/SQL terminado correctamente.

NRO_SOLIC_CREDITO MONTO_SOLICITADO TOTAL_CUOTAS_CREDITO
----------------- ---------------- --------------------
             3013           300000                    3
                1           300000                    3


 NRO_CUOTA VALOR_CUOTA MONTO_PAGADO SALDO_POR_PAGAR FECHA_VE
---------- ----------- ------------ --------------- --------
         1      100000            0          100000 15/11/26
         2      100000            0          100000 15/12/26
         3      100000            0          100000 15/01/27

OK, error esperado: ORA-20002: El socio ya tiene 2 créditos simultáneos

Procedimiento PL/SQL terminado correctamente.

CREDITOS_SOCIO_1
----------------
               2

Pago 50.000 registrado al crédito 3013

Procedimiento PL/SQL terminado correctamente.

 NRO_CUOTA MONTO_PAGADO SALDO_POR_PAGAR NRO_PAGOS_PARCIALES FECHA_PA
---------- ------------ --------------- ------------------- --------
         1        50000           50000                   1 20/10/26
         2            0          100000                   0         
         3            0          100000                   0         


1 fila actualizadas.

Pago fuera de plazo registrado

Procedimiento PL/SQL terminado correctamente.

 NRO_CUOTA MONTO_PAGADO SALDO_POR_PAGAR NRO_PAGOS_PARCIALES
---------- ------------ --------------- -------------------
         1        60000           41200                   2
         2            0          100000                   0
         3            0          100000                   0


CREDITOS_SOCIO_2
----------------
               0

Procedimiento PL/SQL terminado correctamente.
Procedimiento PL/SQL terminado correctamente.

 NRO_CUOTA VALOR_CUOTA MONTO_PAGADO SALDO_POR_PAGAR NRO_PAGOS_PARCIALES
---------- ----------- ------------ --------------- -------------------
         1      100000        50000           50000                   5
         2      100000            0          100000                   0
         3      100000            0          100000                   0

Procedimiento PL/SQL terminado correctamente.

 NRO_CUOTA VALOR_CUOTA MONTO_PAGADO SALDO_POR_PAGAR NRO_PAGOS_PARCIALES
---------- ----------- ------------ --------------- -------------------
         1      100000        60000               0                   6
         2      141200            0          141200                   5
         3      100000            0          100000                   0

OK, error esperado: ORA-20004: El monto supera el saldo de la cuota 2 (saldo: 141200)

Procedimiento PL/SQL terminado correctamente.
OK, error esperado: ORA-20003: El crédito no tiene cuotas pendientes

Procedimiento PL/SQL terminado correctamente.

CORREL_ERROR SENTENCIA_ERROR                                                                                                          DESCRIP_ERROR                                                                                                                                                                                                                                                  
------------ ------------------------------------------------------------------------------------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
          10 sp_registra_pago                                                                                                         ORA-20003: El crédito no tiene cuotas pendientes                                                                                                                                                                                                               
           9 sp_registra_pago                                                                                                         ORA-20004: El monto supera el saldo de la cuota 2 (saldo: 141200)                                                                                                                                                                                              
           8 sp_registra_credito                                                                                                      ORA-20002: El socio ya tiene 2 créditos simultáneos                                                                                                                                                                                                            
           7 sp_registra_credito                                                                                                      ORA-20002: El socio ya tiene 2 créditos simultáneos                                                                                                                                                                                                            


*/