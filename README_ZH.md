# Niri Window Switcher

**[English](README.md)** | **中文**

现代化的 Niri 窗口管理器快速跳转工具，采用 GTK4 + Layer Shell 实现

![截图](demo.png)

## 特性

- 模糊搜索，智能排序
- 完整键盘导航支持
- 毛玻璃 UI 设计
- 支持配置文件自定义
- 快速轻量

## 安装

一行命令安装（零环境依赖，安装后 Alt+Tab 直接可用）：

```bash
curl -fsSL https://raw.githubusercontent.com/Crosery/niri-window-switcher/main/install.sh | bash
```

支持发行版：Arch / Manjaro / EndeavourOS / CachyOS / Debian / Ubuntu / Mint / Pop!_OS / Fedora / Nobara / openSUSE

卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/Crosery/niri-window-switcher/main/install.sh | bash -s -- --uninstall
```

### 手动编译

```bash
cargo build --release
cp target/release/niri-switcher ~/.local/bin/niri-window-switcher
```

手动安装需要自行配置键位绑定，在 `~/.config/niri/binds.kdl` 中添加：

```kdl
binds {
    Alt+Tab repeat=false { spawn "niri-window-switcher"; }
}
```

## 配置

### 窗口尺寸（可选）

创建 `~/.config/niri-window-switcher/config.toml`：

```toml
[window]
width = 680
height = 520
```

### 自定义样式（可选）

复制并修改默认样式：

```bash
mkdir -p ~/.config/niri-window-switcher
cp style.css ~/.config/niri-window-switcher/style.css
# 编辑 ~/.config/niri-window-switcher/style.css
```

CSS 文件使用标准 GTK4 CSS 语法。主要选择器：

- `window` - 主窗口背景和边框
- `entry` - 搜索输入框
- `row` - 窗口列表项
- `row:selected` - 选中项
- `label` - 文字样式

## 快捷键

- 输入文字搜索
- `↑`/`↓` 或 `Ctrl+P`/`Ctrl+N` 导航
- `Enter` 选择
- `1-9` 快速选择
- `Esc` 取消

## License

MIT
