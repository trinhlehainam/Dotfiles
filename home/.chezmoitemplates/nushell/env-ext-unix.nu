# NOTE: use '/home/linuxbrew/.linuxbrew/bin/brew shellenv' cmd to log brew env setup
$env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
$env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
$env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"

$env.HOMEBREW_FORCE_BREWED_CURL = 1

use std "path add"
path add /home/linuxbrew/.linuxbrew/bin
path add /home/linuxbrew/.linuxbrew/sbin

# $env.MANPATH = ($env.MANPATH | split row (char esep) | append '/home/linuxbrew/.linuxbrew/share/man')
# $env.INFOPATH = ($env.INFOPATH | split row (char esep) | append '/home/linuxbrew/.linuxbrew/share/info')
#
