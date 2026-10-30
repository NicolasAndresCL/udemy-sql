#!/usr/bin/env bash
# Prueba de humo: MySQL arranca con ESTE docker-compose.yml, se entra por
# consola, guarda bien la ñ y conserva los datos al recrear el contenedor.
#
# Lo corren igual el CI (job `smoke`) y ./verificar.sh. Usa un proyecto de
# Compose aparte (`udemy-sql-verificar`) con su propio volumen y claves
# efímeras: nunca toca el contenedor ni los datos de uso diario. El trap lo
# baja con `down -v` aunque la prueba falle.
#
# Uso:  bash scripts/smoke.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# Git Bash (Windows) reescribe rutas Linux como /ejercicios a C:/Program
# Files/Git/...; en Linux la variable no existe y se ignora.
export MSYS_NO_PATHCONV=1

proyecto='udemy-sql-verificar'
export MYSQL_ROOT_PASSWORD="smoke-root-$RANDOM$RANDOM"
export MYSQL_PASSWORD="smoke-alumno-$RANDOM$RANDOM"

dc() { docker compose -p "$proyecto" "$@"; }
# Consola de MySQL dentro del contenedor, sin TTY (-T) y sin cabeceras (-N -B).
sql_root()   { dc exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -B "$@" 2>/dev/null; }
sql_alumno() { dc exec -T mysql mysql -ualumno -p"$MYSQL_PASSWORD" -N -B practica "$@" 2>/dev/null; }

bajar() { dc down -v --remove-orphans >/dev/null 2>&1 || true; }
trap bajar EXIT

falla() {
    echo "  [FALLA] $1" >&2
    dc logs --tail 50 mysql >&2 || true
    exit 1
}
ok() { echo "  [ok]    $1"; }

bajar   # por si quedó algo de una corrida anterior interrumpida

echo '-- Levantar y esperar healthy'
# --wait espera al healthcheck; si queda unhealthy o pasa el timeout, falla.
dc up -d --wait --wait-timeout 240 >/dev/null || falla 'MySQL no llegó a healthy'
ok 'contenedor healthy'

version="$(sql_root -e 'SELECT VERSION();')"
[[ "$version" == 8.4.* ]] || falla "versión inesperada: '$version'"
ok "MySQL $version"

echo '-- Usuarios creados por el primer arranque'
[ "$(sql_alumno -e 'SELECT DATABASE();')" = 'practica' ] \
    || falla 'alumno no entra a la base practica'
ok 'alumno entra a practica'

echo '-- Carga de un .sql desde la carpeta montada'
sql_root -e 'SOURCE /ejercicios/00-hola-mysql.sql;' >/dev/null \
    || falla 'SOURCE /ejercicios/00-hola-mysql.sql falló (¿bind mount?)'
ok 'SOURCE /ejercicios/... funciona'

echo '-- La ñ se guarda en UTF-8'
# "año" en UTF-8 es 61 C3B1 6F. Corrupto (cliente en latin1) sería 61 C383C2B1 6F.
hex="$(sql_root -e "SELECT HEX(texto) FROM practica.saludos ORDER BY id LIMIT 1;")"
[[ "$hex" == *61C3B16F* ]] || falla "la ñ se guardó mal: $hex"
ok 'ñ guardada como C3B1'

# Prueba en negativo: sin LANG=C.UTF-8 el cliente DEBE corromperla. Si esto
# saliera bien, la comprobación de arriba no estaría distinguiendo nada.
# CONVERT a utf8mb4 imita lo que hace una columna real: HEX('ñ') a secas
# devuelve los bytes en el charset de la conexión y daría C3B1 igual.
hex_malo="$(dc exec -T -e LANG= mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -B \
    -e "SELECT HEX(CONVERT('ñ' USING utf8mb4));" 2>/dev/null)"
[ "$hex_malo" != 'C3B1' ] \
    || falla 'sin LANG la ñ también sale bien: la prueba UTF-8 no detecta nada'
ok "sin LANG=C.UTF-8 se corrompe ($hex_malo): la prueba sí discrimina"

echo '-- Los datos sobreviven a destruir el contenedor'
dc down >/dev/null 2>&1
dc up -d --wait --wait-timeout 240 >/dev/null || falla 'no volvió a healthy tras recrear'
filas="$(sql_root -e 'SELECT COUNT(*) FROM practica.saludos;')"
[ "$filas" -ge 1 ] || falla 'la tabla saludos desapareció: el volumen no persiste'
ok "datos intactos tras down/up ($filas fila/s)"

echo
echo 'Smoke: OK'
