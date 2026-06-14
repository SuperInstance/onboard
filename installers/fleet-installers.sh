install_fleet_daemon() {
  local dir="$1"
  if [ -f "$dir/fleet-daemon.yml" ]; then
    echo "  ✓ fleet-daemon already installed"
    return 0
  fi
  echo "  → Installing Fleet Daemon (real-time MQTT agent)..."
  # Pull config template from GitHub
  curl -sL "https://raw.githubusercontent.com/SuperInstance/fleet-daemon/main/fleet-daemon.yml" -o "$dir/fleet-daemon.yml" 2>/dev/null || {
    cat > "$dir/fleet-daemon.yml" << 'YML'
agent_id: "${HOSTNAME:-agent}"
broker_url: "wss://broker.hivemq.com:8000/mqtt"
repo_url: ""
repo_dir: /tmp/fleet-workdir
git_poll_interval: 5
log_level: INFO
task_topic: fleet/tasks
log_topic: fleet/logs
status_topic: fleet/agent/status
announce_topic: fleet/agents
YML
  }
  if [ -f "$dir/requirements.txt" ]; then
    if ! grep -q "paho-mqtt" "$dir/requirements.txt" 2>/dev/null; then
      echo "paho-mqtt>=1.6" >> "$dir/requirements.txt"
    fi
  fi
  echo "  ✓ fleet-daemon installed (fleet-daemon.yml)"
  echo "  ℹ️  Run: pip install fleet-daemon && fleet-daemon --config fleet-daemon.yml"
}

install_fleet_dashboard() {
  local dir="$1"
  if [ -f "$dir/fleet-dashboard.html" ] || [ -d "$dir/fleet-dashboard" ]; then
    echo "  ✓ fleet-dashboard already installed"
    return 0
  fi
  echo "  → Installing Fleet C2 Dashboard..."
  if command -v gh &>/dev/null; then
    gh repo clone SuperInstance/fleet-dashboard "$dir/fleet-dashboard" 2>/dev/null || {
      mkdir -p "$dir/fleet-dashboard"
      curl -sL "https://raw.githubusercontent.com/SuperInstance/fleet-dashboard/main/index.html" -o "$dir/fleet-dashboard/index.html"
      curl -sL "https://raw.githubusercontent.com/SuperInstance/fleet-dashboard/main/README.md" -o "$dir/fleet-dashboard/README.md"
    }
  else
    mkdir -p "$dir/fleet-dashboard"
    curl -sL "https://raw.githubusercontent.com/SuperInstance/fleet-dashboard/main/index.html" -o "$dir/fleet-dashboard/index.html"
    curl -sL "https://raw.githubusercontent.com/SuperInstance/fleet-dashboard/main/README.md" -o "$dir/fleet-dashboard/README.md"
  fi
  echo "  ✓ fleet-dashboard installed (fleet-dashboard/)"
  echo "  ℹ️  Open fleet-dashboard/index.html in a browser or deploy to GitHub Pages"
}
