"""Opt-in network test: install Python tooling into disposable Neovim directories."""

import os
from pathlib import Path
import subprocess
import tempfile


config = Path(__file__).resolve().parents[1]
data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
plugins = Path(os.environ.get("NVIM_TEST_PLUGIN_DIR", data / "nvim/lazy"))
with tempfile.TemporaryDirectory(prefix="nvim-tool-install-") as directory:
    env = os.environ.copy()
    env["NVIM_TEST_PLUGIN_DIR"] = str(plugins)
    for kind in ("CONFIG", "DATA", "STATE", "CACHE"):
        env[f"XDG_{kind}_HOME"] = str(Path(directory) / kind.lower())
    env["NVIM_APPNAME"] = "nvim"
    # Native LSP enable checks VimEnter when installation finishes asynchronously.
    command = (
        "lua vim.api.nvim_create_autocmd('VimEnter', {once = true, callback = function() vim.schedule(function() "
        "local ok, err = pcall(dofile, 'tests/plenary/integration/tool_install.lua'); "
        "if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd('cquit 1') end; "
        "vim.cmd('qa!') end) end})"
    )
    result = subprocess.run(
        ["nvim", "--headless", "--noplugin", "-i", "NONE", "-u", "NONE",
         "-c", command],
        cwd=config, env=env, timeout=240, check=False,
    )
    raise SystemExit(result.returncode)
