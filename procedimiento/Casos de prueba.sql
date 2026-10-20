INSERT INTO gtt_clientes
VALUES(/home/exepulgar/Duoc/SegundoAnio/SEGUNDO SEMESTRE/TALLER DE BASE DE DATOS/Caso Semestral/repo/procedimiento/Casos de prueba.sql
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

-- CASO RUT INCORRECTO (guion no numero ni K)
INSERT INTO gtt_clientes
VALUES(
    '12345678-f',
    'Caso',
    'digito',
    'verificador',
    'malo',
    '20000101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);

-- CASO RUT LONGITUD NO VALIDA (menor que 1 millon)
INSERT INTO gtt_clientes
VALUES(
    '345.678-9',
    'Caso',
    'rut',
    'longitud',
    'invalida',
    '20010101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);

-- CASO NOMBRE VACIO (no permite null)
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    ' 12 ',
    'Primer',
    'Nombre',
    'Vacio',
    '20000101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);

-- CASO MENOR DE EDAD
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Menor',
    'de',
    'edad',
    '20180101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);

-- CASO UBICACION NO EXISTENTE
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Ubicacion',
    'no',
    'existente',
    '20010101',
    'Pedro Aguirre Cerda',
    'Lemuria',
    'Republica de Lemuria',
    1,
    1,
    10,
    300000,
    24
);

-- CASO TIPO SOCIO ERRONEO
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Tipo',
    'Socio',
    'Erroneo',
    '20010101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    4,
    1,
    10,
    300000,
    24
);

-- CASO PROFESION/OFICIO ERRONEO
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Profesion',
    'Oficio',
    'Erroneo',
    '20010101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    24,
    10,
    300000,
    24
);

-- CASO PRODUCTO ERRONEO
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Producto',
    'Solicitado',
    'Erroneo',
    '20010101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    5,
    300000,
    24
);

-- CASO CLIENTE TERCERA EDAD
INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Cliente',
    'Tercera',
    'Edad',
    '1966-01-01',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);

-- CASOS CLIENTES CORRECTOS
INSERT INTO gtt_clientes
VALUES(
    '12.345.678-9',
    'Caso',
    'De',
    'Cliente',
    'Correcto',
    '2001-01-01',
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
    '22345678-9',
    'Caso',
    'De',
    'Cliente',
    'Correcto',
    '2001-01-01',
    'Pedro Aguirre Cerda',
    'Tal',
    'Anto',
    1,
    1,
    10,
    300000,
    24
);

INSERT INTO gtt_clientes
VALUES(
    '32345678-9',
    'Caso',
    'De',
    'Cliente',
    'Correcto',
    '2001-01-01',
    'Pedro Aguirre Cerda',
    'Tal',
    'Del Ma',
    1,
    1,
    10,
    300000,
    24
);

INSERT INTO gtt_clientes
VALUES(
    '12345678-9',
    'Caso',
    'Menor',
    'de',
    'edad',
    '20180101',
    'Pedro Aguirre Cerda',
    'Olm',
    'Valp',
    1,
    1,
    10,
    300000,
    24
);