# debian-bootstrap

One script, public so it can be fetched before anything is configured.

```bash
wget -qO setup.sh https://raw.githubusercontent.com/richyp/debian-bootstrap/main/setup.sh
bash setup.sh
```

**Download, do not pipe.** `wget -qO- ... | bash` makes stdin the script
rather than your terminal, which breaks every `read` prompt and the
`gh auth login` flow.

## Why this exists

The GitHub CLI was removed from Debian testing in December 2025 and
migration is still blocked, so `apt install gh` fails there. Without
`gh` there is no straightforward way to authenticate and clone a private
repository from a bare console — no browser, no key, no token.

This script adds upstream's apt repository, installs `gh`, and uses it
to bootstrap the rest.

## What it does

1. Installs `curl`, `git` and `gnupg`
2. Offers to switch the machine from stable to testing, adding `contrib`
   and `non-free` while it rewrites the sources — a `full-upgrade`, so
   it asks first
3. Adds the GitHub CLI apt repository and installs `gh`
4. Authenticates with `admin:public_key` scope requested up front, so
   the key upload in the next step works without a second device code
5. Generates an ed25519 key and registers it with GitHub
6. Clones `richyp/dotfiles`
7. Hands over to `dotfiles/packages/debian-setup.sh`

Every step is guarded, so re-running is safe.

## Assumptions

- Debian, freshly installed, no desktop
- Wireless (if used) configured during installation, so networking works
  at the console
- `wget` is present; a minimal Debian has it but not `curl`

## Notes

The suite check looks for `trixie` in `/etc/apt/sources.list`. When the
next stable release lands that string changes, and this needs updating.

`NEEDRESTART_MODE=a` is set so the upgrade does not stop to ask about
restarting services.
