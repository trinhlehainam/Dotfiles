.PHONY: test test-tmux

test:
	nvim --headless --noplugin -u tests/plenary/minimal_init.lua -c "PlenaryBustedDirectory tests/plenary/spec/ { minimal_init = 'tests/plenary/minimal_init.lua', sequential = true }"

test-tmux:
	nvim --headless --noplugin -u tests/plenary/minimal_init.lua -c "lua require('plenary.busted').run('tests/plenary/integration/tmux_markers_spec.lua')"
