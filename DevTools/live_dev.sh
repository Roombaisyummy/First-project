#!/bin/bash
set -euo pipefail

BASE_DIR="/home/natha/dev-for-ios"
IP="192.168.0.166"
SERVER_IP="192.168.0.102"

echo "=== 🚀 STARTING GOD-MODE DEV LOOP ==="

# 1. Start Python Backend in background
echo "[1/3] Starting Mock Backend..."
python "$BASE_DIR/GildedHarness/game_server.py" &
SERVER_PID=$!

cleanup() {
    kill "$SERVER_PID" 2>/dev/null || true
}

trap cleanup EXIT

# 2. Initial Build and Deploy
echo "[2/3] Performing Initial Sync..."
"$BASE_DIR/deploy_all.sh"

# 3. Follow Logs
echo "[3/3] Streaming Tweak Logs (Ctrl+C to stop)..."
echo "------------------------------------------------"
sshpass -p alpine ssh -o StrictHostKeyChecking=no root@$IP "tail -f /var/jb/var/mobile/Library/Logs/SatellaJailed.log"
