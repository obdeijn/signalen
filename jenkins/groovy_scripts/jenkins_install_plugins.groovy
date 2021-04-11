import jenkins.model.*
import jenkins.install.InstallState
import java.util.logging.Logger
import java.net.SocketTimeoutException

def logger = Logger.getLogger("")

def plugins = [
  "ansicolor",
  "cloudbees-folder",
  "docker-plugin",
  "docker-workflow",
  "generic-webhook-trigger",
  "git",
  "git-parameter",
  "github",
  "github-api",
  "github-branch-source",
  "job-dsl",
  "nodejs",
  "pipeline-build-step",
  "pipeline-github-lib",
  "pipeline-graph-analysis",
  "pipeline-input-step",
  "pipeline-milestone-step",
  "pipeline-model-api.jpi",
  "pipeline-model-definition",
  "pipeline-model-definition-plugin",
  "pipeline-rest-api",
  "pipeline-stage-tags-metadata",
  "pipeline-stage-view",
  "timestamper",
  "workflow-aggregator",
  "workflow-cps-global-lib",
  "workflow-job",
  "workflow-multibranch",
  "ws-cleanup"
]

def installPlugin(plugin, name, logger) {
  def attempts = 0
  def success = false
  def installFuture = null

  while(!success && attempts < 3) {
    try {
      attempts++
      logger.info("Installing " + name)
      installFuture = plugin.deploy()

      while(!installFuture.isDone() && !installFuture.isCancelled()) {
        sleep(3000)
      }

      success = true
    } catch(SocketTimeoutException ex) {
      def retrying = attempts < 3 ? "Retrying." : "Too many attempts."

      logger.info("Timed out while installing " + name + ". " + retrying)
    }
  }
  return installFuture
}

def instance = Jenkins.get()
def pluginManager = instance.getPluginManager()
def updateCenter = instance.getUpdateCenter()

updateCenter.updateAllSites()

plugins.each {
  if (!pluginManager.getPlugin(it)) {
    logger.info("Checking UpdateCenter for " + it)
    def plugin = updateCenter.getPlugin(it)
    if (plugin) {
      def installFuture = installPlugin(plugin, it, logger)
      def job = installFuture.get()

      if (job.getErrorMessage()) {
        logger.severe(job.getErrorMessage())
      } else {
        logger.info(it + " installed.")
      }
    }
  } else {
    logger.info(it + " already installed. Skipping.")
  }
}

instance.save()
logger.info("Plugins installed.")

println("Plugins installed:")
println(plugins)
