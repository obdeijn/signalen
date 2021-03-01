#!/usr/bin/env bash
# @name Bootstrap SIA Jenkins Docker Environment
# @file bootstrap-docker-jenkins.sh
# @brief Script to clone Basis SIA Jenkins environment to Docker
# @description
#     This script configures a local Docker environment with SIA pipelines.
#
#     Instructions:
#
#      * Start the Jenkins docker environment and bootstrap it:
#        cd ~/signalen/docker-jenkins-environment
#        docker-compose up
#        ./bootstrap_sia_jenkins_environment.sh
#
#     Generate shell script Markdown documentation:
#
#     * shdoc < bootstrap-docker-jenkins.sh > bootstrap-docker-jenkins.md
#

JENKINS_DOCKER_URL="http://localhost:8081"
JENKINS_PRODUCTION_URL="https://ci.data.amsterdam.nl"
JENKINS_ADMIN_USER="admin"
JENKINS_ADMIN_PASSWORD="admin"
JENKINS_JOB_FIELDS="name,color,url"
SMEE_PROXY_URL="https://smee.io/rMm3gwdjhMxFnkZg"
GITHUB_API_URL=https://api.github.com
CACHE_DIRECTORY=./cache

JENKINS_CRUMB=$(
  curl --silent \
    --cookie-jar jenkins_admin_cookies.txt \
    --user "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
    $JENKINS_DOCKER_URL'/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)'
)

# @description Generate a Jenkins Token.
#
# @example
#    jenkins_token_generate
#
# @arg $1 string A value to print
#
# @exitcode 0 If successful.
# @exitcode 1 If failed.
#
function jenkins_token_generate() {
  curl \
    --silent \
    --cookie jenkins_admin_cookies.txt \
    --header "$JENKINS_CRUMB" \
    --user "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
    --data 'newTokenName=jenkins-docker-admin-token' \
    "${JENKINS_DOCKER_URL}/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" | \
    jq --raw-output '.data.tokenValue'
}

JENKINS_ADMIN_TOKEN=$(jenkins_token_generate)

# @description Log info.
#
# @example
#    log_info "this will be logged to stdout"
#
# @arg $1 string String to print
#
function log_info() {
  echo -e "\033[33;1m$* \033[0m"
}

# @description Log error.
#
# @example
#    log_error "this error will be logged to stdout"
#
# @arg $1 string String to print
#
function log_error() {
  echo -e "\033[31;1m[ERROR] $* \033[0m"
}

# @description Make a GET request and return the response code.
#
# @example
#    _get_response_code https://amsterdam.nl
#
# @arg $1 string url - Url
#
function _get_response_code() {
  local url=$1

  curl -s -w "%{http_code}" "$url" -o /dev/null
}

# @description Make an authorized GET request to GitHub.
#
# @example
#    _github_get user
#
# @arg $1 string url - Url
#
function _github_get() {
  local url=$1

  curl --silent \
    -X GET \
    -H "Authorization: token ${GITHUB_JENKINS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "$url"
}

# @description Make an authorized GET request to Jenkins.
#
# @example
#    _jenkins_get
#
# @arg $1 string query - Query
#
function _jenkins_get() {
  local query=$1

  curl --user "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_TOKEN}" "${JENKINS_DOCKER_URL}/${query}"
}

# @description Make an authorized POST request to Jenkins.
#
# @example
#    _jenkins_post safeRestart
#
# @arg $1 string query - Query
#
function _jenkins_post() {
  local query=$1

  curl -X POST \
    --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" \
    --header "Content-Type: text/xml" \
    "$JENKINS_DOCKER_URL/$query"
}

# @description Make an authorized POST request with data to Jenkins.
#
# @example
#    _jenkins_post_data "$query" "@cache/${job_xml}"
#
# @arg $1 string query - Query
# @arg $2 string data - Data to post
#
function _jenkins_post_data() {
  local query=$1
  local data=$2

  curl -X POST \
    --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" \
    --header "Content-Type: text/xml" \
    --data "$data" \
    "$JENKINS_DOCKER_URL/$query"
}

# @description Make an authorized POST request with JSON data to Jenkins.
#
# @example
#    _jenkins_post_json
#
# @arg $1 string query - Query
# @arg $2 string json - JSON data to post
#
function _jenkins_post_json() {
  local query=$1
  local json=$2

  curl \
    --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" \
    --header "Accept: application/json" \
    --data-urlencode json="$json" \
    "$JENKINS_DOCKER_URL/$query"
}

# @description Check if command exists or exit.
#
# @example
#    _check_command git
#
# @arg $1 string command_name - Command to check
#
function _check_command() {
  local command_name=$1

  if ! [[ -x "$(command -v "$command_name")" ]]; then
    log_error "${0} requires ${command_name} to run, please install and/or add it to your path" >&2
    exit 1
  fi
}

# @description Check if directory exists otherwise create it.
#
# @example
#    _check_directory_exists git
#
# @arg $1 string directory - Directory to check and to create
#
function _check_directory_exists() {
  local directory=$1

  if [[ ! -d  "$directory" ]]; then
    log_info "Creating directory: ${directory}"
    mkdir "$directory"
  fi
}

# @description Check if environment variable exists, otherwise print message and exit.
#
# @example
#    _check_env_variable ENVIRONMENT_VARIABLE_NAME "description of environment variable"
#
# @arg $1 string env_name - Name of the environment variable
# @arg $1 string message - Message to display when environment variable is empty
#
function _check_env_variable() {
  local env_name=$1
  local message=$2

  if [[ -z "${!env_name}" ]]; then
    log_error "$0 requires env variable: \$${env_name}" >&2
    log_info "hint: it should contain $message"
    exit 1
  fi
}

# @description Execute a Groovy script via the Jenkins rest API.
#
# @example
#    _jenkins_groovy ./script.groovy
#
# @arg $1 string script_name - Name of the Groovy script to execute
#
function _jenkins_groovy() {
  local script_name=$1

  curl \
    --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" \
    --data-urlencode "script=$(< "./groovy_scripts/${script_name}.groovy")" \
    "${JENKINS_DOCKER_URL}/scriptText"
}

# @description Get user details from GitHub
#
# @example
#    github_user_details
#
# @noargs
#
function github_user_details() {
  _github_get ${GITHUB_API_URL}/user
}

# @description Get user name from GitHub user details
#
# @example
#    github_user_get
#
# @noargs
#
function github_user_get() {
  github_user_details | jq -r '.login'
}

# @description Check if environment variable exists, otherwise print message and exit.
#
# @example
#    github_repo_delete ENVIRONMENT_VARIABLE_NAME "description of environment variable"
#
# @arg $1 string org - Name of Github repository owner/organization
# @arg $2 string repo - Name of GitHub repository
#
function github_repo_delete() {
  local org=$1
  local repo=$2

  # gh alias set repo-delete 'api -X DELETE "repos/$1"'
  gh repo-delete "${GITHUB_USER}/${repo}"
}

# @description Check if GitHub repository exists, otherwise log error and exit.
#
# @example
#    github_repository_exists signals-frontend
#
# @arg $1 string repository - Name of GitHub repository to check
#
function github_repository_exists() {
  local repository=$1
  local response_code

  response_code=$(_get_response_code "https://api.github.com/repos/${GITHUB_USER}/$repository")

  if [[ "$response_code" -ne 200 ]]; then
    log_error "repository ${GITHUB_USER}/${repository} does not exist"
    return 1
  fi

  return 0
}

# @description Get GitHub web hook details.
#
# @example
#    github_webhook_get signals-frontend 123456
#
# @arg $1 string repository - Name of GitHub repository
# @arg $2 string id - GitHub webhook id
#
function github_webhook_get() {
  local repository=$1
  local id=$2

  local url="${GITHUB_API_URL}/repos/${GITHUB_USER}/${repository}/hooks/$id"

  curl \
    -H "Authorization: token $GITHUB_JENKINS_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -X GET "$url"
}

# @description Delete GitHub web hook.
#
# @example
#    github_webhook_delete signals-frontend 280511274
#
# @arg $1 string repository - Name of GitHub repository
# @arg $2 string id - GitHub webhook id
#
function github_webhook_delete() {
  local repository=$1
  local id=$2

  local url="${GITHUB_API_URL}/repos/${GITHUB_USER}/${repository}/hooks/$id"

  curl \
    -H "Authorization: token ${GITHUB_JENKINS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -X DELETE "$url"
}

# @description Create GitHub web hook.
#
# @example
#    github_webhook_create signals-frontend 123456
#
# @arg $1 string repository - Name of GitHub repository
# @arg $2 string url - Url where the hooks will be delivered
#
function github_webhook_create() {
  local repository=$1
  local url=$2

  curl \
    -H "Authorization: token $GITHUB_JENKINS_TOKEN" -H "Accept: application/vnd.github.v3+json" \
    -X POST --data '{"name": "web", "active": true, "config": {"url": "'"$url"'", "content_type": "json"}}' \
    "${GITHUB_API_URL}/repos/${GITHUB_USER}/${repository}/hooks"
}

# @description Fork GitHub repository.
#
# @example
#    github_repo_fork Amsterdam signals-frontend
#
# @arg $1 string org - Name of Github repository owner/organization
# @arg $2 string repo - Name of GitHub repository
#
function github_repo_fork() {
  local org=$1
  local repo=$2
  local repository="$org/$repo"

  echo "forking repository: ${repository}"
  gh repo fork "${org}/${repo}" --remote=false --clone=true
}

# @description Copy a Jenkins pipeline from production.
#
# @example
#    production_jenkins_job_get SIA_Signalen_Amsterdam
#    production_jenkins_job_get signalen-release SIA_Signalen_Amsterdam
#
# @arg $1 string job_name - Name of the Jenkins pipeline
# @arg $2 string folder_name - Name of the pipeline folder
#
function production_jenkins_job_get() {
  local job_name=$1
  local folder_name=$2

  local url
  local local_file_name

  if [[ -z $folder_name ]]; then
    url="${JENKINS_PRODUCTION_URL}/job/${job_name}/config.xml"
    local_file_name="${job_name}.xml"
  else
    url="${JENKINS_PRODUCTION_URL}/job/${folder_name}/job/${job_name}/config.xml"
    local_file_name="${folder_name}___${job_name}.xml"
  fi

  curl --user "$JENKINS_PRODUCTION_USER:$JENKINS_PRODUCTION_TOKEN" "$url" > "./cache/$local_file_name"
}

# @description Install a Jenkins plugin.
#
# @example
#    jenkins_plugin_install git
#
# @arg $1 string plugin_name - Name of the Jenkins plugin
#
function jenkins_plugin_install() {
  local plugin_name=$1

  _jenkins_post_data \
    pluginManager/installNecessaryPlugins \
    "<jenkins><install plugin=\"${plugin_name}@latest\" /></jenkins>"
}

# @description List all installed Jenkins plugins.
#
# @example
#    jenkins_plugin_list
#
# @noargs
#
function jenkins_plugin_list() {
  _jenkins_get pluginManager/api/json?depth=1 | \
    jq --raw-output '.plugins[] | "\(.shortName):\(.version)"' | \
    sort
}

# @description Restart Jenkins.
#
# @example
#    jenkins_safe_restart
#
# @noargs
#
function jenkins_safe_restart() {
  _jenkins_post safeRestart

  sleep 10

  while [[ $(_get_response_code "$JENKINS_DOCKER_URL") != "200" ]]; do sleep 5; done;
}

# @description Copy a Jenkins pipeline.
#
# @example
#    jenkins_job_get SIA_Signalen_Amsterdam
#    jenkins_job_get signalen-release SIA_Signalen_Amsterdam
#
# @arg $1 string job_name - Name of the Jenkins pipeline
# @arg $2 string folder_name - Name of the pipeline folder
#
function jenkins_job_get() {
  local job_name=$1
  local folder_name=$2

  local url
  local local_file_name

  if [[ -z $folder_name ]]; then
    query="job/${job_name}/config.xml"
    local_file_name="${job_name}.xml"
  else
    query="job/${folder_name}/job/${job_name}/config.xml"
    local_file_name="${folder_name}___${job_name}.xml"
  fi

  _jenkins_get "$query" | xmlstarlet format > "local_${local_file_name}"
}

# @description Create or update a Jenkins pipeline.
#
# @example
#    jenkins_job_create SIA_Signalen_Amsterdam
#    jenkins_job_create signalen-release SIA_Signalen_Amsterdam
#
# @arg $1 string job_name - Name of the Jenkins pipeline
# @arg $2 string folder_name - Name of the pipeline folder
#
function jenkins_job_create() {
  local job_name=$1
  local folder_name=$2

  local query
  local job_xml

  if [[ -z $folder_name ]]; then
    query="createItem?name=${job_name}"
    job_xml="${job_name}.xml"
  else
    query="job/${folder_name}/createItem?name=${job_name}"
    job_xml="${folder_name}___${job_name}.xml"
  fi

  _jenkins_post_data "$query" "@cache/${job_xml}"
}

# @description Delete a Jenkins pipeline.
#
# @example
#    jenkins_job_delete SIA_Signalen_Amsterdam
#    jenkins_job_delete signalen-release SIA_Signalen_Amsterdam
#
# @arg $1 string job_name - Name of the Jenkins pipeline
# @arg $2 string folder_name - Name of the pipeline folder
#
function jenkins_job_delete() {
  local job_name=$1
  local folder_name=$2

  if [[ -n $folder_name ]]; then
    echo "deleting jenkins job: ${folder_name}/${job_name}"
    curl -X POST --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" "${JENKINS_DOCKER_URL}/job/${folder_name}/job/${job_name}/doDelete"
  else
    echo "deleting jenkins job: ${job_name}"
    curl -X POST --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" "${JENKINS_DOCKER_URL}/job/${job_name}/doDelete"
  fi
}

# @description List Jenkins pipelines.
#
# @example
#    jenkins_job_list
#
# @noargs
#
function jenkins_job_list() {
  # NOTE: tree is currently 3 levels deep
  _jenkins_get \
    "api/json?tree=jobs\[$JENKINS_JOB_FIELDS,jobs\[$JENKINS_JOB_FIELDS,jobs\[$JENKINS_JOB_FIELDS\]\]\]" | \
    jq '.jobs'
}

# @description Add Jenkinst global GitHub credentials.
#
# @example
#    jenkins_credentials_global_add jpoppe 3233243242343243242344
#
# @arg $1 string github_user - Your GitHub user name
# @arg $2 string github_token - Your secret GitHub Token
#
function jenkins_credentials_global_add() {
  local github_user=$1
  local github_token=$2

  # shellcheck disable=SC2016
  curl -X POST \
    --user "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_TOKEN" \
    --data-urlencode 'json={
      "": "0",
      "credentials": {
        "scope": "GLOBAL",
        "id": "5b5e63e2-8db7-48c7-8e14-41cbd10eeb4a",
        "username": "'"$github_user"'",
        "password": "'"$github_token"'",
        "description": "jenkins github credentials",
        "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
      }
    }' \
    "${JENKINS_DOCKER_URL}/credentials/store/system/domain/_/createCredentials"
}

# @description Trigger a Jenkins pipeline build.
#
# @example
#    jenkins_job_build signalen-acceptance SIA_Signalen_Amsterdam
#
# @arg $1 string job_name - Name of the Jenkins pipeline
# @arg $2 string folder_name - Name of the pipeline folder
# @arg $3 string data - Job parameters could be json, url encoded or data file
#
function jenkins_job_build() {
  # curl -X POST --data "package_name=ABC.tar.gz" --data "release_notes=none" --data "delay=0sec"o
  # https://github.com/stevshil/Shell/blob/master/jenkinsapi/buildJob

  local job_name=$1
  local folder_name=$2
  local data=$3

  echo "data: $data"

  local query
  local local_file_name

  if [[ -z $folder_name ]]; then
    query="job/${job_name}/build"
  else
    query="job/${folder_name}/job/${job_name}/build"
    # query="job/${folder_name}/job/${job_name}/buildWithParameters"
  fi

  _jenkins_post_json "$query" "$data"
}

# @description Bootstap a SIA Docker Jenkins environment.
#
# @example
#    bootstrap_sia_jenkins_environment
#
# @noargs
#
function bootstrap_sia_jenkins_environment() {
  log_info "bootstrap - get the SIA pipelines from production (Make sure shared VPN is active)"
  echo "this requires the following environment values to be set: $JENKINS_PRODUCTION_USER and $JENKINS_PRODUCTION_TOKEN"

  production_jenkins_job_get SIA_Signalen_Amsterdam
  production_jenkins_job_get signalen-release SIA_Signalen_Amsterdam
  production_jenkins_job_get signalen-acceptance SIA_Signalen_Amsterdam

  log_info "bootstrap - adapt the production pipelines to local"

  xmlstarlet edit --inplace \
    --update '//scm/repoOwner' --value "$GITHUB_USER" \
    --update '//scm/repositoryUrl' --value "https://github.com/${GITHUB_USER}/signalen/" \
    cache/SIA_Signalen_Amsterdam.xml

  xmlstarlet edit  --inplace \
    --update '//hudson.plugins.git.UserRemoteConfig[name="signalen"]/url' --value "https://github.com/${GITHUB_USER}/signalen" \
    --update '//hudson.plugins.git.UserRemoteConfig[name="signals-frontend"]/url' --value "https://github.com/${GITHUB_USER}/signals-frontend" \
    cache/SIA_Signalen_Amsterdam___signalen-acceptance.xml

  xmlstarlet edit  --inplace \
    --update '//hudson.plugins.git.UserRemoteConfig[1]/url' --value "https://github.com/${GITHUB_USER}/signalen" \
    --update '//hudson.plugins.git.UserRemoteConfig[2]/url' --value "https://github.com/${GITHUB_USER}/signals-frontend" \
    --update '//scriptPath' --value "Jenkinsfile.release" \
    --update '//credentialsId' --value "31185606-fa65-4aca-b78e-6da37bb39257" \
    --delete '//com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty' \
    --delete '//hudson.plugins.git.extensions.impl.LocalBranch' \
    --delete '//hudson.plugins.throttleconcurrents.ThrottleJobProperty' \
    --delete '//com.synopsys.arc.jenkins.plugins.ownership.jobs.JobOwnerJobProperty' \
    cache/SIA_Signalen_Amsterdam___signalen-release.xml

  log_info "bootstap - installing Jenkins plugins (will take a while, see docker logs for progress)"
  _jenkins_groovy jenkins_install_plugins

  log_info "bootstap - restart Jenkis and wait until it is reachable again"
  jenkins_safe_restart

  log_info "adding ${GITHUB_USER} GitHub credentials to Jenkins"
  jenkins_credentials_global_add "$GITHUB_USER" "$GITHUB_JENKINS_TOKEN"

  log_info "bootstap - set Jenkins environment variables"
  _jenkins_groovy jenkins_set_env_variables

  log_info "bootstap - configure Jenkins Node plugin"
  _jenkins_groovy jenkins_node_js_plugin_configure

  log_info "bootstap - import local SIA pipelines to local Jenkins"
  jenkins_job_create SIA_Signalen_Amsterdam
  jenkins_job_create signalen-acceptance SIA_Signalen_Amsterdam
  jenkins_job_create signalen-release SIA_Signalen_Amsterdam

  log_info "you should now be able to login to Jenkins on: http://localhost:8081, user name: admin, password: admin"
}

# @description Replace pipeline parameters in SIA Jenkinsfiles.
#
# @example
#    jenkins_parameter_replace signalen/Jenkinsfile.acceptance JENKINS_NODE master
#
# @arg $1 string jenkins_file - Path of Jenkinsfile
# @arg $2 string key - Key name which holds value to replace
# @arg $3 string value - Value to replace with
#
function jenkins_parameter_replace() {
  local jenkins_file=$1
  local key=$2
  local value=$3

  $SED -i "s,\(${key} = \).*,\1'${value}'," "$jenkins_file"
}

# @description Prepare the SIA GitHub repositories, this will clone and modify the SIA repositories.
#
# @example
#    prepare_github_repositories
#
# @noargs
#
function prepare_github_repositories() {
  local current_directory

  current_directory=$(pwd)

  log_info "github - check if GitHub repository ${GITHUB_USER}/signalen exists"

  github_repository_exists signalen || {
    cd "$CACHE_DIRECTORY" || { log_error "cache directory does not exist: ${CACHE_DIRECTORY}"; exit 1; }

    github_repo_fork Amsterdam signalen

    cd "./signalen" || { log_error "signalen directory does not exist: ${CACHE_DIRECTORY}"; exit 1; }

    git checkout --track origin/master

    jenkins_parameter_replace ./Jenkinsfile.acceptance JENKINS_TARGET docker
    jenkins_parameter_replace ./Jenkinsfile.acceptance SIGNALEN_REPOSITORY "${GITHUB_USER}/signalen"
    jenkins_parameter_replace ./Jenkinsfile.acceptance SIGNALS_FRONTEND_REPOSITORY "${GITHUB_USER}/signals-frontend"
    jenkins_parameter_replace ./Jenkinsfile.acceptance DOCKER_BUILD_ARG_REGISTRY_HOST localhost:5000
    jenkins_parameter_replace ./Jenkinsfile.acceptance SLACK_NOTIFICATIONS_CHANNEL ""
    jenkins_parameter_replace ./Jenkinsfile.acceptance JENKINS_NODE "master"
    jenkins_parameter_replace ./Jenkinsfile.acceptance DOCKER_REGISTRY_AUTH ""

    jenkins_parameter_replace ./Jenkinsfile.release JENKINS_TARGET docker
    jenkins_parameter_replace ./Jenkinsfile.release SIGNALEN_REPOSITORY "${GITHUB_USER}/signalen"
    jenkins_parameter_replace ./Jenkinsfile.release SIGNALS_FRONTEND_REPOSITORY "${GITHUB_USER}/signals-frontend"
    jenkins_parameter_replace ./Jenkinsfile.release DOCKER_BUILD_ARG_REGISTRY_HOST localhost:5000
    jenkins_parameter_replace ./Jenkinsfile.release SLACK_NOTIFICATIONS_CHANNEL ""
    jenkins_parameter_replace ./Jenkinsfile.release JENKINS_NODE "master"
    jenkins_parameter_replace ./Jenkinsfile.release DOCKER_REGISTRY_AUTH ""

    git commit -a -m 'updated Jenkinsfiles for local testing' && git push

    cd "$current_directory" || { log_error "could not open directory: ${current_directory}"; exit 1; }
  }

  log_info "github - check if GitHub repository ${GITHUB_USER}/signals-frontend exists"
  github_repository_exists signals-frontend || github_repo_fork Amsterdam signals-frontend

  log_info "github - create GitHub signalen web hook"
  github_webhook_create signalen "$SMEE_PROXY_URL"

  log_info "github - create GitHub signals-frontend web hook"
  github_webhook_create signals-frontend "$SMEE_PROXY_URL"
}

##############################################################################
# Check requirements
##############################################################################

log_info "requirements - checking script dependencies"

if [[ "$OSTYPE" == "darwin"* ]]; then
  SED='gsed'
else
  SED='sed'
fi

_check_command git
_check_command jq
_check_command gh
_check_command xmlstarlet
_check_command curl
_check_command $SED

_check_env_variable JENKINS_PRODUCTION_USER "your ci.data.amsterdam Jenkins user account name"
_check_env_variable JENKINS_PRODUCTION_TOKEN "your personal ci.data.amsterdam Jenkins user token"
_check_env_variable GITHUB_JENKINS_TOKEN "your personal GitHub access token with read/write permissions"

_check_directory_exists $CACHE_DIRECTORY

##############################################################################
# Development / Info functions
##############################################################################

# jenkins_plugin_list
# jenkins_job_list

# log_info "development - store Docker Jenkins Pipelines in ./cache"
# jenkins_job_get SIA_Signalen_Amsterdam
# jenkins_job_get signalen-release SIA_Signalen_Amsterdam
# jenkins_job_get signalen-acceptance SIA_Signalen_Amsterdam

# log_info "deleting GitHub repository"
# gh repo-delete "jpoppe/signals-frontend"

# jenkins_job_delete SIA_Signalen_Amsterdam
# jenkins_job_delete signalen-acceptance SIA_Signalen_Amsterdam
# jenkins_job_delete signalen-release SIA_Signalen_Amsterdam

# jenkins_job_build \
#   signalen-acceptance \
#   SIA_Signalen_Amsterdam \
#   '{"parameter": [{"name": "CLEAN_WORKSPACE", "value": "true"}]}'

# jenkins_job_build \
#   signalen-release \
#   SIA_Signalen_Amsterdam \
#   '{"parameter": [{"name": "SIGNALS_FRONTEND_RELEASE_TAG", "value": "master"}, {"name": "SIGNALEN_RELEASE_TAG", "value": "master"}]}'

# log_info "requirements - get github token from user when $GITHUB_JENKINS_TOKEN environment variable is not set"

##############################################################################
# Main
##############################################################################

log_info "requirements - get the  user which is the owner of ${GITHUB_JENKINS_TOKEN}"

GITHUB_USER=$(github_user_get)

log_info "this script will continue with GitHub user: ${GITHUB_USER}"

prepare_github_repositories
bootstrap_sia_jenkins_environment
