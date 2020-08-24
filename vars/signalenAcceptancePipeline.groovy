def call(body) {
  // Pre pipeline script block ----------------------------------------------------------------------------------------

  env.DEVELOPMENT = true
  env.SLACK_NOTIFICATIONS_ENABLED = !env.DEVELOPMENT
  env.SLACK_NOTIFICATIONS_CHANNEL = '#ci-signalen'
  JENKINS_NODE = env.DEVELOPMENT ? 'master' : 'BS16 || BS17'
  DOCKER_REGISTRY_AUTH = env.DEVELOPMENT ? null : 'docker_registry_auth'

  SIGNALEN_REPOSITORY = 'jpoppe/signalen'
  SIGNALS_FRONTEND_REPOSITORY = 'jpoppe/signals-frontend'
  JENKINS_GITHUB_CREDENTIALS_ID = '431d5971-5b08-46d8-b225-74368ee31ec0'
  DOCKER_BUILD_ARG_REGISTRY_HOST = DOCKER_REGISTRY_HOST_SHORT

  REPOSITORIES = [
    signalen: [
      name: 'signalen',
      repositoryUrl: "https://github.com/${SIGNALEN_REPOSITORY}.git"
    ],
    signalsFrontend: [
      name: 'signals-frontend',
      buildPath: '.',
      repositoryUrl: "https://github.com/${SIGNALS_FRONTEND_REPOSITORY}.git"
    ]
  ]

  releaseRefs = ''

  def pipelineParameters= [:]

  ansiColor('xterm') {
    log.highlight('''
     _                   _                                       _
 ___(_) __ _ _ __   __ _| | ___ _ __     __ _  ___ ___ ___ _ __ | |_ __ _ _ __   ___ ___
/ __| |/ _` | '_ \\ / _` | |/ _ \\ '_ \\   / _` |/ __/ __/ _ \\ '_ \\| __/ _` | '_ \\ / __/ _ \\
\\__ \\ | (_| | | | | (_| | |  __/ | | | | (_| | (_| (_|  __/ |_) | || (_| | | | | (_|  __/
|___/_|\\__, |_| |_|\\__,_|_|\\___|_| |_|  \\__,_|\\___\\___\\___| .__/ \\__\\__,_|_| |_|\\___\\___|
       |___/                                               |_|
    ''')

    log.info('🦄 we are now in the scripted "pre declarative" pipeline scope 🦄')

    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = pipelineParameters
    body()

    log.info('pipeline parameters:')
    log.highlight(pipelineParameters)

    log.info('🐵 starting declarative pipeline 🐵')
  }

  // Declarative pipeline ---------------------------------------------------------------------------------------------

  pipeline {
    agent any

    options {
      buildDiscarder(logRotator(numToKeepStr: '5'))
      timeout(unit: 'MINUTES', time: 30)
      ansiColor('xterm')
      timestamps()
    }

    parameters {
      choice(
        description: 'build and deploy a single domain instead of all domains',
        name: 'DOMAIN',
        choices: ['', 'weesp', 'amsterdam', 'amsterdamsebos']
      )
      gitParameter(
        name: "SIGNALEN_BRANCH",
        description: 'signalen Git repository branch',
        defaultValue: 'origin/master',
        useRepository: 'signalen',
        tagFilter: 'v[0-9]*.[0-9]*.[0-9]*',
        branchFilter: '*',
        quickFilterEnabled: false,
        selectedValue: 'DEFAULT',
        sortMode: 'DESCENDING_SMART',
        type: 'PT_BRANCH_TAG'
      )
      booleanParam(defaultValue: false, description: 'clean workspace before build', name: "CLEAN_WORKSPACE")
    }

    stages {
      stage('cleaning workspace') {
        when { expression { params.CLEAN_WORKSPACE } }
        steps {
            script {
              log.info('cleaning workspace folders')
              // cleanWs()
            }
        }

      }

      stage('checkout signalen') {
        steps {
          script {
            releaseRefs = "signalen: ${params.SIGNALEN_BRANCH}, signals-frontend: ${BRANCH_NAME}"
            log.info('🌈 checking out the signalen repository 🌈')

            utils.checkoutWorkspace(JENKINS_GITHUB_CREDENTIALS_ID, REPOSITORIES.signalen, params.SIGNALEN_BRANCH)
            // git branch: pipelineParameters.branch, credentialsId: 'GitCredentials', url: pipelineParameters.scmUrl

            log.info("multibranch branch name: ${BRANCH_NAME}")
            signalen.logBuildInformation(signalen.getDomains(), DOCKER_BUILD_ARG_REGISTRY_HOST)
            def globalVariables = getBinding().getVariables()
            for (variable in getBinding().getVariables()) echo "${variable} " + globalVariables.get(variable)
          }
        }
      }

      stage('validate') {
        steps {
          script {
            signalen.validateDomainSchemas('acceptance', signalen.getDomains(), '..', releaseRefs)
            signalen.validateDomainSchemas('production', signalen.getDomains(), '..', releaseRefs)
          }
        }
      }

      stage('build signals-frontend') {
        steps {
          script {
            signalen.buildAndPushSignalsFrontendDockerImage(BRANCH_NAME, REPOSITORIES.signalsFrontend.buildPath)
          }
        }
      }

      stage ('build domain images') {
        steps {
          script {
            signalen.buildAndPushDockerDomainImages(DOCKER_BUILD_ARG_REGISTRY_HOST, 'acceptance', signalen.getDomains())
          }

          // parallel (
          //   "unit tests": { sh 'mvn test' },
          //   "integration tests": { sh 'mvn integration-test' }
          // )
        }
      }

      stage('deploy domains'){
        steps {
          script {
            signalen.deployDomains('acceptance', signalen.getDomains())
          }
        }
      }
    }

    post {
      success {
        script { log.info("pipeline success: ${env.BUILD_URL}}") }
      }

      changed {
        script { log.info("status changed: [From: $currentBuild.previousBuild.result, To: $currentBuild.result]") }
      }

      always {
        script {
          def result = currentBuild.result
          if (result == null) { result = "SUCCESS" }
        }
      }

      failure {
        script { log.error("pipeline failure: ${env.BUILD_URL}") }
      }
    }
  }
}
