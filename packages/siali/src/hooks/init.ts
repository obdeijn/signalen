import {Hook} from '@oclif/config'

import {initializeState} from '../lib/state'

const initHook: Hook<'init'> = async ({config}): Promise<void> => { await initializeState(config.root) }

export default initHook
