#!/bin/bash

cd "$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Activating virtual environment...${NC}"
source .venv/bin/activate

echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build dist *.spec

echo -e "${GREEN}Building with PyInstaller...${NC}"
pyinstaller \
  --windowed \
  --name "DistractedTimer" \
  main.py

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo -e "${BLUE}Output is in ./dist/${NC}"
echo ""
read -p "Press ENTER to close..."
