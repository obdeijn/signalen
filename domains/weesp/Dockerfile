ARG DOCKER_REGISTRY=docker-registry.data.amsterdam.nl
ARG DOCKER_IMAGE_TAG=latest

FROM ${DOCKER_REGISTRY}/ois/signalsfrontend:${DOCKER_IMAGE_TAG}

ARG BUILD_ENV=prod

COPY ${BUILD_ENV}.config.json /app.json
RUN mv /app.amsterdam.json /app.base.json

# merge assets folder from this repository with assets folder from signals-frontend
COPY ./assets/. /usr/share/nginx/html/assets/
