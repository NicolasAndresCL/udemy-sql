#!/usr/bin/env bash
# Reproduce en local los jobs del CI (lint → smoke), con las mismas
# herramientas y versiones. Si esto pasa, el CI pasa.
#
# Los linters (shellcheck, actionlint) corren en contenedores efímeros: nada
# que instalar.
#
# Uso:  ./verificar.sh          (todo)
#       ./verificar.sh --rapido (solo lint, sin levantar MySQL)
set -euo pipefail

cd "$(dirname "$0")"

# Git Bash: `pwd -W` da C:/... (lo que entiende Docker Desktop) y
# MSYS_NO_PATHCONV evita que /mnt o /repo se reescriban como rutas de Windows.
ruta_repo="$(pwd -W 2>/dev/null || pwd)"
export MSYS_NO_PATHCONV=1

# El compose exige las claves (`:?`). Para validar la sintaxis basta con
# valores de relleno, sin necesitar un .env.
echo '== 1/5  Sintaxis del compose =='
MYSQL_ROOT_PASSWORD=x MYSQL_PASSWORD=x docker compose config --quiet

echo '== 2/5  El compose falla ruidoso sin claves (prueba en negativo) =='
if env -u MYSQL_ROOT_PASSWORD -u MYSQL_PASSWORD \
        docker compose --env-file /dev/null config --quiet >/dev/null 2>&1; then
    echo 'ERROR: el compose acepta arrancar sin MYSQL_ROOT_PASSWORD.' >&2
    exit 1
fi
echo '  [ok]    sin claves, config se niega'

echo '== 3/5  Scripts ejecutables y analisis estatico =='
if git ls-files -s -- '*.sh' .githooks | grep -v '^100755'; then
    echo 'ERROR: scripts sin bit ejecutable en git (git update-index --chmod=+x).' >&2
    exit 1
fi
docker run --rm -v "${ruta_repo}:/mnt" koalaman/shellcheck:stable \
    verificar.sh scripts/smoke.sh .githooks/pre-commit

echo '== 4/5  Lint de los workflows de GitHub Actions =='
docker run --rm -v "${ruta_repo}:/repo" -w /repo rhysd/actionlint:latest -color

if [ "${1:-}" = '--rapido' ]; then
    echo
    echo 'Verificacion rapida: OK (smoke omitido)'
    exit 0
fi

echo '== 5/5  Smoke: MySQL arranca, UTF-8 y persistencia =='
bash scripts/smoke.sh

echo
echo 'Verificacion completa: OK'
