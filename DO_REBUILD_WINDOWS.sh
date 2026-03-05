#!/bin/bash
# Wrapper script to rebuild Windows plugin with sudo
# This script handles the sudo password prompt properly

echo "This script will rebuild the UTHelper Windows plugin using Docker."
echo "You will be prompted for your sudo password."
echo ""

# Run the rebuild script with sudo
sudo ./rebuild_windows_plugin.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "Next step: Update test package"
    echo "Run: ./test_windows_plugin.sh"
fi
