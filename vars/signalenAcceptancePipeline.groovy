def call(Closure body) {
  // Scripted pipeline scope ------------------------------------------------------------------------------------------

  def pipelineParams = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = pipelineParams
  body()

  banner = '''
     _                   _                                       _
 ___(_) __ _ _ __   __ _| | ___ _ __     __ _  ___ ___ ___ _ __ | |_ __ _ _ __   ___ ___
/ __| |/ _` | '_ \\ / _` | |/ _ \\ '_ \\   / _` |/ __/ __/ _ \\ '_ \\| __/ _` | '_ \\ / __/ _ \\
\\__ \\ | (_| | | | | (_| | |  __/ | | | | (_| | (_| (_|  __/ |_) | || (_| | | | | (_|  __/
|___/_|\\__, |_| |_|\\__,_|_|\\___|_| |_|  \\__,_|\\___\\___\\___| .__/ \\__\\__,_|_| |_|\\___\\___|
       |___/                                               |_|
  '''

  env.RELEASE_DESCRIPTION = "${pipelineParams.ENVIRONMENT} | signalen @ ${pipelineParams.SIGNALEN_BRANCH} | signals-frontend @ ${pipelineParams.SIGNALS_FRONTEND_BRANCH}"

  signalen.initializePipeline(banner, pipelineParams, params)

  // Declarative pipeline ---------------------------------------------------------------------------------------------

  pipeline {
    agent {
      node { label pipelineParams.JENKINS_NODE }
    }

    triggers {
      githubPush() // listen for GitHub webhooks
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
          checkoutGithubRepository('signalen', pipelineParams.SIGNALEN_REPOSITORY, pipelineParams.SIGNALEN_BRANCH)

          checkoutGithubRepository(
            'signals-frontend',
            pipelineParams.SIGNALS_FRONTEND_REPOSITORY,
            pipelineParams.SIGNALS_FRONTEND_BRANCH
          )
        }
      }

      stage('Validate Domain Schema\'s') {
        steps { validateDomainSchemas(pipelineParams.ENVIRONMENT, pipelineParams.DOMAINS) }
      }

      stage('Build `signals-frontend` Base Image') {
        steps {
          buildAndPushSignalsFrontendDockerImage(
            pipelineParams.DOCKER_BUILD_ARG_REGISTRY_HOST,
            pipelineParams.SIGNALS_FRONTEND_BRANCH,
            'signals-frontend'
          )
        }
      }

      stage ('Build Domain Images') {
        steps {
          buildAndPushDockerDomainImages(
            pipelineParams.DOCKER_BUILD_ARG_REGISTRY_HOST,
            pipelineParams.ENVIRONMENT,
            pipelineParams.DOMAINS,
          )
        }
      }

      stage('Deploy Domains') {
        steps {
          // script { log.warning('deployDomains has been disabled for development purposes') }
          deployDomains('acceptance', pipelineParams.DOMAINS)
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
          log.notify("`acceptance pipeline` success: ${env.BUILD_URL}}, ${env.RELEASE_DESCRIPTION}, domains: ${pipelineParams.DOMAINS.join(', ')}")
        }
      }

      failure {
        script {
          log.notifyError("`acceptance pipeline` failure: ${env.BUILD_URL}, ${env.RELEASE_DESCRIPTION}, domains: ${pipelineParams.DOMAINS.join(', ')}")
        }
      }
    }
  }
}
