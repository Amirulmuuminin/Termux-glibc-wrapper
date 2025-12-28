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

    # 1. Get the absolute path
    local real_path=$(command -v "$target_cmd")

    if [ -z "$real_path" ]; then
        echo "Error: Command '$target_cmd' not found in PATH."
        return 1
    fi

    # Remove old entry if exists (clean update)
    if [ -f ~/.grun_aliases ]; then
        sed -i "/$target_cmd() {/,/}/d" ~/.grun_aliases
    fi

    # 2. Append: grun + path + all arguments ($@)
    cat << INNER_EOF >> ~/.grun_aliases
$target_cmd() {
    grun "$real_path" "\$@"
}
INNER_EOF

    # 3. Activate instantly in the current session
    eval "$target_cmd() { grun \"$real_path\" \"\$@\"; }"

    echo "Success: '$target_cmd' is now managed by grun."
}

# --- 4. UTILITY: grun-list ---
grun-list() {
    if [ -s ~/.grun_aliases ]; then
        echo "Currently patched commands:"
        grep "()" ~/.grun_aliases | sed 's/() {//g'
    else
        echo "No commands patched yet."
    fi
}
EOF

# 4. Refresh session for the first time
source ~/.bashrc

echo "--------------------------------------------------"
echo "Installation Finished!"
echo "Now you can run: grun-set bun"
