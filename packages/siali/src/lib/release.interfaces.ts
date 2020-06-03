import {Issue, GroupedIssues} from './issue.interface'

export type SemanticVersion = 'invalid' | 'patch' | 'minor' | 'major'

export interface ReleaseSummary {
  number: number
  title: string
  version: string
  url: string
  description: string
  isDraft: boolean
  publishedAt: string
  repositoryId: string
  pullRequestId: string
  headRefName: string
  state: string
  createdAt: string
  updatedAt: string
}

export interface Release {
  headRefName: string
  semanticVersion: SemanticVersion
  type: string
  title: string
  number: number
  pullRequestId: string
  isDraft: boolean
  description: string
  url: string
  state: string
  createdAt: string
  updatedAt: string
  version: string
  issues: Issue[]
  groupedIssues: GroupedIssues
  localDescription: string
  isDescriptionInSync: boolean
}
