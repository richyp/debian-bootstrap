#!/usr/bin/env bash
# Bootstrap a fresh Debian testing install.
#
#   curl -fsSL https://raw.githubusercontent.com/richyp/bootstrap/main/bootstrap.sh | bash
#
# Installs the GitHub CLI (absent from Debian testing since Dec 2025),
# authenticates, generates and registers an SSH key, then clones the
# private dotfiles repo and hands over to its setup script.

set -euo pipefail

info() { echo -e "\n==> $*"; }

info "Installing prerequisites"
sudo apt update
sudo apt install -y curl git gnupg

info "Adding the GitHub CLI repository"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

info "Authenticating with GitHub"
gh auth status >/dev/null 2>&1 || gh auth login

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  info "Generating an SSH key"
  ssh-keygen -t ed25519 -N "" -C "$USER@$(hostname)-$(date +%Y-%m)" \
    -f "$HOME/.ssh/id_ed25519"
  gh ssh-key add "$HOME/.ssh/id_ed25519.pub" \
    --title "$(hostname)-$(date +%Y-%m)"
fi

if [ ! -d "$HOME/dotfiles" ]; then
  info "Cloning dotfiles"
  git clone git@github.com:richyp/dotfiles.git "$HOME/dotfiles"
fi

info "Running the setup script"
exec "$HOME/dotfiles/packages/debian-setup.sh"
