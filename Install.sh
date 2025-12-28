#!/bin/bash

# 1. Update and Install required packages
echo "Updating packages and installing glibc requirements..."
pkg update -y
pkg install glibc-repo -y
pkg install glibc-runner -y

# 2. Ensure configuration files exist
touch ~/.bashrc
touch ~/.grun_aliases

# 3. Write the full configuration to .bashrc
cat << 'EOF' > ~/.bashrc
# --- 1. ENV CONFIGURATION ---
# Add glibc to PATH and unset LD_PRELOAD for compatibility
export PATH=$PREFIX/glibc/bin:$PATH
unset LD_PRELOAD

# --- 2. LOAD EXTERNAL ALIASES ---
# Loads the specific file where patched commands are stored
if [ -f ~/.grun_aliases ]; then
    . ~/.grun_aliases
fi

# --- 3. CORE FUNCTION: grun-set ---
# Usage: grun-set <command_name>
# This overrides a command to run through glibc-runner (grun)
grun-set() {
    local target_cmd=$1
    if [ -z "$target_cmd" ]; then
        echo "Usage: grun-set <command_name>"
        return 1
    fi

    # Find the absolute path of the original binary
    local real_path=$(command -v "$target_cmd")

    if [ -z "$real_path" ]; then
        echo "Error: Command '$target_cmd' not found in PATH."
        return 1
    fi

    # Check if the command is already patched in the alias file
    if ! grep -q "${target_cmd}()" ~/.grun_aliases 2>/dev/null; then
        # Append the function permanently to the alias file
        # \$@ is escaped so it is written literally into the file
        cat << INNER_EOF >> ~/.grun_aliases

$target_cmd() {
    grun "$real_path" "\$@"
}
INNER_EOF
    fi

    # Inject the function into the current session immediately
    # Using escaped quotes to ensure multi-arguments are handled correctly
    eval "$target_cmd() { grun \"$real_path\" \"\$@\"; }"

    echo "Success: '$target_cmd' is now running via grun."
}

# --- 4. UTILITY: grun-list ---
# List all commands currently managed by grun-set
grun-list() {
    if [ -s ~/.grun_aliases ]; then
        echo "Commands patched to run via grun:"
        grep "()" ~/.grun_aliases | sed 's/() {//g'
    else
        echo "No commands have been patched yet."
    fi
}
EOF

# 4. Refresh the current session for the installer script
source ~/.bashrc

echo "--------------------------------------------------"
echo "Setup Complete! Glibc environment & 'grun-set' are ready."
echo "Example usage: grun-set bun"
echo "To see patched commands, type: grun-list"
