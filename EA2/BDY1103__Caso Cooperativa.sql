DROP TABLE reg_auditoria;

CREATE TABLE reg_auditoria(
    nombre_tabla    VARCHAR2(30),
    nombre_trans    VARCHAR2(15),
    usuario_trans   VARCHAR2(30),
    fecha_trans     DATE DEFAULT SYSDATE
);


DROP TRIGGER tgr_reg_aud_ai;

CREATE OR REPLACE TRIGGER tgr_reg_aud_ai
AFTER INSERT OR UPDATE OR DELETE ON gtt_clientes
DECLARE
    v_tipo_trans    VARCHAR2(15);
BEGIN
    v_tipo_trans := CASE
                        WHEN UPDATING THEN 'UPDATE'
                        WHEN DELETING THEN 'DELETE'
                        WHEN INSERTING THEN 'INSERT'
                    END;
                    
    DBMS_OUTPUT.PUT_LINE('TIPO TRANSACCION: '||v_tipo_trans);
    
    INSERT INTO reg_auditoria(
        nombre_tabla,
        nombre_trans,
        usuario_trans
    )
    VALUES (
        'GTT_CLIENTES',
        v_tipo_trans,
        USER
    );
END;

INSERT INTO gtt_clientes
VALUES(
    '20.781.681-7',
    'E xe3 qui e1l',
    'Ra 4ul ',
    'P ulg 4ar',
    'C e3r da ',
    '2001-06-25',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);

INSERT INTO gtt_clientes
VALUES(
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
