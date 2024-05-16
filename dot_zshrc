# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="nvim ~/.zshrc"
alias zshconfig="nvim.exe ~/.zshrc"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Set default editor to nvim
export EDITOR="nvim"

alias vi="nvim"
alias v="nvim"
#

# [[ VIM MODE ]]
bindkey -v

# Change to VIM NORNAL MODE
bindkey 'jk' vi-cmd-mode

# Remove key binding
bindkey -rM vicmd 'h'

# Override key binding
# [NORMAL MODE]
bindkey -M vicmd "j" vi-backward-char
bindkey -M vicmd ";" vi-forward-char
bindkey -M vicmd 'k' vi-down-line-or-history
bindkey -M vicmd 'l' vi-up-line-or-history
bindkey -M vicmd "g;" vi-end-of-line
bindkey -M vicmd "gj" vi-beginning-of-line
bindkey -M vicmd "'" vi-repeat-find

# [VISUAL MODE]
bindkey -M visual "j" vi-backward-char
bindkey -M visual ";" vi-forward-char
bindkey -M visual 'k' vi-down-line-or-history
bindkey -M visual 'l' vi-up-line-or-history
#

# nnn settings
# export NNN_BMS="b:$HOME/Documents/Books/;p:$HOME/Documents/Project/;g:$HOME/Documents/Git/;c:$HOME/Documents/Git/Dotfiles/;d:$HOME/Documents/"
# WSL version
export WSL_HOME="/mnt/c/Users/trinh/"
export NNN_BMS="b:$WSL_HOME/Documents/Books/;p:$WSL_HOME/Documents/Project/;g:$WSL_HOME/Documents/Git/;c:$WSL_HOME/Documents/Git/Dotfiles/;d:$WSL_HOME/Documents/"
#

n ()
{
    # Block nesting of nnn in subshells
    if [ -n $NNNLVL ] && [ "${NNNLVL:-0}" -ge 1 ]; then
        echo "nnn is already running"
        return
    fi

    # The default behaviour is to cd on quit (nnn checks if NNN_TMPFILE is set)
    # To cd on quit only on ^G, remove the "export" as in:
    #     NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"

    # Unmask ^Q (, ^V etc.) (if required, see `stty -a`) to Quit nnn
    # stty start undef
    # stty stop undef
    # stty lwrap undef
    # stty lnext undef

    nnn "$@"

    if [ -f "$NNN_TMPFILE" ]; then
            . "$NNN_TMPFILE"
            rm -f "$NNN_TMPFILE" > /dev/null
    fi
}
#

eval "$(starship init zsh)"
