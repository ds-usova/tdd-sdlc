#!/usr/bin/env bash
# PreToolUse hook on Bash: maps the session to the task directory a framework script call names.
# What the mapping is for is docs/cost-recording.md.
set -u

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat)"
# One jq call, one field per line: this hook runs on every Bash call the session makes.
{
    read -r session_id
    read -r transcript
    read -r cwd
    read -r command_text
} < <(printf '%s' "$input" | jq -r '
    .session_id // "", .transcript_path // "", .cwd // "",
    (.tool_input.command // "" | gsub("[\t]"; " ") | gsub("[\n\r]"; ";"))' | tr -d '\r')
session_id="${session_id:-}"; transcript="${transcript:-}"; cwd="${cwd:-}"; command_text="${command_text:-}"
[ -n "$command_text" ] || exit 0
[ -n "$session_id" ] || exit 0

# A framework script invoked as a command word - plan.sh, fix.sh, rework.sh, upgrade.sh, design.sh,
# cost.sh - with any leading path, quoted or not, after `bash`, `sh` or an env assignment or none. A
# file merely named in an argument does not count. Backslashes are read as slashes.
command_text="$(printf '%s' "$command_text" | tr '\134' '/')"
word='(^|[;&|])[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|bash|sh)[[:space:]]+)*[""'"'"']?'
script='("[^"]*/|"'"'"'[^"'"'"']*/|[^[:space:]""'"'"']*/)?(plan|fix|rework|upgrade|design|cost)\.sh[""'"'"']?([[:space:]]|$)'
printf '%s' "$command_text" | grep -Eq "$word$script" || exit 0

# The first argument naming a task directory. docs/implemented/<n>-<name> does not match, since the
# segment after docs/ is not a number: an archived task maps nothing.
task="$(printf '%s' "$command_text" \
    | grep -Eo '(^|[^A-Za-z0-9_])docs/[0-9]+-[A-Za-z0-9._-]+' \
    | head -1 | sed -E 's|^.*(docs/)|\1|')"
[ -n "$task" ] || exit 0

# Windows hands paths over with backslashes; every path below is used as a POSIX one.
transcript="$(printf '%s' "$transcript" | tr '\134' '/')"
cwd="$(printf '%s' "$cwd" | tr '\134' '/')"

git_dir="$(cd "${cwd:-.}" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)" || exit 0
[ -n "$git_dir" ] || exit 0
case "$git_dir" in
    /*|?:*) ;;
    *) git_dir="${cwd:-.}/$git_dir" ;;
esac

dir="$git_dir/tdd-sdlc/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0
file="$dir/$session_id"

# Five lines: the task, the session transcript, the time of the first framework call, the time of
# the latest, and the machine's UTC offset at the latest, as `date +%z` prints it. The first is kept
# across calls; the rest are rewritten.
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
offset="$(date +%z 2>/dev/null)"
[ -n "$offset" ] || offset="+0000"
first="$(sed -n '3p' "$file" 2>/dev/null)"
[ -n "$first" ] || first="$now"

printf '%s\n%s\n%s\n%s\n%s\n' "$task" "$transcript" "$first" "$now" "$offset" > "$file" 2>/dev/null

find "$dir" -type f -mtime +30 -exec rm -f {} + 2>/dev/null

exit 0
