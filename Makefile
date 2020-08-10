# set shell
@SHELL := /bin/bash

# constants
ENVIRONMENTS = acceptance development production
DOCKER_COMPOSE_FILE = docker-compose.yml
BASE_IMAGE = signalsfrontend
CONFIGURATION_SCHEMA_FILE = environment.conf.schema.json

# globals which could be overriden on the CLI
BUILD_PATH ?= ../signals-frontend
ENVIRONMENT ?= acceptance
REPOSITORY_OWNER ?= Amsterdam
FRONTEND_REPOSITORY_NAME ?= signals-frontend
DOMAIN ?= amsterdam
DOCKER_REGISTRY ?= docker-registry.data.amsterdam.nl/ois
IMAGE_TAG ?= latest
FRONTEND_GIT_REF ?= master

# Jenkins development
JENKINS_HOST=localhost
JENKINS_PORT=8090

# images
@FRONTEND_IMAGE = ${DOCKER_REGISTRY}/${BASE_IMAGE}:${IMAGE_TAG}
@WEESP_IMAGE = ${DOCKER_REGISTRY}/signals-weesp_web-container:${IMAGE_TAG}
@AMSTERDAM_IMAGE = ${DOCKER_REGISTRY}/signals-amsterdam-container:${IMAGE_TAG}

# dynamic globals
DOMAINS = $(shell ls -d domains/* | cut -d '/' -f2)
SCHEMA_TEMP_FILE = /tmp/signalen-configuration-schema.$(shell git branch -v | grep \* | cut -d ' ' -f2,3 --output-delimiter='_').json
SCHEMA_FILE := ${BUILD_PATH}/internals/schemas/${CONFIGURATION_SCHEMA_FILE}

.DEFAULT_GOAL := help

.PHONY: help start reset stop build

help: ## show this help page
	@echo -e "Amsterdam/signalen Makefile help"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

info: ## dump various variables to screen
	@echo -----------------
	@echo DOMAINS=${DOMAINS}
	@echo ENVIRONMENTS=${ENVIRONMENTS}
	@echo SCHEMA_TEMP_FILE=${SCHEMA_TEMP_FILE}
	@echo -----------------
	@echo
	@echo arguments
	@echo ---------
	@echo
	@echo BUILD_PATH=${BUILD_PATH}
	@echo ENVIRONMENT=${ENVIRONMENT}
	@echo SCHEMA_TEMP_FILE=${SCHEMA_TEMP_FILE}
	@echo REPOSITORY_OWNER=${REPOSITORY_OWNER}
	@echo FRONTEND_REPOSITORY_NAME=${FRONTEND_REPOSITORY_NAME}
	@echo FRONTEND_GIT_REF=${FRONTEND_GIT_REF}
	@echo DOMAIN=${DOMAIN}
	@echo DOCKER_REGISTRY=${DOCKER_REGISTRY}

rebuild: stop build start status ## rebuild Docker containers

list-domains: ## list domains
	@echo ${DOMAINS}

status: ## show Docker Compose process list
	docker-compose ps

start: ## start Docker Compose
	docker-compose up --remove-orphans
	@echo
	@docker-compose ps

start-domain: ## start single Docker Compose. Usage `make start DOMAIN=amsterdam`
	docker-compose up --remove-orphans ${DOMAIN}
	@echo
	@docker-compose ps

stop: ## stop Docker Compose
	docker-compose down -v --remove-orphans

logs: ## tail Docker Compose container logs
	docker-compose logs --tail=100 -f ${DOMAIN}

restart: stop start status ## restart Docker Compose

build: ## build Docker Compose images
	docker-compose build --parallel

validate-schema: ## validate JSON schema with local definition. Usage `make BUILD_PATH=../signals-frontend DOMAIN=amsterdam ENVIRONMENT=acceptance validate-schema-local`
	@if [[ ${ENVIRONMENT} == "acceptance" ]]; then \
		npx ajv-cli validate -s ${SCHEMA_FILE} -d domains/${DOMAIN}/acc.config.json; \
	elif [[ ${ENVIRONMENT} == "production" ]]; then \
		npx ajv-cli validate -s ${SCHEMA_FILE} -d domains/${DOMAIN}/prod.config.json; \
	else \
		echo "ENVIRONMENT is invalid: ${environment} (valid values: [acceptance, production])"; \
	fi

get-schema: ## download JSON validation schema to /tmp
	wget --no-clobber --quiet https://github.com/Amsterdam/signals-frontend/raw/${FRONTEND_GIT_REF}/internals/schemas/${CONFIGURATION_SCHEMA_FILE} -O ${SCHEMA_TEMP_FILE} | true
	[[ -f ${SCHEMA_TEMP_FILE} ]]

validate-remote-schema: get-schema ## validate JSON schema. Usage `make DOMAIN=amsterdam ENVIRONMENT=acceptance FRONTEND_GIT_REF=master validate-schema`
	npx ajv-cli validate -s ${SCHEMA_TEMP_FILE} -d domains/${DOMAIN}/${ENVIRONMENT_SHORT}.config.json

validate-remote-schemas: get-schema ## validate JSON schemas
	@for domain in ${DOMAINS}; do \
		for environment in acc prod; do \
			npx ajv-cli validate -s ${SCHEMA_TEMP_FILE} -d domains/$${domain}/$${environment}.config.json; \
		done \
	done

build-base: ## build and tag signals-frontend container. Usage `make build-base BUILD_PATH=../signals-frontend`
	docker build -t $(BASE_IMAGE) $(BUILD_PATH)
	docker tag $(BASE_IMAGE):latest $(FRONTEND_IMAGE)

shell: ## execute command on container. Usage `make shell ${ENVIRONMENT}`
	docker-compose exec ${DOMAIN} sh
