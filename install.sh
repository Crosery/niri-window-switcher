#!/usr/bin/env bash
# niri-window-switcher 安装脚本
# 安装: curl -fsSL https://raw.githubusercontent.com/Crosery/niri-window-switcher/main/install.sh | bash
# 卸载: curl -fsSL https://raw.githubusercontent.com/Crosery/niri-window-switcher/main/install.sh | bash -s -- --uninstall

set -euo pipefail

REPO="https://github.com/Crosery/niri-window-switcher.git"
BINARY_NAME="niri-window-switcher"
INSTALL_DIR="$HOME/.local/bin"
TMP_DIR=""

# 颜色输出
info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
error() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$1" >&2; exit 1; }

cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# root 用户不需要 sudo
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ============================================================================
# 卸载
# ============================================================================
uninstall() {
    echo ""
    echo "  niri-window-switcher 卸载"
    echo "  =========================="
    echo ""

    local binary="$INSTALL_DIR/$BINARY_NAME"
    if [ -f "$binary" ]; then
        rm "$binary"
        ok "已删除 $binary"
    else
        warn "$binary 不存在，跳过"
    fi

    # 清理 niri 键位绑定
    remove_keybinding

    # 只清理安装脚本装的东西，不动 Rust 和系统包
    echo ""
    ok "卸载完成"
    info "Rust 和系统依赖包未移除，如需卸载 Rust: rustup self uninstall"
    exit 0
}

# ============================================================================
# 发行版检测
# ============================================================================
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif command -v pacman &>/dev/null; then
        echo "arch"
    elif command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v dnf &>/dev/null; then
        echo "fedora"
    elif command -v zypper &>/dev/null; then
        echo "opensuse-tumbleweed"
    else
        echo "unknown"
    fi
}

# ============================================================================
# 收集缺失的系统依赖（只检测，不安装）
# ============================================================================
collect_missing_deps() {
    local distro="$1"
    local missing=()

    case "$distro" in
        arch|endeavouros|manjaro|garuda|cachyos)
            command -v git &>/dev/null  || missing+=(git)
            command -v curl &>/dev/null || missing+=(curl)
            pacman -Qi gtk4 &>/dev/null || missing+=(gtk4)
            pacman -Qi gtk4-layer-shell &>/dev/null || missing+=(gtk4-layer-shell)
            pacman -Qi base-devel &>/dev/null || missing+=(base-devel)
            ;;
        debian|ubuntu|linuxmint|pop)
            command -v git &>/dev/null  || missing+=(git)
            command -v curl &>/dev/null || missing+=(curl)
            dpkg -s libgtk-4-dev &>/dev/null 2>&1   || missing+=(libgtk-4-dev)
            dpkg -s build-essential &>/dev/null 2>&1 || missing+=(build-essential)
            dpkg -s pkg-config &>/dev/null 2>&1      || missing+=(pkg-config)
            # gtk4-layer-shell 需要从源码编译，构建依赖
            if ! pkg-config --exists gtk4-layer-shell 2>/dev/null; then
                dpkg -s meson &>/dev/null 2>&1              || missing+=(meson)
                dpkg -s ninja-build &>/dev/null 2>&1        || missing+=(ninja-build)
                dpkg -s libwayland-dev &>/dev/null 2>&1     || missing+=(libwayland-dev)
                dpkg -s wayland-protocols &>/dev/null 2>&1  || missing+=(wayland-protocols)
                dpkg -s gobject-introspection &>/dev/null 2>&1       || missing+=(gobject-introspection)
                dpkg -s libgirepository1.0-dev &>/dev/null 2>&1      || missing+=(libgirepository1.0-dev)
            fi
            ;;
        fedora|nobara)
            command -v git &>/dev/null  || missing+=(git)
            command -v curl &>/dev/null || missing+=(curl)
            rpm -q gtk4-devel &>/dev/null 2>&1             || missing+=(gtk4-devel)
            rpm -q gtk4-layer-shell-devel &>/dev/null 2>&1 || missing+=(gtk4-layer-shell-devel)
            rpm -q gcc &>/dev/null 2>&1                    || missing+=(gcc)
            rpm -q pkg-config &>/dev/null 2>&1             || missing+=(pkg-config)
            ;;
        opensuse*|suse*)
            command -v git &>/dev/null  || missing+=(git)
            command -v curl &>/dev/null || missing+=(curl)
            rpm -q gtk4-devel &>/dev/null 2>&1             || missing+=(gtk4-devel)
            rpm -q gtk4-layer-shell-devel &>/dev/null 2>&1 || missing+=(gtk4-layer-shell-devel)
            rpm -q gcc &>/dev/null 2>&1                    || missing+=(gcc)
            rpm -q pkg-config &>/dev/null 2>&1             || missing+=(pkg-config)
            ;;
        *)
            error "不支持的发行版: $distro\n  请手动安装 git, curl, gtk4, gtk4-layer-shell 开发包后再运行此脚本"
            ;;
    esac

    echo "${missing[@]}"
}

# ============================================================================
# 安装系统依赖
# ============================================================================
install_deps() {
    local distro="$1"
    info "检测到发行版: $distro"
    info "检查系统依赖..."

    local missing
    missing=$(collect_missing_deps "$distro")

    if [ -z "$missing" ]; then
        ok "所有系统依赖已就绪"
        return
    fi

    info "安装系统包: $missing"

    case "$distro" in
        arch|endeavouros|manjaro|garuda|cachyos)
            $SUDO pacman -Sy --needed --noconfirm $missing
            ;;
        debian|ubuntu|linuxmint|pop)
            $SUDO apt-get update -qq
            $SUDO apt-get install -y $missing
            ;;
        fedora|nobara)
            $SUDO dnf install -y $missing
            ;;
        opensuse*|suse*)
            $SUDO zypper install -y $missing
            ;;
    esac

    ok "系统依赖安装完成"

    # Debian/Ubuntu: gtk4-layer-shell 不在官方仓库，需要源码编译
    case "$distro" in
        debian|ubuntu|linuxmint|pop)
            build_gtk4_layer_shell
            ;;
    esac
}

# ============================================================================
# 源码编译 gtk4-layer-shell（仅 Debian/Ubuntu 需要）
# ============================================================================
build_gtk4_layer_shell() {
    if pkg-config --exists gtk4-layer-shell 2>/dev/null; then
        ok "gtk4-layer-shell 已安装"
        return
    fi

    info "从源码编译 gtk4-layer-shell..."
    local build_dir
    build_dir="$(mktemp -d)"

    local orig_dir="$PWD"
    git clone --depth 1 https://github.com/wmww/gtk4-layer-shell.git "$build_dir/gtk4-layer-shell"
    cd "$build_dir/gtk4-layer-shell"
    meson setup build -Dexamples=false -Ddocs=false -Dtests=false -Dvapi=false
    ninja -C build
    $SUDO ninja -C build install
    $SUDO ldconfig
    cd "$orig_dir"

    rm -rf "$build_dir"
    ok "gtk4-layer-shell 编译安装完成"
}

# ============================================================================
# 安装 Rust（用户空间，不影响系统）
# ============================================================================
install_rust() {
    if command -v cargo &>/dev/null; then
        ok "Rust 已安装"
        return
    fi

    info "安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    ok "Rust 安装完成"
}

# ============================================================================
# 编译并安装
# ============================================================================
build_and_install() {
    TMP_DIR="$(mktemp -d)"

    info "克隆仓库..."
    git clone --depth 1 "$REPO" "$TMP_DIR/niri-window-switcher"

    info "编译中..."
    cd "$TMP_DIR/niri-window-switcher"
    cargo build --release

    # 安装二进制文件
    mkdir -p "$INSTALL_DIR"
    local target="$INSTALL_DIR/$BINARY_NAME"

    if [ -f "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        warn "已存在旧版本，备份到 $backup"
        mv "$target" "$backup"
    fi

    cp target/release/niri-switcher "$target"
    chmod +x "$target"
    ok "已安装到 $target"
}

# ============================================================================
# 检查 PATH
# ============================================================================
check_path() {
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo ""
        warn "$INSTALL_DIR 不在 PATH 中，请添加到 shell 配置文件:"
        echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
}

# ============================================================================
# 配置 niri 键位绑定
# ============================================================================
NIRI_BIND_COMMENT="// niri-window-switcher keybinding (auto-generated)"
NIRI_BIND_LINE='    Alt+Tab repeat=false { spawn "niri-window-switcher"; }'

setup_keybinding() {
    local niri_config_dir="$HOME/.config/niri"
    local binds_file="$niri_config_dir/binds.kdl"
    local config_file="$niri_config_dir/config.kdl"

    # 检查 niri 是否安装
    if ! command -v niri &>/dev/null; then
        warn "未检测到 niri，跳过键位绑定配置"
        return
    fi

    # 已经配置过则跳过
    if [ -f "$binds_file" ] && grep -q "niri-window-switcher" "$binds_file"; then
        ok "Alt+Tab 键位绑定已存在"
        return
    fi
    if [ -f "$config_file" ] && grep -q "niri-window-switcher" "$config_file"; then
        ok "Alt+Tab 键位绑定已存在"
        return
    fi

    # 优先写入 binds.kdl（如果 config.kdl 中 include 了它）
    if [ -f "$binds_file" ]; then
        # 在 binds { 后面插入
        if grep -q "^binds {" "$binds_file"; then
            sed -i "/^binds {/a\\
$NIRI_BIND_COMMENT\n$NIRI_BIND_LINE" "$binds_file"
            ok "已添加 Alt+Tab 键位绑定到 $binds_file"
            return
        fi
    fi

    # 没有 binds.kdl，写入 config.kdl
    if [ -f "$config_file" ]; then
        if grep -q "^binds {" "$config_file"; then
            sed -i "/^binds {/a\\
$NIRI_BIND_COMMENT\n$NIRI_BIND_LINE" "$config_file"
            ok "已添加 Alt+Tab 键位绑定到 $config_file"
            return
        fi
    fi

    # 都没有 binds 块，创建 binds.kdl
    mkdir -p "$niri_config_dir"
    cat > "$binds_file" << 'BINDS_EOF'
binds {
    // niri-window-switcher keybinding (auto-generated)
    Alt+Tab repeat=false { spawn "niri-window-switcher"; }
}
BINDS_EOF

    # 如果 config.kdl 存在但没有 include binds.kdl，添加 include
    if [ -f "$config_file" ] && ! grep -q 'include "binds.kdl"' "$config_file"; then
        sed -i '1i include "binds.kdl"' "$config_file"
    fi

    ok "已创建 $binds_file 并添加 Alt+Tab 键位绑定"
}

remove_keybinding() {
    local binds_file="$HOME/.config/niri/binds.kdl"
    local config_file="$HOME/.config/niri/config.kdl"

    for f in "$binds_file" "$config_file"; do
        if [ -f "$f" ] && grep -q "niri-window-switcher" "$f"; then
            # 删除包含 niri-window-switcher 的行和对应的注释行
            sed -i '/niri-window-switcher keybinding (auto-generated)/d' "$f"
            sed -i '/niri-window-switcher/d' "$f"
            ok "已从 $f 移除键位绑定"
        fi
    done
}

# ============================================================================
# 环境检测汇总
# ============================================================================
check_environment() {
    local distro="$1"

    echo "  环境检测"
    echo "  --------"

    # 发行版
    printf "  %-24s" "发行版:"
    printf '\033[1;36m%s\033[0m\n' "$distro"

    # Rust/cargo
    printf "  %-24s" "Rust:"
    if command -v cargo &>/dev/null; then
        printf '\033[1;32m已安装\033[0m\n'
    else
        printf '\033[1;33m未安装，将自动安装\033[0m\n'
    fi

    # git
    printf "  %-24s" "git:"
    if command -v git &>/dev/null; then
        printf '\033[1;32m已安装\033[0m\n'
    else
        printf '\033[1;33m未安装，将自动安装\033[0m\n'
    fi

    # 系统依赖
    local missing
    missing=$(collect_missing_deps "$distro")
    printf "  %-24s" "系统依赖:"
    if [ -z "$missing" ]; then
        printf '\033[1;32m已就绪\033[0m\n'
    else
        printf '\033[1;33m缺少: %s\033[0m\n' "$missing"
    fi

    # 已安装的二进制
    printf "  %-24s" "niri-window-switcher:"
    if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
        printf '\033[1;32m已安装，将备份后更新\033[0m\n'
    else
        printf '\033[1;33m未安装\033[0m\n'
    fi

    # niri
    printf "  %-24s" "niri:"
    if command -v niri &>/dev/null; then
        printf '\033[1;32m已安装\033[0m\n'
    else
        printf '\033[1;33m未检测到\033[0m\n'
    fi

    echo ""
}

# ============================================================================
# 主流程
# ============================================================================
main() {
    # 处理参数
    if [ "${1:-}" = "--uninstall" ]; then
        uninstall
    fi

    echo ""
    echo "  niri-window-switcher 安装脚本"
    echo "  =============================="
    echo ""

    local distro
    distro=$(detect_distro)

    check_environment "$distro"

    install_deps "$distro"
    install_rust
    build_and_install
    setup_keybinding
    check_path

    echo ""
    ok "安装完成！Alt+Tab 即可使用"
    info "卸载方式: curl -fsSL https://raw.githubusercontent.com/Crosery/niri-window-switcher/main/install.sh | bash -s -- --uninstall"
}

main "$@"
