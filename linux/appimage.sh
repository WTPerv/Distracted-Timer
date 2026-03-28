#!/bin/bash


# Colors
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Clearing AppImage/DistractedTimer.AppDir/usr/bin"
rm -rf AppImage/DistractedTimer.AppDir/usr/bin/*

echo -e "${BLUE}Copying binaries from dist/DistractedTimer"
cp -r dist/DistractedTimer/. AppImage/DistractedTimer.AppDir/usr/bin/

cd "$(dirname "$0")/AppImage"

echo -e "${GREEN}Packaging with AppImage...${NC}"
./appimagetool.AppImage DistractedTimer.AppDir

echo ""
echo -e "${GREEN}AppImage complete!${NC}"
echo -e "${BLUE}Output is in ./AppImage/${NC}"
echo ""
read -p "Press ENTER to close..."
