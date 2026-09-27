*This project has been created as part of the 42 curriculum by rein.*

# Inception

## Description

Inception is a system administration project: build a small web infrastructure out of Docker containers, running inside a virtual machine, using only images I write myself.

The stack serves a WordPress site over HTTPS:

```
            443 (TLSv1.2/1.3)
 browser ─────────────────────▶ nginx ──9000──▶ wordpress (php-fpm) ──3306──▶ mariadb
                                  │                  │                          │
                                  └── wordpress_data ┘                    mariadb_data
                                        (/home/rein/data/wordpress)   (/home/rein/data/mariadb)
```

- **nginx**: the only entrypoint. Terminates TLS on port 443 and forwards PHP requests to WordPress.
- **wordpress**: WordPress + php-fpm (no web server). Installed and configured automatically with WP-CLI on first start, with an administrator and a second (author) user.
- **mariadb**: the database server (no web server).

All three containers share a private bridge network called `inception` and restart automatically if they crash.

### Use of Docker and sources in this project

Each service has its own `Dockerfile` in `srcs/requirements/<service>/`, built from `debian:bookworm` (the penultimate stable Debian). No ready-made images are pulled apart from the Debian base. Each service folder contains:

- `Dockerfile`: installs the packages and copies in config and scripts
- `conf/`: the service configuration (`50-server.cnf`, `www.conf`, nginx server block)
- `tools/`: the entrypoint script that prepares the service on first run and then `exec`s the daemon in the foreground so it runs as PID 1 and receives signals correctly

`srcs/docker-compose.yml` wires the services, the network, the volumes and the secrets together, and the root `Makefile` drives everything.

### Main design choices

- **Debian bookworm** over Alpine, for familiar packages (`php8.2-fpm`, `mariadb-server`) and glibc compatibility.
- **No infinite-loop hacks.** Every container runs its real daemon as PID 1 (`mariadbd`, `php-fpm8.2 -F`, `nginx -g 'daemon off;'`).
- **Idempotent first-run setup.** The entrypoints only initialise the database or install WordPress when the volume is empty, so restarts keep existing data.
- **Startup order** comes from a MariaDB healthcheck plus `depends_on: condition: service_healthy`, with a bounded retry in the WordPress script as a safety net.
- **Self-signed TLS certificate** generated at container start for `DOMAIN_NAME`, restricted to `TLSv1.2 TLSv1.3`.
- **Explicit image tags** (`:inception`) because the `latest` tag is forbidden.

### Virtual Machines vs Docker

A virtual machine emulates a full computer with its own kernel. It is strongly isolated but heavy: gigabytes of disk, a full boot, and dedicated RAM. A Docker container is an isolated process sharing the host kernel through namespaces and cgroups. It starts in seconds, weighs megabytes, and is described entirely by a Dockerfile. Here both are used: the VM provides an isolated, reproducible host, and Docker splits the services inside it.

### Secrets vs Environment Variables

Environment variables (from `srcs/.env`) hold non-sensitive configuration: domain, database name, user names. They are visible to anyone who can run `docker inspect` or read `/proc/<pid>/environ`. Docker secrets (files in `secrets/`) hold passwords. They are mounted read-only at `/run/secrets/<name>`, only in the containers that declare them, and never appear in the image, the environment, or git (`secrets/` is git-ignored).

### Docker Network vs Host Network

With `network: host` a container shares the host's network stack, so every port it opens is exposed on the machine and there is no isolation. This is forbidden here. A user-defined bridge network (`inception`) gives the containers a private network with built-in DNS (they reach each other as `mariadb`, `wordpress`, `nginx`). Only port 443 on nginx is published to the host, so MariaDB and php-fpm are not reachable from outside.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary host path straight into a container. It is simple but tied to the host's layout, and Docker does not manage it. A named volume is a Docker-managed object: it has a name, it is listed by `docker volume ls`, and it survives `docker compose down`. This project uses two **named volumes** (`mariadb_data`, `wordpress_data`) with the `local` driver configured to store their data in `/home/rein/data/`, as the subject requires, while remaining named volumes rather than service-level bind mounts.

## Instructions

Prerequisites on the VM: Docker Engine, the Docker Compose plugin, `make`, and `sudo`.

```sh
cp srcs/.env.example srcs/.env   # then set LOGIN, DOMAIN_NAME and the user names
make hosts                       # maps <login>.42.fr in /etc/hosts (to VM_IP if set, else 127.0.0.1)
make                             # creates data dirs + secrets, builds and starts everything
```

Then open `https://<login>.42.fr` (accept the self-signed certificate warning).

To browse from another machine (e.g. your PC with a cloud VM), set `VM_IP` in `srcs/.env` to the VM's IP and run `make hosts` on that machine.

| Command | Effect |
|---|---|
| `make` / `make up` | Build images and start the stack |
| `make down` | Stop and remove the containers (data is kept) |
| `make stop` / `make start` | Pause / resume the containers |
| `make ps` / `make logs` | Status / follow logs |
| `make fclean` | Remove containers, images, volumes **and** `/home/<login>/data` |
| `make re` | `fclean` then rebuild from scratch |

See [USER_DOC.md](USER_DOC.md) for day-to-day use and [DEV_DOC.md](DEV_DOC.md) for development details.

## Resources

- [Docker documentation](https://docs.docker.com/): Dockerfile reference, Compose file reference, secrets, volumes, networking
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker and the PID 1 problem](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/)
- [NGINX documentation](https://nginx.org/en/docs/): `ngx_http_ssl_module`, `ngx_http_fastcgi_module`
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/): `mariadb-install-db`, server system variables
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### Use of AI

Claude (Anthropic) was used as an assistant to:

- read the subject and scaffold the directory structure, Dockerfiles, `docker-compose.yml`, and Makefile
- draft the entrypoint scripts (MariaDB bootstrap, WP-CLI install, nginx certificate generation)
- run a local test of the stack (HTTPS, TLS versions, WordPress users, PID 1, restart on crash)
- draft this README, USER_DOC.md and DEV_DOC.md

All generated content was reviewed, tested, and is understood by the author, who can explain and modify every part of it.
