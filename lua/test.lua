---@diagnostic disable: lowercase-global
local softuart = require "softuart"
local net = require "net"
local uart = require "uart"

dofile("utils.lua")
tcp_port = 1234
recv = nil

--- Initialiser la connexion serie de controle
---@return nil
function serial_init()
    -- RX1 ARDUINO <-> PIN 5 CARTE COMM
    -- TX1 ARDUINO <-> PIN 4 CARTE COMM
    local TX, RX = 6, 7
    suart = softuart.setup(9600, TX, RX)
    local server = net.createServer(net.TCP, 360)
    local global_sck = nil
    -- uart.alt(1)
    -- uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
    server:listen(tcp_port, function(sck)
        global_sck = sck
        sck:on("receive", function(_, pl)
            -- print("TCP_R " .. pl .. "\n")
            suart:write(tostring(pl) .. "\n")
        end)
    end)
    suart:on("data", 2, function(data)
        -- print("SUART_R " .. data)
        if global_sck ~= nil then
            -- print("SUART_S " .. data)
            global_sck:send(tostring(data))
        end
    end)
end

print("Serial TEST")
serial_init()
