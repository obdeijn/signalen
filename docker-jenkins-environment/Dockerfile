FROM jenkins/jenkins:lts

ENV JENKINS_ADMIN_USER admin
ENV JENKINS_ADMIN_PASSWORD jenkins123

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

COPY ./groovy_scripts/basic-security.groovy /usr/share/jenkins/ref/init.groovy.d/

USER root

RUN apt-get update
RUN apt-get install -y bash build-essential apt-transport-https ca-certificates curl gnupg-agent software-properties-common
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN apt-get update
RUN apt-get install -y docker-ce-cli
