import chalk from 'chalk'
import inquirer from 'inquirer'

import {Release, ReleaseSummary} from './release.interfaces'

import {confirm, exit, pause, renderHeader, menu} from './cli'

import {
  formatDescriptionState,
  formatNumber,
  formatSummary,
  formatVersion,
  loadLast,
  loadReleaseByVersion,
  renderDescription,
  renderGitHubDescription,
  renderLocalDescription,
  startRelease,
  versionIcon
} from './release.cli'

import ReleaseService from './release.service'

const menuGoBack = () => ({name: '🛩  go back ...', value: () => { console.clear() }})

async function manageDescription(release: Release, releaseService: ReleaseService) {
  renderHeader(`manage description (release: ${formatVersion(release)})`)

  await menu(`Manage release ${formatVersion(release)} description`, [
    {
      name: `🦄 update GitHub (${formatNumber(release)})`,
      value: async () => {
        const update = await confirm('Do you want to update the GitHub description')
        if (update) {
          await releaseService.updateGitHubDescription(release.pullRequestId, release.localDescription)
          release.isDescriptionInSync = true // eslint-disable-line require-atomic-updates
        }
      }
    },
    new inquirer.Separator(),
    {
      name: '🐵 show local',
      value: async () => {
        renderLocalDescription(release)
        await pause()
        return manageDescription(release, releaseService)
      }
    },
    {
      name: `🐱 show GitHub (${formatNumber(release)})`,
      value: async () => {
        renderGitHubDescription(release)
        await pause()
        return manageDescription(release, releaseService)
      }
    },
    new inquirer.Separator(),
    menuGoBack()
  ])
}

export async function releaseNew(releaseService: ReleaseService, latestRelease: ReleaseSummary) {
  renderHeader(`start new release | latest ${formatVersion(latestRelease)}`)

  const nextVersion = releaseService.getNextVersion(latestRelease.version)

  await menu('New release', [
    {
      name: `🐁 start a patch release (${chalk.yellow(nextVersion.patch)})`,
      value: () => startRelease(nextVersion.patch, latestRelease.repositoryId, releaseService)
    },
    {
      name: `🐻 start a minor release (${chalk.magenta(nextVersion.minor)})`,
      value: () => startRelease(nextVersion.minor, latestRelease.repositoryId, releaseService)
    },
    {
      name: `🐘 start a major release (${chalk.red(nextVersion.major)})`,
      value: () => startRelease(nextVersion.major, latestRelease.repositoryId, releaseService)
    },
    new inquirer.Separator(),
    menuGoBack()
  ])
}

export async function lastReleases(releaseService: ReleaseService, releases: undefined | any[] = undefined) {
  renderHeader('loading last releases')

  releases = releases ? releases : await loadLast(releaseService) // eslint-disable-line require-atomic-updates

  renderHeader('release summary browser')

  await menu('Choose a release', [
    ...releases.map((release: any) => {
      return {
        name: `${versionIcon(release.version)} ${chalk.green(release.version)}`,
        value: async () => {
          console.clear()
          const fullRelease = await loadReleaseByVersion(release.version, releaseService)
          console.clear()

          renderDescription(fullRelease)

          await pause()
          return lastReleases(releaseService, releases)
        }
      }}),
    new inquirer.Separator(),
    menuGoBack()
  ])
}

export async function mainMenu(
  latestRelease: ReleaseSummary | undefined,
  pendingRelease: Release | undefined,
  releaseService: ReleaseService
): Promise<any> {
  renderHeader('main menu')

  if (pendingRelease) console.log(formatSummary(pendingRelease))

  const choices = []

  if (pendingRelease) {
    choices.push({
      name: `🦄 show summary (${pendingRelease.version})`,
      value: async () => {
        console.clear()
        renderDescription(pendingRelease)
        await pause()
        console.clear()
        return mainMenu(latestRelease, pendingRelease, releaseService)
      }})

    if (pendingRelease.isDescriptionInSync) {
      choices.push({
        name: `🐱 show description (${formatDescriptionState(pendingRelease)})`,
        value: async () => {
          console.clear()
          renderLocalDescription(pendingRelease)
          await pause()
          console.clear()
          return mainMenu(latestRelease, pendingRelease, releaseService)
        }
      })
    } else {
      choices.push({
        name: `🐱 manage description (${formatDescriptionState(pendingRelease)})`,
        value: async () => {
          console.clear()
          await manageDescription(pendingRelease, releaseService)
          return mainMenu(latestRelease, pendingRelease, releaseService)
        }
      })
    }

    choices.push(new inquirer.Separator())
  }

  if (!pendingRelease && latestRelease) {
    choices.push({
      name: '🌱 start new release',
      value: () => releaseNew(releaseService, latestRelease)
    })
  }

  choices.push({
    name: '🌴 browse last releases',
    value: async () => {
      await lastReleases(releaseService)
      return mainMenu(latestRelease, pendingRelease, releaseService)
    }
  })

  choices.push(new inquirer.Separator())

  choices.push({name: '🏁 leave ...', value: () => { exit() }})

  await menu('Choose an action', choices)
}
