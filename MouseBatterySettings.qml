import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "mouseBattery"

    StyledText {
        width: parent.width
        text: "Mouse Battery & DPI"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Battery is read from <b>upower</b>. DPI control requires <b>solaar</b> (Logitech HID++) or <b>libratbag</b> (ratbagctl, generic). Auto-detection picks whichever is installed."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        textFormat: Text.RichText
    }

    SelectionSetting {
        settingKey: "upowerType"
        label: "UPower device type"
        description: "Section header used to identify the device in `upower -i` output. Use `mouse` for most pointing devices."
        options: [
            {label: "Mouse", value: "mouse"},
            {label: "Keyboard", value: "keyboard"},
            {label: "Gaming input", value: "gaming-input"},
            {label: "Headset", value: "headset"}
        ]
        defaultValue: "mouse"
    }

    ToggleSetting {
        settingKey: "hideWhenAbsent"
        label: "Hide when no device is connected"
        description: "If no matching device is found, the pill disappears from the bar."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pollInterval"
        label: "Battery refresh interval"
        description: "How often (in seconds) to query upower."
        defaultValue: 60
        minimum: 10
        maximum: 600
        unit: "s"
        leftIcon: "schedule"
    }

    StyledText {
        width: parent.width
        text: "DPI control"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "dpiBackend"
        label: "DPI backend"
        description: "Choose which tool drives the mouse. Auto picks solaar first, then ratbagctl."
        options: [
            {label: "Auto-detect", value: "auto"},
            {label: "Solaar (Logitech)", value: "solaar"},
            {label: "ratbagctl (libratbag)", value: "ratbagctl"}
        ]
        defaultValue: "auto"
    }

    StringSetting {
        settingKey: "dpiDevice"
        label: "Device identifier (optional)"
        description: "Override the device passed to the backend. For solaar: receiver index (1, 2…) or device name. For ratbagctl: short device name from `ratbagctl list`."
        placeholder: "leave empty for default"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "presetDpi"
        label: "Preset values"
        description: "Comma-separated DPI presets shown as a grid in the popout. Click a value to apply it instantly."
        placeholder: "400, 600, 800, 1200, 1600, 2000, 2400, 3200, 4000, 4800, 6400, 8000"
        defaultValue: "400, 600, 800, 1200, 1600, 2000, 2400, 3200, 4000, 4800, 6400, 8000"
    }

    StyledText {
        width: parent.width
        text: "Tip: click the pill in the bar, then click any preset to apply it. To use a value that isn't listed, add it to the preset list above."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
