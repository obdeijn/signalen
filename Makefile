FRONTEND_NAME=signals-frontend
IMAGE_TAG=latest
GIT_BRANCH := $(shell git branch | grep \* | cut -d ' ' -f2)
ENV=''

ifeq ($(ENV), '')
COMPOSE_FILE=docker-compose.yml
else
COMPOSE_FILE=docker-compose.${ENV}.yml
endif

DOCKER_REGISTRY=docker-registry.data.amsterdam.nl/ois

FRONTEND_IMAGE='${DOCKER_REGISTRY}/signalsfrontend:${IMAGE_TAG}'
WEESP_IMAGE='${DOCKER_REGISTRY}/signals-weesp_web-container:${IMAGE_TAG}'
AMSTERDAM_IMAGE='${DOCKER_REGISTRY}/signals-amsterdam-container:${IMAGE_TAG}'

.DEFAULT_GOAL := help

.PHONY: help start reset stop build

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

rebuild: stop build start status ## rebuild Docker containers

start: # start Docker containers
	docker-compose -f $(COMPOSE_FILE) up -d --remove-orphans

stop: ## stop all running Docker containers
	docker-compose -f $(COMPOSE_FILE) kill
	docker-compose -f $(COMPOSE_FILE) rm -v --force

status: ## show Docker processes
	docker-compose -f $(COMPOSE_FILE) ps

restart: stop start status ## restart Docker containers

login-weesp: ## execute a command on the signals-frontend container
	docker-compose exec weesp sh

login-amsterdam: ## execute a command on the amsterdam container
	docker-compose exec frontend sh

build: ## build Docker images
	docker-compose -f $(COMPOSE_FILE) build --parallel

download-schema: ## download the JSON validation schema to /tmp
	rm -f /tmp/environment.conf.schema.json
	wget -q https://github.com/Amsterdam/signals-frontend/raw/develop/internals/schemas/environment.conf.schema.json -O /tmp/environment.conf.schema.json

validate-schemas: download-schema validate-acc validate-prod ## validate JSON schemas
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d acc.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d prod.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d environment.conf.json


