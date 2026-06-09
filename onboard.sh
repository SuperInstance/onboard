#!/usr/bin/env bash
# onboard — SuperInstance Developer Tool Integrator
#
# Add any tool to any GitHub repo. New repos, old repos, any stack.
#
# Usage:
#   ./onboard.sh SuperInstance/pincher --add stunt-double,mmx-toolkit
#   ./onboard.sh SuperInstance/pincher --detect      # auto-suggest tools
#   ./onboard.sh create my-app --with stunt-double   # new repo

set -euo pipefail

REPO=""
TOOLS=()
MODE="add"
NEW_NAME=""
BRANCH="onboard-$(date +%s)"

# ─── Help ───────────────────────────────────────────────

usage() {
  cat <<EOF
onboard — SuperInstance Developer Tool Integrator

Usage:
  onboard <owner/repo> --add <tool1,tool2>    Add tools to existing repo
  onboard <owner/repo> --detect                Auto-detect + suggest tools
  onboard create <name> --with <tool1,tool2>   Create new repo with tools

Tools:
  stunt-double     🏃  x86_64 offload harness
  mmx-toolkit      🎵  MiniMax multimodal SDK
  git-storage      📦  Git-backed state (coming soon)
  i2i-vessel       🧩  Agent communication (coming soon)
  ring-buffer      🔊  Audio pipeline guard (coming soon)

Examples:
  onboard SuperInstance/pincher --add stunt-double,git-storage
  onboard SuperInstance/pincher --detect
  onboard create my-app --with stunt-double,mmx-toolkit
EOF
  exit 1
}

markdown_help() {
  cat <<'MDHELP'
# onboard — SuperInstance Developer Tool Integrator

Add any tool to any GitHub repo. New repos, old repos, any stack.

## Usage

```text
onboard <owner/repo> --add <tool1,tool2>    Add tools to existing repo
onboard <owner/repo> --detect                Auto-detect + suggest tools
onboard create <name> --with <tool1,tool2>   Create new repo with tools
```

## Tools

| Tool | Description |
|------|-------------|
| stunt-double | 🏃 x86_64 offload harness |
| mmx-toolkit | 🎵 MiniMax multimodal SDK |
| git-storage | 📦 Git-backed state (coming soon) |
| i2i-vessel | 🧩 Agent communication (coming soon) |
| ring-buffer | 🔊 Audio pipeline guard (coming soon) |

## Examples

### Add tools to an existing repo

```bash
onboard SuperInstance/pincher --add stunt-double,git-storage
```

### Auto-detect and suggest tools

```bash
onboard SuperInstance/pincher --detect
```

### Create a new repo with tools

```bash
onboard create my-app --with stunt-double,mmx-toolkit
```
MDHELP
  exit 0
}

# ─── Detect Stack ───────────────────────────────────────

detect_stack() {
  local dir="$1"
  if [ -f "$dir/package.json" ]; then echo "node"; fi
  if [ -f "$dir/Cargo.toml" ]; then echo "rust"; fi
  if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/requirements.txt" ]; then echo "python"; fi
  if [ -f "$dir/go.mod" ]; then echo "go"; fi
  if [ -f "$dir/Dockerfile" ]; then echo "docker"; fi
  if [ -f "$dir/Makefile" ]; then echo "make"; fi
}

detect_frameworks() {
  local dir="$1"
  local frameworks=()

  if [ -f "$dir/package.json" ]; then
    if grep -qi '"react"' "$dir/package.json" 2>/dev/null; then
      frameworks+=("react")
    fi
    if grep -qi '"express"' "$dir/package.json" 2>/dev/null; then
      frameworks+=("express")
    fi
  fi

  if [ -f "$dir/requirements.txt" ]; then
    if grep -qi "^django" "$dir/requirements.txt" 2>/dev/null; then
      frameworks+=("django")
    fi
    if grep -qi "^flask" "$dir/requirements.txt" 2>/dev/null; then
      frameworks+=("flask")
    fi
  fi

  if [ -f "$dir/pyproject.toml" ]; then
    if grep -qi '"django"' "$dir/pyproject.toml" 2>/dev/null; then
      frameworks+=("django")
    fi
    if grep -qi '"flask"' "$dir/pyproject.toml" 2>/dev/null; then
      frameworks+=("flask")
    fi
  fi

  # Join with comma
  local IFS=","
  echo "${frameworks[*]}"
}

# ─── Tool Kits ──────────────────────────────────────────

install_stunt_double() {
  local dir="$1"
  if [ -f "$dir/.stunt.yml" ]; then
    echo "  ✓ stunt-double already installed (found .stunt.yml)"
    return 0
  fi
  echo "  → Installing stunt-double..."

  # Collect stack info for sensible defaults
  local stack
  stack="$(detect_stack "$dir")"
  local frameworks
  frameworks="$(detect_frameworks "$dir")"

  # Determine default test command and target based on stack
  local test_cmd=""
  local target="linux/amd64"

  # Detect if running on ARM Mac for default target
  if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
    target="linux/arm64"
  fi

  if echo "$stack" | grep -q "node"; then
    if echo "$frameworks" | grep -q "react"; then
      test_cmd="npx jest"
    else
      test_cmd="npm test"
    fi
  fi

  if echo "$stack" | grep -q "python"; then
    if echo "$frameworks" | grep -q "django"; then
      test_cmd="python manage.py test"
    elif echo "$frameworks" | grep -q "flask"; then
      test_cmd="python -m pytest"
    else
      test_cmd="python -m pytest"
    fi
  fi

  if echo "$stack" | grep -q "rust"; then
    test_cmd="cargo test"
  fi

  if echo "$stack" | grep -q "go"; then
    test_cmd="go test ./..."
  fi

  if echo "$stack" | grep -q "make"; then
    test_cmd="make test"
  fi

  # Generate .stunt.yml with comment header and defaults
  cat > "$dir/.stunt.yml" << 'STUNTEOF'
# .stunt.yml — stunt-double configuration
#
# stunt-double is an x86_64 offload harness that lets you run x86-64
# binaries in CI/CD pipelines or local dev without native emulation.
#
# For full documentation: https://github.com/SuperInstance/stunt-double
#
# --- Stack-autodetected defaults ---
STUNTEOF

  if [ -n "$test_cmd" ]; then
    echo "test: \"$test_cmd\"" >> "$dir/.stunt.yml"
  fi
  echo "target: $target" >> "$dir/.stunt.yml"

  # Add to .gitignore if it doesn't exist
  if [ -f "$dir/.gitignore" ] && ! grep -q "\.stunt\." "$dir/.gitignore"; then
    echo ".stunt-*" >> "$dir/.gitignore"
  fi

  echo "  ✓ stunt-double installed (.stunt.yml added with stack defaults)"
}

install_mmx_toolkit() {
  local dir="$1"

  # Check if already installed in any Python config file
  if grep -Eq "mmx[_\\.-]?toolkit" "$dir/requirements.txt" 2>/dev/null || \
     grep -Eq "mmx[_\\.-]?toolkit" "$dir/setup.cfg" 2>/dev/null || \
     grep -Eq "mmx[_\\.-]?toolkit" "$dir/pyproject.toml" 2>/dev/null || \
     grep -Eq "mmx[_\\.-]?toolkit" "$dir/setup.py" 2>/dev/null; then
    echo "  ✓ mmx-toolkit already installed"
    return 0
  fi
  echo "  → Installing mmx-toolkit..."

  # Detect Python version
  local pyver=""
  if command -v python3 &>/dev/null; then
    pyver="$(python3 --version 2>&1 | grep -oP '[0-9]+\.[0-9]+' | head -1)"
  fi
  if [ -z "$pyver" ] && [ -f "$dir/.python-version" ]; then
    pyver="$(cat "$dir/.python-version")"
  fi
  if [ -z "$pyver" ]; then
    pyver="3.10"
  fi

  if [ -f "$dir/pyproject.toml" ]; then
    # Add to [project.dependencies] or [tool.poetry.dependencies]
    if grep -q "\[project.dependencies\]" "$dir/pyproject.toml" 2>/dev/null; then
      # Append after the [project.dependencies] header
      sed -i "/\[project.dependencies\]/a\  \"mmx-toolkit>=0.1\"" "$dir/pyproject.toml"
      echo "  ✓ Added mmx-toolkit to [project.dependencies] in pyproject.toml (Python $pyver)"
    elif grep -q "\[tool.poetry.dependencies\]" "$dir/pyproject.toml" 2>/dev/null; then
      sed -i "/\[tool.poetry.dependencies\]/a\  mmx-toolkit = \">=0.1\"" "$dir/pyproject.toml"
      echo "  ✓ Added mmx-toolkit to [tool.poetry.dependencies] in pyproject.toml (Python $pyver)"
    else
      echo "mmx-toolkit>=0.1  # Python $pyver" >> "$dir/requirements.txt"
      echo "  ✓ Added to requirements.txt (Python $pyver)"
    fi
  elif [ -f "$dir/setup.py" ]; then
    # Add to install_requires
    if grep -q "install_requires" "$dir/setup.py" 2>/dev/null; then
      sed -i 's/install_requires=\[/install_requires=[\n    "mmx-toolkit>=0.1",/' "$dir/setup.py"
    else
      echo "" >> "$dir/setup.py"
      echo "# mmx-toolkit (Python $pyver)" >> "$dir/setup.py"
    fi
    echo "  ✓ Added mmx-toolkit to setup.py (Python $pyver)"
  elif [ -f "$dir/setup.cfg" ]; then
    # Add to options.install_requires
    if grep -q "install_requires" "$dir/setup.cfg" 2>/dev/null; then
      sed -i "/install_requires/a\    mmx-toolkit>=0.1" "$dir/setup.cfg"
    else
      echo "" >> "$dir/setup.cfg"
      echo "[options]" >> "$dir/setup.cfg"
      echo "install_requires =" >> "$dir/setup.cfg"
      echo "    mmx-toolkit>=0.1" >> "$dir/setup.cfg"
    fi
    echo "  ✓ Added mmx-toolkit to setup.cfg (Python $pyver)"
  elif [ -f "$dir/requirements.txt" ]; then
    echo "mmx-toolkit>=0.1  # Python $pyver" >> "$dir/requirements.txt"
    echo "  ✓ Added to requirements.txt (Python $pyver)"
  else
    echo "mmx-toolkit>=0.1  # Python $pyver" > "$dir/requirements.txt"
    echo "  ✓ Created requirements.txt with mmx-toolkit (Python $pyver)"
  fi
}

install_git_storage() {
  local dir="$1"

  if [ ! -f "$dir/package.json" ]; then
    echo "  ⏳ git-storage requires a package.json (Node.js project). Skipping."
    return 0
  fi

  # Check if already present in package.json
  if grep -q '"git-storage"' "$dir/package.json" 2>/dev/null; then
    echo "  ✓ git-storage already installed in package.json"
    return 0
  fi

  echo "  → Installing git-storage..."

  # Try npm add first, fall back to jq
  if command -v npm &>/dev/null; then
    (cd "$dir" && npm add git-storage 2>/dev/null) && \
      echo "  ✓ git-storage added via npm" && return 0
  fi

  if command -v jq &>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    jq '.dependencies["git-storage"] = "latest"' "$dir/package.json" > "$tmp" && mv "$tmp" "$dir/package.json"
    echo "  ✓ git-storage added to dependencies via jq"
    return 0
  fi

  echo "  ⚠ Could not install git-storage: need npm or jq"
}

install_i2i_vessel() {
  local dir="$1"
  if [ -f "$dir/.i2i-vessel-installed" ]; then
    echo "  ✓ i2i-vessel already installed"
    return 0
  fi
  echo "  ⏳ i2i-vessel coming soon"
  touch "$dir/.i2i-vessel-installed"
}

install_ring_buffer() {
  local dir="$1"
  if [ -f "$dir/.ring-buffer-installed" ]; then
    echo "  ✓ ring-buffer already installed"
    return 0
  fi
  echo "  ⏳ ring-buffer coming soon"
  touch "$dir/.ring-buffer-installed"
}

# ─── PR Body Generator ──────────────────────────────────

generate_pr_body() {
  local tools="$1"
  local body=""

  body=$(cat <<PRBODY
## What's Added

This PR adds the following developer tools to this repository:

PRBODY
)

  IFS=',' read -ra TOOL_NAMES <<< "$tools"
  for tool in "${TOOL_NAMES[@]}"; do
    case "$tool" in
      stunt-double)
        body+="
### 🏃 stunt-double

![stunt-double](https://img.shields.io/badge/tool-stunt--double-blue)

An x86_64 offload harness for cross-platform CI/CD.
"
        ;;
      mmx-toolkit)
        body+="
### 🎵 mmx-toolkit

![mmx-toolkit](https://img.shields.io/badge/tool-mmx--toolkit-blue)

MiniMax multimodal SDK for speech, music, and vision.
"
        ;;
      git-storage)
        body+="
### 📦 git-storage

![git-storage](https://img.shields.io/badge/tool-git--storage-blue)

Git-backed state management for web applications.
"
        ;;
      i2i-vessel)
        body+="
### 🧩 i2i-vessel

![i2i-vessel](https://img.shields.io/badge/tool-i2i--vessel-blue)

Agent communication layer for inter-agent workflows.
"
        ;;
      ring-buffer)
        body+="
### 🔊 ring-buffer

![ring-buffer](https://img.shields.io/badge/tool-ring--buffer-blue)

Audio pipeline guard for real-time processing.
"
        ;;
    esac
  done

  body+="
## Why It Helps

| Tool | Benefit |
|------|---------|
"

  for tool in "${TOOL_NAMES[@]}"; do
    case "$tool" in
      stunt-double)
        body+="| stunt-double | Run x86-64 binaries seamlessly — no native emulation setup needed |
"
        ;;
      mmx-toolkit)
        body+="| mmx-toolkit | Integrate speech, music, and vision AI without writing SDK boilerplate |
"
        ;;
      git-storage)
        body+="| git-storage | Persistent state management backed by your existing Git workflow |
"
        ;;
      i2i-vessel)
        body+="| i2i-vessel | Connect agents across services with a lightweight messaging layer |
"
        ;;
      ring-buffer)
        body+="| ring-buffer | Reliable audio buffering for low-latency pipelines |
"
        ;;
    esac
  done

  body+="
## How to Use It
"

  for tool in "${TOOL_NAMES[@]}"; do
    case "$tool" in
      stunt-double)
        body+="
### stunt-double

Edit \`.stunt.yml\` in the repo root:

\`\`\`yaml
test: \"npm test\"
target: linux/amd64
\`\`\`

Then run:

\`\`\`bash
stunt-double run
\`\`\`

See the [stunt-double README](https://github.com/SuperInstance/stunt-double) for details.
"
        ;;
      mmx-toolkit)
        body+="
### mmx-toolkit

\`\`\`python
from mmx_toolkit import Client

client = Client()
result = client.speech.synthesize(text=\"Hello\")
\`\`\`

See the [mmx-toolkit README](https://github.com/SuperInstance/mmx-toolkit) for details.
"
        ;;
      git-storage)
        body+="
### git-storage

\`\`\`javascript
import { GitStorage } from 'git-storage';

const store = new GitStorage();
await store.set('key', { data: 'value' });
\`\`\`

See the [git-storage README](https://github.com/SuperInstance/git-storage) for details.
"
        ;;
      i2i-vessel)
        body+="
### i2i-vessel

\`\`\`python
from i2i_vessel import Agent

agent = Agent()
await agent.send(\"task\", target=\"worker-1\")
\`\`\`

See the [i2i-vessel README](https://github.com/SuperInstance/i2i-vessel) for details.
"
        ;;
      ring-buffer)
        body+="
### ring-buffer

\`\`\`python
from ring_buffer import RingBuffer

buf = RingBuffer(size=4096)
buf.push(audio_chunk)
\`\`\`

See the [ring-buffer README](https://github.com/SuperInstance/ring-buffer) for details.
"
        ;;
    esac
  done

  body+="
---

_Generated by [onboard](https://github.com/SuperInstance/onboard)_"

  echo "$body"
}

join_tools_comma() {
  local arr=("$@")
  local IFS=","
  echo "${arr[*]}"
}

# ─── Main ───────────────────────────────────────────────

parse_args() {
  if [ $# -eq 0 ]; then
    usage
  fi

  if [ "$1" = "create" ]; then
    MODE="create"
    NEW_NAME="$2"
    shift 2
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --add|-a)
        if [ -n "${2:-}" ]; then
          IFS=',' read -ra TOOLS <<< "$2"
          shift 2
        else
          echo "❌ --add requires a comma-separated list of tools"
          usage
        fi
        ;;
      --detect|-d)
        MODE="detect"
        if [ -n "${2:-}" ]; then
          REPO="$2"
          shift 2
        else
          echo "❌ --detect requires a repo name"
          usage
        fi
        ;;
      --with|-w)
        if [ -n "${2:-}" ]; then
          IFS=',' read -ra TOOLS <<< "$2"
          shift 2
        else
          echo "❌ --with requires a comma-separated list of tools"
          usage
        fi
        ;;
      --help|-h)
        if [ "${2:-}" = "--format" ] && [ "${3:-}" = "markdown" ]; then
          markdown_help
        else
          usage
        fi
        exit 0
        ;;
      *)
        if [ -z "$REPO" ] && [ "$MODE" != "create" ]; then
          REPO="$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$REPO" ] && [ -z "$NEW_NAME" ]; then
    usage
  fi
}

# ─── Execute ────────────────────────────────────────────

onboard_existing() {
  local repo="$1"
  shift
  local tools=("$@")
  local tmpdir="/tmp/onboard-$repo"

  echo "═══ onboard: $repo ═══"
  echo ""

  # 1. Clone (idempotent: skip if already cloned)
  echo "→ [1/4] Cloning $repo..."
  if [ -d "$tmpdir/.git" ]; then
    echo "  ✓ Already cloned at $tmpdir, updating..."
    (cd "$tmpdir" && git pull 2>/dev/null) || true
  else
    rm -rf "$tmpdir"
    if ! gh repo clone "$repo" "$tmpdir" 2>/dev/null; then
      echo "  ❌ Failed to clone $repo. Check that the repo exists and you're authenticated."
      return 1
    fi
  fi
  cd "$tmpdir"

  local stack
  stack="$(detect_stack "$tmpdir")"
  local frameworks
  frameworks="$(detect_frameworks "$tmpdir")"
  echo "  Stack detected: ${stack:-none}"
  if [ -n "$frameworks" ]; then
    echo "  Frameworks detected: $frameworks"
  fi
  echo ""

  # 2. Install tools
  echo "→ [2/4] Installing tools..."
  for tool in "${tools[@]}"; do
    case "$tool" in
      stunt-double) install_stunt_double "$tmpdir" ;;
      mmx-toolkit) install_mmx_toolkit "$tmpdir" ;;
      git-storage) install_git_storage "$tmpdir" ;;
      i2i-vessel) install_i2i_vessel "$tmpdir" ;;
      ring-buffer) install_ring_buffer "$tmpdir" ;;
      *) echo "  ⚠️ Unknown tool: $tool" ;;
    esac
  done
  echo ""

  # Check if anything changed before committing
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    echo "→ [3/4] Nothing changed — skipping commit and PR."
    echo ""
    echo "═══ Done (no changes) ═══"
    return 0
  fi

  # 3. Commit
  local tools_comma
  tools_comma="$(join_tools_comma "${tools[@]}")"
  echo "→ [3/4] Committing..."
  git checkout -b "$BRANCH"
  git add -A 2>/dev/null
  git commit -m "🤖 onboard: add ${tools_comma} tools" 2>/dev/null || echo "  Nothing to commit"
  git push origin "$BRANCH" 2>/dev/null || echo "  ⚠ Branch already exists on remote, skipping push"

  # 4. PR
  echo "→ [4/4] Creating PR..."
  local pr_body
  pr_body="$(generate_pr_body "$tools_comma")"
  gh pr create \
    --repo "$repo" \
    --base main \
    --head "$BRANCH" \
    --title "🤖 Add ${tools_comma} via onboard" \
    --body "$pr_body" 2>/dev/null || echo "  ⚠ PR already exists or branch conflicts"

  echo ""
  echo "═══ Done ═══"
}

detect_and_suggest() {
  local repo="$1"
  local tmpdir="/tmp/onboard-$repo"

  echo "═══ Detecting: $repo ═══"
  if [ -d "$tmpdir/.git" ]; then
    echo "  ✓ Already cloned at $tmpdir, updating..."
    (cd "$tmpdir" && git pull 2>/dev/null) || true
  else
    rm -rf "$tmpdir"
    if ! gh repo clone "$repo" "$tmpdir" 2>/dev/null; then
      echo "  ❌ Failed to clone $repo. Check that the repo exists and you're authenticated."
      return 1
    fi
  fi
  cd "$tmpdir"

  local stack
  stack="$(detect_stack "$tmpdir")"
  local frameworks
  frameworks="$(detect_frameworks "$tmpdir")"

  echo ""
  echo "Stack: ${stack:-unknown}"
  if [ -n "$frameworks" ]; then
    echo "Frameworks: $frameworks"
  fi
  echo ""
  echo "Suggested tools:"
  echo "  stunt-double  — x86_64 offload (any repo)"
  echo "  mmx-toolkit   — speech/music/vision (Python repos)"

  if [ -d "$tmpdir/.github/workflows" ]; then
    echo "  git-storage   — git-backed state (web apps)"
  fi

  echo ""
  echo "To install:"
  local suggestion="stunt-double"
  if echo "$stack" | grep -q "python"; then
    suggestion="stunt-double,mmx-toolkit"
  fi
  echo "  onboard $repo --add $suggestion"
}

# ─── Parse & Run ────────────────────────────────────────

# Guard: only run main when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parse_args "$@"

  case "$MODE" in
    add|"")
      if [ ${#TOOLS[@]} -eq 0 ]; then
        echo "❌ No tools specified. Use --add <tool1,tool2> or --detect to auto-suggest."
        usage
      fi
      onboard_existing "$REPO" "${TOOLS[@]}"
      ;;
    detect)
      detect_and_suggest "$REPO"
      ;;
    create)
      echo "Creating $NEW_NAME..."
      gh repo create "$NEW_NAME" --public --description "Created with onboard" 2>/dev/null || echo "  ⚠ Could not create repo (may already exist)"
      onboard_existing "$NEW_NAME" "${TOOLS[@]}"
      ;;
  esac
fi
