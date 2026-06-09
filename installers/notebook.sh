install_notebook() {
  local dir="$1"
  if [ -f "$dir/.devcontainer/agent-entrypoint.sh" ]; then
    echo "  ✓ notebook agent already installed"
    return 0
  fi
  echo "  → Installing A2A Notebook Agent..."
  mkdir -p "$dir/.devcontainer"
  cat > "$dir/.devcontainer/devcontainer.json" << 'DEVJSON'
{
  "name": "A2A Notebook Agent",
  "image": "python:3.12",
  "features": {
    "ghcr.io/devcontainers/features/sshd:1": { "version": "latest" },
    "ghcr.io/devcontainers/features/node:1": { "version": "22" }
  },
  "forwardPorts": [8080],
  "portsAttributes": {
    "8080": { "label": "Agent Dashboard", "onAutoForward": "notify" }
  }
}
DEVJSON
  cat > "$dir/.devcontainer/agent-entrypoint.sh" << 'AGENT'
#!/bin/bash
REPO="$(basename $(git rev-parse --show-toplevel))"
echo "═══════════════════════════════════════"
echo "  Notebook Agent - $REPO"
echo "  Dashboard: http://localhost:8080"
echo "═══════════════════════════════════════"
find . -not -path './node_modules/*' -not -path './.git/*' -maxdepth 3 -type f | head -30
npm test 2>/dev/null || cargo check 2>/dev/null || pytest 2>/dev/null || echo "  Done"
AGENT
  chmod +x "$dir/.devcontainer/agent-entrypoint.sh"
  echo "  ✓ notebook agent installed"
}
