#!/bin/sh
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
# Provides WP_ADMIN_PASSWORD and WP_USER_PASSWORD
. /run/secrets/credentials

case "$WP_ADMIN_USER" in
	*[Aa][Dd][Mm][Ii][Nn]*)
		echo "WP_ADMIN_USER must not contain 'admin'" >&2
		exit 1 ;;
esac

# Wait (bounded) for MariaDB to accept connections
tries=0
until mariadb-admin ping -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" --silent; do
	tries=$((tries + 1))
	if [ "$tries" -ge 30 ]; then
		echo "MariaDB not reachable, giving up" >&2
		exit 1
	fi
	sleep 2
done

if [ ! -f wp-config.php ]; then
	wp core download --allow-root
	wp config create --allow-root \
		--dbname="$MYSQL_DATABASE" \
		--dbuser="$MYSQL_USER" \
		--dbpass="$DB_PASSWORD" \
		--dbhost=mariadb:3306
	wp core install --allow-root --skip-email \
		--url="https://$DOMAIN_NAME" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL"
	wp user create --allow-root \
		"$WP_USER" "$WP_USER_EMAIL" \
		--role=author \
		--user_pass="$WP_USER_PASSWORD"
fi

chown -R www-data:www-data /var/www/html

# Foreground php-fpm as PID 1
exec php-fpm8.2 -F
