#!/usr/bin/env python3
"""Connect Pi and GitHub Copilot CLI to USAi.

Commands:
  usai.py key         save a new USAi key (checked with USAi first)
  usai.py ensure-key  ask for a key only if none is saved yet
  usai.py print-key   print the saved key (Pi and Copilot run this for each request)
  usai.py pi          refresh the USAi model list, then open Pi
  usai.py copilot     refresh the USAi model list, choose a model, then open Copilot
  usai.py dashboard   run the AgentsView usage dashboard (if installed)

The key is kept in one private file and never placed in settings, arguments or
environment variables.
"""

import getpass
import json
import os
import shlex
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE_URL = "https://api.gsa.usai.gov/api/v1"
HOME = Path.home()
APP = HOME / ".local/share/simple-engineer"
CONFIG = HOME / ".config/simple-engineer"
KEY_FILE = CONFIG / "usai-api-key"
MODELS_FILE = CONFIG / "usai-models.json"
SETTINGS_FILE = CONFIG / "settings.json"
PI_DIR = HOME / ".pi/agent"
DASHBOARD_PORT = 18088
CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt"

DEFAULT_MODEL = "claude-sonnet-5.5"
CHAT_PREFIXES = ("claude-", "claude_", "gpt-", "gpt_", "gemini-")
# Copilot completes tool calls on USAi only with Claude models (checked with Copilot CLI 1.0.111).
COPILOT_PREFIXES = ("claude-", "claude_")
EMBEDDING_MODELS = {"cohere-v4", "cohere_english_v3", "text-embedding-005"}
FALLBACK_MODELS = ["claude-haiku-5.5", "claude-opus-5.5", "claude-sonnet-5.5", "gemini-4-argon",
                   "gpt-6.1-sol-latest-guardrails-defaultv2"]
# Below the providers' ~1M windows; models not listed keep each tool's defaults.
MODEL_LIMITS = {
    **{model: {"contextWindow": 400_000, "maxTokens": 32_000} for model in (
        "claude-haiku-5.5", "claude-opus-5", "claude-opus-5.5", "claude-sonnet-5.5", "gemini-4-argon")},
    **{model: {"contextWindow": 272_000, "maxTokens": 32_000} for model in (
        "gpt-5.6-sol-latest-guardrails-defaultv2", "gpt-6.1-sol-latest-guardrails-defaultv2")},
}
INHERITED_SECRETS = ("USAI_API_KEY", "COPILOT_PROVIDER_API_KEY", "COPILOT_PROVIDER_BEARER_TOKEN",
                     "COPILOT_PROVIDER_HEADERS", "COPILOT_PROVIDERS_CONFIG")


class Problem(Exception):
    pass


def write_private(path, text):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(text)
    os.replace(temporary, path)


def read_json(path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, ValueError):
        return default


def write_json(path, value):
    write_private(path, json.dumps(value, indent=2) + "\n")


def clean_key(key):
    key = key.strip()
    if not key or len(key) > 8192 or any(not 33 <= ord(c) <= 126 for c in key):
        raise Problem("That does not look like a USAi key (it must be one piece of text with no spaces).")
    return key


def load_key():
    try:
        return clean_key(KEY_FILE.read_text())
    except FileNotFoundError:
        return None


def fetch_models(key, timeout=30):
    """Return the model IDs USAi offers for this key."""
    request = urllib.request.Request(BASE_URL + "/models", headers={
        "Authorization": "Bearer " + key, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    ids = sorted({entry["id"] for entry in payload.get("data", [])
                  if isinstance(entry, dict) and isinstance(entry.get("id"), str) and entry["id"].strip()})
    if not ids:
        raise Problem("USAi returned an empty model list.")
    return ids


def save_models(ids):
    write_json(MODELS_FILE, {"models": ids})


def ask_yes_no(question):
    return input(f"{question} [y/N] ").strip().lower() in ("y", "yes")


def key_command():
    if not sys.stdin.isatty():
        raise Problem("Run this in a terminal window; the key is never accepted any other way.")
    print("Paste your USAi API key. It stays hidden while you paste and is never shown.")
    key = clean_key(getpass.getpass("USAi API key: "))
    try:
        save_models(fetch_models(key))
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise Problem("USAi rejected this key. Check that you copied all of it, then try again. "
                          "Nothing was changed.") from None
        raise Problem(f"USAi could not check the key (HTTP {error.code}). Nothing was changed.") from None
    except (urllib.error.URLError, OSError, ValueError):
        print("Could not reach USAi to check the key (are you on the GSA network or VPN?).")
        if not ask_yes_no("Save the key anyway?"):
            raise Problem("Nothing was changed.") from None
    write_private(KEY_FILE, key + "\n")
    print("Your USAi key is saved. Pi and Copilot use it from their next request.")


def require_key():
    if load_key():
        return
    print("No USAi key is saved yet.")
    key_command()


def refresh_models():
    """Return the current USAi model list, falling back to the last saved list when offline."""
    try:
        ids = fetch_models(load_key(), timeout=10)
        save_models(ids)
        return ids
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise Problem("USAi rejected your saved key. Double-click \"Update USAi key\" "
                          "and paste a new one.") from None
        reason = f"HTTP {error.code}"
    except (urllib.error.URLError, OSError, ValueError, Problem) as error:
        reason = str(error) or type(error).__name__
    ids = read_json(MODELS_FILE, {}).get("models") or FALLBACK_MODELS
    print(f"Could not refresh the model list from USAi ({reason}); using the last saved list.")
    return ids


def chat_models(ids, prefixes=CHAT_PREFIXES):
    return [model for model in ids if model.startswith(prefixes) and model not in EMBEDDING_MODELS]


def preferred(models, current):
    for model in (current, DEFAULT_MODEL):
        if model in models:
            return model
    return models[0]


def key_command_line():
    return shlex.join([sys.executable, str(Path(__file__).resolve()), "print-key"])


def tool_env():
    env = {name: value for name, value in os.environ.items() if name not in INHERITED_SECRETS}
    env["PATH"] = os.pathsep.join([str(APP / "npm/bin"), str(APP / "node/bin"), env.get("PATH", "")])
    if Path(CA_BUNDLE).is_file():
        env.setdefault("NODE_EXTRA_CA_CERTS", CA_BUNDLE)
    return env


def configure_pi(ids):
    """Point Pi's "usai" provider at USAi with the current model list; other providers are kept."""
    models = chat_models(ids)
    if not models:
        raise Problem("USAi offers no chat models for Pi right now.")
    path = PI_DIR / "models.json"
    config = read_json(path, {})
    config.setdefault("providers", {})["usai"] = {
        "baseUrl": BASE_URL,
        "api": "openai-completions",
        "apiKey": "!" + key_command_line(),
        "models": [{"id": model, "compat": {"supportsDeveloperRole": False}, **MODEL_LIMITS.get(model, {})}
                   for model in models],
    }
    write_json(path, config)
    settings_path = PI_DIR / "settings.json"
    settings = read_json(settings_path, {})
    current = settings.get("defaultModel") if settings.get("defaultProvider") == "usai" else None
    settings.update({"defaultProvider": "usai", "defaultModel": preferred(models, current)})
    write_json(settings_path, settings)
    print(f"Pi is connected to USAi ({len(models)} models; type /model in Pi to switch).")


def pi_command(args):
    require_key()
    configure_pi(refresh_models())
    binary = APP / "npm/bin/pi"
    if not binary.exists():
        raise Problem("Pi is not installed. Run \"Install Engineer\" again and choose Pi.")
    env = tool_env()
    env["PI_OFFLINE"] = "1"   # no update checks; the USAi model list is refreshed above
    os.execve(str(binary), [str(binary), *args], env)


def choose(models, current):
    if not sys.stdin.isatty() or len(models) == 1:
        return current
    print("\nUSAi models that work with Copilot:")
    for number, model in enumerate(models, 1):
        print(f"  {number:>2}. {model}{'   (last used)' if model == current else ''}")
    while True:
        answer = input(f"Press Enter for {current}, or type a number: ").strip()
        if not answer:
            return current
        if answer.isdigit() and 1 <= int(answer) <= len(models):
            return models[int(answer) - 1]
        if answer in models:
            return answer
        print("That is not one of the listed models.")


def copilot_command(args):
    require_key()
    models = chat_models(refresh_models(), COPILOT_PREFIXES)
    if not models:
        raise Problem("USAi offers no Claude models right now, and Copilot needs one.")
    binary = APP / "npm/bin/copilot"
    if not binary.exists():
        raise Problem("Copilot is not installed. Run \"Install Engineer\" again and choose Copilot.")
    settings = read_json(SETTINGS_FILE, {})
    model = choose(models, preferred(models, settings.get("copilot_model")))
    write_json(SETTINGS_FILE, {**settings, "copilot_model": model})
    env = tool_env()
    env.update({
        "COPILOT_PROVIDER_BASE_URL": BASE_URL,
        "COPILOT_PROVIDER_TYPE": "openai",
        "COPILOT_PROVIDER_API_KEY_COMMAND": key_command_line(),
        "COPILOT_MODEL": model,
        "COPILOT_AUTO_UPDATE": "false",
        # A providers file that does not exist, so a saved ~/.copilot/providers.json cannot replace USAi.
        "COPILOT_PROVIDERS_CONFIG": str(CONFIG / "copilot-providers.json"),
    })
    limits = MODEL_LIMITS.get(model)
    if limits:
        env["COPILOT_PROVIDER_MAX_PROMPT_TOKENS"] = str(limits["contextWindow"] - limits["maxTokens"])
        env["COPILOT_PROVIDER_MAX_OUTPUT_TOKENS"] = str(limits["maxTokens"])
    print(f"Copilot is connected to USAi model {model}.")
    os.execve(str(binary), [str(binary), *args], env)


def dashboard_command():
    binary = APP / "bin/agentsview"
    if not binary.exists():
        raise Problem("The AI usage dashboard is not installed. Run \"Install Engineer\" again to add it.")
    env = tool_env()
    env["AGENTSVIEW_TELEMETRY_ENABLED"] = "0"
    os.execve(str(binary), [str(binary), "serve", "--host", "127.0.0.1", "--port", str(DASHBOARD_PORT),
                            "--no-browser", "--no-update-check"], env)


def main(argv):
    os.umask(0o077)
    command, args = (argv[0], argv[1:]) if argv else ("", [])
    try:
        if command == "print-key":
            key = load_key()
            if not key:
                raise Problem("No USAi key is saved; double-click \"Update USAi key\".")
            print(key)
        elif command == "key":
            key_command()
        elif command == "ensure-key":
            require_key()
        elif command == "pi":
            pi_command(args)
        elif command == "copilot":
            copilot_command(args)
        elif command == "dashboard":
            dashboard_command()
        else:
            print(__doc__.strip(), file=sys.stderr)
            return 2
    except Problem as error:
        print(f"\n{error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
