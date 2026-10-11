import type { EngineInterface, Register } from 'claude-code'

import { isTick, keyOf, labelOf, lineOf, progressOf, roleOf } from './stage-line'
import type { Role, Segment } from './stage-line'

type Agent = { key: string; role: Role }

// A file's text, or undefined when it cannot be read.
const readText = ($: EngineInterface, path: string): Promise<string | undefined> =>
  $.fs.read(path).then(
    text => (typeof text === 'string' ? text : undefined),
    () => undefined,
  )

// A work file's text. The key is relative to the repository root, so it is looked for in the session's directory
// and then in each directory above it.
async function readWork($: EngineInterface, key: string): Promise<string | undefined> {
  let dir = (await $.session.cwd()).replace(/\\/g, '/').replace(/\/+$/, '')

  for (;;) {
    const path = `${dir}/${key}`

    if (await $.fs.exists(path).catch(() => false)) {
      return readText($, path)
    }

    const cut = dir.lastIndexOf('/')

    if (cut <= 0) {
      return undefined
    }
    dir = dir.slice(0, cut)
  }
}

// Rereads each work file the keys name and records its done share as a whole percent; a key that is no file, or a
// file with no items, records none.
async function refresh($: EngineInterface, percents: Map<string, number | undefined>, keys: string[]) {
  for (const key of keys) {
    const text = key.endsWith('.md') ? await readWork($, key) : undefined
    const progress = text === undefined ? undefined : progressOf(text)
    const isCounted = progress !== undefined && progress.total > 0

    percents.set(key, isCounted ? Math.floor((progress.done * 100) / progress.total) : undefined)
  }
}

// The stage line: while framework agents run, the status line shows each work file's running stages and how many
// of its items are done. `showStage` off registers nothing.
export const register: Register = (on, options) => {
  if (options.showStage === false) {
    return
  }

  // Every framework agent of the session, by id. An orchestrator ends its turn while a wave runs and is resumed
  // later with no new spawn, so an agent stays known after its turn completes and is active again at its next tool
  // call.
  const known = new Map<string, Agent>()
  const active = new Set<string>()
  const percents = new Map<string, number | undefined>()

  const segments = (): Segment[] => {
    const byKey = new Map<string, Agent[]>()

    for (const id of active) {
      const agent = known.get(id)

      if (agent !== undefined) {
        byKey.set(agent.key, [...(byKey.get(agent.key) ?? []), agent])
      }
    }

    return [...byKey].map(([key, running]) => ({
      label: key === '' ? '' : labelOf(key),
      running,
      percent: running.every(agent => agent.role.isReadOnly) ? undefined : percents.get(key),
    }))
  }

  const reset = () => {
    known.clear()
    active.clear()
    percents.clear()
  }

  on('agent.spawn', async ($, e, next) => {
    const result = await next(e)
    const role = roleOf(e.subagentType)

    if (result.agentId === undefined || role === undefined) {
      return result
    }

    const parent = e.parentAgentId === undefined ? undefined : known.get(e.parentAgentId)
    const key = keyOf(e.prompt, role, parent?.key)

    known.set(result.agentId, { key, role })
    active.add(result.agentId)
    await refresh($, percents, [key])
    $.ui.status(lineOf(segments()))

    return result
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    if (e.agentId !== undefined && known.has(e.agentId) && !active.has(e.agentId)) {
      active.add(e.agentId)
      $.ui.status(lineOf(segments()))
    }

    const result = await next(e)

    if (active.size > 0 && result.deny === undefined && e.tool === 'Bash' && isTick(e.command)) {
      await refresh($, percents, [...percents.keys()])
      $.ui.status(lineOf(segments()))
    }

    return result
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    if (e.agentId !== undefined && active.delete(e.agentId)) {
      $.ui.status(lineOf(segments()))
    }

    return next(e)
  })

  on('session.start', async ($, e, next) => {
    reset()
    $.ui.status(undefined)

    return next(e)
  })

  on('session.end', async ($, e, next) => {
    reset()
    $.ui.status(undefined)

    return next(e)
  })
}
