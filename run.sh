#!/usr/bin/env bash
# fzmenu launcher. Run it from this folder:
#   ./run.sh                 # uses menu.conf next to this script
#   ./run.sh other.conf      # uses another config
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cfg=${1:-$here/menu.conf}
[[ -r $cfg ]] || cfg=$here/menu.conf.example
args=(-c "$cfg")

[[ -r "$HOME/.bashrc" ]] && args+=(-s "$HOME/.bashrc")
#[[ -r "$HOME/.bashrc.d/crym2.sh" ]] && args+=(-s "$HOME/.bashrc.d/crym2.sh")
exec "$here/cmdmenu.sh" "${args[@]}"
