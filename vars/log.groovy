#!/usr/bin/env groovy

enum Colors {
  BLUE('\u001B[34m'), GREEN('\u001B[32m'), RED('\u001B[31m'), CYAN('\u001B[36m'), PURPLE('\u001B[35m')
  public String xterm_code
  public Colors(String xterm_code) { this.xterm_code = xterm_code }
}

def _sendSlackMessage(String channel, def message, Boolean notificationsEnabled, String color) {
  String slackMessage = "<${env.BUILD_URL}|${env.BUILD_TAG}>"

  if (env.STAGE_NAME) slackMessage += " (stage: ${env.STAGE_NAME})"

  slackMessage += "\n${message}"

  if (notificationsEnabled) {
    slackSend message: slackMessage, channel: channel, color: color
    return
  }

  warning("Slack notifications are disabled, message: ${message}")
}

def _formatMessage(Map message) {
  return message
}

def _formatMessage(def message) {
  return message
}

def _formatMessage(String message) {
  if (env.STAGE_NAME) message = "[${env.STAGE_NAME}] ${message}"
  return message
}

// def console(message, color, tag) {
//   echo(String.format("%s%s %s%s", color.xterm_code, tag, _formatMessage(message), '\u001B[0m'))
// }

def console(message, color, tag) {
  echo(String.format("%s%s %s%s", color.xterm_code, tag, message, '\u001B[0m'))
}

def console(message, color) { echo(String.format("%s%s%s", color.xterm_code, message, '\u001B[0m')) }

// def console(message, color) { echo(String.format("%s%s%s", color.xterm_code, _formatMessage(message), '\u001B[0m')) }

def console(message) { console(message, Colors.CYAN) }

def highlight(message) { console(message, Colors.PURPLE) }

def error(message) { console(message, Colors.RED, '[ERROR]') }

def info(message) { console(message, Colors.GREEN) }

def warning(message) { console(message, Colors.GREEN, '[WARNING]') }

def separator() { console('**********************************************************') }

def notify(String channel, def message, Boolean notificationsEnabled) {
  info(message)
  _sendSlackMessage(channel, message, notificationsEnabled, 'good')
}

def notifyError(String channel, def message, Boolean notificationsEnabled) {
  error(message)
  _sendSlackMessage(channel, message, notificationsEnabled, 'danger')
}
