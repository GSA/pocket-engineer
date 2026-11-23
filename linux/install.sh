#!/usr/bin/env bash
# Runs inside Ubuntu: install the chosen AI tools and the USAi launcher.
# Usage: install.sh [pi] [copilot] [agentsview]
# Safe to run again; anything already installed at the pinned version is kept.
set -euo pipefail

NODE_VERSION=24.11.1
NODE_SHA256=60e3b0a8500819514aca603487c254298cd776de0698d3cd08f11dba5b8289a8
PI_PACKAGE=@earendil-works/pi-coding-agent
PI_VERSION=1.5.2
COPILOT_PACKAGE=@github/copilot
COPILOT_VERSION=1.0.111
AGENTSVIEW_VERSION=0.48.0
AGENTSVIEW_SHA256=4ea250e9de87530d2850ad3903185982db89a99b45d41363458e05cd18f5e5fc

# The Windows installer runs this through `bash <(...)`, so it names the source folder.
here="${SIMPLE_ENGINEER_SOURCE:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
app="$HOME/.local/share/simple-engineer"
want_pi=no want_copilot=no want_agentsview=no
for choice in "$@"; do
    case "$choice" in
        pi) want_pi=yes ;;
        copilot) want_copilot=yes ;;
        agentsview) want_agentsview=yes ;;
        *) echo "Unknown choice: $choice" >&2; exit 2 ;;
    esac
done
if [ "$want_pi$want_copilot" = nono ]; then
    echo "Choose Pi, Copilot or both." >&2
    exit 2
fi
if [ "$(uname -m)" != x86_64 ]; then
    echo "This installer supports 64-bit Intel/AMD PCs only." >&2
    exit 1
fi

umask 077
mkdir -p "$app/bin" "$app/downloads"
if [ -f /etc/ssl/certs/ca-certificates.crt ]; then export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt; fi

missing=()
for package in ca-certificates curl python3 xz-utils; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'ok installed' || missing+=("$package")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing ${missing[*]} (Ubuntu may ask for your Ubuntu password)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq --no-install-recommends "${missing[@]}"
fi

download() {  # download URL SHA256 FILE
    curl --fail --location --silent --show-error --max-time 600 "$1" -o "$3.part"
    echo "$2  $3.part" | sha256sum --check --quiet
    mv "$3.part" "$3"
}

if [ "$("$app/node/bin/node" --version 2>/dev/null)" != "v$NODE_VERSION" ]; then
    echo "Installing Node.js $NODE_VERSION..."
    archive="$app/downloads/node-v$NODE_VERSION-linux-x64.tar.xz"
    download "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" "$NODE_SHA256" "$archive"
    rm -rf "$app/node"
    mkdir -p "$app/node"
    tar -xJf "$archive" -C "$app/node" --strip-components=1
fi
export PATH="$app/node/bin:$PATH"

npm_install() {  # npm_install PACKAGE VERSION
    manifest="$app/npm/lib/node_modules/$1/package.json"
    if [ "$(node -p "require('$manifest').version" 2>/dev/null)" != "$2" ]; then
        echo "Installing $1 $2..."
        npm install --global --no-fund --no-audit --no-update-notifier --loglevel=error --prefix "$app/npm" "$1@$2"
    fi
}
if [ "$want_pi" = yes ]; then npm_install "$PI_PACKAGE" "$PI_VERSION"; fi
if [ "$want_copilot" = yes ]; then npm_install "$COPILOT_PACKAGE" "$COPILOT_VERSION"; fi

if [ "$want_agentsview" = yes ] && ! "$app/bin/agentsview" --version 2>/dev/null | grep -q "^agentsview v$AGENTSVIEW_VERSION "; then
    echo "Installing the AgentsView usage dashboard $AGENTSVIEW_VERSION..."
    archive="$app/downloads/agentsview_${AGENTSVIEW_VERSION}_linux_amd64.tar.gz"
    download "https://github.com/kenn-io/agentsview/releases/download/v$AGENTSVIEW_VERSION/agentsview_${AGENTSVIEW_VERSION}_linux_amd64.tar.gz" \
        "$AGENTSVIEW_SHA256" "$archive"
    tar -xzf "$archive" -C "$app/bin" agentsview
fi

# The Windows download may have Windows line endings; strip them when copying.
sed 's/\r$//' "$here/usai.py" > "$app/usai.py"
chmod 700 "$app/usai.py"
rm -rf "$app/downloads"

installed=()
if [ -x "$app/npm/bin/pi" ]; then installed+=(pi); fi
if [ -x "$app/npm/bin/copilot" ]; then installed+=(copilot); fi
if [ -x "$app/bin/agentsview" ]; then installed+=(agentsview); fi
echo "Installed: ${installed[*]}"
