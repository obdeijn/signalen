def tryStep(String message, Closure block, Closure tearDown = null) {
    try {
        block()
    }
    catch (Throwable t) {
        // slackSend message: "${env.JOB_NAME}: ${message} failure ${env.BUILD_URL}", channel: '#ci-channel', color: 'danger'
        throw t
    }
    finally {
        if (tearDown) {
            tearDown()
        }
    }
}

def buildAndPush(String configuration, String tag, String environment) {
    docker.withRegistry("${DOCKER_REGISTRY_HOST}",'docker_registry_auth') {
        sh 'pwd'
        def image = docker.build("ois/signals-${configuration}:${env.BUILD_NUMBER}",
        "--shm-size 1G " +
        "--build-arg BUILD_ENV=${environment} " +
        "./domains/${configuration} ")
        image.push()
        image.push(tag)
    }
}

def deploy(String appName, String tag) {
    build job: 'Subtask_Openstack_Playbook',
    parameters: [
        [$class: 'StringParameterValue', name: 'INVENTORY', value: tag],
        [$class: 'StringParameterValue', name: 'PLAYBOOK', value: 'deploy.yml'],
        [$class: 'StringParameterValue', name: 'PLAYBOOKPARAMS', value: "-e cmdb_id=${appName}"],
    ]

}

String BRANCH = "${env.BRANCH_NAME}"
Boolean IS_SEMVER_TAG = BRANCH ==~ /v(\d{1,3}\.){2}\d{1,3}/

properties([
  parameters([
      [
          $class: 'ParameterSeparatorDefinition',
          name: 'FOO_HEADER',
          sectionHeader: 'Foo Parameters',
          separatorStyle: separatorStyle,
          sectionHeaderStyle: sectionHeaderStyle
      ],
      string(name: 'FOO 1'),
      string(name: 'FOO 2'),
      string(name: 'FOO 3'),
      [
          $class: 'ParameterSeparatorDefinition',
          name: 'BAR_HEADER',
          sectionHeader: 'Bar Parameters',
          separatorStyle: separatorStyle,
          sectionHeaderStyle: sectionHeaderStyle
      ],
      string(name: 'BAR 1'),
      string(name: 'BAR 2'),
      string(name: 'BAR 3'),
      string(defaultValue: '', description: 'Release versie tag van de signals-frontend (vX.XX.XX)', name: 'APP_VERSION'),
      string(defaultValue: '', description: 'Release versie tag van de signals monorepo (vX.XX.XX)', name: 'CONFIG_VERSION')
  ])])

node('BS16 || BS17') {
    ansiColor('xterm') {
      echo(String.format("%s%s %s%s", '\u001B[35m', '[INFO]', 'testing ansi colors...', '\u001B[0m'))
    }

    stage('Validate configuration schema\'s') {
        tryStep "build", {
            sh "echo starting to build signals-fronten ${params.APP_VERSION} with the signals configuration ${params.CONFIG_VERSION}"
            sh 'echo Skip this step for now. npx is not present on the build server'
            nodejs(nodeJSInstallationName: 'node12') { sh 'make validate-schemas' }
            // sh 'make validate-schemas'
        }
    }

    stage('Checkout repositories') {
        tryStep "checkout", {
            checkout scm
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
        tryStep "build", {
            docker.withRegistry("${DOCKER_REGISTRY_HOST}", 'docker_registry_auth') {
                def cachedImage = docker.image("ois/signalsfrontend:latest")

                if (cachedImage) {
                    cachedImage.pull()
                }

                def buildParams = "--shm-size 1G " + "--build-arg BUILD_NUMBER=${env.BUILD_NUMBER} "
                buildParams += IS_SEMVER_TAG ? "--build-arg GIT_BRANCH=${BRANCH} " : ''
                buildParams += './signals-frontend'

                def image = docker.build("ois/signalsfrontend:${env.BUILD_NUMBER}", buildParams)
                image.push()
                image.push("latest")
            }
        }
    }

    stage("Build and push amsterdam acceptance image") {
        tryStep "build", {
            buildAndPush "amsterdam", "acceptance", "acc"
        }
    }

    stage("Build and push amsterdamsebos acceptance image") {
        tryStep "build", {
          buildAndPush "amsterdamsebos", "acceptance", "acc"
        }
    }

    stage("Build and push weesp acceptance image") {
        tryStep "build", {
          buildAndPush "weesp", "acceptance", "acc"
        }
    }

    // stage("Deploy signals amsterdam to ACC") {
    //     tryStep "deployment", {
    //         deploy "app_signals-amsterdam" "acceptance"
    //     }
    // }

    // stage("Deploy signals amsterdamsebos to ACC") {
    //     tryStep "deployment", {
    //         deploy "app_signals-amsterdamsebos" "acceptance"
    //     }
    // }

    // stage("Deploy signals weesp to ACC") {
    //     tryStep "deployment", {
    //         deploy "app_signals-weesp" "acceptance"
    //     }
    // }
}
