## Qué cambia

<!-- Descripción breve del cambio y por qué. -->

## Cómo se verificó

- [ ] `./verificar.sh` pasa en local (lint + smoke)
- [ ] `docker compose up -d --wait` deja MySQL en `healthy`

## Datos

- [ ] Si el cambio toca el volumen `mysql_data` o las variables `MYSQL_*`, el README explica qué hacer con
      un volumen ya inicializado

## Secretos

- [ ] `git status` revisado: no se incluyen `.env`, respaldos ni material del curso (`ejercicios/curso/`)
