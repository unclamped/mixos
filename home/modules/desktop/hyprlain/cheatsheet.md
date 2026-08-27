# Hyprlain — Keybindings Cheat Sheet

> **MOD = Super (Windows/Meta)**
>
> Everything here comes from `default.nix` in this directory, so it applies to
> **both** hosts unless a row says otherwise. Host-specific bindings live in
> `home/hosts/<host>/hyprlain-*.nix`.

---

## Applications

| Binding | Action |
|---------|--------|
| `MOD + Q` | Terminal (kitty, session-scoped config) |
| `MOD + W` | Browser (turing: Zen · cerf: Helium) |
| `MOD + E` | File manager (Dolphin) |
| `MOD + T` | Editor (kitty → nvim) |
| `MOD + SPACE` | App launcher (Vicinae) |
| `MOD + SHIFT + M` | Music (Spotify) — **turing only** |

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
| `MOD + SHIFT + H/J/K/L` | Move window within a group ← → ↑ ↓ |
| `MOD + CTRL + H` | Previous tab in group |
| `MOD + CTRL + L` | Next tab in group |
| `MOD + LMB drag` | Move floating window |
| `MOD + RMB drag` | Resize window |

---

## Workspaces

| Binding | Action |
|---------|--------|
| `MOD + 1–9` | Switch to workspace 1–9 |
| `MOD + SHIFT + 1–9` | Move window to workspace 1–9 |
| `MOD + S` | Toggle special workspace (scratchpad) |
| `MOD + TAB` | Next workspace |
| `MOD + SHIFT + TAB` | Previous workspace |

**cerf** has one output, so those are plain global workspaces.

**turing** slices them per monitor — `MOD + N` always acts on whichever monitor
has focus, and never jumps you across screens:

| Monitor | Position | Workspaces |
|---------|----------|------------|
| `HDMI-A-1` (Samsung S19D300) | centre, main | 1–9 |
| `DP-3` (Samsung SyncMaster CRT) | right | 10–18 |
| `DP-1` (LG T730SH CRT) | ambient / bed | 19–20, **outside** the `MOD + N` rotation |

---

## Ambient display (LG CRT, DP-1) — turing only

Placed at detached coordinates so the pointer can't wander onto it and tiled
windows never spill across — it's only visible from the bed. Runs btop, and
switches itself to cava whenever anything is actually playing.

| Binding | Action |
|---------|--------|
| ``MOD + ` `` | Jump focus to the LG, or back to where you came from |
| ``MOD + SHIFT + ` `` | Throw the focused window onto the LG (focus stays put) |
| ``MOD + ALT + ` `` | Flip the LG between its dashboard and its media workspace |

---

## Utilities

| Binding | Action |
|---------|--------|
| `MOD + O` | Toggle waybar |
| `MOD + SHIFT + P` | Colour picker (hex to clipboard) |
| `MOD + SHIFT + S` | Screenshot (region, freeze) |
| `Print` | Screenshot (region, freeze) |
| `MOD + SHIFT + N` | Toggle night mode (hyprsunset, 3500K ↔ 6500K) |

---

## Media / function keys

Every one of these is bound `locked = true`, so they keep working on the
lockscreen.

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` / `MOD + =` | Volume +5% |
| `XF86AudioLowerVolume` / `MOD + -` | Volume −5% |
| `XF86AudioMute` / `MOD + \` | Mute/unmute sink |
| `XF86AudioMicMute` | Mute/unmute mic |
| `XF86MonBrightnessUp` / `MOD + ]` | Brightness +10% |
| `XF86MonBrightnessDown` / `MOD + [` | Brightness −10% |
| `XF86KbdBrightnessUp/Down` | Keyboard backlight |
| `XF86Display` | Re-apply the monitor layout (after (un)plugging a screen) |
| `XF86AudioNext` / `MOD + .` | Next track |
| `XF86AudioPlay`/`Pause` / `MOD + P` | Play/pause |
| `XF86AudioPrev` / `MOD + ,` | Previous track |
| `XF86Sleep` | Suspend |
| `XF86PowerOff` | Power menu (see below) |

On the EliteBook, whether you press these directly or need `Fn` first is a BIOS
setting ("Action Keys Mode"); see `modules/hardware/laptop-keys.nix` for the
per-key map and for how to find out what a key really emits (`wev`).

---

## Session / Power

Three things open the same **wlogout** overlay:

* `MOD + ESCAPE`
* the **physical power button** (logind is told to ignore it — see
  `modules/desktop/power-menu.nix`; a *long* press still forces a hard poweroff)
* the power button in waybar

| Action | Description |
|--------|-------------|
| Lock (`l`) | `hyprlock`, Lain wall lockscreen |
| Logout (`e`) | `uwsm stop` — ends the session cleanly and returns to SDDM |
| Suspend (`u`) | `systemctl suspend` |
| Hibernate (`h`) | `systemctl hibernate` |
| Shutdown (`s`) | `systemctl poweroff` |
| Reboot (`r`) | `systemctl reboot` |

### Idle timers

| Stage | turing | cerf |
|-------|--------|------|
| Dim backlight | 2m30s | 2m30s |
| Lock | 5m | 5m |
| Displays off | 5m30s | 5m30s |
| Suspend | 30m | 15m |

Nothing dims or suspends while PipeWire has a playback stream running
(`wayland-pipewire-idle-inhibit`).

---

## Keyboard layouts

| Host | Internal keyboard | External keyboards |
|------|-------------------|--------------------|
| turing | — | `us` + `altgr-intl` |
| cerf | `latam` (la-latin1) | `us` + `altgr-intl` |

On cerf the two are live **at the same time** — it is a per-device rule
(`hl.device`), not a layout cycle, so there is nothing to toggle. The lockscreen
shows the active layout in its bottom-right corner.
