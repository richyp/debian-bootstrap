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

# --- Switch to testing ------------------------------------------------
# The package lists in dotfiles assume testing. On stable several are
# missing, and Plasma is a release behind.

echo "\$nrconf{restart} = 'a';" | sudo tee /etc/needrestart/conf.d/50-autorestart.conf

if grep -qE '^\s*(deb|URIs).*trixie' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
  info "This machine is on stable (trixie)"
  echo "    Switching to testing rewrites your apt sources and pulls a"
  echo "    full-upgrade. That is a large download and takes a while."
  echo
  read -rp "Switch to testing? [y/N] " reply

  if [ "$reply" = "y" ]; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sudo sed -i 's/trixie/testing/g' /etc/apt/sources.list
    # trixie-updates has no testing equivalent.
    sudo sed -i '/testing-updates/d' /etc/apt/sources.list
    # Steam is in non-free; firmware and some drivers in non-free-firmware.
    sudo sed -i -E 's/^(deb .*testing.*[[:space:]]main)$/\1 contrib non-free non-free-firmware/' \
      /etc/apt/sources.list
    sudo apt update
    sudo apt full-upgrade -y
  fi
fi

# Steam is in non-free; some drivers in contrib. non-free-firmware is
# already enabled by the installer.
if ! grep -qE '^deb .*[[:space:]]non-free([[:space:]]|$)' /etc/apt/sources.list; then
  info "Enabling contrib and non-free"
  sudo sed -i -E 's/^(deb(-src)? .*[[:space:]])main([[:space:]]|$)/\1main contrib non-free\3/' \
    /etc/apt/sources.list
  sudo apt update
fi
info "Adding the GitHub CLI repository"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

info "Authenticating with GitHub"
if ! gh auth status >/dev/null 2>&1; then
  gh auth login -h github.com -s admin:public_key
fi

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
