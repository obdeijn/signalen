import {flags} from '@oclif/command'

import {cli, IPromptOptions} from 'cli-ux'

import chalk from 'chalk'

import configuration from './lib/configuration'

const setFlag = async (flagName: string, description: string | undefined, options: IPromptOptions | undefined = undefined) => {
  const configuredValue = configuration.get(flagName)
  if (configuredValue) return configuredValue

  console.log(`Default ${chalk.red(flagName)} is not configured, flag --${chalk.green(flagName)} flag is not specified`)
  console.log()

  if (description) console.log(description)
  const value = await cli.prompt(`Default ${flagName} (will be stored in configuration)`, options)
  if (!value) throw new Error(`flag ${flagName} is required...`)

  configuration.set(flagName, value)

  return value
}

const gitHubTokenInstructions = 'Get personal access GitHub token from https://github.com/settings/tokens/new'
const jiraTokenInstructions = 'Get Jira token from https://id.atlassian.com/manage-profile/security/api-tokens'

export const repository = flags.string({description: 'Repository slug'})
export const setRepository = () => setFlag('repository', undefined, {default: 'Amsterdam/signals-frontend'})

export const gitHubToken = flags.string({description: 'GitHub Personal Access Token'})
export const setGitHubToken = () => setFlag('gitHubToken', gitHubTokenInstructions, {type: 'hide'})

export const jiraUrl = flags.string({description: 'Jira API Url'})
export const setJiraUrl = () => setFlag('jiraUrl', undefined, {default: 'https://datapunt.atlassian.net/'})

export const jiraUser = flags.string({description: 'Jira User (e-mail)'})
export const setJiraUser = () => setFlag('jiraUser', undefined)

export const jiraToken = flags.string({description: 'Jira API Token'})
export const setJiraToken = () => setFlag('jiraToken', jiraTokenInstructions, {type: 'hide'})
