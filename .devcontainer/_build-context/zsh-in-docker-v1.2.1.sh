#!/bin/sh

#######################################################################################################
# MIT License (MIT)
# Copyright 2019 Deluan Quintao
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
# OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#######################################################################################################

set -e

THEME=default
PLUGINS=""
ZSHRC_APPEND=""

while getopts ":t:p:a:" opt; do
    case ${opt} in
        t)  THEME=$OPTARG
            ;;
        p)  PLUGINS="${PLUGINS}$OPTARG "
            ;;
        a)  ZSHRC_APPEND="$ZSHRC_APPEND\n$OPTARG"
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            ;;
        :)
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            ;;
    esac
done
shift $((OPTIND -1))

echo
echo "Installing Oh-My-Zsh with:"
echo "  THEME   = $THEME"
echo "  PLUGINS = $PLUGINS"
echo

zshrc_template() {
    _HOME=$1;
    _THEME=$2; shift; shift
    _PLUGINS=$*;

    if [ "$_THEME" = "default" ]; then
        _THEME="powerlevel10k/powerlevel10k"
    fi

    cat <<EOM
[ -z "$TERM" ] && export TERM=xterm

##### Zsh/Oh-my-Zsh Configuration
export ZSH="$_HOME/.oh-my-zsh"

ZSH_THEME="${_THEME}"
plugins=($_PLUGINS)

EOM
    printf "$ZSHRC_APPEND"
    printf "\nsource \$ZSH/oh-my-zsh.sh\n"
}

powerline10k_config() {
    cat <<EOM
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_to_last"
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir vcs status)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
POWERLEVEL9K_STATUS_OK=false
POWERLEVEL9K_STATUS_CROSS=true
POWERLEVEL9K_DISABLE_GITSTATUS=true
EOM
}

cd /tmp

# Install On-My-Zsh
if [ ! -d "$HOME"/.oh-my-zsh ]; then
    # https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
    sh -c "$(curl https://install.ohmyz.sh)" "" --unattended --keep-zshrc
fi

# Generate plugin list
plugin_list=""
for plugin in $PLUGINS; do
    if [ "$(echo "$plugin" | grep -E '^http.*')" != "" ]; then
        plugin_name=$(basename "$plugin")
        git clone "$plugin" "$HOME"/.oh-my-zsh/custom/plugins/"$plugin_name"
    else
        plugin_name=$plugin
    fi
    plugin_list="${plugin_list}$plugin_name "
done

# Handle themes
if [ "$(echo "$THEME" | grep -E '^http.*')" != "" ]; then
    theme_repo=$(basename "$THEME")
    THEME_DIR="$HOME/.oh-my-zsh/custom/themes/$theme_repo"
    git clone "$THEME" "$THEME_DIR"
    theme_name=$(cd "$THEME_DIR"; ls *.zsh-theme | head -1)
    theme_name="${theme_name%.zsh-theme}"
    THEME="$theme_repo/$theme_name"
fi

# Generate .zshrc
zshrc_template "$HOME" "$THEME" "$plugin_list" > "$HOME"/.zshrc

# Install powerlevel10k if no other theme was specified
if [ "$THEME" = "default" ]; then
    git clone --depth 1 https://github.com/romkatv/powerlevel10k "$HOME"/.oh-my-zsh/custom/themes/powerlevel10k
    powerline10k_config >> "$HOME"/.zshrc
fi
