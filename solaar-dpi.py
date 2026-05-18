#!/usr/bin/env python3
"""solaar-dpi.py — set Logitech mouse DPI via solaar's Python API.

The `solaar config <device> dpi_extended X <val>` CLI is broken when the
solaar daemon isn't running: write_key_value() validates ALL keys (X, Y, LOD)
of the keyed setting, but the in-memory `_value` only holds the key just set —
the others are missing -> KeyError on Y.

This wrapper works around it by calling `setting.read()` first, which loads
the current device state into `_value`, and then writes both X and Y in turn.

Usage:
    solaar-dpi.py get [--device <name-or-index>]
    solaar-dpi.py set <dpi> [--device <name-or-index>]
    solaar-dpi.py range [--device <name-or-index>]

Device selection defaults to the first paired mouse on the first receiver,
or to the first standalone Logitech mouse (Bluetooth / direct USB).
"""

from __future__ import annotations

import argparse
import logging
import sys

logging.getLogger().setLevel(logging.ERROR)


def _open_devices():
    """Yield all live Logitech HID++ devices (receiver-paired or standalone)."""
    from logitech_receiver import base, device as device_mod, receiver as receiver_mod

    for info in base.receivers_and_devices():
        try:
            if info.isDevice:
                dev = device_mod.create_device(base, info)
                if dev:
                    yield dev
            else:
                r = receiver_mod.create_receiver(base, info)
                if not r:
                    continue
                for idx in range(1, r.max_devices + 1):
                    d = r[idx]
                    if d:
                        yield d
        except Exception as e:
            print(f"warning: could not open {info.path}: {e}", file=sys.stderr)


def _pick_device(selector: str | None):
    devs = list(_open_devices())
    if not devs:
        return None
    if not selector:
        for d in devs:
            if str(d.kind).lower() == "mouse":
                return d
        return devs[0]
    try:
        idx = int(selector)
        return devs[idx - 1] if 1 <= idx <= len(devs) else None
    except ValueError:
        pass
    sel = selector.lower()
    for d in devs:
        if sel in d.name.lower() or sel == (d.serial or "").lower() or sel == (d.codename or "").lower():
            return d
    return None


def _dpi_setting(dev):
    """Locate the DPI keyed-setting on a device. Returns (setting, x_key, y_key) or (None,...)."""
    for s in dev.settings:
        if s.name in ("dpi_extended", "dpi"):
            keys = getattr(s, "keys", None)
            if keys is None:
                return s, None, None
            x = next((k for k in keys if str(k) == "X"), None)
            y = next((k for k in keys if str(k) == "Y"), None)
            return s, x, y
    return None, None, None


def cmd_get(args):
    dev = _pick_device(args.device)
    if not dev:
        print("no Logitech device found", file=sys.stderr)
        return 2
    s, x, _ = _dpi_setting(dev)
    if not s:
        print("device has no DPI setting", file=sys.stderr)
        return 3
    value = s.read(cached=False)
    if isinstance(value, dict):
        v = value.get(x) if x is not None else next(iter(value.values()), None)
        print(int(v) if v is not None else "")
    elif value is not None:
        print(int(value))
    return 0


def cmd_range(args):
    dev = _pick_device(args.device)
    if not dev:
        print("400 6400 50")
        return 0
    s, x, _ = _dpi_setting(dev)
    if not s or x is None:
        print("400 6400 50")
        return 0
    try:
        choices = s.choices[x] if isinstance(s.choices, dict) or hasattr(s.choices, "__getitem__") else s.choices
        values = sorted({int(c) for c in choices if str(c).isdigit() or isinstance(c, int)})
    except Exception:
        values = []
    if not values:
        print("400 6400 50")
        return 0
    mn, mx = values[0], values[-1]
    step = min((b - a for a, b in zip(values, values[1:]) if b > a), default=50)
    print(f"{mn} {mx} {step}")
    return 0


def _maybe_disable_onboard_profiles(dev):
    """Onboard profiles override external DPI; disable if active."""
    for s in dev.settings:
        if s.name == "onboard_profiles":
            try:
                value = s.read(cached=False)
                if value and int(value) != 0:
                    s.write(0, save=True)
                    print("note: disabled onboard profiles to allow external DPI control", file=sys.stderr)
            except Exception as e:
                print(f"warning: could not disable onboard profiles: {e}", file=sys.stderr)
            return


def _write_dpi(s, x, y, dpi):
    if x is None:
        return bool(s.write(dpi, save=True))
    ok_x = bool(s.write_key_value(int(x), dpi, save=True))
    ok_y = True
    if y is not None:
        ok_y = bool(s.write_key_value(int(y), dpi, save=True))
    return ok_x and ok_y


def cmd_set(args):
    dpi = int(args.value)
    dev = _pick_device(args.device)
    if not dev:
        print("no Logitech device found", file=sys.stderr)
        return 2
    s, x, y = _dpi_setting(dev)
    if not s:
        print("device has no DPI setting", file=sys.stderr)
        return 3
    # Crucial: load the device's current value so write_key_value can validate all keys.
    current = s.read(cached=False)
    if current is None:
        print("could not read current DPI", file=sys.stderr)
        return 4
    try:
        if _write_dpi(s, x, y, dpi):
            return 0
    except Exception as e:
        first_err = e
    else:
        first_err = RuntimeError("DPI write returned false")
    # Common cause on Logitech Pro mice: onboard profiles override the live DPI.
    # Disable them and retry once.
    try:
        _maybe_disable_onboard_profiles(dev)
        s.read(cached=False)
        if _write_dpi(s, x, y, dpi):
            return 0
    except Exception as e:
        print(f"DPI write failed after disabling onboard profiles: {e}", file=sys.stderr)
        return 5
    print(f"DPI write failed: {first_err}", file=sys.stderr)
    return 5


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else "")
    sub = p.add_subparsers(dest="cmd", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--device", help="device selector: name fragment, codename, serial, or index (1-based)")

    sp_get = sub.add_parser("get", parents=[common])
    sp_get.set_defaults(func=cmd_get)

    sp_range = sub.add_parser("range", parents=[common])
    sp_range.set_defaults(func=cmd_range)

    sp_set = sub.add_parser("set", parents=[common])
    sp_set.add_argument("value", type=int)
    sp_set.set_defaults(func=cmd_set)

    args = p.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
