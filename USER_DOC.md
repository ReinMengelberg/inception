# User documentation

## What the stack provides

| Service | Role | Reachable from outside? |
|---|---|---|
| **nginx** | HTTPS web server, the single entrypoint (port 443, TLSv1.2/1.3 only) | Yes, `https://<login>.42.fr` |
| **wordpress** | The WordPress website, run by php-fpm | No, only through nginx |
| **mariadb** | The database holding posts, users and settings | No, only from WordPress |

## Starting and stopping

Run these from the project root:

```sh
make          # build (if needed) and start everything
make stop     # pause the containers
make start    # resume them
make down     # stop and remove the containers; website data is kept
```

Data survives `stop`, `down` and VM reboots. Only `make fclean` deletes it.

## Accessing the website

1. Make sure the domain points to the VM (one time only) on the machine you browse from:
   - **On the VM itself:** leave `VM_IP` empty in `srcs/.env` and run `make hosts` (maps to `127.0.0.1`).
   - **From your PC:** set `VM_IP=<vm-ip>` in `srcs/.env` in your local copy and run `make hosts` there.
2. Open **https://\<login\>.42.fr** in a browser.
3. The certificate is self-signed, so accept the browser warning ("Advanced → Continue").

**Administration panel:** https://\<login\>.42.fr/wp-admin

## Credentials

| What | User name | Password |
|---|---|---|
| WordPress administrator | `WP_ADMIN_USER` in `srcs/.env` | `WP_ADMIN_PASSWORD` in `secrets/credentials.txt` |
| WordPress second user (author) | `WP_USER` in `srcs/.env` | `WP_USER_PASSWORD` in `secrets/credentials.txt` |
| Database user | `MYSQL_USER` in `srcs/.env` | `secrets/db_password.txt` |
| Database root | `root` | `secrets/db_root_password.txt` |

Passwords are generated randomly the first time you run `make`. To view them:

```sh
cat secrets/credentials.txt
```

To use your own passwords, edit the files in `secrets/` **before the first `make`**. Passwords are only applied when the database and site are first created. To change them afterwards, run `make fclean`, edit the files, then `make` again (this erases the site's data).

Never commit the `secrets/` folder. It is already listed in `.gitignore`.

## Checking that everything runs

```sh
make ps
```

All three containers should be `Up`, and mariadb should show `(healthy)`.

More checks:

```sh
make logs                                           # live logs of all services
curl -kI https://<login>.42.fr                      # expect "HTTP/1.1 200 OK"
docker exec wordpress wp user list --allow-root     # the two WordPress users
```

If a container keeps restarting, `make logs` usually shows why: a missing `srcs/.env`, a missing secret, or a data folder that is not writable.
