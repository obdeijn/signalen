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
