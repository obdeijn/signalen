import readPkg from 'read-pkg'

const state = {
  appName: '',
  homePage: ''
}

export default state

export async function initializeState(cwd: string) {
  const packageJson = await readPkg({cwd})

  if (!packageJson) throw new Error('unable to find a package.json')
  if (!packageJson.homepage) throw new Error('homepage is not defined in package.json')

  state.appName = packageJson.name.split('/')[1]
  state.homePage = packageJson.homepage
}
