#!/usr/bin/env groovy

def initializePipeline(banner, pipelineParams, params) {
  // Set environment variables used by Jenkins external lib
  env.SLACK_NOTIFICATIONS_CHANNEL = pipelineParams.SLACK_NOTIFICATIONS_CHANNEL
  env.DOCKER_REGISTRY_AUTH = pipelineParams.DOCKER_REGISTRY_AUTH
  env.JENKINS_GITHUB_CREDENTIALS_ID = pipelineParams.JENKINS_GITHUB_CREDENTIALS_ID
  env.JENKINS_TARGET = pipelineParams.JENKINS_TARGET

  ansiColor('xterm') {
    log.highlight(banner)

    log.info("🦄 ${env.RELEASE_DESCRIPTION} 🦄")

    log.info('pipeline parameters:')
    log.highlight(pipelineParams)

    log.info('parameters:')
    log.highlight(params)

    log.info('🐵 starting declarative pipeline 🐵')
  }

  // log.highlight(env)
  // params.each {parameterName, parameterValue -> if (!parameterName.startsWith('_'))
  //   log.highlight("${parameterName}=${parameterValue}")
  // }
}

def pushImageToDockerRegistry(def image) {
  log.console('pushing image to Docker Registry')
  image.push()
}

def pushImageToDockerRegistry(def image, String tag) {
  log.console("pushing image to Docker Registry with tag: ${tag}")
  image.push(tag)
}
