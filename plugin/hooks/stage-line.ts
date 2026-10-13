// The stage line's pure part: which stage an agent type runs, which work file a prompt names, how far a work file
// has got, and the status text all of that comes to.

export type Stage =
  | 'stabilization'
  | 'red'
  | 'green'
  | 'refactor'
  | 'fix'
  | 'rework'
  | 'upgrade'
  | 'grill'
  | 'review'

export type Level = 'unit' | 'integration' | 'system'

// What a framework agent stands for on the line. A module agent owns a work file; its stage shows only while none
// of its step agents runs.
export type Role = { stage?: Stage; level?: Level; isModule: boolean; isReadOnly: boolean }

const ROLES: Record<string, Role> = {
  'implement-plan-module': { isModule: true, isReadOnly: false },
  'fix-bug-module': { stage: 'fix', isModule: true, isReadOnly: false },
  'rework-module': { stage: 'rework', isModule: true, isReadOnly: false },
  'upgrade-deps-module': { stage: 'upgrade', isModule: true, isReadOnly: false },
  'stabilize': { stage: 'stabilization', isModule: false, isReadOnly: false },
  'refactor': { stage: 'refactor', isModule: false, isReadOnly: false },
  'grill-design': { stage: 'grill', isModule: false, isReadOnly: true },
  'grill-frontend': { stage: 'grill', isModule: false, isReadOnly: true },
  'review-plan': { stage: 'review', isModule: false, isReadOnly: true },
  'review-plan-facts': { stage: 'review', isModule: false, isReadOnly: true },
}

const STEP = /^(red|green)-(unit|integration|system)$/

const ICONS: Record<Stage, string> = {
  stabilization: '🧱',
  red: '🔴',
  green: '🟢',
  refactor: '🔵',
  fix: '🐞',
  rework: '🔧',
  upgrade: '⬆️',
  grill: '🔍',
  review: '🔎',
}

const STAGE_ORDER: Stage[] = Object.keys(ICONS) as Stage[]
const LEVEL_ORDER: Level[] = ['unit', 'integration', 'system']

export const MAX_SEGMENTS = 3

// The role of an agent type, with any leading `<plugin>:` stripped; undefined for an agent the framework does not
// ship.
export const roleOf = (subagentType: string): Role | undefined => {
  const name = subagentType.slice(subagentType.lastIndexOf(':') + 1)
  const step = STEP.exec(name)

  if (step !== null) {
    return { stage: step[1] as Stage, level: step[2] as Level, isModule: false, isReadOnly: false }
  }

  return ROLES[name]
}

const WORK_FILE = /^Work file: (\S+)\s*$/m
const WORK_PATH =
  /(?:^|[^A-Za-z0-9_])(docs\/[0-9]+-[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)*\/(?:plan|fix|steps|rework|upgrade|bug)\.md)/
const TASK_DIR = /(?:^|[^A-Za-z0-9_])(docs\/[0-9]+-[A-Za-z0-9._-]+)/

// The file or task directory an agent works on, first found of: the `Work file:` line validate-agent-assignment.sh
// prepends; the parent agent's key; the first work file the prompt names; the first task directory. '' when none.
// A refactor pass skips the prompt's work files: fix-bug and rework name every module's in its brief.
export const keyOf = (prompt: string, role: Role, parentKey?: string): string => {
  const text = prompt.replace(/\\/g, '/')
  const header = WORK_FILE.exec(text)?.[1]

  if (header !== undefined && header !== 'none') {
    return header
  }
  if (parentKey !== undefined) {
    return parentKey
  }

  const file = role.stage === 'refactor' ? undefined : WORK_PATH.exec(text)?.[1]

  return file ?? TASK_DIR.exec(text)?.[1] ?? ''
}

// What the line calls a work key: the directory a module's file sits in, or the task's own name when the file
// sits at the top of the task directory.
export const labelOf = (key: string): string => {
  const parts = key.split('/')
  const isFile = parts[parts.length - 1]?.endsWith('.md') === true
  const dir = isFile ? parts.slice(0, -1) : parts

  return dir[dir.length - 1] ?? key
}

const ITEM = /^- \[([ xX])\] [A-Z]+[0-9]+(?:\s|$)/
const CLOSED = /abandoned —/
const FENCE = /^\s*(`{3,}|~{3,})(.*)$/

// Done and total items of a plan, fix, rework or upgrade file. A ticked item is done, and so is an abandoned one.
// Items inside fenced blocks are examples and do not count; a fence closes on its own marker, as the parsers read it.
export const progressOf = (text: string): { done: number; total: number } => {
  let fence: string | undefined
  let done = 0
  let total = 0

  for (const line of text.split(/\r?\n/)) {
    const marker = FENCE.exec(line)

    if (marker !== null) {
      if (fence === undefined) {
        fence = marker[1]
      } else if (marker[1] === fence && marker[2]?.trim() === '') {
        fence = undefined
      }
      continue
    }

    const item = fence === undefined ? ITEM.exec(line) : null

    if (item !== null) {
      total += 1
      if (item[1] !== ' ' || CLOSED.test(line)) {
        done += 1
      }
    }
  }

  return { done, total }
}

const TICK = /(?:^|[\s/"'])(?:plan|fix|rework|upgrade)\.sh["']?\s+tick(?:\s|$)/

// Whether a Bash command ticks an item of a work file.
export const isTick = (command: string): boolean => TICK.test(command.replace(/\\/g, '/'))

export type Running = { role: Role }

export type Segment = { label: string; running: Running[]; percent?: number }

const stagesOf = (running: Running[]): string => {
  const steps = running.filter(r => !r.role.isModule && r.role.stage !== undefined)
  const shown = steps.length > 0 ? steps : running.filter(r => r.role.stage !== undefined)
  const parts: string[] = []

  for (const stage of STAGE_ORDER) {
    const ofStage = shown.filter(r => r.role.stage === stage)

    if (ofStage.length === 0) {
      continue
    }

    const levels = LEVEL_ORDER.map(level => {
      const count = ofStage.filter(r => r.role.level === level).length

      return count === 0 ? '' : count === 1 ? level : `${level} ×${count}`
    }).filter(level => level !== '')
    const unlevelled = ofStage.filter(r => r.role.level === undefined).length
    const head = `${ICONS[stage]}  ${stage}${levels.length === 0 && unlevelled > 1 ? ` ×${unlevelled}` : ''}`

    parts.push([head, ...levels].join(' · '))
  }

  return parts.join(' + ')
}

const segmentText = (segment: Segment): string => {
  const stages = stagesOf(segment.running)
  const percent = segment.percent === undefined ? '' : `${segment.percent}%`

  return [segment.label, [stages, percent].filter(part => part !== '').join(' · ')]
    .filter(part => part !== '')
    .join(' ')
}

// The stage line: one segment per work key, the first MAX_SEGMENTS in full and the rest as `+N`. Undefined when
// nothing runs, which clears the line.
export const lineOf = (segments: Segment[]): string | undefined => {
  if (segments.length === 0) {
    return undefined
  }

  const shown = segments.slice(0, MAX_SEGMENTS).map(segmentText)
  const hidden = segments.length - MAX_SEGMENTS

  return [...shown, ...(hidden > 0 ? [`+${hidden}`] : [])].join(' │ ')
}
