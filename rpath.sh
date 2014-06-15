#!/usr/bin/env bash
#
# Copyright 2014 David Vazgenovich Shakaryan
# Distributed under the terms of the MIT License.
#
# rpath
# https://github.com/omp/rpath
# Manage multiple Ruby installations with no black magic.
#
# In order to prevent environment pollution, the output of this script
# is a list of commands which must be sourced. This can be achieved
# through a simple shell function:
#
#     rpath() { source <(/path/to/rpath.sh "${@}"); }
#
# Two methods of version matching are supported. If the specified
# argument consists of only numbers, it is matched against the list
# number shown in `rpath ls`. Otherwise, a substring match is performed
# against the directory name.

: ${RUBIES_PATH:="${HOME}/.rubies"}

_echo() {
    echo "echo '${@//\'/\'\\\'\'}'"
}

_export_path() {
    echo "export PATH='${PATH//\'/\'\\\'\'}'"
    echo "hash -r"
}

_warn() {
    echo "echo 'rpath: ${@//\'/\'\\\'\'}' 1>&2"
}

_die() {
    [[ -n "${@}" ]] && _warn "${@}"

    echo "false"
    exit 1
}

_populate_dirs() {
    [[ -d "${RUBIES_PATH}" ]] \
        || _die "directory ${RUBIES_PATH} does not exist."

    # Cannot handle paths containing a newline. Only an idiot would
    # encounter this in practice.
    readarray -t dirs < <(shopt -s nullglob; \
        printf '%s\0' "${RUBIES_PATH}"/* | sort -zV | xargs -0n1)

    [[ -n "${dirs}" ]] || _die "directory ${RUBIES_PATH} is empty."
}

_match() {
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        [[ "${2}" == "${1}" ]] && return
    else
        [[ "${3}" == *"${1}"* ]] && return
    fi

    return 1
}

_populate_selected() {
    local dir dirs
    unset selected

    IFS=':' read -a dirs <<< "${PATH}"

    for dir in "${dirs[@]}"; do
        if [[ "${dir}" == "${RUBIES_PATH}/"* ]]; then
            dir="${dir%/bin}"
            selected+=("${dir##*/}")
        fi
    done

    [[ -n "${selected}" ]] || return 1

    [[ "${#selected[@]}" -eq 1 ]] \
        || _warn 'warning: multiple rubies found in PATH.'
}

_set() {
    _clear
    _echo "Adding ${1}/bin to PATH."

    PATH="${1}/bin:${PATH}"
}

_clear() {
    local dir dirs cdirs

    IFS=':' read -a dirs <<< "${PATH}"

    for dir in "${dirs[@]}"; do
        if [[ "${dir}" == "${RUBIES_PATH}/"* ]]; then
            _echo "Removing ${dir} from PATH."
        else
            cdirs+=("${dir}")
        fi
    done

    [[ "${#cdirs[@]}" -ne "${#dirs[@]}" ]] || return 1

    PATH="$(IFS=':'; echo "${cdirs[*]}")"
}

rpath_ls() {
    _populate_dirs
    _populate_selected

    counter=0

    for dir in "${dirs[@]}"; do
        str="  [$((++counter))] ${dir##*/}"

        [[ "${dir##*/}" == "${selected}" ]] && str="${str/ /*}"

        _echo "${str}"
    done
}

rpath_get() {
    _populate_selected || _die 'no rubies found in PATH.'

    for dir in "${selected[@]}"; do
        _echo "${dir}"
    done
}

rpath_set() {
    [[ -n "${1}" ]] || _die 'set command requires an argument.'

    _populate_dirs

    counter=0

    for dir in "${dirs[@]}"; do
        if _match "${1}" "$((++counter))" "${dir##*/}"; then
            _set "${dir}"
            _export_path

            return
        fi
    done

    _die 'no matching ruby found.'
}

rpath_clear() {
    _clear || _die 'no rubies found in PATH.'
    _export_path
}

rpath_help() {
    _echo 'Usage: rpath <command> [args]'
    _echo
    _echo 'Commands:'
    _echo '  ls     List all available rubies.'
    _echo '  get    Display currently selected ruby.'
    _echo '  set    Select specified ruby.'
    _echo '  clear  Clear path of any rubies.'
    _echo '  help   Display this help information.'
}

case "${1}" in
    'ls')
        rpath_ls ;;
    'get')
        rpath_get ;;
    'set')
        rpath_set "${2}" ;;
    'clear')
        rpath_clear ;;
    *)
        rpath_help ;;
esac
