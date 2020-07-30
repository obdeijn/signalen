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

BASE_IMAGE=signalsfrontend
BUILD_PATH=../signals-frontend

FRONTEND_IMAGE='${DOCKER_REGISTRY}/${BASE_IMAGE}:${IMAGE_TAG}'
WEESP_IMAGE='${DOCKER_REGISTRY}/signals-weesp_web-container:${IMAGE_TAG}'
AMSTERDAM_IMAGE='${DOCKER_REGISTRY}/signals-amsterdam-container:${IMAGE_TAG}'

.DEFAULT_GOAL := help

.PHONY: help start reset stop build
dc = docker-compose

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

rebuild: stop build start status       ## rebuild Docker containers

start:                                 ## start Docker containers
	$(dc) -f $(COMPOSE_FILE) up -d --remove-orphans

stop:                                  ## stop all running Docker containers
	$(dc) -f $(COMPOSE_FILE) kill
	$(dc) -f $(COMPOSE_FILE) rm -v --force

status:                                ## show Docker processes
	$(dc) -f $(COMPOSE_FILE) ps

restart: stop start status             ## restart Docker containers

build:                                 ## build Docker images
	$(dc) -f $(COMPOSE_FILE) build --parallel

download-schema:                       ## download the JSON validation schema to /tmp
	rm -f /tmp/environment.conf.schema.json
	wget -q https://github.com/Amsterdam/signals-frontend/raw/develop/internals/schemas/environment.conf.schema.json -O /tmp/environment.conf.schema.json

validate-schemas: download-schema      ## validate JSON schemas
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d domains/amsterdam/acc.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d domains/amsterdam/prod.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d domains/amsterdamsebos/acc.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d domains/amsterdamsebos/prod.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d domains/weesp/acc.config.json
	npx ajv-cli validate -s /tmp/environment.conf.schema.json -d domains/weesp/prod.config.json

build-base:                            ## build and tag the base signals container. Usage `make build-base BUILD_PATH=../signals-frontend`
	docker build -t $(BASE_IMAGE) $(BUILD_PATH)
	docker tag $(BASE_IMAGE):latest $(FRONTEND_IMAGE)

clean:
	$(dc) down -v --remove-orphans

amsterdam:                             ## starts signals amsterdam on port 3001
	$(dc) up --build amsterdam

amsterdamsebos:                        ## starts signals amsterdamsebos on port 3001
	$(dc) up --build amsterdamsebos

weesp:                                 ## starts signals weesp on port 3001
	$(dc) up --build weesp

login-amsterdam:                       ## execute a command on the amsterdam container
	$(dc) exec amsterdam sh

login-amsterdamsebos:                  ## execute a command on the amsterdamsebos container
	$(dc) exec amsterdam sh

login-weesp:                           ## execute a command on the weesp container
	$(dc) exec weesp sh

