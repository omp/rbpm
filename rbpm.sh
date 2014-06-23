#!/usr/bin/env bash
#
# Copyright 2014 David Vazgenovich Shakaryan
# Distributed under the terms of the MIT License.
#
# rbpm (ruby path mangler)
# https://github.com/omp/rbpm
# Manage multiple Ruby installations with no black magic.
#
# In order to prevent environment pollution, the output of this script
# is a list of commands which must be sourced. This can be achieved
# through a simple shell function:
#
#     rbpm() { source <(/path/to/rbpm.sh "${@}"); }
#
# Placing the above function inside ~/.bashrc (or equivalent) will load
# it upon starting your shell.

: ${RUBIES_PATH:="${HOME}/.rubies"}

_echo() {
    echo "echo '${@//\'/\'\\\'\'}'"
}

_export() {
    echo "export PATH='${PATH//\'/\'\\\'\'}'"
    echo 'hash -r'
}

_warn() {
    echo "echo 'rbpm: ${@//\'/\'\\\'\'}' 1>&2"
}

_die() {
    [[ -n "${@}" ]] && _warn "${@}"

    echo 'false'
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

_populate_selected() {
    local dir dirs

    IFS=':' read -a dirs <<< "${PATH}"

    for dir in "${dirs[@]}"; do
        if [[ "${dir}" == "${RUBIES_PATH}/"* ]]; then
            dir="${dir%/bin}"
            selected+=("${dir##*/}")
        fi
    done

    [[ "${#selected[@]}" -ne 0 ]] || return 1
    [[ "${#selected[@]}" -eq 1 ]] \
        || _warn 'warning: multiple rubies found in PATH.'
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

_add() {
    _echo "Adding ${1}/bin to PATH."

    PATH="${1}/bin:${PATH}"
}

rbpm_ls() {
    local dir dirs selected str

    _populate_dirs
    _populate_selected

    for dir in "${dirs[@]}"; do
        str="  ${dir##*/}"

        [[ "${dir##*/}" == "${selected}" ]] && str="${str/ /*}"

        _echo "${str}"
    done
}

rbpm_get() {
    local dir selected

    _populate_selected || _die 'no rubies found in PATH.'

    for dir in "${selected[@]}"; do
        _echo "${dir}"
    done
}

rbpm_set() {
    [[ -n "${1}" ]] || _die 'set command requires an argument.'

    local dir dirs match

    _populate_dirs

    for dir in "${dirs[@]}"; do
        if [[ "${dir##*/}" == *"${1}"* ]]; then
            match="${dir}"
        fi
    done

    [[ -n "${match}" ]] || _die 'no matching ruby found.'

    _clear
    _add "${match}"
    _export
}

rbpm_clear() {
    _clear || _die 'no rubies found in PATH.'
    _export
}

rbpm_help() {
    _echo 'Usage: rbpm <command> [args]'
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
        rbpm_ls ;;
    'get')
        rbpm_get ;;
    'set')
        rbpm_set "${2}" ;;
    'clear')
        rbpm_clear ;;
    *)
        rbpm_help ;;
esac
