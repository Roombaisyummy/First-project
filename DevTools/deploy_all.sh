#!/bin/bash
set -euo pipefail

export THEOS=/opt/theos
IP="192.168.0.166"
PASS="alpine"
BASE_DIR="/home/natha/dev-for-ios"
SATELLA_DIR="$BASE_DIR/SatellaJailed-Modernized"
GILDED_DIR="$BASE_DIR/GildedClient"
SATELLA_DEB="$SATELLA_DIR/packages/lilliana.satellajailed_0.0.1_iphoneos-arm64.deb"
GILDED_DEB="$GILDED_DIR/packages/com.natha.gilded_1.0.0_iphoneos-arm64.deb"

echo "=== 🛠️ BUILDING TWEAK ==="
cd "$SATELLA_DIR"
bash ./build.sh

echo "=== 🛠️ BUILDING HARNESS ==="
cd "$GILDED_DIR"
make package FINALPACKAGE=1

echo "=== 🚀 DEPLOYING TO IPHONE ==="
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no "$SATELLA_DEB" root@"$IP":/var/root/
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no "$GILDED_DEB" root@"$IP":/var/root/

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no root@"$IP" "dpkg -i /var/root/$(basename "$SATELLA_DEB") /var/root/$(basename "$GILDED_DEB") && uicache -a && killall -9 SpringBoard"

echo "=== ✅ DONE ==="
