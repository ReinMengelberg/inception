#!/bin/sh
set -e

# Self-signed certificate for the domain, generated once per container
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout /etc/nginx/ssl/inception.key \
		-out /etc/nginx/ssl/inception.crt \
		-subj "/C=FR/L=Paris/O=42/CN=${DOMAIN_NAME}"
fi

sed "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/inception.conf.template \
	> /etc/nginx/conf.d/inception.conf

# Keep nginx in the foreground as PID 1
exec nginx -g 'daemon off;'
