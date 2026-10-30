# Changelog

Todos los cambios relevantes de este proyecto se documentan aquí.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[Versionado Semántico](https://semver.org/lang/es/).

## [Sin publicar]

### Cambiado

- Dependabot solo propone parches de la rama 8.4 LTS de MySQL. Ignora los saltos de rama, como el `26.7.0`
  Innovation que propuso el PR #1: no es LTS y un volumen de 8.4 no se actualiza directo a esa versión.
- El smoke explica qué rama esperaba cuando rechaza una versión.

## [0.1.0] — 2026-10-30

### Añadido

- `docker-compose.yml` con MySQL `8.4.13` (LTS), base `practica`, usuario `alumno`, zona horaria de Chile y
  `LANG=C.UTF-8` para que la consola guarde bien la ñ y los acentos.
- Healthcheck por TCP, que no da por sano el servidor temporal del primer arranque.
- Claves obligatorias desde `.env` (`.env.example` como plantilla); sin ellas, Compose se niega a arrancar.
- Carpeta `ejercicios/` montada en `/ejercicios` para cargar scripts con `SOURCE`, con un primer ejercicio
  (`00-hola-mysql.sql`) que comprueba la consola y la codificación.
- `scripts/smoke.sh`: arranque, acceso de `alumno`, `SOURCE`, UTF-8 (con prueba en negativo) y persistencia tras
  recrear el contenedor, en un proyecto Compose aislado.
- `verificar.sh` (clon local del CI) y hook `pre-commit`.
- CI (lint + secretos → smoke), workflow de releases por tag, Dependabot y plantillas de issue y PR.
