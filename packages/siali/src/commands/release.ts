import Command, {flags} from '@oclif/command'
import {Input} from '@oclif/command/lib/flags'

import {exit, renderHeader, sleep} from '../lib/cli'

import GitHubService from '../lib/github.service'
import JiraService from '../lib/jira.service'
import ReleaseService from '../lib/release.service'

import {loadLatestRelease, loadPendingRelease, loadRelease} from '../lib/release.cli'

import {mainMenu} from '../lib/release.menus'

import {
  gitHubToken,
  jiraToken,
  jiraUrl,
  jiraUser,
  repository,
  setGitHubToken,
  setJiraToken,
  setJiraUrl,
  setJiraUser,
  setRepository
} from '../flags'

export default class ReleaseCommand extends Command {
  static description = 'SIA Release Manager'

  static flags: Input<any> = {
    help: flags.help({char: 'h', description: 'show release help'}),
    repository, gitHubToken, jiraUrl, jiraUser, jiraToken
  }

  async run() {
    const {flags} = this.parse(ReleaseCommand) // eslint-disable-line no-shadow

    renderHeader('manager')

    flags.repository = flags.repository || await setRepository()
    flags.gitHubToken = flags.gitHubToken || await setGitHubToken()
    flags.jiraUrl = flags.jiraUrl || await setJiraUrl()
    flags.jiraUser = flags.jiraUser || await setJiraUser()
    flags.jiraToken = flags.jiraToken || await setJiraToken()

    renderHeader('loading release data')

    const gitHubService = new GitHubService(flags.repository, flags.gitHubToken)
    const jiraService = new JiraService(flags.jiraUser, flags.jiraToken, flags.jiraUrl)
    const releaseService = new ReleaseService(gitHubService, jiraService)

    const latestRelease = await loadLatestRelease(releaseService)
    const pendingRelease = await loadPendingRelease(releaseService)
    const release = pendingRelease ? await loadRelease(pendingRelease, releaseService) : undefined

    await sleep(0.5)

    await mainMenu(latestRelease, release, releaseService)

    exit()
  }
}
