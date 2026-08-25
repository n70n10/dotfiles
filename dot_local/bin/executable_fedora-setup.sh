#!/usr/bin/env bash
# fedora44-setup.sh — post-install setup for fresh Fedora 44 (KDE Plasma spin)
set -euo pipefail

# ---------------------------------------------------------------------------
# Locale: en_IE.UTF-8 (system + Plasma formats)
# ---------------------------------------------------------------------------
echo "==> Setting locale to en_IE.UTF-8"
sudo dnf install -y glibc-langpack-en
sudo localectl set-locale LANG=en_IE.UTF-8

mkdir -p "$HOME/.config"
cat > "$HOME/.config/plasma-localerc" <<'EOF'
[Formats]
LANG=en_IE.UTF-8
EOF

# ---------------------------------------------------------------------------
# Keyboard layout: prompt for US or IE
# ---------------------------------------------------------------------------
echo "==> Choose keyboard layout"
echo "  1) US"
echo "  2) IE (Irish)"
read -rp "Select keyboard layout [1-2]: " kb_choice
case "$kb_choice" in
    1) KEYMAP="us" ;;
    2) KEYMAP="ie" ;;
    *) echo "  Invalid choice, defaulting to us"; KEYMAP="us" ;;
esac

echo "==> Applying keyboard layout: $KEYMAP"
sudo localectl set-x11-keymap "$KEYMAP"
sudo localectl set-keymap "$KEYMAP" 2>/dev/null \
    || echo "  (console keymap '$KEYMAP' not found — X11/Wayland layout still applied)"

cat > "$HOME/.config/kxkbrc" <<EOF
[Layout]
LayoutList=$KEYMAP
Use=true
EOF

# ---------------------------------------------------------------------------
# Flatpak: swap Fedora repo for Flathub
# ---------------------------------------------------------------------------
echo "==> Swapping Fedora flatpak repo for Flathub"
for remote in fedora fedora-testing; do
    if flatpak remote-list | grep -q "^${remote}"; then
        flatpak remote-delete "$remote"
    fi
done
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ---------------------------------------------------------------------------
# PackageKit: remove with discover
# ---------------------------------------------------------------------------
sudo dnf remove -y PackageKit plasma-discover

# ---------------------------------------------------------------------------
# Games: remove pre-instlalled KDE games
# ---------------------------------------------------------------------------
sudo dnf remove -y kmahjongg kmines kpat

# ---------------------------------------------------------------------------
# CLI tools
# ---------------------------------------------------------------------------
echo "==> Installing CLI tools"
sudo dnf install -y zsh fzf ripgrep fd-find atuin eza zoxide chezmoi helix distrobox

echo "==> Installing starship"
curl -sS https://starship.rs/install.sh | sh -s -- -y

# ---------------------------------------------------------------------------
# iwd: install and set as the NetworkManager Wi-Fi backend
# ---------------------------------------------------------------------------
echo "==> Installing iwd"
sudo dnf install -y iwd

echo "==> Setting iwd as the NetworkManager Wi-Fi backend"
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi-backend-iwd.conf > /dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF

# prevent anything else from racing to start wpa_supplicant on the wifi device
sudo systemctl mask wpa_supplicant.service
sudo systemctl restart NetworkManager

echo
echo "==> Done. Log out and back in for locale, keyboard, and Plasma changes to fully apply."
echo "    You'll likely need to re-enter Wi-Fi passwords after the iwd backend switch."
