#!/usr/bin/env groovy

// -- Options ---------------------------------------------------------------------------------------------------------

DEVELOPMENT = false

SIGNALEN_REPOSITORY = 'Amsterdam/signalen'
SIGNALS_FRONTEND_REPOSITORY = 'Amsterdam/signals-frontend'
JENKINS_GITHUB_CREDENTIALS_ID = '5b5e63e2-8db7-48c7-8e14-41cbd10eeb4a'
DOCKER_BUILD_ARG_REGISTRY_HOST = DOCKER_REGISTRY_HOST
SLACK_NOTIFICATIONS_CHANNEL = '#jpoppe'
// SLACK_NOTIFICATIONS_CHANNEL = '#ci-channel'

ENABLE_SLACK_NOTIFICATIONS = !DEVELOPMENT
JENKINS_NODE = DEVELOPMENT ? 'master' : 'BS16 || BS17'
DOCKER_REGISTRY_AUTH = DEVELOPMENT ? null : 'docker_registry_auth'

INFO_HEADER = '''

  ___(_) __ _ _ __   __ _| | ___ _ __    _ __ (_)_ __   ___| (_)_ __   ___
 / __| |/ _` | '_ \\ / _` | |/ _ \\ '_ \\  | '_ \\| | '_ \\ / _ \\ | | '_ \\ / _ \\
 \\__ \\ | (_| | | | | (_| | |  __/ | | | | |_) | | |_) |  __/ | | | | |  __/
 |___/_|\\__, |_| |_|\\__,_|_|\\___|_| |_| | .__/|_| .__/ \\___|_|_|_| |_|\\___|
        |___/                           |_|     |_|
'''

// -- Domains ---------------------------------------------------------------------------------------------------------

DOMAINS = []

// -- Workspaces ------------------------------------------------------------------------------------------------------

WORKSPACES = [
  signalen: [
    currentGitRef: '',
    gitRefParamName: 'SIGNALEN_TAG',
    name: 'signalen',
    repository: SIGNALEN_REPOSITORY,
    repositoryUrl: "https://github.com/${SIGNALEN_REPOSITORY}.git"
  ],
  signalsFrontend: [
    currentGitRef: '',
    gitRefParamName: 'SIGNALS_FRONTEND_TAG',
    name: 'signals-frontend',
    repository: SIGNALS_FRONTEND_REPOSITORY,
    repositoryUrl: "https://github.com/${SIGNALS_FRONTEND_REPOSITORY}.git"
  ],
]

// -- Section header styles -------------------------------------------------------------------------------------------

separatorStyle = '''
  border: 0;
  border-bottom: 0;
  background: #999;
'''

sectionHeaderStyle = '''
  color: white;
  background: hotpink;
  font-family: Roboto, sans-serif !important;
  font-weight: 700;
  font-size: 1.3em;
  padding: 5px;
  margin-top: 10px;
  margin-bottom: 20px;
  text-align: left;
'''

// -- Colorized logging -----------------------------------------------------------------------------------------------

enum Colors {
  BLUE('\u001B[34m'), GREEN('\u001B[32m'), RED('\u001B[31m'), CYAN('\u001B[36m'), PURPLE('\u001B[35m')
  public String xterm_code
  public Colors(String xterm_code) { this.xterm_code = xterm_code }
}
def log(message, color, tag) { echo(String.format("%s%s %s%s", color.xterm_code, tag, message, '\u001B[0m')) }
def log(message, color) { echo(String.format("%s%s%s", color.xterm_code, message, '\u001B[0m')) }
def log(message) { log(message, Colors.PURPLE) }
def info(message) { log(message, Colors.PURPLE, '[INFO]') }
def error(message) { log(message, Colors.RED, '[ERROR]') }
def warn(message) { log(message, Colors.GREEN, '[WARNING]') }

// -- Helper functions ------------------------------------------------------------------------------------------------

def tryStep(String message, Closure block, Closure tearDown = null) {
  try {
    block()
  } catch (Throwable throwable) {
    if (ENABLE_SLACK_NOTIFICATIONS) {
      slackSend message: "${env.JOB_NAME}: ${message} failure ${env.BUILD_URL}",
        channel: SLACK_NOTIFICATIONS_CHANNEL,
        color: 'danger'
    } else {
      warn("slack notifications are disabled, message: ${message}")
    }

    throw throwable
  } finally {
    if (tearDown) tearDown()
  }
}

def checkoutWorkspace(workspace, String refName = 'origin/master') {
  log("[${workspace.name}] checkout Git ref: ${refName}")

  checkout([
    $class: 'GitSCM',
    branches: [[name: refName]],
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: workspace.name]],
    userRemoteConfigs: [[credentialsId: JENKINS_GITHUB_CREDENTIALS_ID, url: workspace.repositoryUrl]]
  ])

  dir("${env.WORKSPACE}/${workspace.name}") {
    def lastGitCommitMessage = sh(returnStdout: true, script: 'git show --oneline --date=relative -s')
    log("[${workspace.name}] last Git commit message: ${lastGitCommitMessage}")
  }
}

def buildAndPushDockerImage(String domain, String environment) {
  def environmentAbbreviations = [acceptance: 'acc', production: 'prod']

  docker.withRegistry(DOCKER_REGISTRY_HOST, DOCKER_REGISTRY_AUTH) {
    def image = docker.build(
      "ois/signals-${domain}:${env.BUILD_NUMBER}", [
        "--build-arg DOCKER_REGISTRY=${DOCKER_BUILD_ARG_REGISTRY_HOST} ",
        '--shm-size 1G ',
        "--build-arg BUILD_ENV=${environmentAbbreviations[environment]} ",
        "${env.WORKSPACE}/signalen/domains/${domain}"
      ].join(' ')
    )

    image.push()
    image.push(environment)
  }
}

def deployDomain(String domain, String tag) {
  def appName = "app_signals-${domain}"

  info("deploying domain: ${params.ENVIRONMENT} ${domain} ${tag} as ${appName}")

  if (params.ENVIRONMENT == 'acceptance') {
    // build job: 'Subtask_Openstack_Playbook',
    //   parameters: [
    //     [$class: 'StringParameterValue', name: 'INVENTORY', value: tag],
    //     [$class: 'StringParameterValue', name: 'PLAYBOOK', value: 'deploy.yml'],
    //     [$class: 'StringParameterValue', name: 'PLAYBOOKPARAMS', value: "-e cmdb_id=${appName}"],
    //   ]
  } else {
    warn("safety first - only 'acceptance' environmnet is allowed to deploy until pipeline is in production")
  }
}

def validateSchema(String domain, String environment) {
  info("validating schema: ${domain} ${environment} ${SIGNALEN_TAG}+${SIGNALS_FRONTEND_TAG}")

  nodejs(nodeJSInstallationName: 'node12') {
    dir("${env.WORKSPACE}/signalen") { sh "make validate-local-schema DOMAIN=${domain} ENVIRONMENT=${environment}" }
  }
}

// -- Jenkins pipeline pre configuration ------------------------------------------------------------------------------

def prepareJenkinsPipeline() {
  slackSend message: "${env.JOB_NAME}: ${message} failure ${env.BUILD_URL}",
    channel: SLACK_NOTIFICATIONS_CHANNEL,
    color: 'danger'

  log("Start preparing job ${env.BUILD_DISPLAY_NAME}", Colors.CYAN)

  if (params.CLEAN_WORKSPACE) {
    info('cleaning workspace folders')
    cleanWs()
  }

  WORKSPACES.each { _workspaceName, workspace -> checkoutWorkspace(workspace) }
  DOMAINS = dir("${env.WORKSPACE}/signalen") { sh(returnStdout: true, script: 'make list-domains').split() }

  properties([
    durabilityHint('PERFORMANCE_OPTIMIZED'),
    parameters([
      [
        $class: 'ParameterSeparatorDefinition',
        name: '_BUILD_PARAMETERS_HEADER',
        sectionHeader: 'Build parameters',
        separatorStyle: separatorStyle,
        sectionHeaderStyle: sectionHeaderStyle
      ],
      choice(description: 'deploy environment', name: 'ENVIRONMENT', choices: ['acceptance', 'production']),
      gitParameter(
        name: 'SIGNALS_FRONTEND_TAG',
        description: 'signals-frontend Git repository tag',
        useRepository: 'signals-frontend',
        branch: '',
        tagFilter: 'v[0-9]*.[0-9]*.[0-9]*',
        defaultValue: 'origin/master',
        branchFilter: '!*',
        quickFilterEnabled: false,
        selectedValue: 'TOP',
        sortMode: 'DESCENDING_SMART',
        type: 'PT_BRANCH_TAG'
      ),
      gitParameter(
        name: 'SIGNALEN_TAG',
        description: 'signalen Git repository tag',
        useRepository: 'signalen',
        branch: '',
        tagFilter: 'v[0-9]*.[0-9]*.[0-9]*',
        defaultValue: 'origin/master',
        branchFilter: '!*',
        quickFilterEnabled: false,
        selectedValue: 'TOP',
        sortMode: 'DESCENDING_SMART',
        type: 'PT_BRANCH_TAG'
      ),

      [
        $class: 'ParameterSeparatorDefinition',
        name: '_ADDITIONAL_BUILD_PARAMETERS_HEADER',
        sectionHeader: 'Additional build parameters',
        separatorStyle: separatorStyle,
        sectionHeaderStyle: sectionHeaderStyle
      ],
      booleanParam(
        name: 'CLEAN_WORKSPACE',
        description: 'clean workspace before the building process starts',
        defaultValue: false
      ),
      choice(
        description: 'build and deploy a single domain instead of all domains',
        name: 'DOMAIN',
        choices: ['', 'weesp', 'amsterdam', 'amsterdamsebos']
      ),

      [
        $class: 'ParameterSeparatorDefinition',
        name: '_DEBUG_AND_MAINTENANCE_PARAMETERS_HEADER',
        sectionHeader: 'Debug and maintenance parameters',
        separatorStyle: separatorStyle,
        sectionHeaderStyle: sectionHeaderStyle
      ],
      booleanParam(name: 'DRY_RUN', description: 'skip building images and deployments', defaultValue: false),
      booleanParam(name: 'DISABLE_PARALLEL_BUILDS', description: 'disable parallel builds', defaultValue: false),
      booleanParam(
        name: 'DISABLE_PARALLEL_DEPLOYMENTS',
        description: 'disable parallel deployments',
        defaultValue: false
      )
    ])
  ])

  log("Finished preparing job ${env.BUILD_DISPLAY_NAME}")
}

// -- Jenkins pipeline ------------------------------------------------------------------------------------------------

ansiColor('xterm') {
  node(JENKINS_NODE) {
    log(INFO_HEADER, Colors.CYAN)

    prepareJenkinsPipeline()

    if (params.DOMAIN) DOMAINS = [params.DOMAIN]

    log("starting build ${env.BUILD_DISPLAY_NAME}")
    log('***********************************************')

    log(
      [
        "BUILD_TAG = ${env.BUILD_TAG}",
        "DOMAINS = ${DOMAINS}",
        "DOCKER_REGISTRY_HOST = ${DOCKER_REGISTRY_HOST}",
        "DOCKER_BUILD_ARG_REGISTRY_HOST = ${DOCKER_BUILD_ARG_REGISTRY_HOST}"
      ].join('\n'),
      Colors.CYAN
    )

    params.each {parameterName, parameterValue -> if (!parameterName.startsWith('_'))
      log("${parameterName}=${parameterValue}", Colors.CYAN)
    }

    log('***********************************************')

    stage('Prepare workspaces') {
      log("[STEP] Prepare workspaces: ${WORKSPACES.keySet().join(', ')}")

      tryStep "PREPARE_WORKSPACES", {
        WORKSPACES.each { _workspaceName, workspace ->
          workspace.currentGitRef = params[workspace.gitRefParamName]
          checkoutWorkspace(workspace, workspace.currentGitRef)
        }
      }
    }

    stage('Validate schema\'s') {
      log("[STEP] Validate ${params.ENVIRONMENT} schema's: ${DOMAINS.join(', ')}")

      tryStep "VALIDATE_SCHEMAS", {
        def steps = [:]

        DOMAINS.each {domain -> steps["VALIDATE_SCHEMA_${domain}_${params.ENVIRONMENT}".toUpperCase()] = {
          validateSchema domain, params.ENVIRONMENT }
        }

        parallel steps
      }
    }

    stage('Build signals-frontend image') {
      def workspace = WORKSPACES.signalsFrontend

      log("[STEP] build signals-frontend ${params.ENVIRONMENT} image: ${workspace.currentGitRef}")

      tryStep 'BUILD_SIGNALS_FRONTEND_IMAGE', {
        docker.withRegistry(DOCKER_REGISTRY_HOST, DOCKER_REGISTRY_AUTH) {
          def image = docker.build(
            "ois/signalsfrontend:${env.BUILD_NUMBER}", [
              '--shm-size 1G',
              "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER}",
              "--build-arg GIT_BRANCH=${params.SIGNALS_FRONTEND_TAG}",
              "${env.WORKSPACE}/signals-frontend"
            ].join(' ')
          )

          image.push()
          image.push('latest')
        }
      }
    }

    stage("Build domain images") {
      tryStep 'BUILD_DOMAIN_IMAGES', {
        info('disabled for testing')
        // if (params.DISABLE_PARALLEL_BUILDS) {
        //   DOMAINS.each { domain -> buildAndPushDockerImage(domain, params.ENVIRONMENT) }
        //   return
        // }

        // def steps = [:]

        // DOMAINS.each {domain -> steps["BUILD_DOMAIN_IMAGE_${domain}_${params.ENVIRONMENT}".toUpperCase()] = {
        //   buildAndPushDockerImage domain, params.ENVIRONMENT
        // }}

        // parallel steps
      }
    }

    stage('Deploy domains') {
      log("[STEP] deploy domains: ${DOMAINS.join(', ')} to ${params.ENVIRONMENT}")

      tryStep 'DEPLOY_DOMAINS', {
        if (params.DISABLE_PARALLEL_DEPLOYMENTS) {
          DOMAINS.each { domain -> deployDomain(domain, params.ENVIRONMENT) }
          return
        }

        def steps = [:]

        DOMAINS.each {domain -> steps["DEPLOY_DOMAIN_${domain}_${params.ENVIRONMENT}".toUpperCase()] = {
          deployDomain domain, params.ENVIRONMENT
        }}

        parallel steps
      }
    }
  }
}
