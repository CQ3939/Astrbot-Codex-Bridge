# AstrBot Codex Bridge · QQ Bot Edition

[简体中文](./README.md) · [English setup prompt for Codex](./Codex-Setup.en.txt)

Use a dedicated QQ account as a bot on Windows. NapCat signs in to QQ and connects to AstrBot over OneBot v11. AstrBot can send selected personal conversations to a local Codex CLI session. This edition includes a NapCat installer that downloads the upstream Windows x64 package during setup. A desktop shortcut starts **AstrBot + NapCat + Codex Bridge** together.

## Quick start

1. Choose **Code → Download ZIP** on GitHub. Extract the repository into a folder you intend to keep. The desktop shortcut refers to files in that folder.
2. Open Codex in that folder and send it the contents of [Codex-Setup.en.txt](./Codex-Setup.en.txt). It checks your current installation, configures the bridge and connects the QQ account.
3. When prompted, sign in to Codex as the Windows user who will run the bridge. Scan the NapCat QR code with your dedicated QQ account. If the automated NapCat download fails, download **NapCat.Shell.Windows.OneKey.zip** from the official release assets and give Codex the local ZIP path. [NapCat releases](https://github.com/NapNeko/NapCatQQ/releases) · [Windows setup guide](https://napcat.napneko.icu/guide/boot/Shell.html)
4. Double-click **AstrBot + NapCat + Codex Bridge**. Once OneBot shows the account is connected, send a private QQ message and confirm the reply arrives in QQ. The default shortcut runs on demand. [AstrBot OneBot v11 guide](https://docs.astrbot.app/en/platform/aiocqhttp.html)

The bridge requires Python 3.10+, a signed-in Codex CLI and AstrBot. The project has tested the bridge with Python 3.12, Codex CLI 0.167.0 and AstrBot 4.29.4.

## Choose who can use the provider

This community project runs as a separate local service. The bridge uses the Windows user's existing Codex CLI sign-in. Its local key authenticates AstrBot; the ordinary chat endpoint cannot identify which QQ user sent a message. Assign a personal subscription bridge only to conversations or actions that the account holder can trigger. For group chats, other users' private messages, fallback models and plugins that inherit the session model, select an official API provider intended for end-user applications. AstrBot can forward external requests to a loopback service. [OpenAI Terms of Use](https://openai.com/policies/terms-of-use/) · [OpenAI Services Agreement, §2.2](https://openai.com/policies/services-agreement/)

## Windows launch options

For the three-app shortcut, run the following in PowerShell from the extracted folder. Reuse existing installations and substitute the actual paths and NapCat WebUI port. If the account uses a custom data directory, supply its own startup script.

```powershell
.\install-napcat.ps1
.\desktop-follow.ps1 CreateShortcut -AstrBotExe "C:\Apps\AstrBot\AstrBot.exe" -PythonExe "C:\Apps\Python312\python.exe" -NapCatStartScript "C:\Apps\NapCat\napcat.bat" -NapCatPort 6099
```

Skip the first command if NapCat is already installed. Remove the shortcut with `.\desktop-follow.ps1 RemoveShortcut`.

Alternatively, to follow the original AstrBot desktop executable, run the command below. This installs a watcher in the current user's Startup folder and starts it immediately. It checks the selected executable every three seconds and starts the bridge if its port is free. Verify the service identity with an authenticated request to `/health`. Choose one launch mode per deployment.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\desktop-follow.ps1 Install -AstrBotExe "C:\Apps\AstrBot\AstrBot.exe" -PythonExe "C:\Apps\Python312\python.exe"
```

Use `-Port` for a custom bridge port, `-CodexExe` for the native Codex binary, or `-BridgeStartScript` in place of `-PythonExe` for a custom deployment. To start NapCat with the watcher, also pass `-NapCatStartScript` and `-NapCatPort`. Run the same script with `Remove` to disable the watcher. Already running applications remain available. Rerun setup after moving the installation. Launcher configuration and default logs live in `%LOCALAPPDATA%\astrbot-codex-bridge`.

## Manual bridge and provider setup

1. Install the [Codex CLI](https://github.com/openai/codex/releases) and run `codex login`. Start the bridge with `python codex_bridge.py` or run [start_bridge.bat](./start_bridge.bat) and keep its window open. On Windows, set `ASTRBOT_BRIDGE_PYTHON` to a Python 3.10+ executable if necessary. The bridge accepts `--codex`, `--port` and `--work-dir`.
2. The first start generates a bridge key in `%LOCALAPPDATA%\astrbot-codex-bridge\bridge.key` on Windows, or `~/.local/state/astrbot-codex-bridge/bridge.key` by default on other systems. To reuse an existing key, use `--key-file` or the `CODEX_BRIDGE_KEY` environment variable. Keep the key on the machine.
3. In AstrBot, add an OpenAI-compatible **Chat Completions** provider named `codex_bridge`. Set the base URL to `http://127.0.0.1:8787/v1` (adjust the port as needed) and enter the bridge key. AstrBot must be able to reach that loopback address. [Example provider configuration](./provider-source.example.json)
4. Fetch the model list, save an entry available to your account, and select it in an owner-only test conversation. For example, `codex_bridge/gpt-6.2-sol@low+fast` selects low reasoning effort and Fast mode if the CLI lists that combination. Restart the bridge and refresh the list when switching accounts.

The bridge exposes `/v1/models` and `/v1/chat/completions`, with support for streaming text. Ordinary chat runs in a read-only sandbox with local tools, plugins and web search disabled.

## Optional T9 integration

Existing T9 deployments can supply `--t9-group-config <external-dir>/t9/test-group.json`. The bridge reads owner and group policies from that external deployment and can write a quota snapshot with `--quota-file`. T9 uses signed requests for additional actions such as image generation, editing and group settings. Keep its configuration, bridge key and runtime data outside the source tree.
