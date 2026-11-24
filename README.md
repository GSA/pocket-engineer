# Pocket Engineer

Installs an AI assistant that uses GSA's USAi models on your Windows PC with one double-click.
You choose:

- **Pi**, **GitHub Copilot CLI**, or both
- **AI usage dashboard** (optional): lists your past AI sessions and how much you have used

Everything runs privately on your PC inside Ubuntu, a Linux system that
Windows runs in the background (WSL).

## What you need

- Windows 10 or 11, with local administrator rights
- The GSA network or VPN
- A **USAi API key** (from the USAi website)
- 3 GB of free disk space and about 15 minutes

## Install

1. On this page, click the green **Code** button, then **Download ZIP**.
2. Unzip the file, open the folder, and double-click **Install Engineer**.
   If Windows says "Windows protected your PC", click **More info**, then **Run anyway**.
3. If Windows asks to turn on WSL, click **Yes**. If it asks you to restart,
   restart, then double-click **Install Engineer** again.
4. Create an Ubuntu user name and password when asked. They are separate from
   your Windows login. **Remember the password**: the installer may ask for it.
5. Choose Pi, Copilot or both, then choose whether to add the AI usage dashboard.
6. Paste your USAi key when asked (right-click pastes; the key stays hidden),
   then press **Enter**.

If it stops, fix what the message says and double-click **Install Engineer**
again; it continues where it left off. Run it again any time to add Pi,
Copilot or the dashboard.

## Desktop shortcuts

| Shortcut | What it does |
| --- | --- |
| **Pi (AI assistant)** | Gets the latest USAi model list, then opens Pi. Type `/model` in Pi to switch models. |
| **Copilot (AI assistant)** | Gets the latest USAi model list, lets you pick a model (Enter keeps your last one), then opens Copilot |
| **Update USAi key** | Replaces your USAi key |
| **AI usage dashboard** | Shows your AI sessions and usage in your browser (only if you chose it) |

Copilot works on USAi with Claude models only, so only those are listed for it.

## Update your USAi key

Do this whenever you get a new key or your old one expires.

1. Copy your new key from the USAi website.
2. Double-click **Update USAi key**.
3. Right-click to paste the key (it stays hidden), then press **Enter**.

USAi checks the key before it is saved. If USAi rejects it, nothing changes.
Open Pi and Copilot windows use the new key from their next request.

## If something goes wrong

1. Double-click **Install Engineer** again.
2. Still stuck? Send the team a screenshot of the message.
   **Never include your USAi key in a screenshot or message.**

## For technical users

Inside Ubuntu (24.04 or newer, WSL 2), the installer (`linux/install.sh`) puts
pinned, checksum-verified copies of Node.js, Pi
(`@earendil-works/pi-coding-agent`), Copilot CLI (`@github/copilot`) and
AgentsView in `~/.local/share/simple-engineer`. It changes nothing else
except installing `curl`, `python3`, `xz-utils` and `ca-certificates` if
they are missing.

`~/.local/share/simple-engineer/usai.py` connects the tools to USAi
(`https://api.gsa.usai.gov/api/v1`):

- `usai.py pi`: writes the `usai` provider and model list into
  `~/.pi/agent/models.json` (other providers are kept), then starts Pi.
- `usai.py copilot`: starts Copilot with the `COPILOT_PROVIDER_*` variables
  for USAi; your own `~/.copilot` settings are otherwise used as they are.
- `usai.py key`: saves the key in `~/.config/simple-engineer/usai-api-key`
  (readable only by you). Pi and Copilot read it with `usai.py print-key` on
  each request, so it is never in settings files, arguments or environment
  variables.
- `usai.py dashboard`: runs AgentsView at `http://127.0.0.1:18088/`. It reads
  the default Pi and Copilot session folders.
