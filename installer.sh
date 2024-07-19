#!/usr/bin/env bash

# Repos we're playing with
PROJECTB_CLI_GITHUB_REPO="git@github.com:the-project-b/cli.git"
PROJECTB_DEV_ENV_GITHUB_REPO="git@github.com:the-project-b/dev-env.git"

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

is_directory_empty() {
  local dir="$1"
  [ -z "$(ls -A "$dir" 2>/dev/null)" ]
}

git_clone_if_empty() {
  local repo_url="$1"
  local target_dir="$2"

  # Check if the target directory exists
  if [ ! -d "$target_dir" ]; then
    info "Creating directory: $target_dir"
    mkdir -p "$target_dir"
  fi

  # Check if the target directory is empty
  if is_directory_empty "$target_dir"; then
    info "Cloning repository into $target_dir"
    git clone "$repo_url" "$target_dir"
  fi
}

# Create the ~/.projectb directory if it doesn't exist
PROJECTB_DIR="$HOME/.projectb"
if [ ! -d "$PROJECTB_DIR" ]; then
  info "Creating directory $PROJECTB_DIR"
  mkdir -p "$PROJECTB_DIR"
fi

# Clone projectb cli to ~/.projectb IF it is empty

git_clone_if_empty "$PROJECTB_CLI_GITHUB_REPO" "$PROJECTB_DIR"

PROJECTB_SCRIPT="$PROJECTB_DIR/projectb"
chmod +x "$PROJECTB_SCRIPT"

# Determine the appropriate shell initialization file
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  bash)
    SHELL_RC="$HOME/.bashrc"
    ;;
  zsh)
    SHELL_RC="$HOME/.zshrc"
    ;;
  *)
    echo "Unsupported shell: $SHELL_NAME"
    exit 1
    ;;
esac

# Add ~/.projectb to the PATH if it's not already there
if ! grep -q 'export PATH="$HOME/.projectb:$PATH"' "$SHELL_RC"; then
  info "Adding $PROJECTB_DIR to PATH in $SHELL_RC"
  echo 'export PATH="$HOME/.projectb:$PATH"' >> "$SHELL_RC"
else
  info "$PROJECTB_DIR is already in PATH"
fi

# Function to prompt the user to choose a directory on Linux using zenity
choose_directory_linux() {
  zenity --file-selection --directory --title="Select ProjectB Installation Directory"
}

# Function to prompt the user to choose a directory on macOS using AppleScript
choose_directory_macos() {
  osascript <<EOT
    tell application "System Events"
      activate
      set theDirectory to choose folder with prompt "Select ProjectB Installation Directory"
      return POSIX path of theDirectory
    end tell
EOT
}

# Determine the operating system
OS="$(uname)"

case "$OS" in
  Linux)
    if ! command -v zenity &> /dev/null; then
      echo "[ERROR] zenity is not installed. Please install it and try again."
      exit 1
    fi
    CHOSEN_DIR=$(choose_directory_linux)
    ;;
  Darwin)
    CHOSEN_DIR=$(choose_directory_macos)
    ;;
  *)
    echo "[ERROR] Unsupported operating system: $OS"
    exit 1
    ;;
esac

# Check if the users cancelled the directory selection
if [ -z "$CHOSEN_DIR" ]; then
  echo "[ERROR] No directory selected. Exiting."
  exit 1
fi

info "Selected ProjectB installation directory: $CHOSEN_DIR"

git_clone_if_empty "$PROJECTB_DEV_ENV_GITHUB_REPO" "$CHOSEN_DIR"

# save installation directory as environment variable
ENV_VAR_NAME="PROJECTB_INSTALLATION_DIR"

# save our vault link as env variable
ENV_VAR_VAULT_URL="VAULT_ADDR"

# Update rc file
if ! grep -q "export $ENV_VAR_NAME=" "$SHELL_RC"; then
  echo "export $ENV_VAR_NAME=\"$CHOSEN_DIR\"" >> "$SHELL_RC"
  #info "Added $ENV_VAR_NAME to $SHELL_RC"
else
  sed -i.bak "s|export $ENV_VAR_NAME=.*|export $ENV_VAR_NAME=\"$CHOSEN_DIR\"|" "$SHELL_RC"
  #info "Updated $ENV_VAR_NAME in $SHELL_RC"
fi


echo -e "${GREEN}Restart your shell or simply open a new terminal and use ${CYAN}projectb init${NC}"