pipeline {
    agent any

    environment {
        IS_RELEASE = "${env.BRANCH_NAME ==~ "release/.*"}"
    }

    stages {
        stage('Validate configuration schema\'s') {
          steps {
            sh 'echo "Skip this step for now. npx is not present on the build server"'
            // sh 'make validate-schemas'
          }
        }

        stage('Checkout signals frontend') {
            steps {
                checkout([
                  $class: 'GitSCM',
                  branches: [[name: '*/master']],
                  doGenerateSubmoduleConfigurations: false,
                  extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'signals-frontend']],
                  submoduleCfg: [],
                  userRemoteConfigs: [
                    [
                      credentialsId: '5b5e63e2-8db7-48c7-8e14-41cbd10eeb4a',
                      url: 'https://github.com/Amsterdam/signals-frontend'
                    ]
                  ]
                ])
            }
        }

        stage('Build signals frontend') {
            steps {
              sh 'make build-base BUILD_PATH=./signals-frontend'
            }
        }

    }
}
