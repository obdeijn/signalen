def call(String dockerBuildArgRegistryHost, String gitRef, String dockerBuildArgImageTag = 'latest', String buildPath = 'signals-frontend' ) {
  log.console("building signals-frontend @ ${gitRef}")
  log.console("${env.DOCKER_REGISTRY_HOST} ${env.DOCKER_REGISTRY_AUTH}")
  log.console("dockerBuildArgRegistryHost:, ${dockerBuildArgRegistryHost}")
  log.console("dockerBuildArgImageTag:, ${dockerBuildArgImageTag}")

  try {
    docker.withRegistry(env.DOCKER_REGISTRY_HOST, env.DOCKER_REGISTRY_AUTH) {
      def image = docker.build(
        "ois/signalsfrontend:${env.BUILD_NUMBER}", [
          '--shm-size 1G',
          "--build-arg DOCKER_REGISTRY=${dockerBuildArgRegistryHost} ",
          "--build-arg DOCKER_IMAGE_TAG=${dockerBuildArgRegistryHost} ",
          "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER}",
          "--build-arg GIT_BRANCH=${gitRef}",
          "${env.WORKSPACE}/${buildPath}"
        ].join(' ')
      )

      signalen.pushImageToDockerRegistry(image)
      signalen.pushImageToDockerRegistry(image, dockerBuildArgImageTag)
    }
  } catch (Throwable throwable) {
    log.error("build of Docker image signals-frontend ${gitRef} failed")
    throw throwable
  }
}
