mkdir -p mock_bin
cat << 'INNER' > mock_bin/bash
#!/bin/sh
exit 0
INNER
cat << 'INNER' > mock_bin/curl
#!/bin/sh
exit 0
INNER
cat << 'INNER' > mock_bin/unzip
#!/bin/sh
exit 0
INNER
cat << 'INNER' > mock_bin/tar
#!/bin/sh
exit 0
INNER
cat << 'INNER' > mock_bin/sed
#!/bin/sh
exit 0
INNER
cat << 'INNER' > mock_bin/sudo
#!/bin/sh
"$@"
INNER
cat << 'INNER' > mock_bin/_curl-fsSL--compressed
#!/bin/sh
echo "mock curl"
touch "$3"
INNER
cat << 'INNER' > mock_bin/_apt-install-cached
#!/bin/sh
echo "MOCK_APT_INSTALL_CALLED_WITH: $@"
# Stop long-running activity after detection
exit 0
INNER
chmod +x mock_bin/*
