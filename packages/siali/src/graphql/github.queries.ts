const gql = (string: TemplateStringsArray): string => string.join('')

export const refsQuery = gql`
  query GitRefs($owner: String!, $repository: String!) {
    repository(owner: $owner, name: $repository) {
      refs(last: 100, refPrefix: "refs/") {
        nodes {
          name
        }
      }
    }
  }
`

export const refLastCommitOidQuery = gql`
  query GitRefLastCommitOid(
    $owner: String!
    $repository: String!
    $qualifiedName: String!
  ) {
    repository(owner: $owner, name: $repository) {
      ref(qualifiedName: $qualifiedName) {
        target {
          ... on Commit {
            oid
          }
        }
      }
    }
  }
`

export const pullRequestsQuery = gql`
  query GitHubPullRequests(
    $owner: String!
    $repository: String!
    $states: [PullRequestState!]
    $last: Int!
  ) {
    repository(owner: $owner, name: $repository) {
      pullRequests(baseRefName: "master", states: $states, last: $last) {
        edges {
          node {
            pullRequestId: id
            number
            title
            baseRefName
            headRefName
            url
            createdAt
            updatedAt
            isDraft
            state
            description: body
            author {
              login
            }
          }
        }
      }
    }
  }
`

export const lastReleasesQuery = gql`
  query GitHubLastReleases(
    $owner: String!
    $repository: String!
    $first: Int!
  ) {
    repository(owner: $owner, name: $repository) {
      id
      releases(orderBy: {field: CREATED_AT, direction: DESC}, first: $first) {
        nodes {
          name
          description
          version: tagName
          url
          publishedAt
          pullRequestId: id
          isDraft
          isPrerelease
        }
      }
    }
  }
`

export const searchPullRequestByHeadRefName = gql`
  query GitHubSearchPullRequestByHeadRefName(
    $owner: String!
    $repository: String!
    $headRefName: String!
  ) {
    repository(name: $repository, owner: $owner) {
      pullRequests(headRefName: $headRefName, first: 1) {
        edges {
          node {
            pullRequestId: id
            description: body
            headRefName
            number
            state
            title
            url
          }
        }
      }
    }
  }
`

export const pullRequestIssuesQuery = gql`
  query GitHubPullRequestIssues(
    $owner: String!
    $repository: String!
    $number: Int!
  ) {
    repository(owner: $owner, name: $repository) {
      pullRequest(number: $number) {
        commits(first: 250) {
          totalCount
          edges {
            node {
              commit {
                associatedPullRequests(first: 1) {
                  edges {
                    node {
                      pullRequestId: id
                      description: body
                      headRefName
                      number
                      state
                      title
                      url
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
`
