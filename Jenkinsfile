#!/usr/bin/env groovy

// -- Options ---------------------------------------------------------------------------------------------------------

DEVELOPMENT = true

SIGNALEN_REPOSITORY = 'Amsterdam/signalen'
SIGNALS_FRONTEND_REPOSITORY = 'Amsterdam/signals-frontend'
GITHUB_CREDENTIALS_ID = '5b5e63e2-8db7-48c7-8e14-41cbd10eeb4a'

ENABLE_SLACK_NOTIFICATIONS = !DEVELOPMENT
JENKINS_NODE = DEVELOPMENT ? 'master' : 'BS16 || BS17'
DOCKER_REGISTRY_AUTH = DEVELOPMENT ? null : 'docker_registry_auth'

ENVIRONMENT_MAP = [acceptance: 'acc', production: 'prod']

// -- Workspaces ------------------------------------------------------------------------------------------------------

state = [
  id: '',
  environment: '',
  environmentShort: '',
  domains: [],
  workspaces: [
    signalen: [
      id: '',
      gitRef: '',
      commitRef: '',
      name: 'signalen',
      repository: SIGNALEN_REPOSITORY,
      repositoryUrl: "https://github.com/${SIGNALEN_REPOSITORY}.git"
    ],
    signalsFrontend: [
      id: '',
      gitRef: '',
      commitRef: '',
      name: 'signals-frontend',
      repository: SIGNALS_FRONTEND_REPOSITORY,
      repositoryUrl: "https://github.com/${SIGNALS_FRONTEND_REPOSITORY}.git"
    ],
  ]
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

def console_log(message, tag, color) {
  ansiColor('css') { echo(String.format("%s%s %s%s", color.xterm_code, tag, message, '\u001B[0m')) }
}

def workspaceInfo(workspace, message) { console_log(message, "[${workspace.name}]", Colors.PURPLE) }
def info(message) { console_log(message, '[INFO]', Colors.PURPLE) }
def error(message) { console_log(message, '[ERROR]', Colors.RED) }
def warn(message) { console_log(message, '[WARNING]', Colors.GREEN) }
def debug(message) { console_log(message, '[DEBUG]', Colors.CYAN) }
def dryRun(message) { console_log(message, '[DRYRUN]', Colors.CYAN) }

def logStart(label) { debug("BEGIN ${label}") }
def logEnd(label) { debug("END ${label}") }

GIT_LOG_COMMAND = 'git show --oneline --date=relative -s'

def workspaceLastCommit(String workspace) {
  dir("${env.WORKSPACE}/${workspace}") {
    return "${workspace}_" + sh(returnStdout: true, script: GIT_LOG_COMMAND)
  }
}

// -- Helper functions ------------------------------------------------------------------------------------------------

def checkoutWorkspace(workspace, String refName = 'origin/master') {
  workspaceInfo(workspace, "checkout ref ${refName}")

  return checkout([
    $class: 'GitSCM',
    branches: [[name: refName]],
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: workspace.name]],
    userRemoteConfigs: [[credentialsId: GITHUB_CREDENTIALS_ID, url: workspace.repositoryUrl]]
  ])
}

String BRANCH = "${env.BRANCH_NAME}"

Boolean IS_SEMVER_TAG = BRANCH ==~ /v(\d{1,3}\.){2}\d{1,3}/

def tryStep(String message, Closure block, Closure tearDown = null) {
  info("[step] ${message}")
  try {
    block()
  } catch (Throwable throwable) {
    if (ENABLE_SLACK_NOTIFICATIONS) {
      slackSend message: "${env.JOB_NAME}: ${message} failure ${env.BUILD_URL}", channel: '#ci-channel', color: 'danger'
    } else {
      warn("slack notifications are disabled, message: ${message}")
    }

    throw throwable
  } finally {
    if (tearDown) tearDown()
  }
}

def buildAndPush(String configuration, String dockerTag, String environment) {
  if (params.dryRun) {
    dryRun("buildAndPush - ${configuration} ${dockerTag} ${environment}")
  } else {
    docker.withRegistry(DOCKER_REGISTRY_HOST, DOCKER_REGISTRY_AUTH) {
      def image = docker.build(
        "ois/signals-${configuration}:${env.BUILD_NUMBER}",
        "--build-arg DOCKER_REGISTRY=${DOCKER_REGISTRY_HOST_SHORT} " +
        '--shm-size 1G ' +
        "--build-arg BUILD_ENV=${environment} " +
        "${env.WORKSPACE}/signalen/domains/${configuration}"
      )

      image.push()
      image.push(dockerTag)
    }
  }
}

def deploy(String appName, String tag) {
  info("deploying signals frontend: ${params.signalsFrontendRef} to ${appName}")

  if (DEVELOPMENT) {
    debug('deployment is skipped when DEVELOPMENT = true!')
    return
  }

  // build job: 'Subtask_Openstack_Playbook',
  //   parameters: [
  //     [$class: 'StringParameterValue', name: 'INVENTORY', value: tag],
  //     [$class: 'StringParameterValue', name: 'PLAYBOOK', value: 'deploy.yml'],
  //     [$class: 'StringParameterValue', name: 'PLAYBOOKPARAMS', value: "-e cmdb_id=${appName}"],
  //   ]
}

def validateSchema(String domain, String environment) {
  echo "validating ${domain} - ${state.id}"
  nodejs(nodeJSInstallationName: 'node12') {
    dir("${env.WORKSPACE}/signalen") { sh "make validate-local-schema DOMAIN=${domain} ENVIRONMENT=${environment}" }
  }
}

def prepareJenkinsPipeline() {
  logStart('preparing Jenkins pipeline')

  if (params.cleanBuild) {
    info('cleaning workspaces')
    cleanWs()
  }

  state.workspaces.each { key, workspace -> checkoutWorkspace(workspace) }

  state.domains = dir("${env.WORKSPACE}/signalen") { sh(returnStdout: true, script: 'make list-domains').split() }

  properties([
    // uncomment the following line to enable GitHub WebHook triggers
    // pipelineTriggers([githubPush()]),
    buildDiscarder(
      logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '10')
    ),
    durabilityHint('PERFORMANCE_OPTIMIZED'),
    // [$class: 'RebuildSettings', autoRebuild: false, rebuildDisabled: false],
    parameters([
      [
        $class: 'ParameterSeparatorDefinition',
        name: 'buildParametersHeader',
        sectionHeader: 'Build',
        separatorStyle: separatorStyle,
        sectionHeaderStyle: sectionHeaderStyle
      ],
      choice(description: 'environment', name: 'environment', choices: ['acceptance', 'production']),
      gitParameter(
        description: 'signals-frontend repository tag or branch',
        name: 'signalsFrontendRef',
        branch: '',
        branchFilter: '.*',
        defaultValue: 'origin/master',
        quickFilterEnabled: false,
        selectedValue: 'TOP',
        sortMode: 'DESCENDING_SMART',
        tagFilter: '*',
        type: 'PT_BRANCH_TAG',
        useRepository: 'signals-frontend'
      ),
      gitParameter(
        name: 'signalenRef',
        branch: '',
        branchFilter: '.*',
        defaultValue: 'origin/master',
        quickFilterEnabled: false,
        selectedValue: 'TOP',
        sortMode: 'DESCENDING_SMART',
        tagFilter: '*',
        type: 'PT_BRANCH_TAG',
        description: 'signalen repository tag or branch',
        useRepository: 'signalen'
      ),
      [
        $class: 'ParameterSeparatorDefinition',
        name: 'debugParametersHeader',
        sectionHeader: 'Debug & Maintenance',
        separatorStyle: separatorStyle,
        sectionHeaderStyle: sectionHeaderStyle
      ],
      booleanParam(name: 'cleanBuild', description: 'Clean workspace before build', defaultValue: false),
      booleanParam(name: 'disableParallelBuilds', description: 'Disable parallel builds', defaultValue: false),
      booleanParam(name: 'disableParallelDeployments', description: 'Disable parallel deployments', defaultValue: false),
      choice(
        description: 'by default all domain images are built and deployed',
        name: 'domain',
        choices: ['', 'weesp', 'amsterdam', 'amsterdamsebos']
      ),
      booleanParam(name: 'dryRun', description: 'Skip deployment and building', defaultValue: false)
    ])
  ])

  logEnd('preparing `signalen` Jenkins pipeline, test 1234')
}

// -- Jenkins pipeline ------------------------------------------------------------------------------------------------

node(JENKINS_NODE) {
  prepareJenkinsPipeline()

  message = [
    '',
    '***********************************************',
    "Running pipeline with parameters",
    '***********************************************',
    "environment = ${params.environment}",
    '',
    "signalenRef = ${params.signalenRef}",
    "signalsFrontendRef = ${params.signalsFrontendRef}",
    '***********************************************',
    ''
  ]

  info('pipeline info' + message.join('\n'))

  stage('Prepare workspaces and initialize state') {
    info("initializing ${state.workspaces.size()} workspaces")

    if (params.domain) state.domains = [params.domain]

    state.environment = params.environment
    state.environmentShort = ENVIRONMENT_MAP[params.environment]

    debug("before - ${workspaceLastCommit('signals-frontend')}")

    def stateIds = []

    state.workspaces.each { key, workspace ->
      workspace.gitRef = params["${key}Ref"]

      def checkoutResult = checkoutWorkspace(workspace, workspace.gitRef)
      workspace.commitRef = checkoutResult.GIT_COMMIT

      workspace.id = "${workspace.name}_${workspace.gitRef}-${workspace.commitRef[0..7]}"

      stateIds.push(workspace.id)
    }

    debug("after - ${workspaceLastCommit('signals-frontend')}")

    state.id = "${state.environment}_${stateIds.join('+')}"
  }

  stage('Validate configuration schema(\'s)') {
    def steps = [:]
    state.domains.each { domain -> steps[domain] = { validateSchema domain, state.environment } }
    parallel steps
  }

  stage('Build and push signals-frontend image') {
    tryStep "build signals-frontend image", {
      def workspace = state.workspaces.signalsFrontend

      info("build image: ${workspace.id} ${workspace.commitRef}")
      debug("${workspaceLastCommit('signals-frontend')}")

      if (params.dryRun) {
        dryRun('build signals-frontend image')
      } else {
        docker.withRegistry(DOCKER_REGISTRY_HOST, DOCKER_REGISTRY_AUTH) {
          // TODO: is this needed?
          // def cachedImage = docker.image("ois/signalsfrontend:latest")
          // if (cachedImage) { cachedImage.pull() }

          def buildParams = "--shm-size 1G " + "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER} "
          buildParams += IS_SEMVER_TAG ? "--build-arg GIT_BRANCH=${BRANCH} " : ''
          buildParams += './signals-frontend'

          def image = docker.build("ois/signalsfrontend:${env.BUILD_NUMBER}", buildParams)
          image.push()
          image.push('latest')
        }
      }
    }
  }

  stage("Build and push domain image(s)") {
    if (params.disableParallelBuilds) {
      state.domains.each { domain -> buildAndPush(domain, params.environment, environment) }
    } else {
      def steps = [:]
      state.domains.each { domain ->
        steps[domain] = { buildAndPush domain, state.environment, state.environmentShort }
      }
      parallel steps
    }
  }

  stage('Deploy signals-frontend domain(s)') {
    tryStep 'deploy signals-frontend domain(s)', {
      deploy("app_signals-${params.domain}", params.environment)
    }
  }
}
