---@diagnostic disable: lowercase-global
local softuart = require "softuart"
local net = require "net"
local uart = require "uart"
local gdbstub = require "gdbstub"

dofile("utils.lua")
tcp_port = 1234
recv = nil

--- Initialiser la connexion serie de controle
---@return nil
function serial_init()
    -- RX1 ARDUINO <-> PIN 5 CARTE COMM
    -- TX1 ARDUINO <-> PIN 4 CARTE COMM
    local TX = 2
    local suart = softuart.setup(9600, TX, nil)
    local server = net.createServer(net.TCP, 360)
    server:listen(tcp_port, function(sck)
        sck:on("receive", function(_, pl)
            print("TCP_R " .. tostring(pl) .. "\n")
            suart:write(tostring(pl) .. "\n")
        end)
    end)
end

print("Serial TEST")
serial_init()
print("Serial TEST2")
