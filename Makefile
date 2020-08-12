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

help: ## show this help screen
	@echo -e "Help (${SIGNALEN_GIT_REF})"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

info: ## dump various variables to screen
	@echo -----------------
	@echo DOMAINS=${DOMAINS}
	@echo ENVIRONMENTS=${ENVIRONMENTS}
	@echo SCHEMA_DEFINITION_TEMP_FILE=${SCHEMA_DEFINITION_TEMP_FILE}
	@echo -----------------
	@echo
	@echo arguments
	@echo ---------
	@echo
	@echo BUILD_PATH=${BUILD_PATH}
	@echo ENVIRONMENT=${ENVIRONMENT}
	@echo SCHEMA_DEFINITION_TEMP_FILE=${SCHEMA_DEFINITION_TEMP_FILE}
	@echo REPOSITORY_OWNER=${REPOSITORY_OWNER}
	@echo FRONTEND_REPOSITORY_NAME=${FRONTEND_REPOSITORY_NAME}
	@echo SCHEMA_DEFINITION_GIT_REF=${SCHEMA_DEFINITION_GIT_REF}
	@echo DOMAIN=${DOMAIN}
	@echo DOCKER_REGISTRY=${DOCKER_REGISTRY}

# images
# BASE_IMAGE := signalsfrontend
# FRONTEND_IMAGE := ${DOCKER_REGISTRY}/${BASE_IMAGE}:${IMAGE_TAG}
# WEESP_IMAGE := ${DOCKER_REGISTRY}/signals-weesp_web-container:${IMAGE_TAG}

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

docker-list: ## list docker processes, containers, images, volumes and networks
	@docker ps
	@echo
	@docker container ls --all
	@echo
	@docker images --all
	@echo
	@docker volume ls
	@echo
	@docker network ls

docker-prune: ## remove stopped docker containers, unused volumes and images and networks
	docker system prune --all --volumes

docker-registry-garbage-collector-dry-run: ## run Docker garbage collector
	docker exec registry bin/registry garbage-collect --dry-run=true /etc/docker/registry/config.yml

docker-registry-garbage-collector: ## run Docker garbage collector
	docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml

docker-registry-shell: ## execute command on container. Usage `make shell ${ENVIRONMENT}`
	docker exec -it registry sh

docker-registry-list-repositories: ## list local docker registry categories
ifneq (, $(shell which jq))
	@wget -q http://localhost:5000/v2/_catalog -O - | jq '.repositories'
else
	@wget -q http://localhost:5000/v2/_catalog -O -
endif

docker-registry-list-tags: ## list local docker registry categories
	wget http://localhost:5000/v2/ois/signals-amsterdam/tags/list -q -O - | jq

docker-registry-list-tag-manifest: ## list local docker registry categories
	# wget -q --header="Accept: application/vnd.docker.distribution.manifest.v2+json" http://localhost:5000/v2/ois/signals-amsterdam/manifests/acceptance -O - | grep Docker-Content-Digest | cut -d' ' -f3
	curl -v --silent -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -X GET http://localhost:5000/v2/ois/signals-amsterdam/manifests/acceptance 2>&1 | grep Docker-Content-Digest | cut -d' ' -f3

