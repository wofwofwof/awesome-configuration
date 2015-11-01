# awesome-configuration
configuration files and extensions for awesome window manager

## Battery module with DBus
The goal of this module was to get imediately feedback after the power AC state changes.
To include this into your configuration copy the battery.lua in your directory with rc.lua.
If you'd like to use the default sound files you need to copy the sound/ directory into this directory, too.

For the configuration you need the correct path for your device. You can find it with the command:
```
upower -e
```


### Changes for rc.lua (please change the path according to your computer):
```
local battery = require('battery')

-- battery widget for awesome 3.5
batterywidget = wibox.widget.textbox()
batterywidget:set_markup(battery.getTextString())

dbus.add_match("system", "interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/freedesktop/UPower/devices/battery_CMB1'")
dbus.connect_signal("org.freedesktop.DBus.Properties", function(...)
                                           batterywidget:set_markup(battery.getTextString())
                                        end
)

```

### Dependencies
- upower package for DBus resouce
- sys filesystem to get the state of power on AC
- xbacklight to set the monitor brightness, in debian from package xbacklight
- aplay for sound, in debian from package alsa-utils




