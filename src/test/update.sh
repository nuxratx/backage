#!/bin/bash
# Test the sprinkler
# Usage: ./update.sh
# Copyright (c) ipitio
#
# shellcheck disable=SC1090,SC1091

if git ls-remote --exit-code origin index &>/dev/null; then
    if [ -d index ]; then
        [ ! -d index.bak ] || rm -rf index.bak
        mv index index.bak
    fi

    git fetch origin index
    git worktree add index index
    pushd index || exit 1
    git reset --hard origin/index
    popd || exit 1
fi

pushd "${0%/*}/.." || exit 1
source bkg.sh
main "$@"

check_json() {
    if [ ! -s "$1" ]; then
        echo "Empty json: $1"
        rm -f "$1"
    else
        jq -e . <<<"$(cat "$1")" &>/dev/null || echo "Invalid json: $1"
    fi
}

# db should not be empty, error if it is
[ "$(stat -c %s "$BKG_INDEX_SQL".zst)" -ge 1000 ] || exit 1
# json should be valid, warn if it is not
find .. -type f -name '*.json' | env_parallel check_json
popd || exit 1

if git worktree list | grep -q index; then
    pushd index || exit 1
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    git add .
    git commit -m "hydration"
    git push
    popd || exit 1
fi
