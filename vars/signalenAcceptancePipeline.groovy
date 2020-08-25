def call(body) {
  // Pre pipeline script block ----------------------------------------------------------------------------------------

  String GIT_REFS = ''

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

    REPOSITORIES = [
      signalen: [
        name: 'signalen',
        repositoryUrl: "https://github.com/${pipelineParameters.SIGNALEN_REPOSITORY}.git"
      ],
      signalsFrontend: [
        name: 'signals-frontend',
        repositoryUrl: "https://github.com/${pipelineParameters.SIGNALS_FRONTEND_REPOSITORY}.git"
      ]
    ]

    env.SLACK_NOTIFICATIONS_ENABLED = pipelineParameters.SLACK_NOTIFICATIONS_ENABLED
    env.SLACK_NOTIFICATIONS_CHANNEL = pipelineParameters.SLACK_NOTIFICATIONS_CHANNEL
    env.JENKINS_NODE = pipelineParameters.JENKINS_NODE
    env.DOCKER_REGISTRY_AUTH = pipelineParameters.DOCKER_REGISTRY_AUTH

    GIT_REFS = "signalen: ${pipelineParameters.SIGNALEN_BRANCH}, signals-frontend: ${pipelineParameters.SIGNALS_FRONTEND_BRANCH}"

    log.info('🐵 starting declarative pipeline 🐵')
  }

  // Declarative pipeline ---------------------------------------------------------------------------------------------

  pipeline {
    agent any

    triggers {
      githubPush() // listen for GitHub webhooks
      pollSCM('*/30 * * * *') // poll every 30 minutes for repository changes (fallback for Github webhooks)
    }

    options {
      durabilityHint('PERFORMANCE_OPTIMIZED') // tweaking Jenkins build strategy
      ansiColor('xterm') // enable colorized logging
      timeout(unit: 'MINUTES', time: 30) // cancel job if it runs longer then 30 minutes
      timestamps() // show timestamps in console log
      disableConcurrentBuilds() // prevent this pipeline from running simutanously
    }

    parameters {
      booleanParam(defaultValue: false, description: 'clean workspace before build', name: 'CLEAN_WORKSPACE')
    }

    stages {
      stage('Clean Workspaces') {
        when { expression { params.CLEAN_WORKSPACE } }
        steps { cleanWorkspaces() }
      }

      stage('Checkout Repositories') {
        steps {
          script {
            utils.checkoutWorkspace(
              pipelineParameters.JENKINS_GITHUB_CREDENTIALS_ID,
              REPOSITORIES.signalen,
              pipelineParameters.SIGNALEN_BRANCH
            )

            utils.checkoutWorkspace(
              pipelineParameters.JENKINS_GITHUB_CREDENTIALS_ID,
              REPOSITORIES.signalsFrontend,
              pipelineParameters.SIGNALS_FRONTEND_BRANCH
            )
          }
        }
      }

      stage('Validate Domain Schema\'s') {
        steps {
          script {
            // log.warning('validate has been disabled for development purposes')
            // signalen.validateDomainSchemas(pipelineParameters.ENVIRONMENT, signalen.getDomains(), '../signals-frontend', GIT_REFS)
            signalen.validateDomainSchemas(pipelineParameters.ENVIRONMENT, pipelineParameters.DOMAINS, '../signals-frontend', GIT_REFS)
          }
        }
      }

      stage('Build `signals-frontend` Base Image') {
        steps {
          script {
            // log.warning('buildAndPushSignalsFrontendDockerImage has been disabled for development purposes')

            signalen.buildAndPushSignalsFrontendDockerImage(
              pipelineParameters.SIGNALS_FRONTEND_BRANCH,
              'signals-frontend'
            )
          }
        }
      }

      stage ('Build Domain Images') {
        steps {
          script {
            // log.warning('buildAndPushDockerDomainImages has been disabled for development purposes')

            signalen.buildAndPushDockerDomainImages(
              pipelineParameters.DOCKER_BUILD_ARG_REGISTRY_HOST,
              pipelineParameters.ENVIRONMENT,
              pipelineParameters.DOMAINS,
              GIT_REFS
            )
          }
        }
      }

      stage('Deploy Domains') {
        steps {
          script {
            log.warning('deployDomains has been disabled for development purposes')
            // signalen.deployDomains('acceptance', pipelineParameters.DOMAINS, GIT_REFS)
          }
        }
      }
    }

    post {
      always {
        script {
          def result = currentBuild.result
          if (result == null) { result = "SUCCESS" }
        }
      }

      changed {
        script { log.notify("status changed: [From: $currentBuild.previousBuild.result, To: $currentBuild.result]") }
      }

      success {
        script { log.notify("pipeline success: ${env.BUILD_URL}}") }
      }

      failure {
        script { log.notifyError("pipeline failure: ${env.BUILD_URL}") }
      }
    }
  }
}
