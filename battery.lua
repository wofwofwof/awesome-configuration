-- module battery
-- tracks the state and percent and changes things accordingly to the configuration
-- 
-- Some parts should be configured by the user, especially the sound files (I think the defaults are
-- from "Battle of Wesnoth".
-- 
-- This modul has some dependencies. None of them are absolute, it should be very easy to 
-- change the code for other binaries.
--
-- There are many differen power management lua scripts available for awesome, but I've found none
-- that supports DBus. I really like it to get immediate feedback after power on AC changes so
-- I had written this battery module.
--
--
-- Add following part into your rc.lua and replace the path with your path.
-- You can get the correct path with "upower -e" 
-- 
-- -- battery widget for awesome 3.5
-- batterywidget = wibox.widget.textbox()
-- batterywidget:set_markup(battery.getTextString())
-- 
-- dbus.add_match("system", "interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/freedesktop/UPower/devices/battery_CMB1'")
-- dbus.connect_signal("org.freedesktop.DBus.Properties", function(...)
--                                            batterywidget:set_markup(battery.getTextString())
--                                         end
-- )
--
--
--
--
-- Dependencies:
-- upower package for DBus resouce
-- sys filesystem to get the state of power on AC 
-- xbacklight to set the monitor brightness, in debian from package xbacklight
-- aplay for sound, in debian from package alsa-utils
--


local awful = require("awful")


local battery = {}


-- consts for configuration
local brightnessOnAC = 100
local brighnessOnBattery = 40
local brightnessOnLowBattery = 20

local batteryLowStatePercent = {
    ['low'] = 20, 
    ['criticalLow'] = 5  
}

local confdir = awful.util.getdir("config")
local soundOnACState = confdir .. "/sound/onac.wav"
local soundOnBatteryState = confdir .. "/sound/onbattery.wav"
local soundOnLowBattery = confdir .. "/sound/timealarm.wav"


local state = {
    [4] = "↯",            -- full
    [2] = "▼",            -- discharging
    [1] = "▲",            -- charging
    [0] = "unknow state"  -- unknown
}


-- closure variables
battery.oldState = 4
battery.oldACOnline = true
battery.oldPercent = 100
battery.critical = 0


function handleState(newAcOnline)
   local changed = false
   if battery.oldACOnline ~= null and battery.oldACOnline ~= newAcOnline then
      changed = true
      if newAcOnline then
         awful.spawn("aplay " .. soundOnACState)
         awful.spawn("xbacklight -set " .. brightnessOnAC)
      else
         awful.spawn("aplay " .. soundOnBatteryState)
         awful.spawn("xbacklight -set " .. brighnessOnBattery)
      end
   end

   return changed
end

function handleCriticality(currentPercent, currentState)
   local changed = false
   if currentPercent <= batteryLowStatePercent["criticalLow"] and battery.oldPercent > batteryLowStatePercent["criticalLow"] 
	and (currentState == 2 or currentState == 0) then
      -- handle critical battery state

      awful.util.spawn("aplay " .. soundOnLowBattery)
      -- maybe later put here some suspend to disk
      changed = true
      battery.critical = 2
   elseif currentPercent <= batteryLowStatePercent["low"] and battery.oldPercent > batteryLowStatePercent["low"] 
        and (currentState == 2 or currentState == 0) then
      -- handle low battery state
      
      awful.util.spawn("aplay " .. soundOnLowBattery)
      awful.util.spawn("xbacklight -set " .. brightnessOnLowBattery)
      changed = true
      battery.critical = 1
   elseif currentPercent > batteryLowStatePercent["low"] then
      battery.critical = 0
   end

   return changed
end

function getAllValuesFromProperties(upower_stat)
   local currentState = string.match(upower_stat, "\"State\".-uint32 ([0-9]+)")
   currentState = tonumber(currentState)

   local currentPercent = string.match(upower_stat, "\"Percentage\".-double ([0-9%.]+)")
   currentPercent = tonumber(currentPercent)

   local currentTimeToEmpty = string.match(upower_stat, "\"TimeToEmpty\".-int64 ([0-9]+)")
   currentTimeToEmpty = tonumber(currentTimeToEmpty)
   
   local currentTimeToFull = string.match(upower_stat, "\"TimeToFull\".-int64 ([0-9]+)")
   currentTimeToFull = tonumber(currentTimeToFull)


   return currentState, currentPercent, currentTimeToEmpty, currentTimeToFull
end

function battery.getTextString(batterywidget)
   return awful.spawn.easy_async('dbus-send --print-reply --system --dest=org.freedesktop.UPower /org/freedesktop/UPower/devices/DisplayDevice org.freedesktop.DBus.Properties.GetAll string:"org.freedesktop.UPower.Device"', 
        function(stdout, stderr, reason, exit_code) 
           return awful.spawn.easy_async('cat /sys/class/power_supply/AC/online',
              function(stdout_proc, stderr_proc, reason_proc, exit_code_proc)
                 local currentAcState = getAcStateFromSys(stdout_proc)
                 local currentState, currentPercent, currentTimeToEmpty, currentTimeToFull = getAllValuesFromProperties(stdout)
                 handleState(currentAcState)
                 handleCriticality(currentPercent, currentState)
                 local widget_text = createTextString(currentAcState, currentState, currentPercent, currentTimeToEmpty, currentTimeToFull)
                 batterywidget:set_markup(widget_text)
                 return 
              end
           )
        end
   )
end


function createTextString(currentAcState, currentState, currentPercent, currentTimeToEmpty, currentTimeToFull)
   battery.oldState = currentState
   battery.oldACOnline = currentAcState
   battery.oldPercent = currentPercent

   local minutes = 0
   if currentAcState then
      minutes = currentTimeToFull/60
   else
      minutes = currentTimeToEmpty/60
   end

   local span_start = ""
   local span_end = ""

   if battery.critical > 0 then
      span_start = "<span foreground=\"red\">"
      span_end = "</span>"
   end

--   return " | " .. span_start .. currentPercent .. "% " .. "(" .. math.floor(minutes) .. "m)" .. state[currentState] .. span_end .. " | "
   return " | " .. span_start .. currentPercent .. "% " .. state[currentState] .. span_end .. " | "
end


function getAcStateFromSys(acStateString)
   return (tonumber(acStateString) == 1)
end





return battery

