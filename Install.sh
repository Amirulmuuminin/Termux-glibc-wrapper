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

    # MENCARI PATH ASLI: 
    # 'type -p' atau 'command -v' yang dipaksa mencari file fisik, bukan fungsi/alias
    local real_path=$(unset -f $target_cmd; unalias $target_cmd 2>/dev/null; command -v "$target_cmd")

    if [ -z "$real_path" ] || [ "$real_path" == "$target_cmd" ]; then
        # Jika cara di atas gagal, coba cari lewat PATH sistem murni
        real_path=$(PATH=$(getconf PATH):$PATH command -v "$target_cmd")
    fi

    if [ -z "$real_path" ]; then
        echo "Error: Binary path for '$target_cmd' not found."
        return 1
    fi

    # Hapus entri lama agar bersih
    if [ -f ~/.grun_aliases ]; then
        sed -i "/$target_cmd() {/,/}/d" ~/.grun_aliases
    fi

    # Simpan path absolut yang ditemukan (Contoh: /data/data/.../.bun/bin/bun)
    cat << INNER_EOF >> ~/.grun_aliases
$target_cmd() {
    grun "$real_path" "\$@"
}
INNER_EOF

    # Aktifkan langsung di sesi saat ini
    eval "$target_cmd() { grun \"$real_path\" \"\$@\"; }"

    echo "Success: '$target_cmd' (at $real_path) is now managed by grun."
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

# 4. Refresh session
source ~/.bashrc

echo "--------------------------------------------------"
echo "Installation Finished!"
echo "Now you can run: grun-set bun"
