def validateSchema(String environment, String domain, String signalsFrontendPath) {
  log.info("validating schema: ${domain} ${environment} ${env.RELEASE_DESCRIPTION}")

  nodejs(nodeJSInstallationName: 'node12') {
    dir("${env.WORKSPACE}/signalen") {
      try {
        sh "make validate-local-schema DOMAIN=${domain} ENVIRONMENT=${environment} SIGNALS_FRONTEND_PATH=${signalsFrontendPath}"
      } catch (Throwable throwable) {
        log.error("schema validation failed: ${domain} ${environment}")
        throw throwable
      }
    }
  }
}

def call(String environment, def domains, String signalsFrontendPath = '../signals-frontend') {
  log.console("Validate ${environment} schema's: ${domains.join(', ')}")

  def steps = [:]

  domains.each {domain -> steps["VALIDATE_SCHEMA_${domain}_${environment}".toUpperCase()] = {
    validateSchema environment, domain, signalsFrontendPath
  }}

  parallel steps
}
