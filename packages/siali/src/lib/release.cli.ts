import chalk from 'chalk'
import plur from 'plur'
import terminalLink from 'terminal-link'

import {cli} from 'cli-ux'

import {JiraIssue, Issue, IssueType, GitHubIssue} from './issue.interface'
import {ReleaseSummary, Release, SemanticVersion} from '../lib/release.interfaces'

import {confirm, pause, fatalError} from './cli'

import ReleaseService, {getSemanticVersionType} from './release.service'

const versionIcons = {
  invalid: '👻',
  patch: '🐁',
  minor: '🐒',
  major: '🐘'
}

const typeIcons = {
  'core task': '🚧',
  'e2e test': '🚥',
  bug: '🐞',
  chore: '🔧',
  story: '📜',
  ticket: '🎫',
  unknown: '🤦'
}

const jiraStatus = (issue: JiraIssue) => terminalLink(
  ['done', 'approved'].includes(issue.status) ? chalk.green(issue.status) : chalk.red(issue.status),
  issue.url
)

const jiraIssueKey = (jiraIssue: JiraIssue) => terminalLink(chalk.magenta(jiraIssue.key), jiraIssue.url)

const renderJiraIssue = (jiraIssue: JiraIssue) => {
  console.log(`  ${jiraIssueKey(jiraIssue)} ${jiraStatus(jiraIssue)} ${jiraIssue.title}`)
}

const pluralUpperCase = (string: string) => plur(string.toUpperCase(), 2)

const typeIcon = (name: IssueType) => typeIcons[name]

const formatSectionHeader = (section: IssueType, count: number) =>
  `${typeIcon(section)} ${pluralUpperCase(section)} (${count})`

export const versionIcon = (version: string) => versionIcons[getSemanticVersionType(version)]
export const semanticVersionIcon = (semanticVersion: SemanticVersion) => versionIcons[semanticVersion]

export const formatLastestState = (latest: any) => `${chalk.green(latest.version)} [${chalk.green('latest')}]`
export const formatNumber = (item: Issue | Release | any) => terminalLink(chalk.blue(`#${item.number}`), item.url)
export const formatPending = () => chalk.yellow('pending')
export const formatVersion = (release: Release | any) => `${terminalLink(chalk.yellow(release.version), release.url)}`
export const formatState = (release: Release) => chalk.yellow(release.state)

export const formatDescriptionState = (release: Release) => release.isDescriptionInSync ?
  chalk.green('in sync') :
  chalk.red('out of sync')

export const formatMultiplePendingError = (releases: any[]) => [
  `Found ${chalk.red(`${releases.length} pending`)} releases 🤦 ${chalk.green('expected 1')}`,
  '',
  releases.map((release: ReleaseSummary) => `${release.title} draft: ${release.isDraft}`).join('\n'),
  '',
  chalk.magenta('please fix...')
].join('\n')

export const formatHeader = (release: Release) => `${release.type} ${formatVersion(release)} [${formatState(release)}]`

export const formatSummary = (release: Release) => {
  const types: string[] = []

  Object.entries(release.groupedIssues).forEach(([section, issues]) => {
    if (issues.length === 0) return
    types.push(`${issues.length} ${typeIcon(section as IssueType)}`)
  })

  return `${formatHeader(release)} | ${types.join(' | ')}\n`
}

export const renderDescription = (release: Release) => {
  console.log(formatHeader(release))
  console.log()

  Object.entries(release.groupedIssues).forEach(([section, issues]) => {
    if (issues.length === 0) return

    console.log(formatSectionHeader(section as IssueType, issues.length))
    console.log()

    issues.forEach((issue: Issue) => {
      console.log(`${formatNumber(issue)} ${issue.displayTitle}`)
      if (issue.jiraParent) renderJiraIssue(issue.jiraParent)
      if (issue.jira) renderJiraIssue(issue.jira)
    })

    console.log()
  })
}

export const renderLocalDescription = (release: Release, clear = true) => {
  if (clear) console.clear()
  console.log(release.localDescription)
  console.log()
}

export const renderGitHubDescription = (release: Release, clear = true) => {
  if (clear) console.clear()
  console.log(release.description)
}

export const loadLast = async (releaseService: ReleaseService) => {
  cli.action.start('Github - load latest releases')
  const releases: ReleaseSummary[] = await releaseService.getLast()
  cli.action.stop()
  return releases
}

export const loadLatestRelease = async (releaseService: ReleaseService) => {
  cli.action.start('Github - get current release state')
  const latest: ReleaseSummary = await releaseService.getLatest()
  cli.action.stop(formatLastestState(latest))
  return latest
}

export const loadPendingRelease = async (releaseService: ReleaseService) => {
  cli.action.start('Github - get pending releases')
  const pendingReleases: ReleaseSummary[] = await releaseService.getPendingPullRequests()
  cli.action.stop()

  if (pendingReleases.length > 1) fatalError(formatMultiplePendingError(pendingReleases))
  if (pendingReleases.length === 0) return
  return pendingReleases[0]
}

export const loadRelease = async (releaseSummary: ReleaseSummary, releaseService: ReleaseService) => {
  cli.action.start(`GitHub - get information about ${releaseSummary.title} ${formatNumber(releaseSummary)}`)

  const gitHubIssues = await releaseService.processGitHubIssues(releaseSummary)

  cli.action.stop()
  console.log()

  const unlinkedJiraIssues = gitHubIssues.filter((issue: GitHubIssue) => issue.jiraKey)

  const linkJiraIssuesProgressBar = cli.progress({
    format: 'Jira - link issues [{bar}] {percentage}% | {value}/{total}',
    barCompleteChar: '\u2588',
    barIncompleteChar: '\u2591'
  })

  linkJiraIssuesProgressBar.start(unlinkedJiraIssues.length, 0)

  let counter = 0
  const issues = []

  for (const gitHubIssue of gitHubIssues) {
    issues.push(await releaseService.processJira(gitHubIssue))

    if (gitHubIssue.jiraKey) {
      counter++
      linkJiraIssuesProgressBar.update(counter)
    }
  }

  linkJiraIssuesProgressBar.stop()

  console.log()

  return releaseService.finalize(releaseSummary, issues)
}

export const loadReleaseByVersion = async (version: string, releaseService: ReleaseService) => {
  const gitHubRelease = await releaseService.getByVersion(version)
  return loadRelease(gitHubRelease, releaseService)
}

export const startRelease = async (version: string, repositoryId: string, releaseService: ReleaseService) => {
  const response = await confirm(`Start new release (${version})`)
  if (!response) return

  const oid = await releaseService.getLastCommitOid('develop')

  await releaseService.createBranch(repositoryId, `refs/heads/release/${version}`, oid)
  await releaseService.createPullRequest(`Release/${version}`, repositoryId, 'master', `refs/heads/release/${version}`)

  await pause()
}
