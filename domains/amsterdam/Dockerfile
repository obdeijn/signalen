ARG DOCKER_REGISTRY=docker-registry.data.amsterdam.nl
FROM ${DOCKER_REGISTRY}/ois/signalsfrontend:latest

ARG BUILD_ENV=prod

COPY ${BUILD_ENV}.config.json /app.json
RUN mv /app.amsterdam.json /app.base.json
