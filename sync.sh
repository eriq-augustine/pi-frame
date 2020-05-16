#!/bin/bash

readonly THIS_DIR=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")

readonly IMAGE_TEMP_DIR='/media/frame-temp'
readonly IMAGE_TARGET_DIR='/media/frame'

readonly S3_BUCKET='s3://piframe'
readonly S3_ENDPOINT='https://s3.us-west-1.wasabisys.com'
readonly AWS_PROFILE='piframe'

readonly CONVERT_IMAGES_SCRIPT="${THIS_DIR}/convert-images.sh"
readonly AWS_CLI='/usr/local/bin/aws'

function fetchImages() {
    echo "Fetching images."
    ${AWS_CLI} s3 sync "${S3_BUCKET}" ${IMAGE_TEMP_DIR} "--endpoint-url=${S3_ENDPOINT}" --profile "${AWS_PROFILE}"
}

function convertImages() {
    echo "Converting images."

    for sourceImage in "${IMAGE_TEMP_DIR}"/* ; do
        if [[ "${sourceImage}" == *"-scaled.jpg" ]]; then
            continue
        fi

        # The image conversion leabes a converted images adjacent to the original.
        local targetImage="${sourceImage%.*}-scaled.jpg"
        if [ -e "${targetImage}" ]; then
            continue
        fi

        echo "Converting '${sourceImage}'."

        ${CONVERT_IMAGES_SCRIPT} "${sourceImage}"
        cp "${targetImage}" "${IMAGE_TARGET_DIR}/"
    done
}

# Fake unplugging an plugging back in the USB device.
function replugUSB() {
    echo "Replugging USB."

    sudo rmmod g_mass_storage
    sleep 2
    sudo systemctl restart g_mass_storage.service
}

function main() {
    if [[ ! $# -eq 0 ]]; then
        echo "USAGE: $0"
        exit 1
    fi

    trap exit SIGINT

    local startingImages=$(ls -1 "${IMAGE_TEMP_DIR}" | wc -l)
    fetchImages
    local endingImages=$(ls -1 "${IMAGE_TEMP_DIR}" | wc -l)

    if [ $startingImages -eq $endingImages ]; then
        echo "No new images found."
        exit 0
    fi

    convertImages
    replugUSB
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
