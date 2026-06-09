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
TOOLS=""
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

# ─── Tool Kits ──────────────────────────────────────────

install_stunt_double() {
  local dir="$1"
  if [ -f "$dir/.stunt.yml" ]; then
    echo "  ✓ stunt-double already installed"
    return 0
  fi
  echo "  → Installing stunt-double..."
  
  # Fetch the template
  curl -sL "https://raw.githubusercontent.com/SuperInstance/stunt-double/main/stunt-double.yml" -o "$dir/.stunt.yml"
  
  # Add to .gitignore if it doesn't exist
  if [ -f "$dir/.gitignore" ] && ! grep -q "\.stunt\." "$dir/.gitignore"; then
    echo ".stunt-*" >> "$dir/.gitignore"
  fi
  
  echo "  ✓ stunt-double installed (./stunt-double.yml added)"
}

install_mmx_toolkit() {
  local dir="$1"
  if grep -q "mmx_toolkit" "$dir/requirements.txt" 2>/dev/null || \
     grep -q "mmx-toolkit" "$dir/setup.cfg" 2>/dev/null || \
     grep -q "mmx-toolkit" "$dir/pyproject.toml" 2>/dev/null; then
    echo "  ✓ mmx-toolkit already installed"
    return 0
  fi
  echo "  → Installing mmx-toolkit..."
  
  if [ -f "$dir/requirements.txt" ]; then
    echo "mmx-toolkit>=0.1" >> "$dir/requirements.txt"
    echo "  ✓ Added to requirements.txt"
  elif [ -f "$dir/setup.py" ]; then
    echo "  → Add 'mmx-toolkit' to install_requires in setup.py"
  else
    echo "  → Create requirements.txt"
    echo "mmx-toolkit>=0.1" > "$dir/requirements.txt"
  fi
}

install_git_storage() {
  local dir="$1"
  echo "  ⏳ git-storage coming soon"
}

install_i2i_vessel() {
  local dir="$1"
  echo "  ⏳ i2i-vessel coming soon"
}

install_ring_buffer() {
  local dir="$1"
  echo "  ⏳ ring-buffer coming soon"
}

# ─── Main ───────────────────────────────────────────────

parse_args() {
  if [ "$1" = "create" ]; then
    MODE="create"
    NEW_NAME="$2"
    shift 2
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --add|-a)
        TOOLS="$2"
        shift 2
        ;;
      --detect|-d)
        MODE="detect"
        REPO="$2"
        shift 2
        ;;
      --with|-w)
        TOOLS="$2"
        shift 2
        ;;
      --help|-h)
        usage
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
  local tools="$2"
  local tmpdir="/tmp/onboard-$repo"

  echo "═══ onboard: $repo ═══"
  echo ""

  # 1. Clone
  echo "→ [1/4] Cloning $repo..."
  rm -rf "$tmpdir"
  gh repo clone "$repo" "$tmpdir" 2>/dev/null
  cd "$tmpdir"

  STACK=$(detect_stack "$tmpdir")
  echo "  Stack detected: ${STACK:-none}" 
  echo ""

  # 2. Install tools
  echo "→ [2/4] Installing tools..."
  IFS=',' read -ra TOOL_LIST <<< "$tools"
  for tool in "${TOOL_LIST[@]}"; do
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

  # 3. Commit
  echo "→ [3/4] Committing..."
  git checkout -b "$BRANCH"
  git add -A 2>/dev/null
  git commit -m "🤖 onboard: add ${tools} tools" 2>/dev/null || echo "  Nothing to commit"
  git push origin "$BRANCH" 2>/dev/null

  # 4. PR
  echo "→ [4/4] Creating PR..."
  gh pr create \
    --repo "$repo" \
    --base main \
    --head "$BRANCH" \
    --title "🤖 Add ${tools} via onboard" \
    --body "This PR adds the following developer tools to your repository:

${tools}

These tools are now ready to use:

${TOOLS}

---

_Generated by [onboard](https://github.com/SuperInstance/onboard)_" 2>/dev/null || echo "  PR already exists or branch conflicts"

  echo ""
  echo "═══ Done ═══"
}

detect_and_suggest() {
  local repo="$1"
  local tmpdir="/tmp/onboard-$repo"

  echo "═══ Detecting: $repo ═══"
  rm -rf "$tmpdir"
  gh repo clone "$repo" "$tmpdir" 2>/dev/null
  cd "$tmpdir"

  STACK=$(detect_stack "$tmpdir")

  echo ""
  echo "Stack: ${STACK:-unknown}"
  echo ""
  echo "Suggested tools:"
  echo "  stunt-double  — x86_64 offload (any repo)"
  echo "  mmx-toolkit   — speech/music/vision (Python repos)"

  if [ -f "$tmpdir/.github/workflows" ]; then
    echo "  git-storage   — git-backed state (web apps)"
  fi

  echo ""
  echo "To install:"
  echo "  onboard $repo --add stunt-double,mmx-toolkit"
}

# ─── Parse & Run ────────────────────────────────────────

if [ $# -eq 0 ]; then
  usage
fi

parse_args "$@"

case "$MODE" in
  add|"")
    onboard_existing "$REPO" "$TOOLS"
    ;;
  detect)
    detect_and_suggest "$REPO"
    ;;
  create)
    echo "Creating $NEW_NAME..."
    gh repo create "$NEW_NAME" --public --description "Created with onboard" 2>/dev/null
    onboard_existing "$NEW_NAME" "$TOOLS"
    ;;
esac
