# show help by default
.DEFAULT_GOAL := help

# PHONY prevents filenames being used as targets
.PHONY: help info rebuild list-domains status start start-domain stop logs restart build validate-schema get-schema validate-remote-schema validate-remote-schemas build-base shell

# constants
ENVIRONMENTS := development acceptance production
CONFIGURATION_SCHEMA_ENVIRONMENTS := acc prod
CONFIGURATION_SCHEMA_FILE := environment.conf.schema.json

# globals which can be overriden by setting make variables on the CLI
BUILD_PATH ?= ../signals-frontend
ENVIRONMENT ?= development
REPOSITORY_OWNER ?= Amsterdam
FRONTEND_REPOSITORY_NAME ?= signals-frontend
DOMAIN ?= amsterdam
DOCKER_REGISTRY ?= docker-registry.data.amsterdam.nl/ois
IMAGE_TAG ?= latest
SCHEMA_DEFINITION_GIT_REF ?= master

# dynamic globals
DOMAINS := $(subst /,,$(subst ./domains/,,$(dir $(wildcard ./domains/*/))))
SIGNALEN_GIT_REF := $(shell git branch -v | grep \* | cut -d ' ' -f2,3 --output-delimiter='_')
SCHEMA_DEFINITION_TEMP_FILE := /tmp/signalen-configuration-schema.$(SIGNALEN_GIT_REF).json
SCHEMA_DEFINITION_FILE := ${BUILD_PATH}/internals/schemas/${CONFIGURATION_SCHEMA_FILE}

ifeq ($(ENVIRONMENT),acceptance)
SCHEMA_ENVIRONMENT := acc
else
SCHEMA_ENVIRONMENT := prod
endif

define validate_schema =
	echo validating schema - domain=$(2), environment=$(ENVIRONMENT), schema environment=${3}; \
	test -f ${1} || (echo validation schema definition not found: ${SCHEMA_DEFINITION_FILE}; exit 1); \
	npx ajv-cli validate -s ${1} -d domains/${2}/${3}.config.json; \
	echo;
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
	@echo -e "Help (${SIGNALEN_GIT_REF})"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

info: ## dump various variables to screen
	@echo -e $(_MAKEFILE_VARIABLES)

build: ## build Docker Compose images
	docker-compose build --parallel

list-domains: ## list frontend domains
	@echo ${DOMAINS}

start: ## start single Docker Compose service. Usage `make start-domain DOMAIN=amsterdam`
	docker-compose up --remove-orphans ${DOMAIN}
	@echo
	@docker-compose ps

stop: ## stop Docker Compose
	docker-compose down -v --remove-orphans

images: ## list Docker Compose images
	docker-compose images

restart: stop start status ## restart Docker Compose

status: ## show Docker Compose process list
	docker-compose ps

rebuild: stop build start status ## rebuild Docker Compose

shell: ## execute command on container. Usage `make shell ${ENVIRONMENT}`
	docker-compose exec ${DOMAIN} sh

logs: ## tail Docker Compose container logs
	docker-compose logs --tail=100 -f ${DOMAIN}

validate-local-schema: ## validate configuration schema in current branch. Usage `make BUILD_PATH=../signals-frontend DOMAIN=amsterdam ENVIRONMENT=development validate-schema`
	@$(call validate_schema,$(SCHEMA_DEFINITION_FILE),$(DOMAIN),$(SCHEMA_ENVIRONMENT))

download-schema: ## download JSON validation schema definition to /tmp
ifeq ("$(wildcard $(SCHEMA_DEFINITION_TEMP_FILE))","")
	wget --no-clobber \
		--quiet https://github.com/Amsterdam/signals-frontend/raw/${SCHEMA_DEFINITION_GIT_REF}/internals/schemas/${CONFIGURATION_SCHEMA_FILE} \
		-O ${SCHEMA_DEFINITION_TEMP_FILE}
endif

validate-all-schemas: download-schema ## validate all domain JSON schema configuration files. Usage `make SCHEMA_DEFINITION_GIT_REF=master validate-all-schemas`
	@$(foreach domain,$(DOMAINS),\
		$(foreach schema_environment,$(CONFIGURATION_SCHEMA_ENVIRONMENTS),\
			$(call validate_schema,$(SCHEMA_DEFINITION_FILE),$(domain),$(schema_environment))\
		)\
	)

validate-schema: download-schema ## validate single domain schema configuration file. Usage `make DOMAIN=amsterdam ENVIRONMENT=development SCHEMA_DEFINITION_GIT_REF=master validate-schema`
	$(call validate_schema,$(SCHEMA_DEFINITION_TEMP_FILE),$(DOMAIN),$(SCHEMA_ENVIRONMENT))
