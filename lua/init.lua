---@diagnostic disable: lowercase-global

--- Empêche un éventuel bootloop en cas de problème avec le script
local file = require "file"
local tmr = require "tmr"
local wifi = require "wifi"

dofile("credentials.lua")

function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in 'application.lua'
        if file.open("test.lua") == nil then
            print("Control.lua")
            dofile("control.lua")
        else
            -- dofile("test.lua")
        end
    end
end

function wifi_init()
    wifi.setcountry({
        country = "FR",
        start_ch = 1,
        end_ch = 13,
        policy = wifi.COUNTRY_AUTO
    })
    -- Passage en mode AP
    wifi.setmode(wifi.SOFTAP)
    -- 802.11b (le plus de portee possible)
    wifi.setphymode(wifi.PHYMODE_B)
    -- Configuration
    wifi.ap.config({
        ssid = WIFI_SSID,
        pwd = WIFI_PWD,
        auth = wifi.WPA2_PSK
    })
end

wifi_got_connected = function (T)
    print("Startup will resume momentarily, you have 5 seconds to abort.")
    print("Waiting...")
    tmr.create():alarm(5000, tmr.ALARM_SINGLE, startup)
end

wifi.eventmon.register(wifi.eventmon.AP_STACONNECTED, wifi_got_connected)
wifi_init()