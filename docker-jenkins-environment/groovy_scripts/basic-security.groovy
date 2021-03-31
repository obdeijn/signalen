// https://github.com/bishoybassem/aws-jenkins/blob/7bae301b5a2d856fe2c0875e98abb9a29633d2c9/scripts/master-configure.groovy

import jenkins.model.Jenkins
import hudson.security.SecurityRealm
import hudson.security.HudsonPrivateSecurityRealm
import hudson.model.User
import hudson.security.AuthorizationStrategy
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy

Jenkins instance = Jenkins.getInstance()

SecurityRealm securityRealm = new HudsonPrivateSecurityRealm(false)
User user = securityRealm.createAccount('admin', 'admin')
instance.setSecurityRealm(securityRealm)

AuthorizationStrategy strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)

instance.save()
