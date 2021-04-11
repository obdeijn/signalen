import jenkins.model.*
import hudson.model.*
import jenkins.plugins.nodejs.tools.*
import hudson.tools.*

def inst = Jenkins.getInstance()

def desc = inst.getDescriptor("jenkins.plugins.nodejs.tools.NodeJSInstallation")

def versions = ['node12': '12.20.1']
def installations = [];

for (version in versions) {
  def installer = new NodeJSInstaller(version.value, "", 100)
  def installerProps = new InstallSourceProperty([installer])

  installations.push(new NodeJSInstallation(version.key, "", [installerProps]))
}

desc.setInstallations(installations.toArray(new NodeJSInstallation[0]))

desc.save()
