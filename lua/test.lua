---@diagnostic disable: lowercase-global
---@diagnostic disable: undefined-global

local softuart = require "softuart"

dofile("utils.lua")

--- Initialiser la connexion serie de controle
---@return nil
function serial_init()
    -- RX1 ARDUINO <-> PIN 5 CARTE COMM
    -- TX1 ARDUINO <-> PIN 4 CARTE COMM
    local TX, RX = 1, 2
    suart = softuart.setup(300, TX, RX)
    suart:write("4,0.0,0,0\n")
    suart:on("data", 24, function(data)
        print(data)
        if startswith(data, "4") then
            local cmd_name = "getPos"
            print(data)
            -- pos_recieved = true
            -- pos_deg = tonumber(split(data, ",")[2])
            -- pos_steps = tonumber(split(data, ",")[3])
        end 
    end)
end

print("Serial TEST")
serial_init()