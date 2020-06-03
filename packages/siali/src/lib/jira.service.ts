import fetch from 'node-fetch'

import {JiraIssue, IssueType} from './issue.interface'

export default class JiraService {
  private token: string
  private headers: {Authorization: string}
  private url: string

  public constructor(user: string, token: string, url: string) {
    this.token = Buffer.from(`${user}:${token}`).toString('base64')
    this.headers = {Authorization: `Basic ${this.token}`}
    this.url = url
  }

  private async get(endpoint: string) {
    const response = await fetch(`${this.url}/rest/api/3/${endpoint}`, {headers: this.headers})
    return response.json()
  }

  private getIssueUrl(jiraKey: string) {
    return `${this.url}/browse/${jiraKey}`
  }

  private getIssueType(title: string, type: string): IssueType {
    if (title.startsWith('[TEST]')) return 'e2e test'
    return type.toLowerCase().replace('sub-task', 'ticket') as IssueType
  }

  public async getIssue(jiraKey: string) {
    const issue = await this.get(`issue/${jiraKey}`)

    const jiraIssue: JiraIssue = {
      key: issue.key,
      type: this.getIssueType(issue.fields.summary, issue.fields.issuetype.name),
      status: issue.fields.status.name.toLowerCase(),
      title: issue.fields.summary.replace('[TEST] ', ''),
      url: this.getIssueUrl(issue.key)
    }

    if (!issue.fields.parent) return {jiraIssue}

    const jiraParentIssueType = this.getIssueType(
      issue.fields.parent.fields.summary,
      issue.fields.parent.fields.issuetype.name
    )

    if (jiraParentIssueType === 'e2e test') jiraIssue.type = jiraParentIssueType

    const jiraParentIssue: JiraIssue = {
      key: issue.fields.parent.key,
      status: issue.fields.parent.fields.status.name.toLowerCase(),
      title: issue.fields.parent.fields.summary.replace('[TEST] ', ''),
      type: this.getIssueType('', issue.fields.parent.fields.issuetype.name),
      url: this.getIssueUrl(issue.fields.parent.key)
    }

    return {jiraIssue, jiraParentIssue}
  }
}
