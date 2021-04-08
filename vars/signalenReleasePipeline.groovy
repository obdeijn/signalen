def call(Closure body) {
  // Scripted pipeline scope ------------------------------------------------------------------------------------------

  def pipelineParams = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = pipelineParams
  body()

  banner = '''
     _                   _                       _
 ___(_) __ _ _ __   __ _| | ___ _ __    _ __ ___| | ___  __ _ ___  ___
/ __| |/ _` | '_ \\ / _` | |/ _ \\ '_ \\  | '__/ _ \\ |/ _ \\/ _` / __|/ _ \\
\\__ \\ | (_| | | | | (_| | |  __/ | | | | | |  __/ |  __/ (_| \\__ \\  __/
|___/_|\\__, |_| |_|\\__,_|_|\\___|_| |_| |_|  \\___|_|\\___|\\__,_|___/\\___|
       |___/
  '''

  targetDomains = params.DOMAIN ? [params.DOMAIN] : pipelineParams.DOMAINS

  env.RELEASE_DESCRIPTION = "signalen: ${params.SIGNALEN_RELEASE_TAG}, signals-frontend: ${params.SIGNALS_FRONTEND_RELEASE_TAG}"

  signalen.initializePipeline(banner, pipelineParams, params)

  // Declarative pipeline ---------------------------------------------------------------------------------------------

  pipeline {
    agent {
      node { label pipelineParams.JENKINS_NODE }
    }

    options {
      durabilityHint('PERFORMANCE_OPTIMIZED') // tweaking Jenkins build strategy
      ansiColor('xterm') // enable colorized logging
      timeout(unit: 'MINUTES', time: 30) // cancel job if it runs longer then 30 minutes
      disableConcurrentBuilds() // prevent this pipeline from running simutanously
    }

    parameters {
      // separatorParameter('Build parameters')
      // separator(name: 'Build Parameters')

      gitParameter(
        name: 'SIGNALS_FRONTEND_RELEASE_TAG',
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
      )

      gitParameter(
        name: 'SIGNALEN_RELEASE_TAG',
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
      )

      // utils.separatorParameter('Debug and maintenance parameters')

      booleanParam(
        name: 'CLEAN_WORKSPACE',
        description: 'clean workspace before the building process starts',
        defaultValue: false
      )

      choice(
        description: 'build and deploy a single domain instead of all domains',
        name: 'DOMAIN',
        choices: ['', 'weesp', 'amsterdam', 'amsterdamsebos']
      )
    }

    stages {
      stage('Clean Workspaces') {
        when { expression { params.CLEAN_WORKSPACE } }
        steps { cleanWorkspaces() }
      }

      stage('Checkout Repositories') {
        steps {
          checkoutGithubRepository('signalen', pipelineParams.SIGNALEN_REPOSITORY, params.SIGNALEN_RELEASE_TAG)

          checkoutGithubRepository(
            'signals-frontend',
            pipelineParams.SIGNALS_FRONTEND_REPOSITORY,
            params.SIGNALS_FRONTEND_RELEASE_TAG
          )
        }
      }

      stage('Validate Domain Schema\'s') {
        steps { validateDomainSchemas(pipelineParams.ENVIRONMENT, targetDomains) }
      }

      stage('Build `signals-frontend` Base Image') {
        steps { buildAndPushSignalsFrontendDockerImage(
          pipelineParams.DOCKER_BUILD_ARG_REGISTRY_HOST,
          params.SIGNALS_FRONTEND_RELEASE_TAG,
          pipelineParams.DOCKER_BUILD_ARG_DOCKER_IMAGE_TAG)
        }
      }

      stage ('Build Domain Images') {
        steps {
          buildAndPushDockerDomainImages(
            pipelineParams.DOCKER_BUILD_ARG_REGISTRY_HOST,
            pipelineParams.ENVIRONMENT,
            targetDomains,
            pipelineParams.DOCKER_BUILD_ARG_DOCKER_IMAGE_TAG
          )
        }
      }

      stage('Deploy Domains') {
        steps {
          // script { log.warning('deployDomains has been disabled for development purposes') }
          deployDomains(pipelineParams.ENVIRONMENT, targetDomains)
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
          log.notify("`release pipeline` success: ${env.BUILD_URL}}, ${env.RELEASE_DESCRIPTION}, domains: ${pipelineParams.DOMAINS.join(', ')}")
        }
      }

      failure {
        script {
          log.notifyError("`release pipeline` failure: ${env.BUILD_URL}, ${env.RELEASE_DESCRIPTION}, domains: ${pipelineParams.DOMAINS.join(', ')}")
        }
      }
    }
  }

}
