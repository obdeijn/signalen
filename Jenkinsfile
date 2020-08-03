pipeline {
    agent any

    environment {
        IS_RELEASE = "${env.BRANCH_NAME ==~ "release/.*"}"
    }

    stages {
        stage('Checkout') {
            steps {
                sh 'echo checkout'
            }
        }
    }
}
