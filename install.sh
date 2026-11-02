#!/usr/bin/env bash
# =============================================================================
# Anchor+ on a small Linux server, in one line
# =============================================================================
# Made for the smallest (free tier) virtual servers: Oracle Cloud's
# VM.Standard.E2.1.Micro and Ampere A1, AWS t2/t3/t4g.micro, Google Cloud's
# e2-micro, a 1 GB VPS. Run as root on a fresh Ubuntu, Debian, Oracle Linux,
# Rocky/Alma/RHEL, Fedora or Amazon Linux server (amd64 or arm64):
#
#   curl -fsSL https://raw.githubusercontent.com/AlxndrJhn/anchor/main/install.sh | sudo bash
#
# With a domain whose DNS already points at the server, Anchor gets HTTPS
# (a Let's Encrypt certificate, through Caddy) on ports 80 and 443:
#
#   curl -fsSL https://raw.githubusercontent.com/AlxndrJhn/anchor/main/install.sh | sudo DOMAIN=notes.example.com bash
#
# It installs Docker if it's missing, adds swap when the server has less than
# 2 GB of memory, opens the port in the server's own firewall, and runs
# Anchor from /opt/anchor. Running it again updates Anchor to the newest
# release and keeps the notes, the settings and the domain.
#
# Settings (environment variables, all optional; remembered for later runs):
#   DOMAIN       serve https://DOMAIN, with Caddy on ports 80 and 443
#   PORT         without DOMAIN, the port Anchor listens on (default 3000)
#   ANCHOR_TAG   the image tag, e.g. fork-preview or fork-0.17.2.36
#                (default fork-latest)
#   ANCHOR_DIR   where it lives (default /opt/anchor)
#   SWAP_SIZE    swap to add on a small server, in MB (default 2048; 0 adds none)
#
# More settings for Anchor itself (OIDC, sign up, ...) go in
# /opt/anchor/anchor.env, followed by `docker compose up -d` in /opt/anchor.
# =============================================================================

# Everything is in main, which runs on the last line, so a download cut short
# by `curl | bash` runs nothing at all.
set -euo pipefail

log() { printf '\033[1;34m[anchor]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[anchor]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[anchor]\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# KEY=value in an env file: replace its line, or add one
set_env() {
  local file=$1 key=$2 value=$3
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
}

get_env() {
  local file=$1 key=$2
  if [ -f "$file" ]; then sed -n "s/^${key}=//p" "$file" | tail -n 1; fi
}

check_system() {
  [ "$(id -u)" -eq 0 ] || die "Run it as root: curl -fsSL <url> | sudo bash"
  [ "$(uname -s)" = Linux ] || die "This is for Linux servers"
  case "$(uname -m)" in
    x86_64 | amd64 | aarch64 | arm64) ;;
    *) die "Anchor's image is for amd64 and arm64, not $(uname -m)" ;;
  esac
  [ -r /etc/os-release ] || die "Can't tell which Linux this is (no /etc/os-release)"
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID=${ID:-}
  OS_LIKE=${ID_LIKE:-}
}

install_docker() {
  if have docker && docker compose version >/dev/null 2>&1; then
    log "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '') is installed"
  else
    log "Installing Docker..."
    case "$OS_ID" in
      ubuntu | debian | raspbian | fedora | centos | rhel)
        docker_script
        ;;
      ol | rocky | almalinux)
        # Docker's script doesn't know these; they take the CentOS packages
        dnf -y install dnf-plugins-core </dev/null
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin </dev/null
        ;;
      amzn)
        dnf -y install docker </dev/null
        install_compose_plugin
        ;;
      *)
        case " $OS_LIKE " in
          *" debian "* | *" ubuntu "* | *" fedora "* | *" rhel "*)
            docker_script
            ;;
          *) die "Install Docker with its Compose plugin, then run this again (no installer for '$OS_ID')" ;;
        esac
        ;;
    esac
  fi
  if have systemctl; then
    systemctl enable --now docker >/dev/null 2>&1 || true
  fi
  docker info >/dev/null 2>&1 || die "Docker is installed but isn't running"
  docker compose version >/dev/null 2>&1 || die "Docker's Compose plugin is missing"
}

# Docker's own install script. Its input isn't this script's: with
# `curl | bash`, that's the rest of this script.
docker_script() {
  local script
  script=$(mktemp)
  curl -fsSL https://get.docker.com -o "$script"
  sh "$script" </dev/null
  rm -f "$script"
}

# Amazon Linux packages Docker without Compose: take it from its releases
install_compose_plugin() {
  local arch dir=/usr/local/lib/docker/cli-plugins
  case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    *) arch=aarch64 ;;
  esac
  mkdir -p "$dir"
  curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${arch}" \
    -o "$dir/docker-compose"
  chmod +x "$dir/docker-compose"
}

# Postgres, the API and the web app need a little more than 1 GB at times
# (imports, reading the text in pictures); swap keeps them from being killed.
add_swap() {
  local mem_mb swap_mb free_mb size=${SWAP_SIZE:-2048}
  mem_mb=$(awk '/^MemTotal:/ {print int($2 / 1024)}' /proc/meminfo)
  swap_mb=$(awk '/^SwapTotal:/ {print int($2 / 1024)}' /proc/meminfo)
  LOW_MEMORY=0
  [ "$mem_mb" -lt 2000 ] && LOW_MEMORY=1
  if [ "$LOW_MEMORY" = 0 ] || [ "$size" -le 0 ] || [ "$swap_mb" -ge 1000 ]; then
    return
  fi
  if [ -e /swapfile ]; then
    warn "/swapfile is there but not in use; leaving it alone"
    return
  fi
  free_mb=$(df -Pm / | awk 'NR == 2 {print $4}')
  if [ "$free_mb" -lt $((size + 3072)) ]; then
    warn "Not enough disk for ${size} MB of swap; Anchor may run short of memory"
    return
  fi
  log "Adding ${size} MB of swap (the server has ${mem_mb} MB of memory)..."
  if ! fallocate -l "${size}M" /swapfile 2>/dev/null; then
    dd if=/dev/zero of=/swapfile bs=1M count="$size" status=none
  fi
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
  # Use it for what's idle, not as memory
  echo 'vm.swappiness=10' >/etc/sysctl.d/90-anchor-swap.conf
  sysctl -q -p /etc/sysctl.d/90-anchor-swap.conf || true
}

load_settings() {
  ANCHOR_DIR=${ANCHOR_DIR:-/opt/anchor}
  mkdir -p "$ANCHOR_DIR"
  chmod 700 "$ANCHOR_DIR"
  CONF="$ANCHOR_DIR/.env"
  ENV_FILE="$ANCHOR_DIR/anchor.env"

  # What an earlier run set, unless given again (DOMAIN= drops the domain)
  OLD_DOMAIN=$(get_env "$CONF" DOMAIN)
  DOMAIN=${DOMAIN-$OLD_DOMAIN}
  PORT=${PORT:-$(get_env "$CONF" PORT)}
  PORT=${PORT:-3000}
  ANCHOR_TAG=${ANCHOR_TAG:-$(get_env "$CONF" ANCHOR_TAG)}
  ANCHOR_TAG=${ANCHOR_TAG:-fork-latest}
  DOMAIN=${DOMAIN#http://}
  DOMAIN=${DOMAIN#https://}
  DOMAIN=${DOMAIN%%/*}
  PUBLIC_IP=$(public_ip)

  touch "$CONF"
  set_env "$CONF" DOMAIN "$DOMAIN"
  set_env "$CONF" PORT "$PORT"
  set_env "$CONF" ANCHOR_TAG "$ANCHOR_TAG"
}

write_anchor_env() {
  if [ ! -f "$ENV_FILE" ]; then
    cat >"$ENV_FILE" <<'EOF'
# Anchor's settings (see "Configure environment" in the README). After a
# change, run `docker compose up -d` in this folder. install.sh keeps what's
# here, and only sets APP_URL when the domain changes.
EOF
  fi
  chmod 600 "$ENV_FILE"
  # Set once: Postgres keeps the password it was first started with
  if [ -z "$(get_env "$ENV_FILE" PG_PASSWORD)" ]; then
    set_env "$ENV_FILE" PG_PASSWORD "$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi
  local app_url
  app_url=$(get_env "$ENV_FILE" APP_URL)
  if [ -n "$DOMAIN" ]; then
    set_env "$ENV_FILE" APP_URL "https://$DOMAIN"
  elif [ -z "$app_url" ] || { [ -n "$OLD_DOMAIN" ] && [ "$app_url" = "https://$OLD_DOMAIN" ]; }; then
    set_env "$ENV_FILE" APP_URL "http://$PUBLIC_IP:$PORT"
  fi
  # Search by what pictures show loads a ~380 MB model: too much for 1 GB
  if [ "$LOW_MEMORY" = 1 ] && [ -z "$(get_env "$ENV_FILE" PICTURE_SEARCH)" ]; then
    set_env "$ENV_FILE" PICTURE_SEARCH off
  fi
}

write_compose() {
  local ports caddy=
  if [ -n "$DOMAIN" ]; then
    ports=
    caddy=$(
      cat <<'EOF'

  # HTTPS for DOMAIN, with a certificate from Let's Encrypt
  caddy:
    image: caddy:2-alpine
    container_name: anchor-caddy
    restart: unless-stopped
    command: caddy reverse-proxy --from ${DOMAIN} --to anchor:3000
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - caddy_data:/data
      - caddy_config:/config
    logging:
      driver: local
    depends_on:
      - anchor
EOF
    )
  else
    ports=$(
      cat <<'EOF'

    ports:
      - "${PORT}:3000"
EOF
    )
  fi
  cat >"$ANCHOR_DIR/docker-compose.yml" <<EOF
# Written by install.sh, which rewrites it on every run: settings go in
# anchor.env (Anchor's own) and .env (DOMAIN, PORT, ANCHOR_TAG).
name: anchor

services:
  anchor:
    image: ghcr.io/alxndrjhn/anchor:\${ANCHOR_TAG}
    container_name: anchor
    restart: unless-stopped
    # Time to shut Postgres down cleanly
    stop_grace_period: 1m
    env_file: anchor.env${ports}
    volumes:
      - anchor_data:/data
    # Rotated logs, so they can't fill a small disk
    logging:
      driver: local${caddy}

volumes:
  anchor_data:
EOF
  if [ -n "$DOMAIN" ]; then
    printf '  caddy_data:\n  caddy_config:\n' >>"$ANCHOR_DIR/docker-compose.yml"
  fi
}

# The server's own firewall. Oracle's Ubuntu images reject everything but SSH
# in iptables; Oracle Linux and RHEL have firewalld.
open_ports() {
  local port ports rules=/etc/iptables/rules.v4 rule
  if [ -n "$DOMAIN" ]; then ports="80 443"; else ports=$PORT; fi
  for port in $ports; do
    if have ufw && ufw status 2>/dev/null | grep -q '^Status: active'; then
      ufw allow "$port/tcp" >/dev/null
    elif have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
      firewall-cmd -q --permanent --add-port="$port/tcp"
    elif have iptables && iptables -S INPUT 2>/dev/null | grep -q -- '-j REJECT'; then
      rule="-p tcp -m state --state NEW -m tcp --dport $port -j ACCEPT"
      # shellcheck disable=SC2086
      iptables -C INPUT $rule 2>/dev/null || iptables -I INPUT 1 $rule
      # And after a reboot: into the saved rules, ahead of the REJECT. Not
      # with iptables-save, which would save Docker's rules too.
      if [ -f "$rules" ] && ! grep -qF -- "-A INPUT $rule" "$rules"; then
        sed -i "0,/^-A INPUT .*-j REJECT/s//-A INPUT $rule\n&/" "$rules"
      fi
    fi
  done
  if have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd -q --reload
  fi
}

# The address the internet sees (a cloud server's own is a private one)
public_ip() {
  curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null ||
    hostname -I 2>/dev/null | awk '{print $1}'
}

start_anchor() {
  cd "$ANCHOR_DIR"
  log "Downloading Anchor (ghcr.io/alxndrjhn/anchor:$ANCHOR_TAG)..."
  docker compose pull -q
  log "Starting Anchor..."
  docker compose up -d --remove-orphans
  # The image before this one, which a small disk can do without
  docker image prune -f >/dev/null 2>&1 || true

  log "Waiting for Anchor to start (a first start takes a minute or two)..."
  local tries=90
  while [ "$tries" -gt 0 ]; do
    tries=$((tries - 1))
    if docker exec anchor curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
      return
    fi
    sleep 2
  done
  die "Anchor didn't answer in 3 minutes. Its log: cd $ANCHOR_DIR && docker compose logs anchor"
}

report() {
  local url
  if [ -n "$DOMAIN" ]; then url="https://$DOMAIN"; else url="http://$PUBLIC_IP:$PORT"; fi
  echo
  log "Anchor is running: $url"
  echo
  echo "  Sign up right away: the first account is the admin."
  if [ -n "$DOMAIN" ]; then
    echo "  The certificate comes once $DOMAIN points at $PUBLIC_IP and ports 80"
    echo "  and 443 are open."
  else
    echo "  Over plain HTTP, passwords and notes cross the internet unencrypted."
    echo "  For HTTPS, point a domain at $PUBLIC_IP and run this again with DOMAIN=<it>."
  fi
  echo
  echo "  Your cloud's firewall must let the port in too (only the server's own"
  echo "  firewall was opened):"
  echo "    Oracle Cloud  VCN > Security List > Ingress rule, TCP, source 0.0.0.0/0"
  echo "    AWS           the instance's security group > Inbound rule"
  echo "    Google Cloud  VPC network > Firewall > rule for the instance"
  echo
  echo "  Update later:  run the same command again"
  echo "  Settings:      $ENV_FILE, then: cd $ANCHOR_DIR && docker compose up -d"
  echo "  Backup:        cd $ANCHOR_DIR && docker compose exec -T anchor backup > anchor-backup-\$(date +%F).tar"
  echo
}

main() {
  check_system
  install_docker
  add_swap
  load_settings
  write_anchor_env
  write_compose
  open_ports
  start_anchor
  report
}

main "$@"
