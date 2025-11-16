#!/bin/zsh
set -e

which bun
which bunx
bun --version

sudo chown -R usr_vscode:usr_vscode /home/usr_vscode/.bun
echo "" >> ~/.zshrc
echo "# >>>>> onCreateCommand.sh START" >> ~/.zshrc

echo "alias clean-node-modules='setopt rm_star_silent; rm -rf node_modules/.*; rm -rf node_modules/*'; unsetopt rm_star_silent" >> ~/.zshrc
echo '# [[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"' >> ~/.zshrc

if command -v bun >/dev/null 2>&1; then
    # bun completions
    # echo 'source "$HOME/.bun/_bun"' >> ~/.zshrc
    IS_BUN_AUTO_UPDATE=true SHELL=zsh bun completions
    # bun
    # echo '# Bun' >> ~/.zshrc
    # echo 'export BUN_INSTALL="/home/usr_vscode/.bun"' >> ~/.zshrc
    # echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.zshrc
    # echo '' >> ~/.zshrc
    bun upgrade
else
    curl -fsSL https://bun.com/install | bash
fi

# >>>>> pnpm
bun add -g pnpm@latest
# echo "alias pnpm='bunx -g pnpm'" >> ~/.zshrc
# echo "alias pnpx='bunx -g pnpx'" >> ~/.zshrc
/home/usr_vscode/.bun/bin/pnpm config set store-dir ~/.pnpm-store
sudo chown -R usr_vscode:usr_vscode ~/.pnpm-store

# >>>>> Claude Code
bun add -g @anthropic-ai/claude-code@latest
echo "alias claude='bunx -g claude --dangerously-skip-permissions'" >> ~/.zshrc
# https://github.com/anthropics/claude-code/blob/1fe9e369a7c30805189cbbb72eb69c15ed4ec96b/.devcontainer/Dockerfile#L42
echo "export DEVCONTAINER=true" >> ~/.zshrc

# >>>>>> Gemini CLI
bun add -g @google/gemini-cli@latest
echo "alias gemini='bunx -g gemini --yolo -m gemini-2.5-pro'" >> ~/.zshrc
echo "export SANDBOX=bun-devcontainer" >> ~/.zshrc

echo "# <<<<< onCreateCommand.sh END" >> ~/.zshrc
