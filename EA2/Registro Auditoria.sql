/*AUDITORIA DE TRANSACCIONES SQL.*/

CREATE IMMUTABLE TABLE reg_auditoria(
    nombre_tabla    VARCHAR2(30),
    nombre_trans    VARCHAR2(15),
    usuario_trans   VARCHAR2(30),
    fecha_trans     DATE
)
NO DROP UNTIL 0 DAYS IDLE
NO DELETE UNTIL 16 DAYS AFTER INSERT;

DROP TABLE reg_auditoria;

/*
    However, you should be mindful when using the reserved word REPLACE for a number of reasons.
    First, if you happen to use REPLACE with the name of an existing 
    stored function, procedure, or package, you will end up with different
    database objects that have the same name. 
    This situation occurs because triggers have a separate naming space in the database.
    
    Although sharing of the same name by a  trigger and a procedure, function, or package
    does not cause errors, potentially it might become confusing; thus, it is not considered a good programming practice.
    
    Second, when you use the reserved word REPLACE 
    and decide to associate a different table with your trigger, an error message is generated.
    
    //  Oracle PL/SQL by Example, Sixth Edition
    //  Benjamin Rosenzweig and Elena Rakhimov
    //  isbn: 9780138062897
*/

-- 1. (Opcional) Si necesitas recrear el trigger para asegurarte de que tiene el SYSDATE
DROP TRIGGER tgr_reg_aud_ai;

CREATE TRIGGER tgr_reg_aud_ai
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
        usuario_trans,
        fecha_trans
    )
    VALUES (
        'GTT_CLIENTES',
        v_tipo_trans,
        USER,
        SYSDATE
    );
END;


-- 2. Ejecutar tu INSERT
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

-- 3. Comprobar que el trigger hizo su trabajo en la tabla inmutable
SELECT * FROM reg_auditoria;