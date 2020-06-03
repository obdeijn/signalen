import plur from 'plur'
import semver from 'semver'

import {Release, SemanticVersion, ReleaseSummary} from './release.interfaces'

import {Issue, IssueStatus, JiraIssue, GitHubIssue, GroupedIssues, IssueType} from './issue.interface'

import {
  lastReleasesQuery,
  pullRequestsQuery,
  pullRequestIssuesQuery,
  searchPullRequestByHeadRefName,
  refLastCommitOidQuery,
  refsQuery
} from '../graphql/github.queries'

import {
  createBranchMutation,
  createPullRequestMutation,
  deleteBranchMutation,
  updatePullRequestBodyMutation
} from '../graphql/github.mutations'

import {fatalError} from './cli'

import GitHubService from './github.service'
import JiraService from './jira.service'

const iconSlugs = {
  bug: ':bug:',
  ticket: ':ticket:',
  story: ':book:',
  chore: ':wrench:',
  unknown: ':face_palm:',
  'e2e test': ':traffic_light:',
  'core task': ':package:'
}

export const getSemanticVersionType = (version: string): SemanticVersion => {
  const semanticVersion = semver.parse(version)
  if (!semanticVersion) return 'invalid'

  if (semanticVersion.patch) return 'patch'
  if (semanticVersion.minor) return 'minor'
  if (semanticVersion.major) return 'major'

  return 'invalid'
}

export default class ReleaseService {
  private gitHubService: GitHubService
  private jiraService: JiraService

  constructor(gitHubService: GitHubService, jiraService: JiraService) {
    this.gitHubService = gitHubService
    this.jiraService = jiraService
  }

  groupIssuesByType(issues: Issue[]) {
    const groupedIssues: GroupedIssues = {
      bug: [],
      story: [],
      ticket: [],
      chore: [],
      'e2e test': [],
      'core task': [],
      unknown: []
    }

    Object.values(issues.reduce((group: GroupedIssues, issue: Issue) => {
      group[issue.type].push(issue)
      return group
    }, groupedIssues))

    return groupedIssues
  }

  getNextVersion(latestVersion: string) {
    return {
      patch: `v${semver.inc(latestVersion, 'patch')}`,
      minor: `v${semver.inc(latestVersion, 'minor')}`,
      major: `v${semver.inc(latestVersion, 'major')}`
    }
  }

  async processGitHubIssues(releaseSummary: ReleaseSummary): Promise<GitHubIssue[]> {
    const response = await this.gitHubService.query(pullRequestIssuesQuery, {number: releaseSummary.number})

    return response.repository.pullRequest.commits.edges
      .map((edge: {node: {commit: any}}): GitHubIssue[] => edge.node.commit.associatedPullRequests.edges[0].node)
      .sort((current: GitHubIssue, next: GitHubIssue) => current.number > next.number ? 1 : -1)
      .reduce((array: GitHubIssue[], gitHubIssue: GitHubIssue) => {
        if (gitHubIssue.number === releaseSummary.number) return array

        if (array.slice(-1)[0]?.number === gitHubIssue.number) return array

        if (gitHubIssue.headRefName.startsWith('sync/')) return array

        const jiraIssueTitleMatch = gitHubIssue.title.match(/sig-\d+/i)
        const jiraIssueRefMatch = gitHubIssue.headRefName.match(/sig-?\d+/i)

        if (gitHubIssue.headRefName.startsWith('feature/')) {
          gitHubIssue.type = 'core task'
        } if (gitHubIssue.headRefName.startsWith('chore')) {
          gitHubIssue.type = 'chore'
          gitHubIssue.displayTitle = gitHubIssue.title.replace(/\(?chore\)? ?/i, '')
        } else if (jiraIssueTitleMatch) {
          gitHubIssue.jiraKey = jiraIssueTitleMatch[0].toUpperCase()
          gitHubIssue.displayTitle = gitHubIssue.title.replace(/\[?sig-\d+\]? ?/i, '')
        } else if (jiraIssueRefMatch) {
          gitHubIssue.jiraKey = jiraIssueRefMatch[0].toUpperCase()
        } else if (gitHubIssue.title.startsWith('chore')) {
          gitHubIssue.type = 'chore'
        }

        if (!gitHubIssue.type) gitHubIssue.type = 'unknown'

        const displayTitle = gitHubIssue.displayTitle ? gitHubIssue.displayTitle : gitHubIssue.title

        gitHubIssue.displayTitle = (displayTitle.charAt(0).toUpperCase() + displayTitle.slice(1))
          .trim()
          .replace(/\.$/, '')

        array.push(gitHubIssue)

        return array
      }, [])
  }

  async processJira(gitHubIssue: GitHubIssue) {
    const issueClone = {...gitHubIssue}
    delete issueClone.jiraKey

    const issue: Issue = {
      ...issueClone,
      status: [],
      ready: Boolean(gitHubIssue.jiraKey)
    }

    if (!gitHubIssue.jiraKey) return issue

    const {jiraIssue, jiraParentIssue} = await this.jiraService.getIssue(gitHubIssue.jiraKey)

    issue.jira = jiraIssue
    issue.status.push(issue.jira.status)
    issue.type = issue.jira.type

    if (jiraParentIssue) {
      issue.jiraParent = jiraParentIssue
      issue.status.push(issue.jiraParent.status)
    }

    issue.ready = issue.status.some((status: IssueStatus) => !['acceptance', 'review'].includes(status))

    return issue
  }

  formatLocalDescription(groupedIssues: GroupedIssues) {
    const markdown: string[] = []
    const markdownJiraUrl = (jiraIssue: JiraIssue) => `[[${jiraIssue.key}](${jiraIssue.url})]`

    Object.entries(groupedIssues).forEach(([section, issues]) => {
      if (issues.length === 0) return

      markdown.push(`## ${iconSlugs[section as IssueType]} ${plur(section.toUpperCase(), 2)} (${issues.length})\n`)
      issues.forEach((issue: Issue) => {
        if (issue.jira) markdown.push(`#${issue.number} ${markdownJiraUrl(issue.jira)} ${issue.displayTitle}`)
        else markdown.push(`#${issue.number} ${issue.displayTitle}`)
      })
    })

    return markdown.join('\n')
  }

  async getPendingPullRequests(limit = 100) {
    const response = await this.gitHubService.query(pullRequestsQuery, {base: 'master', states: 'OPEN', last: limit})
    return [response.repository.pullRequests.edges.map((edge: any) => edge.node)[0]]
  }

  async getLatestPullRequests(limit = 10) {
    const response = await this.gitHubService.query(pullRequestsQuery, {base: 'master', states: 'MERGED', last: limit})
    return response.repository.pullRequests.edges.map((edge: any) => edge.node)
  }

  async getLatest() {
    const response = await this.gitHubService.query(lastReleasesQuery, {first: 1})
    const node = response.repository.releases.nodes[0]
    node.repositoryId = response.repository.id
    return node
  }

  async getLast(limit = 10) {
    const response = await this.gitHubService.query(lastReleasesQuery, {first: limit})
    return response.repository.releases.nodes
  }

  async getByVersion(version: string) {
    const headRefName = `release/${version}`
    const response = await this.gitHubService.query(searchPullRequestByHeadRefName, {headRefName})
    const edges = response.repository.pullRequests.edges

    if (edges.length === 0) fatalError(`failed to get release: ${version}`)

    return edges[0].node
  }

  finalize(releaseSummary: ReleaseSummary, issues: Issue[]): Release {
    const [type, version] = releaseSummary.headRefName.split('/').slice(-2)

    const groupedIssues = this.groupIssuesByType(issues)
    const localDescription = this.formatLocalDescription(groupedIssues)
    const isDescriptionInSync = localDescription === releaseSummary.description

    return {
      ...releaseSummary,
      issues,
      groupedIssues,
      type,
      version,
      semanticVersion: getSemanticVersionType(version),
      localDescription,
      isDescriptionInSync
    }
  }

  createPullRequest(title: string, repositoryId: string, baseRefName: string, headRefName: string) {
    return this.gitHubService.mutation(createPullRequestMutation, {
      createPullRequestInput: {
        title,
        repositoryId,
        baseRefName,
        headRefName
        // body,
      }
    })
  }

  getRefs() {
    return this.gitHubService.query(refsQuery, {})
  }

  async getLastCommitOid(qualifiedName: string) {
    const response = await this.gitHubService.query(refLastCommitOidQuery, {qualifiedName})
    return response.repository.ref.target.oid
  }

  deleteBranch(refId: string) {
    return this.gitHubService.mutation(deleteBranchMutation, {deleteRefInput: {refId}})
  }

  createBranch(repositoryId: string, name: string, oid: string) {
    return this.gitHubService.mutation(createBranchMutation, {createRefInput: {name, repositoryId, oid}})
  }

  updateGitHubDescription(pullRequestId: string, description: string) {
    return this.gitHubService.mutation(updatePullRequestBodyMutation, {pullRequestId, body: description})
  }
}
