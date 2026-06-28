#!/bin/bash

# =============================================================================
#  ZealousNerve Dotfiles — Auto Installer
#  github.com/ZealousNerve/dotfiles
#
#  Run with:
#  bash <(curl -s https://raw.githubusercontent.com/ZealousNerve/dotfiles/main/install.sh)
#
#  WARNING: This is designed for a FRESH Arch Linux + Hyprland base install.
#  Running on an existing system may overwrite your configs.
# =============================================================================

set -e

# ─────────────────────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $1"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $1"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $1"; exit 1; }
step()    { echo -e "\n${BLUE}${BOLD}━━━  $1${RESET}\n"; }

DOTFILES_REPO="https://github.com/ZealousNerve/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
 ______           _                        _   _
|___  /           | |                      | \ | |
   / / ___  __ _| | ___  _   _ ___ _ __  |  \| | ___ _ ____   _____
  / / / _ \/ _` | |/ _ \| | | / __| '_ \ | . ` |/ _ \ '__\ \ / / _ \
 / /_|  __/ (_| | | (_) | |_| \__ \ | | || |\  |  __/ |   \ V /  __/
/_____\___|\__,_|_|\___/ \__,_|___/_| |_||_| \_|\___|_|    \_/ \___|

  Dotfiles Auto Installer — github.com/ZealousNerve/dotfiles
EOF
echo -e "${RESET}"

warn "This script is designed for a FRESH Arch Linux + Hyprland base install."
warn "Running on an existing configured system may overwrite your configs."
echo ""
read -rp "$(echo -e ${YELLOW}"Continue? [y/N]: "${RESET})" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — System update
# ─────────────────────────────────────────────────────────────────────────────
step "Step 1 — Updating system"
sudo pacman -Syuu --noconfirm
success "System updated"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Install base dependencies
# ─────────────────────────────────────────────────────────────────────────────
step "Step 2 — Installing base dependencies"
sudo pacman -S --needed --noconfirm git base-devel curl wget
success "Base dependencies installed"

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Install yay (AUR helper)
# ─────────────────────────────────────────────────────────────────────────────
step "Step 3 — Installing yay (AUR helper)"
if command -v yay &>/dev/null; then
    success "yay already installed — skipping"
else
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
    success "yay installed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Clone dotfiles (bare repo)
# ─────────────────────────────────────────────────────────────────────────────
step "Step 4 — Cloning dotfiles"

dotfiles() { /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }

if [[ -d "$DOTFILES_DIR" ]]; then
    warn "~/.dotfiles already exists — skipping clone"
else
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    success "Dotfiles cloned"
fi

dotfiles config --local status.showUntrackedFiles no

# Backup existing configs that would conflict
step "Step 4b — Backing up existing configs"
BACKUP_DIR="$HOME/.config-backup-$(date +%F_%H-%M-%S)"
mkdir -p "$BACKUP_DIR"

dotfiles checkout 2>&1 | grep "^\s" | awk '{print $1}' | while read -r file; do
    if [[ -f "$HOME/$file" || -d "$HOME/$file" ]]; then
        warn "Backing up: $file"
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        mv "$HOME/$file" "$BACKUP_DIR/$file"
    fi
done

dotfiles checkout
success "Dotfiles checked out (backups in $BACKUP_DIR)"

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Install all packages
# ─────────────────────────────────────────────────────────────────────────────
step "Step 5 — Installing packages from pkglist.txt"

PKGLIST="$HOME/.config/pkglist.txt"
if [[ -f "$PKGLIST" ]]; then
    yay -S --needed --noconfirm - < "$PKGLIST" || warn "Some packages may have failed — check output above"
    success "Packages installed"
else
    warn "pkglist.txt not found at $PKGLIST — skipping package install"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Install oh-my-zsh
# ─────────────────────────────────────────────────────────────────────────────
step "Step 6 — Installing oh-my-zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    success "oh-my-zsh already installed — skipping"
else
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "oh-my-zsh installed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 7 — Install zsh plugins
# ─────────────────────────────────────────────────────────────────────────────
step "Step 7 — Installing zsh plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    success "zsh-autosuggestions installed"
else
    success "zsh-autosuggestions already exists"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    success "zsh-syntax-highlighting installed"
else
    success "zsh-syntax-highlighting already exists"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 8 — Install Powerlevel10k
# ─────────────────────────────────────────────────────────────────────────────
step "Step 8 — Installing Powerlevel10k"

if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
    success "Powerlevel10k installed"
else
    success "Powerlevel10k already exists"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 9 — Set zsh as default shell
# ─────────────────────────────────────────────────────────────────────────────
step "Step 9 — Setting zsh as default shell"

if [[ "$SHELL" == "$(which zsh)" ]]; then
    success "zsh already default shell"
else
    chsh -s "$(which zsh)"
    success "Default shell changed to zsh (takes effect on next login)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 10 — Add dotfiles alias to .zshrc
# ─────────────────────────────────────────────────────────────────────────────
step "Step 10 — Ensuring dotfiles alias in .zshrc"

if ! grep -q "alias dotfiles=" "$HOME/.zshrc" 2>/dev/null; then
    echo "alias dotfiles='/usr/bin/git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME'" >> "$HOME/.zshrc"
    success "dotfiles alias added to .zshrc"
else
    success "dotfiles alias already in .zshrc"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 11 — Create required directories
# ─────────────────────────────────────────────────────────────────────────────
step "Step 11 — Creating required directories"

mkdir -p "$HOME/Pictures/Screen"
mkdir -p "$HOME/Videos/Recordings"
mkdir -p "$HOME/.cache"
mkdir -p "$HOME/.local/share/color-schemes"

success "Directories created"

# ─────────────────────────────────────────────────────────────────────────────
# Step 12 — Generate initial colors from first wallpaper
# ─────────────────────────────────────────────────────────────────────────────
step "Step 12 — Generating initial color palette"

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
FIRST_WALL=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | head -1)

if [[ -n "$FIRST_WALL" ]] && command -v matugen &>/dev/null; then
    matugen image "$FIRST_WALL"
    cp "$FIRST_WALL" "$HOME/.cache/lock_background"
    success "Color palette generated from: $FIRST_WALL"
else
    warn "matugen not found or no wallpaper found — run manually:"
    warn "  matugen image ~/Pictures/Wallpapers/[your-wallpaper.png]"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 13 — Apply GTK theme
# ─────────────────────────────────────────────────────────────────────────────
step "Step 13 — Applying GTK theme"

if command -v nwg-look &>/dev/null; then
    nwg-look -a
    success "GTK theme applied"
else
    warn "nwg-look not found — apply GTK theme manually after login"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 14 — .env file reminder
# ─────────────────────────────────────────────────────────────────────────────
step "Step 14 — .env file setup"

ENV_FILE="$HOME/.config/bin/.env"
ENV_EXAMPLE="$HOME/.config/bin/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        warn ".env created from example — fill in your API keys:"
        warn "  nano ~/.config/bin/.env"
        warn "  Required: ZIPLINE_URL, ZIPLINE_API_KEY, ZIPLINE_FOLDER_ID"
        warn "  Optional: CHIBISAFE_URL, CHIBISAFE_API_KEY"
    fi
else
    success ".env already exists"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
cat << 'EOF'
 ██████╗  ██████╗ ███╗   ██╗███████╗██╗
 ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
 ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
 ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
 ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
 ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝
EOF
echo -e "${RESET}"

echo -e "${BOLD}Installation complete. Here's what to do next:${RESET}"
echo ""
echo -e "  ${CYAN}1.${RESET} Fill in API keys (for screenshot upload):"
echo -e "     ${YELLOW}nano ~/.config/bin/.env${RESET}"
echo ""
echo -e "  ${CYAN}2.${RESET} Check your monitor name (should be eDP-1):"
echo -e "     ${YELLOW}hyprctl monitors${RESET}"
echo -e "     If different, update: ${YELLOW}~/.config/hypr/hyprland/monitors.lua${RESET}"
echo ""
echo -e "  ${CYAN}3.${RESET} Reboot and start Hyprland:"
echo -e "     ${YELLOW}reboot${RESET}"
echo ""
echo -e "  ${CYAN}4.${RESET} On first login, if colors look off, run:"
echo -e "     ${YELLOW}matugen image ~/Pictures/Wallpapers/[wallpaper.png]${RESET}"
echo ""
echo -e "  ${CYAN}5.${RESET} Read the full system map:"
echo -e "     ${YELLOW}cat ~/SYSTEM.md${RESET}"
echo ""
echo -e "${GREEN}${BOLD}Welcome to the system. Everything should just work.${RESET}"
echo ""
