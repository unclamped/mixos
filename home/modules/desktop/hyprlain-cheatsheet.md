# Hyprlain — Keybindings Cheat Sheet

> **MOD key = Super (Windows/Meta)**

---

## Applications

| Binding | Action |
|---------|--------|
| `MOD + Q` | Terminal (kitty) |
| `MOD + W` | Browser (Helium) |
| `MOD + E` | File manager (Dolphin) |
| `MOD + T` | Editor (kitty → nvim) |
| `MOD + SHIFT + M` | Music (Spotify) |
| `MOD + SPACE` | App launcher (Rofi combi) |

---

## Window Management

| Binding | Action |
|---------|--------|
| `MOD + X` | Close active window |
| `MOD + F` | Toggle fullscreen |
| `MOD + V` | Toggle floating |
| `MOD + B` | Toggle pseudo-tiling (dwindle) |
| `MOD + N` | Toggle split direction (dwindle) |
| `MOD + M` | Toggle group |

---

## Focus & Movement

| Binding | Action |
|---------|--------|
| `MOD + H/J/K/L` | Move focus ← ↓ ↑ → |
| `MOD + SHIFT + H/J/K/L` | Move window/group ← ↓ ↑ → |
| `MOD + CTRL + H/J` | Previous tab in group |
| `MOD + CTRL + K/L` | Next tab in group |
| `MOD + LMB drag` | Move floating window |
| `MOD + RMB drag` | Resize window |

---

## Workspaces

| Binding | Action |
|---------|--------|
Each desk monitor owns its own private set of 9 workspaces, and `MOD + N` always
acts on whichever monitor currently has focus — it never jumps you across screens.

| Monitor | Position | Workspaces |
|---------|----------|------------|
| `HDMI-A-1` (Samsung S19D300) | centre, main | 1–9 |
| `DP-3` (Samsung SyncMaster CRT) | right | 10–18 |
| `DP-1` (LG T730SH CRT) | ambient / bed | 19–20, **outside** the `MOD + N` rotation |

| Binding | Action |
|---------|--------|
| `MOD + 1–9` | Switch the focused monitor to its own workspace 1–9 |
| `MOD + SHIFT + 1–9` | Move window to the focused monitor's workspace 1–9 |
| `MOD + S` | Toggle special workspace (scratchpad) |
| `MOD + TAB` | Next workspace |
| `MOD + SHIFT + TAB` | Previous workspace |

---

## Ambient display (LG CRT, DP-1)

Placed at detached coordinates so the pointer can't wander onto it and tiled
windows never spill across — it's only visible from the bed. Runs btop, and
switches itself to cava whenever anything is actually playing.

| Binding | Action |
|---------|--------|
| `MOD + \`` | Jump focus to the LG, or back to where you came from |
| `MOD + SHIFT + \`` | Throw the focused window onto the LG (focus stays put) |
| `MOD + ALT + \`` | Flip the LG between its dashboard and its media workspace |

---

## Utilities

| Binding | Action |
|---------|--------|
| `MOD + O` | Toggle waybar |
| `MOD + SHIFT + P` | Color picker (hex to clipboard) |
| `MOD + SHIFT + S` | Screenshot (region freeze) |
| `Print` | Screenshot (region freeze) |
| `MOD + SHIFT + K` | Switch keyboard layout (US ↔ IT) |
| `MOD + SHIFT + .` | Emoji picker (Rofi) |
| `MOD + scroll up` | Zoom in |
| `MOD + scroll down` | Zoom out |

---

## Media Keys

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume +5% |
| `XF86AudioLowerVolume` | Volume −5% |
| `XF86AudioMute` | Mute/unmute sink |
| `XF86AudioMicMute` | Mute/unmute mic |
| `XF86MonBrightnessUp` | Brightness +10% |
| `XF86MonBrightnessDown` | Brightness −10% |
| `XF86AudioNext` | Next track |
| `XF86AudioPlay/Pause` | Play/pause |
| `XF86AudioPrev` | Previous track |

---

## Session / Power

The **power button** in waybar opens **wlogout** with six actions:

| Action | Description |
|--------|-------------|
| Lock | `hyprlock` (lain wall lockscreen) |
| Logout | End Hyprland session |
| Suspend | `systemctl suspend` |
| Hibernate | `systemctl hibernate` |
| Shutdown | `systemctl poweroff` |
| Reboot | `systemctl reboot` |

Idle lock triggers automatically at **5 minutes** of inactivity; display turns off at **5m30s**; suspend at **30 minutes**.
