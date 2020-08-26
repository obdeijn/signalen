def call(String name, String repository, String gitRef = 'origin/master') {
  log.console("checking out Github repository ${repository}@${gitRef}")

  String repositoryUrl = "https://github.com/${repository}"

  try {
    checkout([
      $class: 'GitSCM',
      branches: [[name: gitRef]],
      extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: name]],
      userRemoteConfigs: [[credentialsId: env.JENKINS_GITHUB_CREDENTIALS_ID, url: repositoryUrl]]
    ])

    dir("${env.WORKSPACE}/${name}") {
      def lastGitCommitMessage = sh(returnStdout: true, script: 'git show --oneline --date=relative -s')
      log.console("${repository}@${gitRef} last Git commit message: ${lastGitCommitMessage}")
    }
  } catch (Throwable throwable) {
    log.error("checking out of gitHub repository ${repository}@${gitRef} failed")
    throw throwable
  }
}
