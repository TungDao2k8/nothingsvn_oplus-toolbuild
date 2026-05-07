#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
source $work_dir/functions.sh
ANDROID_VER=$(cat $work_dir/bin/ddevice/androidver.txt)
DEVICE_MODEL=$(cat $work_dir/bin/ddevice/device_model.txt)
BASE_BUILD_ID=$(cat $work_dir/bin/ddevice/base_build_id.txt)
BRAND=$(cat $work_dir/bin/ddevice/brand.txt)
RCLONE_CONFIG_1DRIVE="$work_dir/rclone.conf"
ONEDRIVE_REMOTE="starxONEDRIVE"



if [ "$1" == "setup" ]; then
  if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "[ERROR] - Please provide rclone token and remote name"
    exit 1
  fi
  curl  -s -o $work_dir/rclone.conf \
        -H "Authorization: token $2" \
        -H "Accept: application/vnd.github.v3.raw" \
        -L https://api.github.com/repos/$3/contents/$4
  exit 0
elif [ "$1" == "dummy" ]; then
  rclone -v --config="$RCLONE_CONFIG_1DRIVE" copy "$work_dir/dummy.txt" "$ONEDRIVE_REMOTE:NTBuild/${uploaddir}/${VERSION}/${DEVICE_MODEL}/" || {
    echo "[ONEDRIVE] - Error uploading file to OneDrive: $FILENAME"
    exit 1
  }
  exit 0
fi



if [[ $(git branch --show-current) == "beta" ]]; then
    VERSION="$(cat $work_dir/Version)"
 	status="Beta"
else
    VERSION="$(cat $work_dir/Version)"
 	status="Official"
fi

if [[ $BRAND == "OnePlus" ]]; then
  NTBUILD="ColorOS"
  uploaddir="ColorOS"
elif [[ $BRAND == "OnePlus_Global" ]]; then
  NTBUILD="OxygenOS"
  uploaddir="OxygenOS"
elif [[ $BRAND == "RealmeUI" ]]; then
  NTBUILD="RealmeUI"
  uploaddir="RealmeUI"
fi

hash=$(md5sum out/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}.zip |head -c 5)
mv out/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}.zip out/${NTBUILD}_${VERSION}_${DEVICE_MODEL}_OS${BASE_BUILD_ID}_${hash}_${status}.zip
echo "[SCRIPT] - Output: "
output_file="out/${NTBUILD}_${VERSION}_${DEVICE_MODEL}_OS${BASE_BUILD_ID}_${hash}_${status}.zip"
echo "$output_file"
echo "[ONEDRIVE] - Uploading"

# ─── Upload to Pixeldrain ─────────────────────────────────────────────────────
upload "Uploading ${final_name}..."

PD_RESPONSE="$(curl -s \
    -u ":${PD_API_KEY}" \
    -F "file=@${work_dir}/out/${final_name};filename=${final_name}" \
    https://pixeldrain.com/api/file)"

PD_ID="$(echo "${PD_RESPONSE}" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || true)"

if [[ -z "${PD_ID}" ]]; then
    error "Upload to Pixeldrain failed! Response: ${PD_RESPONSE}"
    exit 1
fi

PD_LINK="https://pixeldrain.com/u/${PD_ID}"
upload "Upload successful: ${PD_LINK}"

# ─── Export output vars cho workflow ─────────────────────────────────────────
# Workflow sẽ dùng các giá trị này trong thông báo Telegram thành công
{
    echo "ROM_NAME=${final_name}"
    echo "PD_LINK=${PD_LINK}"
} >> "${GITHUB_OUTPUT}"

echo "[SYSTEM] - Clean Workflow.."
rm -rf $work_dir/out
rm -rf $work_dir/build

echo "[INFO] - Build ${NTBUILD}_${VERSION} for ${DEVICE_MODEL} successfull !"
