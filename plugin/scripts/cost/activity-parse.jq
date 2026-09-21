def epoch:
  tostring | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;

def clean_summary:
  tostring | gsub("[\\r\\n\\t ]+"; " ") | .[0:500];

def content_blocks:
  if (.message.content | type) == "array" then .message.content else [] end;

def tool_summary($tool):
  ($tool.input // {}) as $input
  | if ($input.command? | type) == "string" then $input.command
    elif ($input.file_path? | type) == "string" then $input.file_path
    elif ($input.path? | type) == "string" then $input.path
    elif ($input.description? | type) == "string" then $input.description
    elif ($input.prompt? | type) == "string" then $input.prompt
    elif ($input | length) > 0 then ($input | tojson)
    else ""
    end
  | clean_summary;

def clipped($from; $to):
  .started = ([.started, $from] | max)
  | .ended = ([.ended, $to] | min)
  | select((.started | epoch) < (.ended | epoch))
  | .seconds = ((.ended | epoch) - (.started | epoch));

([splits("\\n") | fromjson? | select((.timestamp? | type) == "string")]
 | to_entries) as $rows
| ($rows | map(select(.value.type == "user")) | first | .key // null) as $first_user
| ([$rows[] as $message
    | select($message.value.type == "assistant")
    | ([$rows[] | select(.key < $message.key and .value.type == "user")] | last) as $input
    | select($input != null)
    | select([$rows[]
              | select(.key > $input.key and .key < $message.key)
              | select(.value.type == "assistant")]
             | length == 0)
    | {
        lane: $lane,
        state: "model",
        tool: "",
        summary: ($message.value.message.model // "model turn" | clean_summary),
        started: $input.value.timestamp,
        ended: $message.value.timestamp,
        incomplete: false
      }
    | clipped($from; $to)]) as $models
| ([$rows[] as $row
    | ($row.value | content_blocks[])
    | select(.type == "tool_use" and (.id? | type) == "string")
    | . as $tool
    | ([$rows[]
        | select(.key > $row.key)
        | . as $candidate
        | [($candidate.value | content_blocks[])
           | select(.type == "tool_result" and .tool_use_id == $tool.id)]
        | select(length > 0)
        | {timestamp: $candidate.value.timestamp, key: $candidate.key}]
       | first) as $result
    | (($result != null)
       and (($result.timestamp | epoch) > ($row.value.timestamp | epoch))) as $complete
    | {
        lane: $lane,
        state: (if $complete | not then "unknown"
                elif ($tool.name // "") | test("^(Agent|Task|TaskOutput)$") then "waiting"
                else "tool" end),
        tool: ($tool.name // "Unknown tool" | clean_summary),
        summary: tool_summary($tool),
        call: $tool.id,
        started: $row.value.timestamp,
        ended: (if $complete then $result.timestamp else $to end),
        incomplete: ($complete | not)
      }
    | clipped($from; $to)]
   | unique_by(.call)) as $tools
| ([$rows[]
    | select($first_user != null and .key > $first_user)
    | select(.value.type == "user" and (.value.message.content | type) == "string")
    | . as $resume
    | ($rows[.key - 1].value.timestamp // "") as $previous
    | select($previous != "")
    | {
        lane: $lane,
        state: "waiting",
        tool: "",
        summary: "waiting for resume",
        started: $previous,
        ended: $resume.value.timestamp,
        incomplete: false
      }
    | clipped($from; $to)]) as $idle
| ($models + $tools + $idle
   | unique_by([.lane, .state, .tool, .started, .ended, .summary])
   | sort_by(.started, .ended, .state, .tool))
