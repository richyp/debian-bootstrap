#!/usr/bin/env bash
# Bootstrap a fresh Debian testing install.
#
#   wget -qO setup.sh https://raw.githubusercontent.com/richyp/debian-bootstrap/main/setup.sh
#   bash setup.sh
#
# Download, do not pipe. Piping makes stdin the script rather than your
# terminal, which breaks every read prompt and the gh auth login flow.
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

# needrestart is not on a truly minimal install, and tee into a missing
# directory would abort the script here. Writing the file regardless is
# inert until needrestart appears -- which it may, during the upgrade
# below -- and it is what stops debian-setup.sh being interrupted later.
sudo mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'a';" \
  | sudo tee /etc/needrestart/conf.d/50-autorestart.conf > /dev/null

if grep -qE '^\s*(deb|URIs).*trixie' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
  info "This machine is on stable (trixie)"
  echo "    Switching to testing rewrites your apt sources and pulls a"
  echo "    full-upgrade. That is a large download and takes a while."
  echo
  read -rp "Switch to testing? [y/N] " reply

  if [[ "$reply" =~ ^[Yy]$ ]]; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sudo sed -i 's/trixie/testing/g' /etc/apt/sources.list
    # trixie-updates has no testing equivalent.
    sudo sed -i '/testing-updates/d' /etc/apt/sources.list
    # Components are added by the block below, which runs either way.
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
  # --skip-ssh-key stops gh generating and uploading a key of its own.
  # Left to itself it titles every one "GitHub CLI", which is no use
  # once the MacBook and the servers each have one. The block below
  # names the key for the host and the month instead.
  #
  # admin:public_key is requested here so that upload needs no second
  # device code.
  gh auth login -h github.com -p ssh --skip-ssh-key -s admin:public_key
fi

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  info "Generating an SSH key"
  ssh-keygen -t ed25519 -N "" -C "$USER@$(hostname)-$(date +%Y-%m)" \
    -f "$HOME/.ssh/id_ed25519"
  gh ssh-key add "$HOME/.ssh/id_ed25519.pub" \
    --title "$(hostname)-$(date +%Y-%m)"
fi

# On a fresh machine known_hosts is empty, and the clone below would stop
# to ask about GitHub's host key. This is trust-on-first-use either way;
# check the fingerprint against GitHub's published one if that matters.
if ! ssh-keygen -F github.com >/dev/null 2>&1; then
  info "Adding GitHub to known_hosts"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
fi

if [ ! -d "$HOME/dotfiles" ]; then
  info "Cloning dotfiles"
  git clone git@github.com:richyp/dotfiles.git "$HOME/dotfiles"
fi

info "Running the setup script"
# Invoked through bash rather than executed directly: a fresh clone that
# lost its executable bit would otherwise fail here with "Permission
# denied" at the very last step, after everything else has succeeded.
exec bash "$HOME/dotfiles/packages/debian-setup.sh"
