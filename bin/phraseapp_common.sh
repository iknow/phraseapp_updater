#!/usr/bin/env bash

# Set up a working directory
working_directory=$(mktemp -d -t phraseapp.XXXXXX)

function cleanup_working_directory(){
    rm -rf "${working_directory}"
}

trap "cleanup_working_directory" EXIT SIGINT

function make_temporary_directory() {
    mktemp -d "${working_directory}/XXXXXXXX"
}

function make_tree_from_directory() {
    local directory filename object
    directory="$1"

    if [ ! -d "$directory" ]; then
        echo "Error: directory not found: '${directory}'" >&2
        exit 1
    fi

    for file in "$directory"/*; do
        if [ -d "$file" ]; then
            echo "Error: make_tree_from_directory cannot create recursive tree: '${file}'" >&2
            exit 1
        fi

        filename=$(basename "${file}")
        object=$(git hash-object -w "${file}")
        printf "100644 blob %s\\t%s\\n" "${object}" "${filename}"
    done | git mktree
}


function extract_commit() {
    extract_files "$1:${PREFIX}"
}

function extract_files() {
    local path
    path=$(make_temporary_directory)

    git archive --format=tar "$1" | tar -x -C "${path}"

    echo "${path}"
}

function locales_changed() {
    ! phraseapp_updater diff --quiet "$1" "$2" --file-format="$FILE_FORMAT"
}

function tree_changed() {
    ! git diff-tree --quiet "$1" "$2"
}

function replace_nested_tree() {
    local root path tree
    root="$1"
    path="$2"
    tree="$3"

    while [ "$path" ]; do
        leaf_name=$(basename "$path")
        path=$(dirname "$path")
        [ "$path" = "." ] && path=''

        # replace `leaf_name` in `path` with `tree`, yielding new tree
        tree=$(git ls-tree "${root}:${path}" | \
                   replace_child_in_tree "${leaf_name}" "${tree}" | \
                   git mktree)
    done

    echo "$tree"
}

function replace_child_in_tree(){
    ruby -pe 'BEGIN { file, tree = ARGV.shift(2) };
              gsub(/ [0-9a-z]{40}\t/, " #{tree}\t") if /\t#{file}$/' "$@"
}
