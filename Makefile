NAME		= inception
COMPOSE		= docker compose -f srcs/docker-compose.yml -p $(NAME)

ifeq ($(wildcard srcs/.env),)
$(error srcs/.env missing: run 'cp srcs/.env.example srcs/.env' and set your login)
endif

LOGIN		:= $(shell grep '^LOGIN=' srcs/.env | cut -d= -f2)
DOMAIN		:= $(shell grep '^DOMAIN_NAME=' srcs/.env | cut -d= -f2)
VM_IP		:= $(shell grep '^VM_IP=' srcs/.env | cut -d= -f2)
HOST_IP		= $(if $(VM_IP),$(VM_IP),127.0.0.1)
DATA_DIR	= /home/$(LOGIN)/data
SECRETS_DIR	= secrets

# Random 24-char hex password, no external tools needed
GEN_PASS	= head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n'

all: up

up: dirs secrets
	$(COMPOSE) up -d --build

dirs:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

# Generates the secret files once if they are missing (never committed to git)
secrets:
	@mkdir -p $(SECRETS_DIR)
	@[ -f $(SECRETS_DIR)/db_root_password.txt ] || { $(GEN_PASS) > $(SECRETS_DIR)/db_root_password.txt; echo "generated db_root_password.txt"; }
	@[ -f $(SECRETS_DIR)/db_password.txt ] || { $(GEN_PASS) > $(SECRETS_DIR)/db_password.txt; echo "generated db_password.txt"; }
	@[ -f $(SECRETS_DIR)/credentials.txt ] || { \
		printf 'WP_ADMIN_PASSWORD=%s\nWP_USER_PASSWORD=%s\n' "$$($(GEN_PASS))" "$$($(GEN_PASS))" > $(SECRETS_DIR)/credentials.txt; \
		echo "generated credentials.txt"; }
	@chmod 600 $(SECRETS_DIR)/*.txt

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

# Maps the domain to VM_IP from .env (run on your PC), or 127.0.0.1 if unset (run on the VM)
hosts:
	@grep -q "$(DOMAIN)" /etc/hosts || echo "$(HOST_IP) $(DOMAIN)" | sudo tee -a /etc/hosts

clean: down
	docker system prune -af

fclean:
	$(COMPOSE) down -v --rmi all
	docker system prune -af
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up dirs secrets down start stop logs ps hosts clean fclean re
