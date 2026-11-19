@echo off
setlocal
if defined ASTRBOT_BRIDGE_PYTHON goto custom_python
py -3 -c "import sys; sys.exit(sys.version_info < (3,10))" >nul 2>&1
if not errorlevel 1 (
    py -3 -B -X utf8 "%~dp0codex_bridge.py" %*
    goto finished
)
python -c "import sys; sys.exit(sys.version_info < (3,10))" >nul 2>&1
if not errorlevel 1 (
    python -B -X utf8 "%~dp0codex_bridge.py" %*
    goto finished
)
echo Python 3.10+ is required. Set ASTRBOT_BRIDGE_PYTHON to the full python.exe path. 1>&2
exit /b 1

:custom_python
"%ASTRBOT_BRIDGE_PYTHON%" -c "import sys; sys.exit(sys.version_info < (3,10))" >nul 2>&1
if errorlevel 1 (
    echo ASTRBOT_BRIDGE_PYTHON must point to a working Python 3.10+ executable. 1>&2
    exit /b 1
)
"%ASTRBOT_BRIDGE_PYTHON%" -B -X utf8 "%~dp0codex_bridge.py" %*

:finished
exit /b %errorlevel%
