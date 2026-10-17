#!/usr/bin/env python3
"""Benchmark actual Neovim TUI startup on Unix with isolated config/state/cache.

Uses already-provisioned plugins/parsers/tools; manager installation checks are disabled.
Runs full and minimal modes, optionally interleaved with a baseline config tree.
Keeps raw traces, plugin load reasons, and terminal output in the output folder.
"""

import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import pty
import select
import shutil
import statistics
import struct
import subprocess
import tempfile
import termios
import time


def prepare(output, name, source, data):
    base = output / name
    shutil.copytree(source, base / 'config/nvim')
    target = base / 'data/nvim'
    target.mkdir(parents=True)
    for entry in ('lazy', 'site', 'mason', 'copilot.lua'):
        if (data / entry).exists():
            (target / entry).symlink_to(data / entry, target_is_directory=True)
    # The installed .NET tool was already provisioned; skip its bootstrap probe.
    (target / 'easy-dotnet').mkdir()
    (target / 'easy-dotnet/easy_dotnet_installed').write_text('installed\n')
    return base


def run(base, case, trial, minimal, output, nvim, filename=None):
    prefix = base / f'{case}-{trial}'
    result_path = prefix.with_suffix('.json')
    log_path = prefix.with_suffix('.log')
    env = os.environ.copy()
    for key in ('NVIM', 'NVIM_APPNAME'):
        env.pop(key, None)
    for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
        env[f'XDG_{kind}_HOME'] = str(base / kind.lower())
    env.update(NVIM_BENCH_RESULT=str(result_path), NVIM_LOG_FILE=str(base / 'nvim.log'),
               NVIM_NOTTYFAST='1', TERM='xterm-256color',
               LLS_LOG_PATH=str(base / 'state/lua-ls'), LLS_META_PATH=str(base / 'cache/lua-ls-meta'))
    probe = Path(__file__).with_name('nvim-startup-probe.lua').resolve()
    env['NVIM_BENCH_PROBE'] = str(probe)
    command = [nvim, '-i', 'NONE', '--startuptime', str(log_path),
               '--cmd', 'lua dofile(vim.env.NVIM_BENCH_PROBE)', '-u', str(output / 'init.lua')]
    if minimal:
        command += ['--cmd', 'let[g:dotfiles_minimal]=[v:true]']
    if filename:
        command += [str(filename)]
    elif case != 'empty':
        command += [str(output / 'fixtures' / ('sample.md' if case == 'markdown' else 'sample.lua'))]
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
    launch = time.monotonic()
    process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env, cwd=output)
    os.close(slave)
    terminal = bytearray()
    inserted = False
    result = None
    launch_to_edit = None
    deadline = time.monotonic() + 20
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.005)[0]:
                try:
                    terminal.extend(os.read(master, 65536))
                except OSError:
                    break
            if not result_path.exists():
                continue
            try:
                result = json.loads(result_path.read_text())
            except json.JSONDecodeError:
                continue
            if 'ui_enter' in result['marks'] and not inserted:
                os.write(master, b'iz')
                inserted = True
            if 'first_edit' in result['marks'] and launch_to_edit is None:
                launch_to_edit = (time.monotonic() - launch) * 1000
            if 'runtime_done' in result['marks']:
                break
        if result is None or 'runtime_done' not in result['marks'] or 'first_edit' not in result['marks'] or result['error']:
            raise RuntimeError(f'{prefix}: startup failed; inspect JSON and terminal capture')
        deadline = time.monotonic() + 5
        while process.poll() is None and time.monotonic() < deadline:
            if select.select([master], [], [], 0.01)[0]:
                try:
                    terminal.extend(os.read(master, 65536))
                except OSError:
                    break
        process.wait(timeout=1)
        if process.returncode:
            raise RuntimeError(f'{prefix}: Neovim exited with {process.returncode}')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)
        prefix.with_suffix('.terminal').write_bytes(terminal)
    # Nvim 0.12 logs both the UI client and embedded editor. Use the editor marker.
    screens = [float(line.split()[0]) for line in log_path.read_text().splitlines()
               if '--- NVIM STARTED ---' in line]
    result['first_screen_ms'] = screens[-1]
    result['launch_to_edit_ms'] = launch_to_edit
    result['first_insert_ms'] = result['marks']['insert_ready'] - result['marks']['insert_enter']
    result['ui_to_edit_ms'] = result['marks']['first_edit'] - result['marks']['ui_enter']
    result_path.write_text(json.dumps(result, indent=2))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'home/.shared-configs/nvim')
    parser.add_argument('--baseline', type=Path, help='Optional unmodified config tree')
    parser.add_argument('--data', type=Path, default=Path(os.environ.get(
        'XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'nvim')
    parser.add_argument('--runs', type=int, default=10)
    parser.add_argument('--file', type=Path, help='Benchmark this existing file instead of sample cases; never saves edits')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error('--runs must be positive')
    if args.file and not args.file.is_file():
        parser.error('--file must name an existing file')
    nvim = shutil.which('nvim')
    if not nvim or not (args.data / 'lazy/lazy.nvim').is_dir():
        parser.error('Neovim and an already-installed lazy.nvim tree are required')
    output = (args.output or Path(tempfile.mkdtemp(prefix='nvim-startup-'))).resolve()
    output.mkdir(parents=True, exist_ok=True)
    revisions = {}
    for plugin in sorted((args.data / 'lazy').iterdir()):
        if (plugin / '.git').exists():
            revisions[plugin.name] = subprocess.check_output(
                ['git', '-C', str(plugin), 'rev-parse', 'HEAD'], text=True).strip()
    (output / 'environment.json').write_text(json.dumps({
        'nvim': subprocess.check_output([nvim, '--version'], text=True),
        'system': list(os.uname()), 'plugin_revisions': revisions,
        'config': str(args.config.resolve()),
        'baseline': str(args.baseline.resolve()) if args.baseline else None,
    }, indent=2))
    (output / 'init.lua').write_text("""require('configs.bootstrap').setup({ lazy = { config = {
  install = { missing = false }, checker = { enabled = false },
  change_detection = { enabled = false },
} } })
""")
    fixtures = output / 'fixtures'
    fixtures.mkdir()
    # Give LuaLS a small workspace instead of letting it index /tmp or the config copies.
    (fixtures / '.luarc.json').write_text('{}\n')
    (fixtures / 'sample.md').write_text('# Prompt\n\nA short prompt to edit.\n')
    (fixtures / 'sample.lua').write_text('local value = 42\nprint(value)\n')
    variants = {'full': args.config, 'minimal': args.config}
    if args.baseline:
        variants = {'before': args.baseline, **variants}
    bases = {name: prepare(output, name, source.resolve(), args.data.resolve())
             for name, source in variants.items()}
    results = {name: {} for name in variants}
    print(f'Artifacts: {output}', flush=True)
    for case in (('file',) if args.file else ('empty', 'markdown', 'lua')):
        for trial in range(args.runs + 1):
            # Rotate every variant through every position, including the full config.
            names = list(variants)
            offset = trial % len(names)
            names = names[offset:] + names[:offset]
            for name in names:
                sample = run(bases[name], case, trial, name == 'minimal', output, nvim,
                             args.file.resolve() if args.file else None)
                if trial:  # First run warms each config's separate bytecode cache.
                    results[name].setdefault(case, []).append(sample)
        for name in variants:
            samples = results[name][case]
            values = [s['first_screen_ms'] for s in samples]
            insert = statistics.median(s['first_insert_ms'] for s in samples)
            edit = statistics.median(s['ui_to_edit_ms'] for s in samples)
            launch_edit = statistics.median(s['launch_to_edit_ms'] for s in samples)
            count = len(samples[-1]['plugins']['ready'])
            inputs = [key['ms'] for sample in samples for key in sample['input_samples']]
            p95 = sorted(inputs)[math.ceil(len(inputs) * 0.95) - 1]
            print(f'{name:8} {case:8} first screen {statistics.median(values):8.1f} ms '
                  f'[{min(values):.1f}–{max(values):.1f}], first insert {insert:.1f} ms, '
                  f'UI to edit {edit:.1f} ms, launch to edit {launch_edit:.1f} ms, '
                  f'input p95 {p95:.1f} ms, {count} plugins', flush=True)
        (output / 'summary.json').write_text(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
