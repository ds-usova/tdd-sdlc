#!/usr/bin/env bash
# Renders every docs/diagrams/*.puml to an SVG beside it through the public
# PlantUML server. Needs only curl and od; no Java. The source is sent to
# plantuml.com — do not put anything private in a diagram.
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
for puml in "$dir"/*.puml; do
  hex="$(od -An -v -tx1 "$puml" | tr -d ' \n')"
  svg="${puml%.puml}.svg"
  curl -fsS "https://www.plantuml.com/plantuml/svg/~h${hex}" -o "$svg"
  echo "rendered ${svg##*/}"
done
