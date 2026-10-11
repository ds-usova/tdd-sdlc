import { describe, expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { isTick, keyOf, labelOf, lineOf, progressOf, roleOf } from './stage-line'
import type { Role } from './stage-line'

const ROOT = '/repo'
const PLAN = 'docs/18-add-widget/module-a/plan.md'

const plan = (ticked: number) =>
  ['RU01', 'RU02', 'GU01', 'GU02']
    .map((id, i) => `- [${i < ticked ? 'x' : ' '}] ${id} · step ${id}`)
    .join('\n')

const role = (subagentType: string): Role => {
  const found = roleOf(subagentType)

  if (found === undefined) {
    throw new Error(`no role for ${subagentType}`)
  }

  return found
}

type World = { files: Record<string, string>; statuses: (string | undefined)[] }

// The world beneath the plugin. Spawns answer with their description as the agent id. The session runs in `cwd`,
// files live under ROOT by their repository-relative path, and every status line the plugin sets is kept. A Bash
// command naming `FAIL` ends in an error, and one naming `DENY` is refused.
const world = (on: On, files: Record<string, string>, cwd = ROOT): World => {
  const statuses: (string | undefined)[] = []
  // The engine may hand a path back with a drive letter and backslashes; the file is found by what follows ROOT.
  const at = (path: string) => {
    const posix = path.replace(/\\/g, '/').replace(/^[A-Za-z]:/, '')

    return posix.startsWith(`${ROOT}/`) ? files[posix.slice(ROOT.length + 1)] : undefined
  }

  on('agent.spawn', ($, e) => ({ model: 'test-model', agentId: e.description }))
  on('session.cwd', () => ({ value: cwd }))
  on('fs.exists', ($, e) => ({ value: at(e.path) !== undefined }))
  on('fs.read', ($, e) => {
    const text = at(e.path)

    if (text === undefined) {
      throw new Error(`ENOENT: ${e.path}`)
    }

    return { value: text }
  })
  on('ui.status', ($, e) => {
    statuses.push(e.text)

    return { value: undefined }
  })
  on('tool.call', ($, e) => {
    const command = e.tool === 'Bash' ? e.command : ''

    if (command.includes('DENY')) {
      return { deny: 'refused' }
    }

    const result = { stdout: '', stderr: '', interrupted: false }

    return command.includes('FAIL') ? { result, isError: true as const } : { result }
  })
  on('turn.complete', () => ({ text: '' }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))

  return { files, statuses }
}

const spawnArgs = (id: string, subagentType: string, prompt: string, parentAgentId?: string) => ({
  tool_use_id: `tu-${id}`,
  prompt,
  description: id,
  subagentType,
  provider: { plugin: 'tdd-sdlc', tier: 'user' as const },
  parentModel: 'test-model',
  background: false,
  fork: false,
  ...(parentAgentId === undefined ? {} : { parentAgentId }),
})

const complete = (agentId: string, isAborted = false) => ({
  answer: '',
  durationMs: 1,
  isAborted,
  turnId: `turn-${agentId}`,
  agentId,
  reason: isAborted ? ('aborted' as const) : ('answer' as const),
})

const header = (workflow: string, file: string, items: string) =>
  `Workflow: ${workflow}\nWork file: ${file}\nAssigned items: ${items}\n\n`

describe('roleOf', () => {
  test('reads a step agent its stage and level, with or without the plugin prefix', () => {
    expect(roleOf('tdd-sdlc:red-unit')).toEqual({
      stage: 'red',
      level: 'unit',
      isModule: false,
      isReadOnly: false,
    })
    expect(roleOf('green-system')?.stage).toBe('green')
    expect(roleOf('tdd-sdlc:implement-plan-module')?.isModule).toBe(true)
    expect(roleOf('tdd-sdlc:review-plan')?.isReadOnly).toBe(true)
  })

  test('knows no agent the framework does not ship', () => {
    expect(roleOf('Explore')).toBeUndefined()
  })
})

describe('keyOf', () => {
  const red = role('red-unit')
  const refactor = role('refactor')

  test('takes the Work file header before the parent and the prompt', () => {
    const prompt = `${header('implement-plan', PLAN, 'RU01')}See docs/9-other/plan.md`

    expect(keyOf(prompt, red, 'docs/9-other/plan.md')).toBe(PLAN)
  })

  test('takes the parent key before the paths a prompt names', () => {
    expect(keyOf('Review docs/9-other/plan.md', red, PLAN)).toBe(PLAN)
  })

  test('falls back to the first work file, then the task directory, reading backslashes as slashes', () => {
    expect(keyOf('Run docs\\7-double-charge\\module-b\\fix.md now', red)).toBe('docs/7-double-charge/module-b/fix.md')
    expect(keyOf('Grill docs/18-add-widget/spec.md', red)).toBe('docs/18-add-widget')
    expect(keyOf('Work file: none\n\nnothing else', red)).toBe('')
  })

  test('gives a refactor pass with no header the task directory, not the first module file', () => {
    const brief = 'Brief: docs/7-double-charge/bug.md, docs/7-double-charge/module-b/fix.md'

    expect(keyOf(brief, refactor)).toBe('docs/7-double-charge')
  })
})

test('labelOf names the module directory, or the task when the file sits at its top', () => {
  expect(labelOf(PLAN)).toBe('module-a')
  expect(labelOf('docs/18-add-widget/plan.md')).toBe('18-add-widget')
  expect(labelOf('docs/18-add-widget')).toBe('18-add-widget')
  expect(labelOf('docs/4-bump/module-c/steps.md')).toBe('module-c')
})

describe('progressOf', () => {
  test('counts ticked and abandoned items as done and skips fenced examples', () => {
    const text = [
      '- [x] FR01 · red · reproduce',
      '- [ ] FG01 · green · abandoned — the cause was elsewhere',
      '- [ ] FG02 · green · fix it',
      '````',
      '```',
      '- [ ] XX01 · a nested example',
      '```',
      '````',
      '- [x] FG03 · green · last',
    ].join('\n')

    expect(progressOf(text)).toEqual({ done: 3, total: 4 })
  })

  test('closes an indented fence on its own marker at any indent, and reads CRLF', () => {
    const text = ['- [x] ST01 · one', '  ```', '- [ ] XX01 · example', '    ```', '- [ ] ST02 · two'].join('\r\n')

    expect(progressOf(text)).toEqual({ done: 1, total: 2 })
  })
})

test('isTick recognises a tick through any script path, quoted or not', () => {
  expect(isTick('bash "/c/plugins/tdd-sdlc/scripts/plan/plan.sh" tick GU07 docs/1-x/plan.md')).toBe(true)
  expect(isTick('bash C:\\p\\scripts\\fix\\fix.sh tick FR01')).toBe(true)
  expect(isTick('bash scripts/upgrade/upgrade.sh tick US01')).toBe(true)
  expect(isTick('bash scripts/plan/plan.sh status')).toBe(false)
  expect(isTick('echo tick')).toBe(false)
})

test('lineOf keeps three segments and counts the rest', () => {
  const red = { role: role('red-unit') }
  const segments = ['a', 'b', 'c', 'd', 'e'].map(label => ({ label, running: [red] }))

  expect(lineOf(segments)).toBe('a 🔴 red · unit │ b 🔴 red · unit │ c 🔴 red · unit │ +2')
  expect(lineOf([])).toBeUndefined()
})

test('shows each step stage and the plan percent, and clears when the agents finish', async ($, on) => {
  const { files, statuses } = world(on, { [PLAN]: plan(1) })

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))
  expect(statuses.at(-1)).toBe('module-a 25%')

  const step = header('implement-plan', PLAN, 'RU01')
  await $.agent.spawn(spawnArgs('ru1', 'tdd-sdlc:red-unit', step, 'module'))
  await $.agent.spawn(spawnArgs('ru2', 'tdd-sdlc:red-unit', step, 'module'))
  await $.agent.spawn(spawnArgs('ri1', 'tdd-sdlc:red-integration', step, 'module'))
  expect(statuses.at(-1)).toBe('module-a 🔴 red · unit ×2 · integration · 25%')

  files[PLAN] = plan(2)
  await $.tool.call({ tool: 'Bash', command: `bash "/p/scripts/plan/plan.sh" tick RU02 ${PLAN}` })
  expect(statuses.at(-1)).toBe('module-a 🔴 red · unit ×2 · integration · 50%')

  await $.turn.complete(complete('ru1'))
  await $.turn.complete(complete('ru2'))
  await $.turn.complete(complete('ri1', true))
  expect(statuses.at(-1)).toBe('module-a 50%')

  await $.turn.complete(complete('module'))
  expect(statuses.at(-1)).toBeUndefined()
})

test('a module that ends its turn on a wave shows again when it resumes', async ($, on) => {
  const { files, statuses } = world(on, { [PLAN]: plan(0) })

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))
  const step = header('implement-plan', PLAN, 'RU01')
  await $.agent.spawn(spawnArgs('ru1', 'tdd-sdlc:red-unit', step, 'module'))
  await $.turn.complete(complete('module'))
  expect(statuses.at(-1)).toBe('module-a 🔴 red · unit · 0%')

  await $.turn.complete(complete('ru1'))
  expect(statuses.at(-1)).toBeUndefined()

  files[PLAN] = plan(1)
  await $.tool.call({ tool: 'Bash', command: `bash plan.sh tick RU01 ${PLAN}`, agentId: 'module' } as never)
  expect(statuses.at(-1)).toBe('module-a 25%')

  await $.agent.spawn(spawnArgs('refactor', 'tdd-sdlc:refactor', 'Clean up the diff', 'module'))
  expect(statuses.at(-1)).toBe('module-a 🔵 refactor · 25%')
})

test('reads the work file from the repository root when the session runs in a subdirectory', async ($, on) => {
  const { statuses } = world(on, { [PLAN]: plan(2) }, `${ROOT}/module-a/src`)

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))

  expect(statuses.at(-1)).toBe('module-a 50%')
})

test('rereads the work file at each spawn, so an edit that is no tick shows', async ($, on) => {
  const { files, statuses } = world(on, { [PLAN]: plan(0) })

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))
  files[PLAN] = plan(3)
  const step = header('implement-plan', PLAN, 'GU01')
  await $.agent.spawn(spawnArgs('gu1', 'tdd-sdlc:green-unit', step, 'module'))

  expect(statuses.at(-1)).toBe('module-a 🟢 green · unit · 75%')
})

test('a tick whose command ends in an error still rereads; a refused one does not', async ($, on) => {
  const { files, statuses } = world(on, { [PLAN]: plan(0) })

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))
  files[PLAN] = plan(1)
  await $.tool.call({ tool: 'Bash', command: `bash plan.sh tick RU01 ${PLAN} && FAIL` })
  expect(statuses.at(-1)).toBe('module-a 25%')

  files[PLAN] = plan(2)
  await $.tool.call({ tool: 'Bash', command: `bash plan.sh tick RU02 ${PLAN} DENY` })
  expect(statuses.at(-1)).toBe('module-a 25%')
})

test('a fix-bug module shows its stage and its own fix file', async ($, on) => {
  const fix = 'docs/7-double-charge/module-b/fix.md'
  const { statuses } = world(on, { [fix]: '- [x] FR01 · red · one\n- [ ] FG01 · green · two' })

  await $.agent.spawn(spawnArgs('fix', 'tdd-sdlc:fix-bug-module', header('fix-bug', fix, 'FR01 FG01')))

  expect(statuses.at(-1)).toBe('module-b 🐞 fix · 50%')
})

test('an upgrade module labels a task-level file by the task', async ($, on) => {
  const upgrade = 'docs/4-bump/upgrade.md'
  const { statuses } = world(on, { [upgrade]: '- [x] US01 · bump · one\n- [x] US02 · bump · two' })

  await $.agent.spawn(spawnArgs('up', 'tdd-sdlc:upgrade-deps-module', header('upgrade-deps', upgrade, 'US01')))

  expect(statuses.at(-1)).toBe('4-bump ⬆️ upgrade · 100%')
})

test('a grill on a task directory shows its stage and no percent', async ($, on) => {
  const { statuses } = world(on, {})

  await $.agent.spawn(spawnArgs('g1', 'tdd-sdlc:grill-design', 'Grill docs/18-add-widget/spec.md'))
  await $.agent.spawn(spawnArgs('g2', 'tdd-sdlc:grill-frontend', 'Grill docs/18-add-widget/spec.md'))

  expect(statuses.at(-1)).toBe('18-add-widget 🔍 grill ×2')
})

test('one segment per plan, a review shows no percent, and plans past three are counted', async ($, on) => {
  const plans = ['a', 'b', 'c', 'd', 'e'].map(name => `docs/18-add-widget/module-${name}/plan.md`)
  const { statuses } = world(on, Object.fromEntries(plans.map(path => [path, plan(1)])))

  await $.agent.spawn(spawnArgs('a', 'tdd-sdlc:implement-plan-module', `Run ${plans[0]}`))
  await $.agent.spawn(spawnArgs('b', 'tdd-sdlc:review-plan', `Review ${plans[1]}`))
  expect(statuses.at(-1)).toBe('module-a 25% │ module-b 🔎 review')

  for (const [i, path] of plans.slice(2).entries()) {
    await $.agent.spawn(spawnArgs(`m${i}`, 'tdd-sdlc:implement-plan-module', `Run ${path}`))
  }
  expect(statuses.at(-1)).toBe('module-a 25% │ module-b 🔎 review │ module-c 25% │ +2')
})

test('a session that ends clears the line and forgets its agents', async ($, on) => {
  const { statuses } = world(on, { [PLAN]: plan(1) })

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))
  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  expect(statuses.at(-1)).toBeUndefined()

  await $.tool.call({ tool: 'Bash', command: 'ls', agentId: 'module' } as never)
  expect(statuses.at(-1)).toBeUndefined()
})

test('an agent the framework does not ship changes nothing', async ($, on) => {
  const { statuses } = world(on, {})

  await $.agent.spawn(spawnArgs('x', 'Explore', 'Look around'))

  expect(statuses).toEqual([])
})

test('showStage off registers nothing', { options: { showStage: false } }, async ($, on) => {
  const { statuses } = world(on, { [PLAN]: plan(1) })

  await $.agent.spawn(spawnArgs('module', 'tdd-sdlc:implement-plan-module', `Run ${PLAN}`))

  expect(statuses).toEqual([])
})
