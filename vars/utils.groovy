#!/usr/bin/env groovy

def semanticGitReleaseTagParameter(String repository) {
  return gitParameter(
    name: "${repository.replace('-', '_').toUpperCase()}_RELEASE_TAG",
    description: "${repository} Git repository tag",
    useRepository: repository,
    branch: '',
    tagFilter: 'v[0-9]*.[0-9]*.[0-9]*',
    defaultValue: 'origin/master',
    branchFilter: '!*',
    quickFilterEnabled: false,
    selectedValue: 'TOP',
    sortMode: 'DESCENDING_SMART',
    type: 'PT_BRANCH_TAG'
  )
}

def separatorParameter(String label) {
  separatorStyle = '''
    border: 0;
    border-bottom: 0;
    background: #999;
  '''

  sectionHeaderStyle = '''
    color: white;
    background: hotpink;
    font-family: Roboto, sans-serif !important;
    font-weight: 700;
    font-size: 1.3em;
    padding: 5px;
    margin-top: 10px;
    margin-bottom: 20px;
    text-align: left;
  '''

  return [
    $class: 'ParameterSeparatorDefinition',
    name: "_BUILD_${label.replace(' ', '_').toUpperCase()}",
    sectionHeader: label,
    separatorStyle: separatorStyle,
    sectionHeaderStyle: sectionHeaderStyle
  ]
}

def checkoutWorkspace(String jenkinsGithubCredentialsId, def workspace, String refName = 'origin/master') {
  log.console("checking out workspace ${workspace.name} @ Git ref ${refName}")

  try {
    checkout([
      $class: 'GitSCM',
      branches: [[name: refName]],
      extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: workspace.name]],
      userRemoteConfigs: [[credentialsId: jenkinsGithubCredentialsId, url: workspace.repositoryUrl]]
    ])

    dir("${env.WORKSPACE}/${workspace.name}") {
      def lastGitCommitMessage = sh(returnStdout: true, script: 'git show --oneline --date=relative -s')
      log.console("${workspace.name} last Git commit message: ${lastGitCommitMessage}")
    }
  } catch (Throwable throwable) {
    log.error("workspace Git checkout @${refName} failed: ${workspace.name}")
    // slack.error("Git checkout failed for workspace: ${workspace.name} (Git ref: ${refName})")
    throw throwable
  }
}
