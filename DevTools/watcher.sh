#!/bin/bash

# Configuration
WATCH_DIRS="/home/natha/dev-for-ios/SatellaJailed-Modernized/Tweak /home/natha/dev-for-ios/GildedClient/Sources"
DEPLOY_SCRIPT="/home/natha/dev-for-ios/deploy_all.sh"

echo "=== 👁️ WATCHER: Monitoring changes in Tweak and GildedClient ==="
echo "Watching: $WATCH_DIRS"

# Monitor for modify, create, and delete events
inotifywait -m -r -e modify,create,delete --format '%w%f' $WATCH_DIRS | while read FILE
do
    echo "[!] Change detected in: $FILE"
    echo "[*] Triggering Deployment..."
    
    # Run the deployment script
    bash "$DEPLOY_SCRIPT"
    
    echo "=== ✅ Deployment Complete. Resuming Watch... ==="
done
