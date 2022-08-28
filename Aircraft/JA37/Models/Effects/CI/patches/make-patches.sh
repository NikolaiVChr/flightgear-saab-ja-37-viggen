#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "usage: $0 path-to-fgdata"
    exit 1
fi

shaders="$1/Shaders"
effects="$1/Effects"

function make_patch {
    name="${2##*/}"
    diff -U 5 --label="a/${name}" --label="b/${name}" "$1" "$2" > "$3"
}

for f in default.{vert,frag} generic-ALS-base.vert model-ALS-base.frag; do
    make_patch "${shaders}/$f" "../$f" "$f.patch"
done

make_patch "${effects}/model-default.eff" "../ci.eff" "ci.eff.patch"

exit 0
