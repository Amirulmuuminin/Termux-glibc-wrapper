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
export PATH=$PREFIX/glibc/bin:$PATH
unset LD_PRELOAD

# --- 2. LOAD EXTERNAL ALIASES ---
if [ -f ~/.grun_aliases ]; then
    . ~/.grun_aliases
fi

# --- 3. CORE FUNCTION: grun-set ---
grun-set() {
    local target_cmd=$1
    if [ -z "$target_cmd" ]; then
        echo "Usage: grun-set <command_name>"
        return 1
    fi

    # Check if already patched to avoid duplicates
    if grep -q "${target_cmd}()" ~/.grun_aliases 2>/dev/null; then
        echo "Warning: Command '$target_cmd' is already patched in ~/.grun_aliases."
        echo "Use 'grun-unset $target_cmd' first if you want to re-patch."
        return 1
    fi

    # Get the real binary path using which (ignoring functions/aliases)
    local real_path=$(which -a "$target_cmd" | grep -v "function" | head -n 1)

    if [ -z "$real_path" ]; then
        echo "Error: Binary for '$target_cmd' not found."
        return 1
    fi

    # Append to alias file: grun + path + all arguments
    cat << INNER_EOF >> ~/.grun_aliases
$target_cmd() {
    grun "$real_path" "\$@"
}
INNER_EOF

    # Apply immediately
    source ~/.grun_aliases
    echo "Success: '$target_cmd' is now patched to $real_path"
}

# --- 4. CORE FUNCTION: grun-unset ---
grun-unset() {
    local target_cmd=$1
    if [ -z "$target_cmd" ]; then
        echo "Usage: grun-unset <command_name>"
        return 1
    fi

    if [ -f ~/.grun_aliases ]; then
        # Remove the function block from the file
        sed -i "/$target_cmd() {/,/}/d" ~/.grun_aliases
        # Remove from current session
        unset -f "$target_cmd"
        echo "Success: Patch for '$target_cmd' removed."
        source ~/.bashrc
    fi
}

# --- 5. UTILITY: grun-list ---
grun-list() {
    if [ -s ~/.grun_aliases ]; then
        echo "Patched commands:"
        grep "()" ~/.grun_aliases | sed 's/() {//g'
    else
        echo "No patches found."
    fi
}
EOF

# 4. Finalizing
source ~/.bashrc
echo "--------------------------------------------------"
echo "Setup Complete! Commands available: grun-set, grun-unset, grun-list"
