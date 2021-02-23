def deployDomain(String dockerImageTag, String domain) {
  def appName = "app_signals-${domain}"

  if (env.JENKINS_TARGET == 'docker') {
    log.info("skip deploying domain ${domain} to ${dockerImageTag} as ${appName} since we are not in production mode")
    return
  }

  log.info("deploying domain ${domain} to ${dockerImageTag} as ${appName}")

  try {
    build job: 'Subtask_Openstack_Playbook',
      parameters: [
        [$class: 'StringParameterValue', name: 'INVENTORY', value: dockerImageTag],
        [$class: 'StringParameterValue', name: 'PLAYBOOK', value: 'deploy.yml'],
        [$class: 'StringParameterValue', name: 'PLAYBOOKPARAMS', value: "-e cmdb_id=${appName}"],
      ]
  } catch (Throwable throwable) {
    log.error("deployment of signals-${domain} ${env.RELEASE_DESCRIPTION} failed")
    throw throwable
  }
}

def call(String environment, def domains) {
  def steps = [:]

  domains.each {domain -> steps["DEPLOY_DOMAIN_${domain}_${environment}".toUpperCase()] = {
    deployDomain environment, domain
  }}

  parallel steps
}
