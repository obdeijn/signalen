FROM docker-registry.data.amsterdam.nl/ois/signalsfrontend:latest

ARG BUILD_ENV=prod

COPY base.config.json /app.base.json
COPY ${BUILD_ENV}.config.json /app.json

# merge assets folder from this repository with assets folder from signals-frontend
COPY ./assets/. /usr/share/nginx/html/assets/
