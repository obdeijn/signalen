const gql = (string: TemplateStringsArray): string => string.join('')

export const createBranchMutation = gql`
  mutation GitHubCreateBranch($createRefInput: CreateRefInput!) {
    createRef(input: $createRefInput) {
      ref {
        id
        name
      }
    }
  }
`

export const deleteBranchMutation = gql`
  mutation GitHubDeleteBranch($deleteRefInput: DeleteRefInput!) {
    deleteRef(input: $deleteRefInput) {
      clientMutationId
    }
  }
`

export const createPullRequestMutation = gql`
  mutation GitHubCreatePullRequest(
    $createPullRequestInput: CreatePullRequestInput!
  ) {
    createPullRequest(input: $createPullRequestInput) {
      clientMutationId
      pullRequest {
        id
        baseRefName
        baseRefOid
        body
        headRefName
        headRefOid
        number
        state
        title
        merged_at: mergedAt
        labels(last: 100) {
          nodes {
            name
          }
        }
      }
    }
  }
`

export const updatePullRequestBodyMutation = gql`
  mutation GitHubUpdatePullRequestBody($pullRequestId: ID!, $body: String!) {
    updatePullRequest(input: {pullRequestId: $pullRequestId, body: $body}) {
      pullRequest {
        id
        number
        title
      }
    }
  }
`
