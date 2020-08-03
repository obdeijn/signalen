def tryStep(String message, Closure block, Closure tearDown = null) {
    try {
        block()
    }
    catch (Throwable t) {
        slackSend message: "${env.JOB_NAME}: ${message} failure ${env.BUILD_URL}", channel: '#ci-channel', color: 'danger'
        throw t
    }
    finally {
        if (tearDown) {
            tearDown()
        }
    }
}

node('BS16 || BS17') {

    parameters {
        string(name: 'PERSON', defaultValue: 'Mr Jenkins', description: 'Who should I say hello to?')

        text(name: 'BIOGRAPHY', defaultValue: '', description: 'Enter some information about the person')

        booleanParam(name: 'TOGGLE', defaultValue: true, description: 'Toggle this value')

        choice(name: 'CHOICE', choices: ['One', 'Two', 'Three'], description: 'Pick something')

        password(name: 'PASSWORD', defaultValue: 'SECRET', description: 'Enter a password')
    }

    environment {
        IS_RELEASE = "${env.BRANCH_NAME ==~ "release/.*"}"
    }

    stage('Validate configuration schema\'s') {
        tryStep "build", {
            echo "Skip this step for now. npx is not present on the build server"
            // sh 'make validate-schemas'
            echo "Hello ${params.PERSON}"

            echo "Biography: ${params.BIOGRAPHY}"

            echo "Toggle: ${params.TOGGLE}"

            echo "Choice: ${params.CHOICE}"

            echo "Password: ${params.PASSWORD}"
        }
    }

    stage('Checkout signals frontend') {
        tryStep "checkout", {
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
        // steps {
        //   sh 'make build-base BUILD_PATH=./signals-frontend'
        // }
          tryStep "build", {
              docker.withRegistry("${DOCKER_REGISTRY_HOST}",'docker_registry_auth') {
                  def cachedImage = docker.image("ois/signalsfrontend:latest")

                  if (cachedImage) {
                      cachedImage.pull()
                  }

                  def buildParams = "--shm-size 1G " +
                      "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER} "

                  buildParams += IS_SEMVER_TAG ? "--build-arg GIT_BRANCH=${BRANCH} " : ''
                  buildParams += './signals-frontend'

                  def image = docker.build("ois/signalsfrontend:${env.BUILD_NUMBER}", buildParams)
                  image.push()
                  image.push("latest")
              }
          }
    }

    // stage("Build and push acceptance image") {
    //     tryStep "build", {
    //         docker.withRegistry("${DOCKER_REGISTRY_HOST}",'docker_registry_auth') {
    //             def image = docker.build("ois/signals-amsterdam:${env.BUILD_NUMBER}",
    //             "--shm-size 1G " +
    //             "--build-arg BUILD_ENV=acc " +
    //             "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER} " +
    //             "--build-arg GIT_COMMIT=${env.GIT_COMMIT} " +
    //             ".")
    //             image.push()
    //             image.push("acceptance")
    //         }
    //     }
    // }

}
