#!/bin/bash
# SatellaJailed Modernized - Quick Build Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== SatellaJailed Modernized Build ===${NC}"
echo ""

if [ -f ~/.bashrc ]; then
    source ~/.bashrc 2>/dev/null || true
fi

if [ -z "${THEOS:-}" ] || [ ! -d "${THEOS:-}" ]; then
    export THEOS="$HOME/theos"
    echo -e "${YELLOW}THEOS not set, using default: $THEOS${NC}"
fi

export PATH="$PATH:$THEOS/bin"

if [ ! -x "$THEOS/toolchain/linux/iphone/bin/clang" ]; then
    echo -e "${YELLOW}Missing Theos Linux iPhone toolchain at:$THEOS/toolchain/linux/iphone/bin/clang${NC}"
    echo -e "${YELLOW}Run ./setup-linux.sh first, or rerun: THEOS=$THEOS bash $THEOS/bin/install-theos${NC}"
    exit 1
fi

# Fetch Jinx if missing
if [ ! -d "Tweak/.build/checkouts/Jinx" ]; then
    echo -e "${YELLOW}Fetching Jinx dependency...${NC}"
    mkdir -p Tweak/.build/checkouts
    git clone https://github.com/Paisseon/Jinx.git Tweak/.build/checkouts/Jinx
fi

# Clean and build
echo ""
echo "Cleaning previous build..."
make clean 2>/dev/null || true

echo ""
echo "Building tweak..."
make package FINALPACKAGE=1

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Output location:"
ls -lh packages/
