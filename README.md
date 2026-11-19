# AstrBot Codex Bridge · QQ 机器人版 / QQ Bot Edition

[English guide](./README.en.md) · [English setup prompt for Codex](./Codex-Setup.en.txt)

这版给希望用 **QQ 小号收发消息**的 Windows 用户。NapCat 登录 QQ 并通过 OneBot v11 连接 AstrBot，AstrBot 再把指定会话的请求交给本机 Codex 桥接。发行包附带 NapCat 安装脚本，首次安装时从上游下载程序。安装完成后，双击桌面的 **AstrBot + NapCat + Codex Bridge** 即可一起启动三者。

**第一次使用**：从本页的 **Code → Download ZIP** 下载并解压到长期保留的文件夹，在这个文件夹打开 Codex，把 [Codex安装提示词.txt](./Codex安装提示词.txt) 发给它。首次 QQ 登录按提示用机器人小号扫码。

AstrBot Codex Bridge 是一个只监听本机的 OpenAI 兼容服务。它使用安装者当前的 Codex CLI 登录状态，通过 `/v1/models` 和 `/v1/chat/completions` 提供文本聊天。基础使用只需要 Python 3.10+、Codex CLI 和 AstrBot。已验证 Codex CLI 0.167.0、Python 3.12 和 AstrBot 4.29.4。

## 适用范围

这是独立运行的本机桥接，通过 AstrBot 的模型提供源连接。本项目由社区维护，使用运行桥接的系统用户已有的 Codex CLI 登录。适合部署者在自己的会话中调用。桥接密钥用于验证本机客户端；普通聊天接口无法凭这把密钥识别发消息的 QQ 用户。

多人使用机器人时，请为群聊、其他用户的私聊、失败回退以及跟随会话模型的插件选择面向最终用户的官方 API 提供源。个人订阅桥接只分配给本人能触发的会话或任务。仅监听本机仍允许 AstrBot 代外部用户转发消息，因此需要在 AstrBot 中核对实际模型路由。参见 [OpenAI 使用条款](https://openai.com/policies/terms-of-use/) 和 [OpenAI 服务协议第 2.2 节](https://openai.com/policies/services-agreement/)。

## 启动

首次安装，可以在本项目目录打开 Codex，把 [Codex安装提示词.txt](./Codex安装提示词.txt) 的全文发给它，让它完成本机配置并测试回复。

### Windows QQ 机器人：双击启动三个程序

首次请将本目录解压到长期保留的位置，把安装提示词交给 Codex。它会复用本机的 AstrBot 和 NapCat；如果缺少 NapCat，Windows x64 安装步骤会从 [NapCat 官方 Releases](https://github.com/NapNeko/NapCatQQ/releases) 下载 Windows OneKey 包并运行安装器。QQ 程序和个人登录数据由用户本机管理。按提示用机器人小号扫码，完成 OneBot 连接后，桌面上会得到 **AstrBot + NapCat + Codex Bridge**。日常双击它即可打开原版 AstrBot 窗口，并按需启动 NapCat 和桥接。默认方案只在点击时运行。

以下是安装提示词会使用的命令。已有 NapCat 时跳过第一行；第二条命令中的路径和端口应取自本机实际配置。遇到已有自定义账号数据目录，应选用该实例的专用启动脚本。

```powershell
.\install-napcat.ps1
.\desktop-follow.ps1 CreateShortcut -AstrBotExe "C:\Apps\AstrBot\AstrBot.exe" -PythonExe "C:\Apps\Python312\python.exe" -NapCatStartScript "C:\Apps\NapCat\napcat.bat" -NapCatPort 6099
```

删除桌面入口可运行 `.\desktop-follow.ps1 RemoveShortcut`。NapCat 首次登录及 WebUI 的说明见 [NapCat Windows 安装指南](https://napcat.napneko.icu/guide/boot/Shell.html)；反向 WebSocket 的两端配置见 [AstrBot OneBot v11 接入指南](https://docs.astrbot.app/platform/aiocqhttp.html)。

### 可选：跟随原版 AstrBot.exe 启动

希望直接双击原来的 `AstrBot.exe` 时，可选择下述监听方案。桌面三程序入口和登录监听选择一种即可。仅使用桥接也可以手动双击 [start_bridge.bat](./start_bridge.bat) 并保留窗口。手动启动时，可用 `ASTRBOT_BRIDGE_PYTHON` 指定 Python 3.10+ 的完整路径。

把解压目录放在长期保留的位置。在该目录用 PowerShell 把下面的示例路径换成本机路径，再执行安装。端口默认为 8787，可用 `-Port` 修改，原生 Codex 可执行文件可用 `-CodexExe` 指定。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\desktop-follow.ps1 Install -AstrBotExe "C:\Apps\AstrBot\AstrBot.exe" -PythonExe "C:\Apps\Python312\python.exe"
```

安装脚本在当前用户的 Windows 启动文件夹注册监听程序并立即运行。它每三秒检查所选 EXE；端口空闲时启动桥接，端口已被占用时跳过启动。可用带密钥的 `/health` 检查服务身份。桥接保留到手动关闭或注销。配置及默认启动日志位于 `%LOCALAPPDATA%\astrbot-codex-bridge`。更换安装路径后重新运行 Install。自定义部署可用 `-BridgeStartScript` 指向已有的桥接专用 .ps1，代替 `-PythonExe`；需要联动已有的 NapCat 时，可额外传入 `-NapCatStartScript` 和它实际使用的 `-NapCatPort`。

关闭联动时，在解压目录运行以下命令。监听程序会在下一次检查时退出，当前已打开的应用可继续使用。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\desktop-follow.ps1 Remove
```

### 手动启动桥接

1. 从 [Codex CLI 官方 Releases](https://github.com/openai/codex/releases) 安装 CLI，在运行桥接的系统用户下执行 `codex login`。
2. 在桥接目录执行 `python codex_bridge.py`。Windows 上如果 `python` 指向旧版本，可以用 `py -3.12 codex_bridge.py` 或直接运行已安装的 Python 3.12。桥接从 PATH 找 Codex，也支持用 `--codex` 指定原生可执行文件。
3. 首次启动会生成本机桥接密钥。Windows 默认保存在 `%LOCALAPPDATA%\astrbot-codex-bridge\bridge.key`，其他系统保存在用户主目录的 `~/.local/state/astrbot-codex-bridge/bridge.key`。可用 `--key-file` 指定其他位置，或通过环境变量 `CODEX_BRIDGE_KEY` 提供现有密钥。工作目录可用 `--work-dir` 指定，端口可用 `--port` 修改。

## 在 AstrBot 添加模型

1. 在模型提供源中新增 **OpenAI 兼容 / Chat Completions** 提供源，ID 设为 `codex_bridge`，API Base URL 填 `http://127.0.0.1:8787/v1`，API Key 填刚生成的本机桥接密钥。AstrBot 与桥接应能访问同一个本机回环地址。
2. 保存提供源后点击获取模型列表。选择所需档位并保存条目，例如 `gpt-6.2-sol@low+fast`；AstrBot 中对应的条目 ID 是 `codex_bridge/gpt-6.2-sol@low+fast`。模型和档位取决于 Codex CLI 启动时从当前账户目录取得的结果。切换账户后重启桥接，再重新获取模型列表。
3. 在仅本人可用的测试会话中显式选择新条目并试发一条消息。多人部署的全局默认、回退和其他用户会话应使用官方 API 提供源。

模型 ID 的 `@档位` 和可选的 `+fast` 决定该请求的推理档位和 Fast 设置。聊天运行在只读沙箱中，禁用本机工具、插件及普通聊天的网络搜索。服务审计 CLI 事件后返回文本，也支持 AstrBot 的 SSE 返回格式。

## 可选 T9 集成

已有 T9 部署可传入 `--t9-group-config <外部目录>/t9/test-group.json`。桥接从同一外部目录读取 `phase0-local.json` 中的 `owner_qq`，以及 `phase2/groups.json` 和 `phase2/group-access.json` 中的群策略。可用 `--quota-file` 将额度快照写回该部署的私有运行目录。

读图、搜索、文档、生图、修图和群设置使用 T9 的签名接口。桥接校验签名、任务内容以及私聊所有者或群权限。T9 和 AstrBot 使用同一个本机桥接密钥。将部署配置、密钥及运行产物保存在源码目录之外。
