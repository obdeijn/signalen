import chalk from 'chalk'
import inquirer from 'inquirer'
import terminalLink from 'terminal-link'

import state from './state'

const messagePrefix = '🦄'
const messageSuffix = '🌈'

export const renderHeader = (title: string) => {
  console.clear()
  console.log(`${messagePrefix} ${terminalLink(state.appName, state.homePage)} | ${title} ${messageSuffix}`)
  console.log()
}

export const exit = () => {
  console.clear()
  console.log(`Thank you for using ${state.appName} 💙`)
  process.exit(0)
}

export const sleep = (seconds: number) => new Promise(resolve => setTimeout(() => resolve(), seconds * 1000))

export const fatalError = (message: string, data: any | undefined = undefined) => {
  console.clear()

  console.log(`${chalk.red('💀 FATAL ERROR 💀')}`)
  console.log()
  console.log(message)

  if (data) {
    console.log()
    console.log(JSON.stringify(data, null, 2))
  }

  process.exit(2)
}

export const confirm = async (message: string, defaultValue = false) => {
  const prompt = await inquirer.prompt({type: 'confirm', name: 'result', message, default: defaultValue})
  return prompt.result
}

export const pause = async (message = 'hit any key to continue...') => {
  await inquirer.prompt({type: 'input', name: 'result', message})
}

export const menu = async (message: string, choices: any[]) => {
  const response = await inquirer.prompt([{type: 'list', name: 'result', pageSize: 20, message, choices}])
  return response.result()
}
