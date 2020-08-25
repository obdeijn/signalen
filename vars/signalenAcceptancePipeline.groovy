def call(body) {
  // Pre pipeline script block ----------------------------------------------------------------------------------------

  String GIT_REFS = ''

  def settings = [:]

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
    body.delegate = settings
    body()

    log.info('pipeline parameters:')
    log.highlight(settings)

    REPOSITORIES = [
      signalen: [
        name: 'signalen',
        repositoryUrl: "https://github.com/${settings.SIGNALEN_REPOSITORY}.git"
      ],
      signalsFrontend: [
        name: 'signals-frontend',
        repositoryUrl: "https://github.com/${settings.SIGNALS_FRONTEND_REPOSITORY}.git"
      ]
    ]

    // Environment variables used by signalen global Jenkins methods defined in /vars
    env.SLACK_NOTIFICATIONS_ENABLED = settings.SLACK_NOTIFICATIONS_ENABLED
    env.SLACK_NOTIFICATIONS_CHANNEL = settings.SLACK_NOTIFICATIONS_CHANNEL
    env.DOCKER_REGISTRY_AUTH = settings.DOCKER_REGISTRY_AUTH

    // Used for logging purposes
    GIT_REFS = "signalen: ${settings.SIGNALEN_BRANCH}, signals-frontend: ${settings.SIGNALS_FRONTEND_BRANCH}"

    log.info('🐵 starting declarative pipeline 🐵')
  }

  // Declarative pipeline ---------------------------------------------------------------------------------------------

  pipeline {
    agent {
      node { label settings.JENKINS_NODE }
    }

    triggers {
      githubPush() // listen for GitHub webhooks
      pollSCM('H/45 * * * *') // poll every 45 minutes for repository changes (fallback for Github webhooks)
    }

    options {
      durabilityHint('PERFORMANCE_OPTIMIZED') // tweaking Jenkins build strategy
      ansiColor('xterm') // enable colorized logging
      timeout(unit: 'MINUTES', time: 30) // cancel job if it runs longer then 30 minutes
      // timestamps() // show timestamps in console log
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
              settings.JENKINS_GITHUB_CREDENTIALS_ID,
              REPOSITORIES.signalen,
              settings.SIGNALEN_BRANCH
            )

            utils.checkoutWorkspace(
              settings.JENKINS_GITHUB_CREDENTIALS_ID,
              REPOSITORIES.signalsFrontend,
              settings.SIGNALS_FRONTEND_BRANCH
            )
          }
        }
      }

      stage('Validate Domain Schema\'s') {
        steps {
          script {
            signalen.validateDomainSchemas(settings.ENVIRONMENT, settings.DOMAINS, '../signals-frontend', GIT_REFS)
          }
        }
      }

      stage('Build `signals-frontend` Base Image') {
        steps {
          script {
            log.warning('buildAndPushSignalsFrontendDockerImage has been disabled for development purposes')

            // signalen.buildAndPushSignalsFrontendDockerImage(
            //   settings.SIGNALS_FRONTEND_BRANCH,
            //   'signals-frontend'
            // )
          }
        }
      }

      stage ('Build Domain Images') {
        steps {
          script {
            log.warning('buildAndPushDockerDomainImages has been disabled for development purposes')

            // signalen.buildAndPushDockerDomainImages(
            //   settings.DOCKER_BUILD_ARG_REGISTRY_HOST,
            //   settings.ENVIRONMENT,
            //   settings.DOMAINS,
            //   GIT_REFS
            // )
          }
        }
      }

      stage('Deploy Domains') {
        steps {
          script {
            log.warning('deployDomains has been disabled for development purposes')

            // signalen.deployDomains('acceptance', settings.DOMAINS, GIT_REFS)
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
        script {
          log.info("status changed: [From: ${currentBuild.previousBuild.result}, To: ${currentBuild.result}]")
        }
      }

      success {
        script {
          log.notify("`acceptance pipeline` success: ${env.BUILD_URL}}, ${gitRefs}, domains: ${settings.DOMAINS.join(', ')}")
        }
      }

      failure {
        script {
          log.notifyError("`acceptance pipeline` failure: ${env.BUILD_URL}, ${gitRefs}, domains: ${settings.DOMAINS.join(', ')}")
        }
      }
    }
  }
}
