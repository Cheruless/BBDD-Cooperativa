DROP TABLE gtt_clientes;
DROP TABLE gtt_cliente_validado; 
DROP SEQUENCE SEQ_SOCIO;
CREATE SEQUENCE SEQ_SOCIO START WITH 130 INCREMENT BY 1;
ALTER TABLE SOCIO MODIFY (nro_socio DEFAULT SEQ_SOCIO.NEXTVAL);

----------------------GTT CLIENTES----------------------------------------------
/*
    Información extraída del libroS
    'Modern Oracle Database Programming' de Alex Nuijten and Patrick Barel
    isbn: 9781484291658 primera edición.
    Capítulo 20: 'Choosing the Right Table Type'.
    Sección: 'Temporary Table', 'Global Temporary Table'.
    
    decidí ocupar este tipo de tabla ya que Meritxel tenía razón
    al respecto sobre una tabla de clientes.
    Sin embargo yo creí que sería una sobre-ingenieria ya que pensaba
        "que pereza tener que insertar data y eliminarla on-go."
        
    Pero gracias a este tipo de tablas, es que se elimina la data al COMMIT;
    básicamente se hace solito.
    cuya eliminación será realizada en otro proceso que se encarga de procesar estos datos.
*/

CREATE GLOBAL TEMPORARY TABLE gtt_clientes(
    run_dv          VARCHAR2(12), -- 12.345.678-9 ó 12345678-9
    pnombre         VARCHAR2(50),
    snombre         VARCHAR2(50),
    appaterno       VARCHAR2(50), -- En caso de apellidos, comprenderemos "paterno" 
                                  --como el primero por motivos de regulación de datos.  
    apmaterno       VARCHAR2(50),
    fecha_nac       VARCHAR2(10), -- ISO 8601: https://www.ionos.es/digitalguide/paginas-web/desarrollo-web/iso-8601/
    direccion       VARCHAR2(50),
    comuna          VARCHAR2(50), -- 'Olm' o 'Tal'
    region          VARCHAR2(50), -- 'Valp' o 'tiag'
    cod_tipo_socio  NUMBER(3),
    cod_prof_ofic   NUMBER(3),
    -- Según lo conversado con profesor, CLIENTE pide aqui mismo su producto inversion
    cod_prod_solic  NUMBER(3),
    ahorro_min_men  NUMBER(10),
    dia_pago_men    NUMBER(2)
) ON COMMIT DELETE ROWS;


----------------------GTT CLIENTE VALIDADO--------------------------------------
/*
    REVISAR SI SE PUEDE HACER COMO IMITACIÓN DE OTRA TABLA (SELECT O ALGO SIMILAR)
    esta tabla es una imitación de SOCIO
        Creo que puedo conseguir una aproximación a lo deseado.
        Leer Oracle PL/SQL by Example, cap 23 y 24 sobre Storing object types
*/

CREATE GLOBAL TEMPORARY TABLE gtt_cliente_validado(
    numrun  NUMBER(10),
    dvrun   VARCHAR2(1),
    pnombre VARCHAR2(50),
    snombre VARCHAR2(50),
    appaterno   VARCHAR2(50),
    apmaterno   VARCHAR2(50),
    foto        BLOB,
    fecha_nacimiento    DATE,
    fecha_inscripcion   DATE,
    correo              VARCHAR2(20),
    fono_contacto       NUMBER(10),
    direccion           VARCHAR2(50),
    
    cod_region          NUMBER(3),
    cod_provincia       NUMBER(3),
    cod_comuna          NUMBER(3),
    
    cod_prof_ofic       NUMBER(3),
    cod_tipo_socio      NUMBER(3),
    
    cod_prod_solic  NUMBER(3),
    ahorro_min_men  NUMBER(10),
    dia_pago_men    NUMBER(2)
) ON COMMIT DELETE ROWS;




/*
    CONSIDERAR FUTURO USO DE CLUSTERS
        Modern Oracle Database Programming, Parte 3 cap 20.
*/
