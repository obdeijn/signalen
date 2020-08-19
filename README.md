# Signalen mono repo

## Makefile

The Makefile in this repository is used to support Jenkins and running local Docker environments with `docker-compose`, besides that it also does schema validation.

Type `make` to list available targets (commands).

```bash
$ make

signalen Makefile help (348990d1687c236951c98666e21247836fa40b43)

build                          build Docker Compose images
download-schema                download JSON validation schema definition to /tmp
help                           show this help screen
images                         list Docker Compose images
info                           dump Makefile variables to screen
list-domains                   list frontend domains
logs                           tail Docker Compose container logs
rebuild                        rebuild Docker Compose. Usage: `make DOMAIN=amsterdam rebuild
restart                        restart Docker Compose
shell                          execute command on container. Usage `make ENVIRONMENT=development shell
start                          start single Docker Compose service. Usage `make DOMAIN=amsterdam start
status                         show Docker Compose process list
stop                           stop Docker Compose
validate-all-schemas           validate all domain JSON schema configuration files. Usage `make SCHEMA_DEFINITION_GIT_REF=master validate-all-schemas
validate-local-schema          validate configuration schema in current branch. Usage `make SIGNALS_FRONTEND_PATH=../signals-frontend DOMAIN=amsterdam ENVIRONMENT=development validate-local-schema
validate-schema                validate single domain schema configuration file. Usage `make DOMAIN=amsterdam ENVIRONMENT=development SCHEMA_DEFINITION_GIT_REF=master validate-schema
```
