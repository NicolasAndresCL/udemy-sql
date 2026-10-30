-- Primer ejercicio: comprueba que la consola funciona y que guarda bien la ñ.
-- Cárgalo desde la consola de MySQL con:
--   SOURCE /ejercicios/00-hola-mysql.sql;

USE practica;

CREATE TABLE IF NOT EXISTS saludos (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    texto   VARCHAR(100) NOT NULL,
    creado  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO saludos (texto) VALUES ('Hola, año nuevo con acentos: canción, pingüino');

-- hex_enie debe dar C3B1. Si da C383C2B1, el cliente no está en UTF-8.
SELECT texto, HEX(CONVERT('ñ' USING utf8mb4)) AS hex_enie, creado FROM saludos;
