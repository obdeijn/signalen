export type IssueStatus =
  | 'acceptance'
  | 'review'
  | 'approved'
  | 'done'
  | 'unknown';

export type IssueType =
  | 'bug'
  | 'story'
  | 'ticket'
  | 'e2e test'
  | 'core task'
  | 'chore'
  | 'unknown'
  | 'spike'
  | 'task'
  | 'epic';

interface BaseIssue {
  description: string
  displayTitle: string
  headRefName: string
  number: number
  pullRequestId: string
  title: string
  type: IssueType
  url: string
}

export interface GroupedIssues {
  bug: Issue[]
  story: Issue[]
  ticket: Issue[]
  chore: Issue[]
  unknown: Issue[]
  'e2e test': Issue[]
  'core task': Issue[]
  spike: Issue[]
  task: Issue[]
  epic: Issue[]
}

export interface JiraIssue {
  key: string
  type: IssueType
  status: IssueStatus
  title: string
  url: string
}

export interface GitHubIssue extends BaseIssue {
  jiraKey?: string
}

export interface Issue extends BaseIssue {
  jira?: JiraIssue
  jiraParent?: JiraIssue
  status: IssueStatus[]
  ready: boolean
}
