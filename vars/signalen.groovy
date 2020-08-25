#!/usr/bin/env groovy

def getDomains() {
  log.info('getting available domains')

  dir("${env.WORKSPACE}/signalen") {
    return sh(returnStdout: true, script: 'make list-domains').split()
  }
}

def logBuildInformation(String[] domains, String dockerBuildArgRegistryHost) {
  log.console("starting build ${env.BUILD_DISPLAY_NAME}")

  log.separator()

  log.highlight(
    [
      "BUILD_TAG = ${env.BUILD_TAG}",
      "DOMAINS = ${domains}",
      "DOCKER_REGISTRY_HOST = ${env.DOCKER_REGISTRY_HOST}",
      "DOCKER_BUILD_ARG_REGISTRY_HOST = ${dockerBuildArgRegistryHost}"
    ].join('\n')
  )
  log.highlight(env)

  params.each {parameterName, parameterValue -> if (!parameterName.startsWith('_'))
    log.highlight("${parameterName}=${parameterValue}")
  }

  log.separator()
}

def _buildAndPushDockerImage(
  String dockerBuildArgRegistryHost,
  String environment,
  String domain,
  String repositoryRefs
) {
  log.console("building ${domain} ${environment} domain image: ${repositoryRefs}")
  log.console("dockerBuildArgRegistryHost:, ${dockerBuildArgRegistryHost}")

  def environmentAbbreviations = [acceptance: 'acc', production: 'prod']

  try {
    docker.withRegistry(env.DOCKER_REGISTRY_HOST, env.DOCKER_REGISTRY_AUTH) {
      def image = docker.build(
        "ois/signals-${domain}:${env.BUILD_NUMBER}", [
          "--build-arg DOCKER_REGISTRY=${dockerBuildArgRegistryHost} ",
          '--shm-size 1G ',
          "--build-arg BUILD_ENV=${environmentAbbreviations[environment]} ",
          "${env.WORKSPACE}/signalen/domains/${domain}"
        ].join(' ')
      )

      image.push()
      image.push(environment)
    }
  } catch (Throwable throwable) {
    log.error("build of signals-${domain} Docker image failed ${repositoryRefs}")
    // slack.error("build of signals-${domain} ${releaseDisplayName} Docker image failed")
    throw throwable
  }
}

def pushImageToDockerRegistry(def image) {
  log.console('pushing image to Docker Registry')
  image.push()
}

def pushImageToDockerRegistry(def image, String tag) {
  log.console("pushing image to Docker Registry with tag: ${tag}")
  image.push('latest')
}

def buildAndPushSignalsFrontendDockerImage(String signalsFrontendGitRef, String signalsFrontendPath = '') {
  log.console("building signals-frontend @ ${signalsFrontendGitRef}")
  log.console("${env.DOCKER_REGISTRY_HOST} ${env.DOCKER_REGISTRY_AUTH}")

  try {
    docker.withRegistry(env.DOCKER_REGISTRY_HOST, env.DOCKER_REGISTRY_AUTH) {
      def image = docker.build(
        "ois/signalsfrontend:${env.BUILD_NUMBER}", [
          '--shm-size 1G',
          "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER}",
          "--build-arg GIT_BRANCH=${signalsFrontendGitRef}",
          "${env.WORKSPACE}/${signalsFrontendPath}"
        ].join(' ')
      )

      pushImageToDockerRegistry(image)
      pushImageToDockerRegistry(image, 'latest')

    }
  } catch (Throwable throwable) {
    log.error("build of Docker image signals-frontend ${signalsFrontendGitRef} failed")
    throw throwable
  }
}

def buildAndPushDockerDomainImages(
  String dockerBuildArgRegistryHost,
  String environment,
  def domains,
  String repositoryRefs
) {
  def steps = [:]

  domains.each {domain -> steps["BUILD_IMAGE_${domain}_${environment}".toUpperCase()] = {
    _buildAndPushDockerImage dockerBuildArgRegistryHost, environment, domain, repositoryRefs
  }}

  parallel steps
}

def deployDomain(String dockerImageTag, String domain, String repositoryRefs) {
  def appName = "app_signals-${domain}"

  log.info("deploying domain ${domain} to ${dockerImageTag} as ${appName}")

  try {
    build job: 'Subtask_Openstack_Playbook',
      parameters: [
        [$class: 'StringParameterValue', name: 'INVENTORY', value: dockerImageTag],
        [$class: 'StringParameterValue', name: 'PLAYBOOK', value: 'deploy.yml'],
        [$class: 'StringParameterValue', name: 'PLAYBOOKPARAMS', value: "-e cmdb_id=${appName}"],
      ]
  } catch (Throwable throwable) {
    log.error("deployment of signals-${domain} ${repositoryRefs} failed")
    throw throwable
  }
}

def deployDomains(String environment, String[] domains, String gitRefs) {
  log.console("deploying ${domains.join(', ')} to environment ${environment}")

  def steps = [:]

  domains.each {domain -> steps["DEPLOY_DOMAIN_${domain}_${environment}".toUpperCase()] = {
    deployDomain environment, domain, gitRefs
  }}

  parallel steps
}

def validateSchema(String environment, String domain, String signalsFrontendPath, String releaseRefs) {
  log.info("validating schema: ${domain} ${environment} ${releaseRefs}")

  nodejs(nodeJSInstallationName: 'node12') {
    dir("${env.WORKSPACE}/signalen") {
      try {
        sh "make validate-local-schema DOMAIN=${domain} ENVIRONMENT=${environment} SIGNALS_FRONTEND_PATH=${signalsFrontendPath}"
      } catch (Throwable throwable) {
        log.error("schema validation failed: ${domain} ${environment}")
        throw throwable
      }
    }
  }
}

def validateDomainSchemas(String environment, def domains, String signalsFrontendPath, String releaseRefs) {
  log.console("Validate ${environment} schema's: ${domains.join(', ')}")

  def steps = [:]

  domains.each {domain -> steps["VALIDATE_SCHEMA_${domain}_${environment}".toUpperCase()] = {
    validateSchema environment, domain, signalsFrontendPath, releaseRefs
  }}

  parallel steps
}
