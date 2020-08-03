pipeline {
    agent any

    environment {
        IS_RELEASE = "${env.BRANCH_NAME ==~ "release/.*"}"
    }

    stages {
        stage('Checkout') {
            steps {
                sh 'echo checkout'
                checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false,
                extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'signals-frontend']],
                submoduleCfg: [],
                userRemoteConfigs: [[credentialsId: '5b5e63e2-8db7-48c7-8e14-41cbd10eeb4a', url: 'https://github.com/Amsterdam/signals-frontend']]])
            }
        }
    }
}
