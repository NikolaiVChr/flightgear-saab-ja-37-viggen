#!/bin/bash

cd ..

if [[ $# -eq 1 ]]; then
    echo "copying files from $1"
    shaders="$1/Shaders"
    effects="$1/Effects"

    for f in default.{vert,frag} generic-ALS-base.vert model-ALS-base.frag; do
        cp "${shaders}/$f" "$f"
    done
    cp "${effects}/model-default.eff" "ci.eff"
fi

echo "applying patches"
for p in patches/*.patch; do
    patch -p1 --merge < "$p"
done
