instance = Jenkins.getInstance()

globalNodeProperties = instance.getGlobalNodeProperties()
envVarsNodePropertyList = globalNodeProperties.getAll(hudson.slaves.EnvironmentVariablesNodeProperty.class)

newEnvVarsNodeProperty = null
envVars = null

if (envVarsNodePropertyList == null || envVarsNodePropertyList.size() == 0) {
  newEnvVarsNodeProperty = new hudson.slaves.EnvironmentVariablesNodeProperty()
  globalNodeProperties.add(newEnvVarsNodeProperty)
  envVars = newEnvVarsNodeProperty.getEnvVars()
} else {
  envVars = envVarsNodePropertyList.get(0).getEnvVars()
}

envVars.put("DOCKER_REGISTRY_HOST", "http://localhost:5000")
envVars.put("DOCKER_REGISTRY", "localhost:5000")

instance.save()
