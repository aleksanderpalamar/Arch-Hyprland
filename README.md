# 🜂 MonadArchy

**The philosophy of functional minimalism applied to Arch Linux + Hyprland**

MonadArchy is a complete and modular configuration system for **Hyprland**, designed for those who seek an aesthetic, lightweight, and deeply customizable environment. Inspired by the principles of freedom, simplicity, and performance from Arch Linux, it unites art, code, and philosophy into a coherent ecosystem.

![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-blue?style=for-the-badge)
![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![License](https://img.shields.io/github/license/aleksanderpalamar/MonadArchy?style=for-the-badge)

---

## ⚙️ Features

- 🚀 **Automated Installation** — a single script installs, configures, and creates backups automatically.
- 🧩 **Total Modularity** — each module can be easily adjusted, replaced, or removed.
- 🎨 **Dynamic Theming** — colors and accents generated automatically from the wallpaper.
- ⚡ **Extreme Performance** — fast startup, intelligent caching, and lazy loading.
- ⌨️ **Intuitive Keybindings** — inspired by productive i3 and sway workflows.
- 🖼️ **Balanced Aesthetics** — a clean fusion of minimalism and visual elegance.

---

## 🚀 Installation

```bash
git clone https://github.com/aleksanderpalamar/MonadArchy.git
cd MonadArchy
./install.sh
```

1. **Log out** from your current desktop session.
2. **Select "Hyprland"** in your display manager.
3. **Use Super + Enter** to open the terminal.

---

## 🧠 MonadArchy Philosophy

MonadArchy is more than a configuration—it’s a statement of intent: **to master digital chaos through conscious simplicity**.
Inspired by Leibniz’s concept of _monads_—autonomous units that reflect the whole—each module mirrors the entire system: harmony, freedom, and self-sufficiency.

---

## 🧰 Core Components

- 🪟 **Hyprland** — modern, responsive Wayland compositor.
- 📊 **Waybar** — elegant and informative status bar.
- 🔍 **Rofi** — lightweight, fluid application launcher.
- 🖼️ **Hyprpaper** — wallpaper manager with dynamic integration.
- 🎨 **Wallust** — generates color schemes based on wallpapers.
- 🔔 **SwayNC** — integrated notification center.
- 📁 **Thunar** — lightweight, functional file manager.
- 💻 **Kitty** — fast, aesthetic terminal emulator.

---

## ⌨️ Keybindings

| Shortcut              | Action                         |
| --------------------- | ------------------------------ |
| `Super + Enter`       | Open terminal                  |
| `Super + Q`           | Close window                   |
| `CTRL + ALT + P`      | Log out                        |
| `Super + R`           | Application menu               |
| `Super + W`           | Wallpaper selector             |
| `Super + 1-9`         | Switch workspace               |
| `Super + Shift + 1-9` | Move window between workspaces |

---

## 🎨 Customization

```bash
Super + W  # Opens wallpaper selector
nano ~/.config/hypr/UserConfigs/UserDecorations.conf
```

- **Waybar:** `~/.config/waybar/`
- **Rofi:** `~/.config/rofi/`
- **Wallpapers:** `~/Pictures/wallpapers/`

---

## 📂 Directory Structure

```
~/.config/hypr/
├── hyprland.conf
├── UserConfigs/
├── scripts/
└── ...

~/.config/waybar/
~/.config/rofi/
~/Pictures/wallpapers/
```

---

## 🔄 Updating

```bash
cd MonadArchy
git pull
./install.sh
```

---

## 🤝 Contributing

1. **Fork** the repository.
2. **Create** a new branch.
3. **Commit** your changes.
4. **Open** a Pull Request.

---

## 📜 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---
