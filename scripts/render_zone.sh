#!/usr/bin/env bash
# ==============================================================================
# Wharf Zone Renderer
# ==============================================================================
# Renders a DNS zone template with variables from a JSON file.
#
# Usage:
#   ./render_zone.sh <template> <vars.json>
#
# Example:
#   ./render_zone.sh templates/maximalist.tpl vars/example.json
#
# This is a fallback script for when the Rust CLI is not available.
# The Rust version (wharf render-zone) is preferred as it has better validation.

set -euo pipefail

TEMPLATE="${1:-}"
VARS_FILE="${2:-}"

# Check arguments
if [[ -z "$TEMPLATE" || -z "$VARS_FILE" ]]; then
    echo "Usage: $0 <template> <vars.json>" >&2
    exit 1
fi

# Check files exist
if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Template not found: $TEMPLATE" >&2
    exit 1
fi

if [[ ! -f "$VARS_FILE" ]]; then
    echo "Error: Variables file not found: $VARS_FILE" >&2
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed." >&2
    echo "Install with: sudo apt install jq (or equivalent)" >&2
    exit 1
fi

# Read the template
content=$(cat "$TEMPLATE")

# Extract all keys from the JSON file and replace them in the template
while IFS= read -r key; do
    # Get the value for this key
    value=$(jq -r --arg k "$key" '.[$k] // ""' "$VARS_FILE")

    # Escape special characters in the value for sed
    escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')

    # Replace %key% with the value
    content=$(echo "$content" | sed "s/%${key}%/${escaped_value}/g")
done < <(jq -r 'keys[]' "$VARS_FILE")

# Check for unreplaced variables (warnings)
if echo "$content" | grep -qE '%[a-z0-9_]+%'; then
    echo "Warning: Unreplaced variables found:" >&2
    echo "$content" | grep -oE '%[a-z0-9_]+%' | sort | uniq >&2
fi

# Output the rendered zone
echo "$content"
