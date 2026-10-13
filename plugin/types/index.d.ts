// The stage line's text, or null while nothing runs.
export type StageLine = string | null

declare module 'claude-code' {
  interface PluginState {
    'tdd-sdlc': { stageLine: StageLine }
  }
}
