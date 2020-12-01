FROM docker-registry.data.amsterdam.nl/ois/signalsfrontend:latest

ARG BUILD_ENV=prod

COPY ${BUILD_ENV}.config.json /app.json
RUN mv /app.amsterdam.json /app.base.json