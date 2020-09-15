# show help by default
.DEFAULT_GOAL := help

# PHONY prevents filenames being used as targets
.PHONY: help info rebuild list-domains status start stop logs restart build validate-schema get-schema validate-remote-schema validate-remote-schemas build-base shell

# constants
ENVIRONMENTS := development acceptance production
CONFIGURATION_SCHEMA_ENVIRONMENTS := acc prod
CONFIGURATION_SCHEMA_FILE := app.schema.json

# globals which can be overriden by setting make variables on the CLI
DOMAIN ?= amsterdam
SIGNALS_FRONTEND_PATH ?= ../signals-frontend
ENVIRONMENT ?= development
GITHUB_REPOSITORY_OWNER ?= Amsterdam
SIGNALS_FRONTEND_REPOSITORY_NAME ?= signals-frontend
IMAGE_TAG ?= latest
SCHEMA_DEFINITION_GIT_REF ?= master
DOCKER_REGISTRY ?= docker-registry.data.amsterdam.nl/ois
SIGNALS_FRONTEND_IMAGE_NAME ?= signalsfrontend
SIGNALS_FRONTEND_FULL_IMAGE_NAME ?= '${DOCKER_REGISTRY}/${SIGNALS_FRONTEND_IMAGE_NAME}:${IMAGE_TAG}'

# dynamic globals
DOMAINS := $(subst /,,$(subst ./domains/,,$(dir $(wildcard ./domains/*/))))
SIGNALEN_GIT_REF := $(shell git rev-parse HEAD)
SCHEMA_DEFINITION_TEMP_FILE := /tmp/signalen-configuration-schema.$(SIGNALEN_GIT_REF).json
SCHEMA_DEFINITION_FILE := ${SIGNALS_FRONTEND_PATH}/internals/schemas/${CONFIGURATION_SCHEMA_FILE}
CONFIG_BASE_FILE := ${SIGNALS_FRONTEND_PATH}/app.base.json
CONFIG_TEST_FILE := /tmp/app.json

ifeq ($(ENVIRONMENT),acceptance)
SCHEMA_ENVIRONMENT := acc
else
SCHEMA_ENVIRONMENT := prod
endif

define _validate_schema =
	echo validating schema - domain=$(2), environment=$(ENVIRONMENT), schema environment=${3} && \
	test -f ${1} || (echo validation schema definition not found: ${SCHEMA_DEFINITION_FILE}; exit 1) && \
	node merge-config.js $(CONFIG_BASE_FILE) domains/${DOMAIN}/${SCHEMA_ENVIRONMENT}.config.json $(CONFIG_TEST_FILE) && \
	npx ajv-cli validate --all-errors -s ${SCHEMA_DEFINITION_FILE} -d $(CONFIG_TEST_FILE);
endef

_MAKEFILE_BUILTIN_VARIABLES := .DEFAULT_GOAL CURDIR MAKEFLAGS MAKEFILE_LIST SHELL

_MAKEFILE_VARIABLES := $(foreach make_variable, $(sort $(.VARIABLES)),\
	$(if $(filter-out _% HELP_FUN $(_MAKEFILE_BUILTIN_VARIABLES),$(make_variable)),\
		$(if $(filter file,$(origin $(make_variable))),\
			"\n$(make_variable)=$($(make_variable))"\
		)\
	)\
)

help: ## show this help screen
	@echo -e "signalen Makefile help (${SIGNALEN_GIT_REF})"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

info: ## dump Makefile variables to screen
	@echo -e $(_MAKEFILE_VARIABLES)

build-base: ## build and tag the base signals container. Usage `make build-base SIGNALS_FRONTEND_PATH=../signals-frontend`
	docker build -t $(SIGNALS_FRONTEND_IMAGE_NAME) $(SIGNALS_FRONTEND_PATH)
	docker tag $(SIGNALS_FRONTEND_IMAGE_NAME):latest $(SIGNALS_FRONTEND_FULL_IMAGE_NAME)

build: ## build Docker Compose images
	docker-compose build --parallel

list-domains: ## list frontend domains
	@echo ${DOMAINS}

start: ## start single Docker Compose service. Usage `make DOMAIN=amsterdam start`
	docker-compose up --remove-orphans ${DOMAIN}

stop: ## stop Docker Compose
	docker-compose down -v --remove-orphans

images: ## list Docker Compose images
	docker-compose images

restart: stop start status ## restart Docker Compose

status: ## show Docker Compose process list
	docker-compose ps

rebuild: stop build start status ## rebuild Docker Compose. Usage: `make DOMAIN=amsterdam rebuild`

shell: ## execute command on container. Usage `make ENVIRONMENT=development shell`
	docker-compose exec ${DOMAIN} sh

logs: ## tail Docker Compose container logs
	docker-compose logs --tail=100 -f ${DOMAIN}

validate-local-schema: ## validate configuration schema in current branch. Usage `make SIGNALS_FRONTEND_PATH=../signals-frontend DOMAIN=amsterdam ENVIRONMENT=development validate-local-schema`
	@$(call _validate_schema,$(SCHEMA_DEFINITION_FILE),$(DOMAIN),$(SCHEMA_ENVIRONMENT))

download-schema: ## download JSON validation schema definition to /tmp
ifeq ("$(wildcard $(SCHEMA_DEFINITION_TEMP_FILE))","")
	@echo downloading schema from ${SIGNALS_FRONTEND_REPOSITORY_NAME} ${SCHEMA_ENVIRONMENT} to ${SCHEMA_DEFINITION_TEMP_FILE}
	@wget --no-clobber \
		--quiet https://github.com/${GITHUB_REPOSITORY_OWNER}/${SIGNALS_FRONTEND_REPOSITORY_NAME}/raw/${SCHEMA_DEFINITION_GIT_REF}/internals/schemas/${CONFIGURATION_SCHEMA_FILE} \
		-O ${SCHEMA_DEFINITION_TEMP_FILE}
endif

validate-all-schemas: download-schema ## validate all domain JSON schema configuration files. Usage `make SCHEMA_DEFINITION_GIT_REF=master validate-all-schemas`
	@$(foreach domain,$(DOMAINS),\
		$(foreach schema_environment,$(CONFIGURATION_SCHEMA_ENVIRONMENTS),\
			$(call _validate_schema,$(SCHEMA_DEFINITION_FILE),$(domain),$(schema_environment))\
		)\
	)

validate-schema: download-schema ## validate single domain schema configuration file. Usage `make DOMAIN=amsterdam ENVIRONMENT=development SCHEMA_DEFINITION_GIT_REF=master validate-schema`
	$(call _validate_schema,$(SCHEMA_DEFINITION_TEMP_FILE),$(DOMAIN),$(SCHEMA_ENVIRONMENT))
