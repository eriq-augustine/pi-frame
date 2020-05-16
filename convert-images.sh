#!/bin/bash

function convertImage() {
    local sourceImage=$1

    local targetImage="${sourceImage%.*}-scaled.jpg"

    isLandscape=$(convert ${sourceImage} -auto-orient -format "%[fx:(w/h>1)?1:0]" info:)
    if [ $isLandscape -eq 1 ]; then
        convert "${sourceImage}" -auto-orient -resize 1280x -interlace none "${targetImage}"
    else
        convert "${sourceImage}" -auto-orient -resize x800 -interlace none "${targetImage}"
    fi
}

function main() {
    if [[ $# -eq 0 ]]; then
        echo "USAGE: $0 <image> ..."
        exit 1
    fi

    trap exit SIGINT

    for image in "$@"; do
        convertImage "${image}"
    done
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
