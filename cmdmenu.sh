#!/usr/bin/env bash
# cmdmenu.sh - config-driven command menu with arrow-key selection (uses fzf).
#
# Config line format (indent = nesting: 4 spaces or 1 tab per level):
#   Menu name
#       Item name => shell command
#   '#'-prefixed lines are comments. Blank lines ignored.
#
# Keys:  Enter=run/enter   Ctrl-R=reload config   Ctrl-O=edit config   Esc=quit
#
# Usage:
#   cmdmenu.sh [-c config] [-s setup.sh] [-d]
#     -c  config file (default: ~/.config/cmdmenu/menu.conf)
#     -s  script sourced once before running any command (e.g. crym2.sh)
#     -d  dump the parsed tree and exit (debug)

set -o pipefail

CONFIG="$HOME/.config/cmdmenu/menu.conf"
SETUP=""
DUMP=0
EDITOR="${EDITOR:-vi}"

while getopts "c:s:dh" o; do
    case $o in
    c) CONFIG=$OPTARG ;;
    s) SETUP=$OPTARG ;;
    d) DUMP=1 ;;
    h)
        sed -n '2,16p' "$0"
        exit 0
        ;;
    *) exit 2 ;;
    esac
done

[[ -r $CONFIG ]] || {
    echo "Config not found: $CONFIG" >&2
    exit 1
}

declare -A TYPE CMD PARENT NAME DEPTH
declare -a ORDER
SEP=$'\x1f'
HISTORY="${CONFIG%/*}/fzmenu.history"

trim() {
    local s=${1#"${1%%[![:space:]]*}"}
    printf '%s' "${s%"${s##*[![:space:]]}"}"
}

parse() {
    TYPE=() CMD=() PARENT=() NAME=() DEPTH=() ORDER=()
    local raw line indent level name cmd parent path
    local -a stack=()
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%$'\r'}
        raw=${line//$'\t'/    }
        [[ $raw =~ ^[[:space:]]*$ ]] && continue
        [[ $raw =~ ^[[:space:]]*# ]] && continue
        indent=${raw%%[^ ]*}
        level=$((${#indent} / 4))
        line=${raw#"$indent"}

        if ((level > 0)); then parent=${stack[$((level - 1))]:-}; else parent=""; fi

        if [[ $line == *'=>'* ]]; then
            name=$(trim "${line%%=>*}")
            cmd=$(trim "${line#*=>}")
            path=$([[ -n $parent ]] && printf '%s%s%s' "$parent" "$SEP" "$name" || printf '%s' "$name")
            TYPE[$path]=cmd CMD[$path]=$cmd PARENT[$path]=$parent NAME[$path]=$name DEPTH[$path]=$level
        else
            name=$(trim "$line")
            path=$([[ -n $parent ]] && printf '%s%s%s' "$parent" "$SEP" "$name" || printf '%s' "$name")
            TYPE[$path]=menu PARENT[$path]=$parent NAME[$path]=$name DEPTH[$path]=$level
            stack[$level]=$path
            local i=$((level + 1))
            while [[ -n ${stack[$i]:-} ]]; do unset 'stack[i]'; ((i++)); done
        fi
        ORDER+=("$path")
    done <"$CONFIG"
}

dump_tree() {
    local p
    for p in "${ORDER[@]}"; do
        printf '%*s[%s] %s%s\n' $((${DEPTH[$p]} * 4)) '' "${TYPE[$p]}" "${NAME[$p]}" \
            "$([[ ${TYPE[$p]} == cmd ]] && printf '  =>  %s' "${CMD[$p]}")"
    done
}

parse
if ((DUMP)); then
    dump_tree
    exit 0
fi

[[ -n $SETUP ]] && source "$SETUP"

reload() {
    local was=$current
    parse
    current=""
    [[ -n $was && ${TYPE[$was]:-} == menu ]] && current=$was
}

current=""
while :; do
    header=" cmdmenu   [enter] run   [ctrl-r] reload   [ctrl-o] edit   [esc] quit "
    [[ -n $current ]] && header=" cmdmenu :: ${current//$SEP/ › }  |  ctrl-r reload  ctrl-o edit "

    items=()
    i=0
    for p in "${ORDER[@]}"; do
        [[ ${PARENT[$p]} == "$current" ]] || continue
        if [[ ${TYPE[$p]} == menu ]]; then
            label="▸ ${NAME[$p]}"
            detail="▸ submenu — enter"
        else
            label="  ${NAME[$p]}"
            detail="\$ ${CMD[$p]}"
        fi
        items+=("$i"$'\t'"$label"$'\t'"$p"$'\t'"$detail")
        ((i++))
    done
    if [[ -n $current ]]; then
        items+=("-1"$'\t'"↩ back"$'\t'""$'\t'"← go up one level")
    fi
    if ((${#items[@]} == 0)); then
        items+=("0"$'\t'"<empty>"$'\t'""$'\t'"no items here")
    fi

    out=$(printf '%s\n' "${items[@]}" |
        fzf --height=60% --reverse --no-multi \
            --delimiter=$'\t' --with-nth=2 \
            --preview 'printf "%s\n" {4}' \
            --preview-window="down,3,wrap" \
            --expect=ctrl-r,ctrl-o \
            --prompt="> " --header="$header" \
            --pointer='▶' --marker='✓') || break

    key=$(printf '%s' "$out" | sed -n '1p')
    choice=$(printf '%s' "$out" | sed -n '2p')

    case $key in
    ctrl-r)
        reload
        continue
        ;;
    ctrl-o)
        "$EDITOR" "$CONFIG" </dev/tty
        reload
        continue
        ;;
    esac

    [[ -z $choice ]] && break

    rest=${choice#*$'\t'}
    rest=${rest#*$'\t'}
    path=${rest%%$'\t'*}

    if [[ $choice == "-1"$'\t'* ]]; then
        current=${PARENT[$current]}
        continue
    fi

    if [[ ${TYPE[$path]} == menu ]]; then
        current=$path
        continue
    fi

    clear
    echo "▶ ${NAME[$path]}"
    echo "  \$ ${CMD[$path]}"
    echo "────────────────────────────────────────"
    eval "${CMD[$path]}"
    rc=$?
    echo "────────────────────────────────────────"
    echo "exit code: $rc"
    printf '%s\t%s\n' "$(date '+%F %T')" "${CMD[$path]}" >>"$HISTORY" 2>/dev/null || true
    { read -n1 -rsp "press any key to return..." _ </dev/tty; } 2>/dev/null || true
    echo
done
