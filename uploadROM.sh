#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
source $work_dir/functions.sh
ANDROID_VER=$(cat $work_dir/bin/ddevice/androidver.txt)
DEVICE_MODEL=$(cat $work_dir/bin/ddevice/device_model.txt)
BASE_BUILD_ID=$(cat $work_dir/bin/ddevice/base_build_id.txt)
BRAND=$(cat $work_dir/bin/ddevice/brand.txt)



if [ "$1" == "setup" ]; then
  # setup không còn cần thiết cho Pixeldrain (không cần rclone.conf)
  # Giữ lại để tương thích với build.yml nếu cần, thoát ngay
  echo "[INFO] - Pixeldrain mode: no setup required."
  exit 0
elif [ "$1" == "dummy" ]; then
  if [ -z "$PIXELDRAIN_API_KEY" ]; then
    echo "[ERROR] - PIXELDRAIN_API_KEY is not set"
    exit 1
  fi
  echo "[PIXELDRAIN] - Uploading dummy.txt..."
  response=$(curl -s -u ":${PIXELDRAIN_API_KEY}" \
    -F "file=@$work_dir/dummy.txt" \
    "https://pixeldrain.com/api/file/dummy.txt")
  file_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
  if [ -z "$file_id" ]; then
    echo "[PIXELDRAIN] - Error uploading dummy.txt: $response"
    exit 1
  fi
  echo "[PIXELDRAIN] - Uploaded: https://pixeldrain.com/u/$file_id"
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
elif [[ $BRAND == "OnePlus_Global" ]]; then
  NTBUILD="OxygenOS"
elif [[ $BRAND == "RealmeUI" ]]; then
  NTBUILD="RealmeUI"
fi

hash=$(md5sum out/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}.zip | head -c 5)
mv out/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}.zip \
   out/${NTBUILD}_${VERSION}_${DEVICE_MODEL}_OS${BASE_BUILD_ID}_${hash}_${status}.zip

output_file="out/${NTBUILD}_${VERSION}_${DEVICE_MODEL}_OS${BASE_BUILD_ID}_${hash}_${status}.zip"
FILENAME=$(basename "$output_file")

echo "[SCRIPT] - Output: $output_file"

# --- Pixeldrain Upload ---
if [ -z "$PIXELDRAIN_API_KEY" ]; then
  echo "[ERROR] - PIXELDRAIN_API_KEY is not set"
  exit 1
fi

echo "[PIXELDRAIN] - Uploading $FILENAME ..."
response=$(curl -s -u ":${PIXELDRAIN_API_KEY}" \
  -F "file=@${output_file};filename=${FILENAME}" \
  "https://pixeldrain.com/api/file/${FILENAME}")

file_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$file_id" ]; then
  echo "[PIXELDRAIN] - Error uploading file: $response"
  exit 1
fi

DOWNLOAD_URL="https://pixeldrain.com/u/$file_id"
echo "[PIXELDRAIN] - Upload successful!"
echo "[PIXELDRAIN] - Download URL: $DOWNLOAD_URL"

# Lưu URL ra file để các bước sau (Telegram notification) có thể dùng
echo "$DOWNLOAD_URL" > $work_dir/download_url.txt

echo "[SYSTEM] - Clean Workflow.."
rm -rf $work_dir/out
rm -rf $work_dir/build

echo "[INFO] - Build ${NTBUILD}_${VERSION} for ${DEVICE_MODEL} successful!"
