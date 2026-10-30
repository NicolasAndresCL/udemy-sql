# udemy-sql — MySQL 8.4 en Docker para practicar SQL solo por consola

[![CI](https://github.com/NicolasAndresCL/udemy-sql/actions/workflows/ci.yml/badge.svg)](https://github.com/NicolasAndresCL/udemy-sql/actions/workflows/ci.yml)
![Versión](https://img.shields.io/badge/versi%C3%B3n-0.1.0-blue)
![MySQL](https://img.shields.io/badge/mysql-8.4%20LTS-4479A1)

| | |
|---|---|
| **Versión** | 0.1.0 |
| **Fecha** | 30 de octubre de 2026 |
| **Autor** | [Nicolás Andrés Cano Leal](#autor) |

Entorno de práctica para el curso de SQL de Udemy: un **servidor MySQL 8.4 LTS en un contenedor**, al que se entra
**solo por la consola `mysql`** que viene dentro de la imagen. No hace falta instalar MySQL en Windows ni
clientes gráficos. Los datos sobreviven a apagar y recrear el contenedor, y los `.sql` del curso se cargan desde una
carpeta compartida con `SOURCE`.

- **Motor:** `mysql:8.4.13` (rama LTS, versión fijada; Dependabot avisa de los parches).
- **Acceso:** `docker compose exec mysql mysql …`, sin puertos publicados.
- **Persistencia:** volumen nombrado `udemy-sql_mysql_data`.
- **Todo dockerizado**, con CI que levanta MySQL de verdad en cada PR.

## Arquitectura

```text
udemy-sql/
├── docker-compose.yml          # servicio mysql: LTS fijado, LANG=C.UTF-8, healthcheck por TCP, sin puertos
├── .env.example                # plantilla de claves; se copia a .env (ignorado por git)
├── ejercicios/                 # montada en /ejercicios: los .sql que se cargan con SOURCE
│   ├── 00-hola-mysql.sql       # primer ejercicio: comprueba consola y que la ñ se guarda en UTF-8
│   └── curso/                  # material del instructor (ignorado: es ajeno, no se publica)
├── scripts/
│   └── smoke.sh                # prueba de humo: arranca, entra, UTF-8 y persistencia (CI y local)
├── verificar.sh                # clon local del CI: lint → smoke
├── .githooks/pre-commit        # corre `verificar.sh --rapido` si el commit toca yml o sh
└── .github/
    ├── workflows/ci.yml        # lint + secretos → smoke
    ├── workflows/release.yml   # tag vX.Y.Z → GitHub Release con la sección del CHANGELOG
    └── dependabot.yml          # parches de mysql:8.4 y versiones de las actions
```

**Flujo:** terminal de Windows → `docker compose exec` → cliente `mysql` dentro del contenedor → servidor MySQL
(socket local). Nada fuera del contenedor habla con MySQL.

## Levantar con Docker

Requisito: Docker Desktop corriendo (`docker info` debe responder).

```powershell
Copy-Item .env.example .env          # y cambia las dos claves dentro de .env
docker compose up -d --wait          # espera a que el healthcheck diga healthy (~30 s la primera vez)
docker compose exec mysql mysql -uroot -p
```

| Qué | Cómo |
|---|---|
| Consola como `root` (crear y borrar bases) | `docker compose exec mysql mysql -uroot -p` |
| Consola como `alumno` (solo la base `practica`) | `docker compose exec mysql mysql -ualumno -p practica` |
| Cargar un `.sql` de `ejercicios/` | dentro de `mysql>`: `SOURCE /ejercicios/<archivo>.sql;` |
| Ver estado | `docker compose ps` |
| Ver logs | `docker compose logs --tail 50 mysql` |

Al terminar de estudiar:

| Comando | Qué conserva |
|---|---|
| `docker compose stop` | Todo. Se retoma con `docker compose start`. |
| `docker compose down` | Los datos (el volumen). Borra contenedor y red. |
| `docker compose down -v` | **Nada: borra el volumen y todas las bases.** |

La guía comentada paso a paso, con qué hace cada comando y qué salida esperar, está en `pasos.md` (local, no
versionada).

## Variables de entorno

| Variable | Servicio | Por defecto | Para qué |
|---|---|---|---|
| **`MYSQL_ROOT_PASSWORD`** | mysql | — (obligatoria) | Clave de `root`. Sin ella, `compose` se niega a arrancar. |
| **`MYSQL_PASSWORD`** | mysql | — (obligatoria) | Clave del usuario `alumno`. |
| `MYSQL_DATABASE` | mysql | `practica` | Base que se crea en el primer arranque. Fija en el compose. |
| `MYSQL_USER` | mysql | `alumno` | Usuario sin privilegios globales, dueño de `practica`. Fijo en el compose. |
| `TZ` | mysql | `America/Santiago` | Que `NOW()` dé la hora de Chile. |
| `LANG` | mysql | `C.UTF-8` | Cliente `mysql` en UTF-8 (ver Decisiones). |

Las `MYSQL_*` **solo se aplican con el volumen vacío** (primer arranque). Para cambiar una clave después:
`ALTER USER` dentro de MySQL, o `down -v` y volver a levantar (borra los datos).

## Verificación

```bash
./verificar.sh            # todo (levanta MySQL dos veces en un proyecto aparte y lo borra al final)
./verificar.sh --rapido   # solo lint, sin levantar MySQL (lo usa el pre-commit)
```

Reproduce los jobs del CI en el mismo orden:

1. **lint** — `docker compose config`; prueba en negativo: sin claves, el compose **debe** negarse; bit
   ejecutable de los scripts en git; `shellcheck`; `actionlint`.
2. **secretos** (solo CI) — `gitleaks` sobre toda la historia y `git check-ignore` de `.env`, `ejercicios/curso/` y
   los documentos internos.
3. **smoke** — `scripts/smoke.sh`, en un proyecto Compose aparte (`udemy-sql-verificar`) con claves efímeras y
   `trap … down -v`:
   - llega a `healthy` y la versión es `8.4.*`;
   - `alumno` entra a `practica`;
   - `SOURCE /ejercicios/00-hola-mysql.sql` funciona (bind mount);
   - la `ñ` queda guardada como `C3B1`, y **sin** `LANG=C.UTF-8` sale `C383C2B1` (la prueba discrimina);
   - los datos siguen ahí tras `down` + `up`.

Para activar el hook en un clon nuevo: `git config core.hooksPath .githooks`.

## Decisiones de diseño

- **`LANG: C.UTF-8` en el servicio.** La imagen oficial arranca en locale `POSIX` y su cliente `mysql` habla
  latin1: la `ñ` de un `INSERT` termina guardada como `C383C2B1`. El servidor ya es `utf8mb4`, así que el problema
  está en el cliente. Con la variable se arregla tanto el init como todo `docker compose exec … mysql`. El smoke lo
  comprueba en los dos sentidos.
- **Sin `ports:`.** El objetivo es practicar por consola: publicar el 3306 no aporta nada, expone una base con
  clave débil a la red local y choca con cualquier MySQL instalado en Windows. Si algún día hace falta un cliente
  gráfico: `"127.0.0.1:3307:3306"`.
- **Healthcheck por TCP (`127.0.0.1`), no por socket.** En el primer arranque la imagen levanta un servidor
  temporal con `--skip-networking` que sí responde por socket: con `localhost` el contenedor quedaría `healthy`
  antes de tiempo y la primera conexión fallaría.
- **`${VAR:?mensaje}` en las claves.** Si falta el `.env`, Compose falla con un mensaje claro en vez de arrancar
  MySQL sin clave de root.
- **Volumen nombrado para los datos y bind mount solo para `ejercicios/`.** En Docker Desktop, cada acceso a una
  carpeta de Windows cruza la capa VM ↔ NTFS. Los ficheros de InnoDB van en el volumen, con I/O nativo, y solo los
  `.sql` que se editan desde Windows van en la carpeta compartida.
- **Sin `container_name`, con `name: udemy-sql`.** Así el smoke puede levantar una copia aislada (`-p
  udemy-sql-verificar`, con volumen propio) sin tocar el contenedor ni los datos de uso diario.
- **Versión fijada (`8.4.13`) y no `8.4` ni `latest`.** Un parche nuevo llega como PR de Dependabot y pasa por el
  smoke antes de usarse.
- **Dependabot solo propone parches de 8.4.** Desde la `26.7`, MySQL numera por calendario y alterna versiones
  Innovation y LTS. Sin el `ignore`, Dependabot propone `8.4.13 → 26.7.0` (Innovation, sin ruta de actualización
  directa desde 8.4). Cambiar de rama es una decisión explícita: se cambia la imagen y la guardia del smoke a la vez.
- **Material del curso fuera de git.** `ejercicios/curso/` está ignorado: los scripts del instructor son
  material ajeno.

## Autor

**Nicolás Andrés Cano Leal**\
Backend Engineer → SRE | Python · Django · Kubernetes · Terraform · CI/CD

- LinkedIn: [linkedin.com/in/nicolasandrescl](https://www.linkedin.com/in/nicolasandrescl/)
- Portafolio: [nicolasandrescl.github.io](https://nicolasandrescl.github.io/)
- Correo: [nicolas.cano.leal@gmail.com](mailto:nicolas.cano.leal@gmail.com)

udemy-sql v0.1.0 · 30 de octubre de 2026
