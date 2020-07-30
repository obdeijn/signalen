# Signalen mono repo



## Build and run different configurations in docker-compose


- Create the docker image of the signals-frontend. Use the environment var BUILD_PATH to override the default path of
  the signals-frontend project (../signals-frontend)

```bash
make build-base # BUILD_PATH=../signals_frontend
```

- Validate the json schemas `make validate-schemas`
- Spin up one of the configurations. Each of them run on localhost:3001

```bash
make amsterdam
make amsterdamsebos
make weesp
```

