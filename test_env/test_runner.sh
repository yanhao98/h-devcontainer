#!/bin/bash
source ./utils.sh

# Mock /etc/os-release
cat > os-release << 'EOR'
ID=ubuntu
VERSION_CODENAME=noble
EOR

# Mock /etc/os-release
mkdir -p /etc
cp os-release /etc/os-release

# Mock curl to return the latest release json
mkdir -p /usr/bin
cat > curl << 'EOC'
#!/bin/bash
if [[ "$@" == *"api.github.com/repos/novnc/noVNC/releases/latest"* ]]; then
    echo '  "tag_name": "v1.9.9",'
else
    # Fallback to real curl if available, or just mock success for other downloads
    echo "Mock: curl $@"
fi
EOC
chmod +x curl
export PATH=$PWD:$PATH

# Mock other commands
touch /usr/bin/unzip /usr/bin/nano /usr/bin/locales
chmod +x /usr/bin/unzip /usr/bin/nano /usr/bin/locales

# Set environment variables for test
export VERSION="latest"
export INSTALL_NOVNC="true"

# Modify the script to source our utils and not fail on missing paths
sed -i 's|/etc/os-release|./os-release|g' github-features-desktop-lite-install.sh

# Run the script (partial run to check variable)
# We can't easily run the whole script because it does a lot of system stuff.
# Instead, I'll extract the relevant part or just run it and see if it outputs the detection message.

# Let's just source the script but trap the exit? No, it has `set -e`.
# I will patch the script to print NOVNC_VERSION and exit after detection.

sed -i '/Auto-detected latest noVNC version:/a echo "FINAL_NOVNC_VERSION=${NOVNC_VERSION}"\nexit 0' github-features-desktop-lite-install.sh

./github-features-desktop-lite-install.sh
