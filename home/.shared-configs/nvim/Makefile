.PHONY: test test-tmux test-tool-install

test:
	nvim --headless --noplugin -u tests/plenary/minimal_init.lua -c "PlenaryBustedDirectory tests/plenary/spec/ { minimal_init = 'tests/plenary/minimal_init.lua', sequential = true }"

test-tmux:
	nvim --headless --noplugin -u tests/plenary/minimal_init.lua -c "lua require('plenary.busted').run('tests/plenary/integration/tmux_markers_spec.lua')"

# Opt-in: real downloads and compilation, with disposable XDG directories.
test-tool-install:
	python3 tests/run-tool-install.py
