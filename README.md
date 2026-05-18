# Mouse Battery & DPI — DankMaterialShell plugin

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar
plugin that shows the battery level of a wireless mouse and lets you switch
DPI presets from a popout.

## Features

- **Battery level** read via `upower` (works with Logitech HID++, Bluetooth
  mice, generic HID power-supply devices).
- **DPI presets** rendered as a grid in the popout; click a value to apply it
  instantly.
- **Two backends** for DPI:
  - [`solaar`](https://pwr-solaar.github.io/Solaar/) — Logitech HID++
    receivers and devices.
  - [`ratbagctl`](https://github.com/libratbag/libratbag) — generic gaming
    mice supported by libratbag.
  - Auto-detection picks the first one available.
- **Bypass for the `solaar config` bug** on keyed settings: ships a small
  Python wrapper (`solaar-dpi.py`) that drives `setting.read()` then
  `write_key_value()` directly, and auto-disables onboard profiles when they
  block external DPI changes (common on Logitech Pro mice).
- **Auto-hide** when no matching device is connected.

## Requirements

- DankMaterialShell ≥ 0.1.0 with the plugin system.
- `upower` (almost certainly already installed).
- One of:
  - `solaar` (recommended for Logitech mice — including PRO X, MX series, G
    series),
  - `libratbag` (provides `ratbagctl` and the `ratbagd` daemon).

On Arch / CachyOS:

```sh
sudo pacman -S upower solaar
# or
sudo pacman -S upower libratbag
sudo systemctl enable --now ratbagd
```

## Installation

Clone into your DMS plugins directory:

```sh
git clone https://github.com/<your-user>/dms-mouse-battery.git \
  ~/.config/DankMaterialShell/plugins/MouseBattery
```

Then in DMS:

1. **Settings → Plugins → Scan for Plugins**
2. Enable **Mouse Battery & DPI**
3. **Settings → Appearance → DankBar Layout** → add `mouseBattery` to the
   section of your choice.

Or, if you prefer to keep the repo under `~/Projects` and symlink:

```sh
git clone https://github.com/<your-user>/dms-mouse-battery.git ~/Projects/dms-mouse-battery
ln -s ~/Projects/dms-mouse-battery ~/.config/DankMaterialShell/plugins/MouseBattery
```

The folder name under `plugins/` must match — `MouseBattery` here.

To apply changes without restarting the whole shell:

```sh
dms ipc plugins reload mouseBattery
```

## Configuration

Open **Settings → Plugins → Mouse Battery & DPI**:

| Setting | What it does |
| ------- | ------------ |
| UPower device type | Section header to match (`mouse`, `gaming-input`, …). Leave at `mouse` for pointing devices. |
| Hide when absent | Hides the pill if no matching device is reported by upower. |
| Battery refresh interval | How often (seconds) upower is polled. |
| DPI backend | `auto`, `solaar`, or `ratbagctl`. |
| Device identifier | Override the device passed to the backend (solaar receiver index/name, ratbagctl short name). Empty = auto. |
| Preset values | Comma-separated list of DPI buttons. Defaults to `400, 600, 800, 1200, 1600, 2000, 2400, 3200, 4000, 4800, 6400, 8000`. |

## How DPI is changed (Solaar backend)

`solaar config <dev> dpi_extended X <n>` from the CLI is broken when the
Solaar GUI daemon isn't running: `write_key_value()` validates the full
`{X, Y, LOD}` value, but `_value` only contains the key you just set, so
the others are missing — `KeyError: NamedInt(1, 'Y')`.

`solaar-dpi.py` works around it:

1. Calls `setting.read(cached=False)` so `_value` is populated with the
   live device state.
2. Calls `write_key_value(X, dpi)` and (if present) `write_key_value(Y, dpi)`.
3. If the write fails because **onboard profiles** are enabled (the device
   ignores external DPI), it disables them and retries once.

This means the script can change the DPI even when Solaar isn't running in
the tray.

## File layout

```
MouseBattery/
├── plugin.json              # DMS manifest
├── MouseBatteryWidget.qml   # Bar pill + popout
├── MouseBatterySettings.qml # Plugin settings tab
├── battery-query.sh         # upower wrapper → key=value output
├── mouse-dpi.sh             # backend dispatcher (solaar | ratbagctl)
└── solaar-dpi.py            # Python wrapper for solaar's keyed DPI setting
```

## Compatibility

Tested with:

- Logitech PRO X 2 (HID++, Lightspeed receiver) via Solaar 1.1.19
- Sony DualShock 4 controller (`gaming-input`, for cross-checking the battery
  query — unrelated to DPI)

Other Logitech wireless mice supported by Solaar should work too. Reports
welcome.

## License

GPL-3.0. See [LICENSE](LICENSE).
