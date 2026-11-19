"""Build the bridge's restricted catalog from the signed-in Codex CLI."""

import json
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path


EFFORTS = ("none", "minimal", "low", "medium", "high", "xhigh")


def cli_environment():
    env = os.environ.copy()
    env.pop("CODEX_BRIDGE_KEY", None)
    return env


def find_codex(setting):
    if setting:
        executable = shutil.which(setting) or setting
        path = Path(executable).resolve(strict=True)
        if path.is_file() and (os.name != "nt" or path.suffix.lower() == ".exe"):
            return str(path)
        raise ValueError("Use the native Codex executable with --codex")

    executable = shutil.which("codex.exe" if os.name == "nt" else "codex")
    if executable:
        return executable
    # npm adds a batch wrapper to PATH on Windows. Invoke its native binary
    # directly so no cmd.exe quoting rules apply to paths or CLI options.
    shim = shutil.which("codex.cmd")
    arch = {"amd64": "x64", "arm64": "arm64"}.get(platform.machine().lower())
    if os.name == "nt" and shim and arch:
        scope = Path(shim).parent / "node_modules" / "@openai"
        package = f"codex-win32-{arch}"
        for root in (scope / "codex/node_modules/@openai" / package, scope / package):
            binaries = sorted(root.glob("vendor/*/bin/codex.exe"))
            if len(binaries) == 1:
                return str(binaries[0])
    raise ValueError("Install and sign in to Codex CLI, or supply --codex")


def restricted_catalog(executable, workdir, destination):
    env = cli_environment()
    login = subprocess.run(
        [executable, "login", "status"],
        capture_output=True, timeout=15, cwd=workdir, env=env,
    )
    if login.returncode != 0:
        raise ValueError("Codex CLI is not signed in. Run codex login before starting the bridge")
    result = subprocess.run(
        [executable, "debug", "models", "-c", 'model_provider="openai"'],
        capture_output=True, check=True, timeout=35, cwd=workdir, env=env,
    )
    models = []
    for model in json.loads(result.stdout)["models"]:
        slug = model["slug"]
        if (model.get("visibility") != "list"
                or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._-]*", slug)
                or slug in {"codex", "default"} or not reasoning_levels(model)):
            continue
        models.append({
            **model,
            "shell_type": "disabled",
            "apply_patch_tool_type": None,
            "experimental_supported_tools": [],
            "tool_mode": None,
            "node_repl_disabled": True,
            "supports_search_tool": False,
            "include_skills_usage_instructions": False,
            "include_apps_usage_instructions": False,
            "include_plugin_usage_instructions": False,
        })
    if not models:
        raise ValueError("Codex CLI returned no visible chat models. Check its login and connectivity")
    destination.write_text(json.dumps({"models": models}, ensure_ascii=False), encoding="utf-8")
    return {model["slug"]: model for model in models}


def reasoning_levels(model):
    supported = {entry["effort"] for entry in model.get("supported_reasoning_levels", [])}
    return [effort for effort in EFFORTS if effort in supported]


def model_choices(catalog):
    return {
        f"{name}@{effort}{'+fast' if fast else ''}": (name, effort, fast)
        for name, model in catalog.items()
        for effort in reasoning_levels(model)
        for fast in ((False, True) if any(tier["id"] == "priority" for tier in model.get("service_tiers", []))
                     else (False,))
    }
