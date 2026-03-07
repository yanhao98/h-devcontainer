#!/bin/bash
RESOLUTION=${1:-${VNC_RESOLUTION:-1920x1080}}
DPI=${2:-${VNC_DPI:-96}}
IGNORE_ERROR=${3:-"false"}
if [ -z "$1" ]; then
    echo -e "**Current Settings **\n"
    xrandr
    echo -n -e "\nEnter new resolution (WIDTHxHEIGHT, blank for ${RESOLUTION}, Ctrl+C to abort).\n> "
    read NEW_RES
    if [ "${NEW_RES}" != "" ]; then
        RESOLUTION=${NEW_RES}
    fi
    if ! echo "${RESOLUTION}" | grep -E '[0-9]+x[0-9]+' > /dev/null; then
        echo -e "\nInvalid resolution format!\n"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo -n -e "\nEnter new DPI (blank for ${DPI}, Ctrl+C to abort).\n> "
        read NEW_DPI
        if [ "${NEW_DPI}" != "" ]; then
            DPI=${NEW_DPI}
        fi
    fi
fi

xrandr --fb ${RESOLUTION} --dpi ${DPI} > /dev/null 2>&1

if [ $? -ne 0 ] && [ "${IGNORE_ERROR}" != "true" ]; then
    echo -e "\nFAILED TO SET RESOLUTION!\n"
    exit 1
fi

echo -e "\nSuccess!\n"
