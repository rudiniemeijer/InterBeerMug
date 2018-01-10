-- Gadget 0.05
-- Copyright (c) 2018 KPN Cloud DevOps
-- Written by Rudi Niemeijer

-- This version clears the wifi settings on power up, then waits for the user
-- to enter wifi SSID credentials by connecting to the gadget as Access Point
-- Wifi stays powered on until a viable wifi connection exists
-- Then sends a welcome message to IFTTT

-- IMPORTANT
-- Note that this version is barely function complete: it will easily get into
-- a state where nothing happens, power consumption is high and battery falls flat

function nocolons(s)
  local t = ""
  for e in string.gmatch(s, '([^:]+)') do
    t = t .. e
  end
  return t
end

-- Basic variable initialisation
tiltswpen = 4 -- D4/GPIO2
swcounter = 0 -- Counts the number of times tilted
treshold = 5 -- After 5 switch closes, trigger the action
semup = false -- Is true when already busy doing the action
debouncetime = 500 -- ms between two successive tilt switch actions

function tiltSwitched()
  if semup == false then
    swcounter = swcounter + 1
    gpio.trig(tiltswpen,"none")
    tmr.alarm(0, debouncetime, tmr.ALARM_SINGLE, debounce) -- Ignore switch bounces
    if swcounter > treshold then
      if wifi.getmode ~= wifi.STATION then
        normalOps()
      end
      if wifi.sta.status() == wifi.STA_GOTIP then
        tm = rtctime.epoch2cal(rtctime.get())
        timeStr = string.format("%02d%02d%04d%02d%02d%02d", tm["day"], tm["mon"], tm["year"], tm["hour"], tm["min"], tm["sec"])
        URL = "http://maker.ifttt.com/trigger/beerhandle/with/key/bKIFdL3yExWU4IEFkR8tkw?value1=" .. timeStr .. "&value2=" .. nocolons(wifi.sta.getmac())
        semup = true
        http.get(URL, nil, function(code, data)
          if (code < 0) then
            print("HTTP request failed")
            semup = false
          else
            swcounter = 0
            powerSave()
            semup = false
            -- print(code, data)
          end
        end)
      else
        -- Do nothing at this time, but leave wifi enabled
      end
    end
  end
end

-- Call this after power up
function setup()
  wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, hasIP)
  wifi.sta.clearconfig() -- Lose the current wifi configuration
  wifi.nullmodesleep(true) -- Enable wifi shutdown while in NULLMODE
  wifi.setphymode(wifi.PHYMODE_N) -- least range, fast transfer rate, least current draw
  wifi.setmode(wifi.STATION) -- set to normal mode
  wifi.sta.sleeptype(wifi.MODEM_SLEEP)
  wifi.sta.autoconnect(1) -- If wifi is lost, autoconnect
  enduser_setup.manual(false)
  enduser_setup.start()
end

-- Re-arms the trigger on the tiltswpen
function debounce()
  gpio.trig(tiltswpen,"down",tiltSwitched)
end

-- Call this to reduce power consumption
function powerSave()
  --wifi.setmode(wifi.NULLMODE) -- low power state
end

-- Call this to resume normal operation
function normalOps()
  --wifi.setmode(wifi.STATION) -- set to normal mode
  --wifi.sta.connect() -- not sure why autoconnect does not work
end

function hasIP()
  sntp.sync(nil, nil, nil, 1)
  gpio.mode(tiltswpen,gpio.INT,gpio.PULLUP)
  gpio.trig(tiltswpen,"down",tiltSwitched)
  -- tmr.alarm(2, 1000, tmr.ALARM_AUTO, tiltSwitched) -- for testing
end

setup()
print("This is Gadget " .. nocolons(wifi.sta.getmac()))
