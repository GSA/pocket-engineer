# Simple Engineer

Installs GSA's AI engineering tools on your Windows PC with one double-click:

- **Pi**: an AI assistant that uses GSA's USAi models
- **GitHub Copilot on USAi** (optional)
- **AI usage dashboard**: see your AI sessions and how much you have used

Everything runs privately on your PC inside Ubuntu, a Linux system that
Windows runs in the background (WSL).

## What you need

- Windows 10 or 11, with local administrator rights
- The GSA network or VPN
- A **USAi API key** (from the USAi website)
- A **GitHub account** (optional; only for pull requests)
- 10 GB of free disk space and about 30 minutes

## Install

1. On this page, click the green **Code** button, then **Download ZIP**.
2. Unzip the file, open the folder, and double-click **Install Engineer**.
   If Windows says "Windows protected your PC", click **More info**, then **Run anyway**.
3. If Windows asks to turn on WSL, click **Yes**. If it asks you to restart,
   restart, then double-click **Install Engineer** again.
4. Create an Ubuntu user name and password when asked. They are separate from
   your Windows login. **Remember the password**: the installer asks for it.
5. Answer the installer's questions. Pressing **Enter** accepts the default,
   which is fine. It asks which optional tools you want.
6. Paste your USAi key when asked (right-click pastes; the key stays hidden),
   then press **Enter**.

The first install takes about 20 minutes. If it stops, fix what the message
says and double-click **Install Engineer** again; it continues where it left off.

## Shortcuts

Find them in **Start menu > Engineer**. The first three are also on your desktop.

| Shortcut | What it does |
| --- | --- |
| **Pi (AI assistant)** | Opens Pi |
| **Update USAi key** | Replaces your USAi key |
| **AI usage dashboard** | Shows your AI usage in your browser |
| **Copilot (AI assistant)** | Opens Copilot on USAi (only if you chose it) |
| **Check Engineer** | Finds problems and tells you how to fix them |
| **Update Engineer** | Installs the latest version |
| **Remove Engineer** | Uninstalls Engineer (keeps your data unless you choose otherwise) |

## Update your USAi key

Do this whenever you get a new key or your old one expires.

1. Copy your new key from the USAi website.
2. Double-click **Update USAi key**.
3. Right-click to paste the key (it stays hidden), then press **Enter**.
4. Close and reopen any open Pi or Copilot windows.

USAi checks the key before it is saved. If USAi rejects it, nothing changes.

## If something goes wrong

1. Open **Check Engineer** and follow what it says.
2. Double-click **Install Engineer** again.
3. Still stuck? Send the team a screenshot of the message.
   **Never include your USAi key in a screenshot or message.**

## For technical users

This repository is a thin Windows wrapper around
[GSA/the_engineer](https://github.com/GSA/the_engineer), which it installs
into `~/engineer` inside Ubuntu (24.04 or newer, WSL 2). `engineer-ref.txt`
chooses the_engineer branch, tag or commit for the first install; **Update
Engineer** then follows the_engineer `main`. Everything else, including the
command line (`~/engineer/engineer`), is documented there.
