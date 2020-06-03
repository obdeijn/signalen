import {graphql} from '@octokit/graphql'
import {graphql as GraphQl} from '@octokit/graphql/dist-types/types'

export default class GitHubService {
  private graphql: GraphQl
  private defaultOptions: {owner: string, repository: string}

  public constructor(repositorySlug: string, token: string) {
    const [owner, repository] = repositorySlug.split('/')
    this.defaultOptions = {owner, repository}

    this.graphql = graphql.defaults({headers: {authorization: `token ${token}`}})
  }

  public query(query: any, options: any = {}): any { return this.graphql(query, {...this.defaultOptions, ...options}) }

  public mutation(mutation: any, options: any = {}) { return this.graphql(mutation, {...this.defaultOptions, ...options}) }
}
