---@diagnostic disable: lowercase-global
dofile("utils.lua")

-- Initialiser

-- Port TCP utilise pour le socket
tcp_port = 1234

-- TX et RX pour l'UART Arduino
TX, RX = 6, 7

to_send_fifo = (require "fifo").new()
local net = require "net"
local softuart = require "softuart"
local uart = require "uart"

-- Classe pour le parser de commande
CommandParser = {
    -- Correspondance interne des commande (meme chose du cote Arduino)
    ---@type table
    commands = {
        setPos = 0,
        setStep = 1,
        setZero = 2,
        setSpeed = 3,
        getPos = 4,
        getMov = 5,
        verFirCom = -1,
        verFirMot = -2
    },
    -- Commmande selectionnee
    ---@type table
    ran_command = {
        ---@type string Commande
        name = "err",
        ---@type number ID de la commande
        value = -3
    },
    -- Une erreur est survenue
    ---@type boolean
    err = false,
    -- Commande a envoyer sur l'UART vers la carte de controle
    ---@type string|nil
    suart_command = "",
    -- Contraintes
    ---@type table
    constraints = {
        -- Commande max degres
        ---@type number
        pos_deg = 360,
        -- Vitesse max
        ---@type number
        speed = 15
    }
}

--- Initialiseur de la classe du parser de commande
---@param o table|nil Initialiseur de classe
---@param payload string Donnees recues
function CommandParser:new(o, payload)
    o = o or {}
    setmetatable(o, self)
    ---@type table
    self.__index = self
    -- String recu
    ---@type string
    self.payload = payload or ""
    return o
end

--- Premier traitement de la commande, avec rejet des commandes invalides
function CommandParser:receive()
    -- Variable d'erreur (interne a la classe)
    self.err = false
    -- Verifie que la commande est valide
    self.ran_command = {
        name = "err",
        value = -3
    }
    for name, value in pairs(self.commands) do
        if string.find(self.payload, tostring(name)) ~= nil then
            self.ran_command = {
                name = tostring(name),
                value = value
            }
        end
    end
    return self.ran_command
end

--- Extraction des parametres de comamnde
---@return table
function CommandParser:extract_args()
    if self.ran_command["value"] < 0 then
        self:parse_ver()
    elseif self.ran_command["value"] == 0 then
        self:setPos()
    elseif self.ran_command["value"] == 1 then
        self:setStep()
    elseif self.ran_command["value"] == 2 then
        self:setZero()
    elseif self.ran_command["value"] == 3 then
        self:setSpeed()
    elseif self.ran_command["value"] == 4 then
        self:getPos()
    elseif self.ran_command["value"] == 5 then
        self:getMov()
    end
    return {
        error = self.err,
        ran_command = self.ran_command,
        return_message = self.return_message,
        suart_command = self.suart_command
    }
end

--- Repondre a la demande de version
--- TODO: version ARDUINO
function CommandParser:parse_ver()
    self.suart_command = nil
    ---@type string
    self.return_message = "0.0.1a"
end

--- Commander une position absolue en degres
function CommandParser:setPos()
    -- Les tableaux commencent a l'index 1
    -- Position de destination
    ---@type number|nil
    local pos_deg = tonumber(split(self.payload, ";")[2]) or nil
    if pos_deg ~= nil or pos_deg < self.constraints["pos_deg"] then
        self.suart_command = string.format("%d,%.1f,0,0", self.ran_command["value"], pos_deg)
        self.return_message = string.format("%sACK", self.ran_command["name"])
        self.err = false
    else
        self.suart_command = nil
        self.return_message = string.format("%sERR", self.ran_command["name"])
        self.err = true
        return
    end
end

--- Commander une position relative en steps
function CommandParser:setStep()
    ---@type number|nil
    -- Commande de step.
    -- Les tableaux commencent a l'index 1
    local step = tonumber(split(self.payload, ";")[2]) or nil
    if step ~= nil then
        self.suart_command = string.format("%d,0.0,0,%d", self.ran_command["value"], step)
        self.return_message = string.format("%sACK", self.ran_command["name"])
        self.err = false
    else
        self.suart_command = nil
        self.return_message = string.format("%sERR", self.ran_command["name"])
        self.err = true
        return
    end
end

--- Assumer que le 0 est a la position actuelle
---@return nil
function CommandParser:setZero()
    self.suart_command = string.format("%d,0.0,0,0", self.ran_command["value"])
    self.return_message = string.format("%sACK", self.ran_command["name"])
end

--- Vitesse de rotation des prochaines commandes
---@return nil
function CommandParser:setSpeed()
    ---@type number|nil
    local speed = tonumber(split(self.payload, ";")[2]) or nil
    if speed ~= nil or speed <= self.constraints["speed"] then
        self.suart_command = string.format("%d,0.0,%d,0", self.ran_command["value"], speed)
        self.return_message = string.format("%sACK", self.ran_command["name"])
        self.err = false
    else
        self.suart_command = nil
        self.return_message = string.format("%sERR", self.ran_command["name"])
        self.err = true
    end
end

--- TODO: Joindre ACK avec valeur
--- Récupérer la position
function CommandParser:getPos()
    print(string.format("%d,0.0,0,0\n", self.ran_command["value"]))
    suart:write(string.format("%d,0.0,0,0\n", self.ran_command["value"]))
    self.suart_command = nil
    self.return_message = nil
end

function CommandParser:getMov()
    suart:write(string.format("%d,0.0,0,0\n", self.ran_command["value"]))
    self.suart_command = nil
    self.return_message = nil
end

--- Fonction callback a la reception TCP
---@param sck any
---@param payload string
function tcp_receiver(sck, payload)
    local function send_gets()
        to_send_fifo:dequeue(function(data, empty)
            print(data)
            print(empty)
            gets_message = data
            return nil
        end)
        sck:send(gets_message)
    end
    -- Envoi d'un message d'erreur
    local function commande_inconnue(message)
        sck:send(message)
        return true
    end
    local function send_suart(message)
        print(message .. "\n")
        suart:write(message .. "\n")
        return false
    end
    local function send_tcp(message)
        sck:send(message)
        return false
    end
    -- Initialiser le parser de commandes
    cp = CommandParser:new(nil, payload)
    -- Si la commande est -3, une commande inconnue a ete passee
    if cp:receive()["value"] == -3 then
        return commande_inconnue("ERR")
    end
    local return_packet = cp:extract_args()
    if return_packet["error"] or return_packet["suart_command"] == nil then
        send_tcp(return_packet["return_message"])
    elseif return_packet["return_message"] ~= nil then
        send_tcp(return_packet["return_message"])
        send_suart(return_packet["suart_command"])
    else
        if pos_recieved then
            send_gets()
            pos_recieved = false
        end
    end
    return return_packet["error"]

end

--- Open the TCP socket on port tcp_port
function open()
    -- Variables d'initialisation
    local server = net.createServer(net.TCP, 360)
    suart = softuart.setup(9600, TX, RX)
    local global_sck = nil
    -- Utilise les pins GPIO TX et RX
    uart.alt(1)
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)

    print("Established")
    -- Initier le callback
    server:listen(tcp_port, function(sck)
        global_sck = sck
        sck:on("receive", function(sock, payload)
            print(payload)
            -- Initialiser le parser de commandes
            cp = CommandParser:new(nil, payload)
            -- Si la commande est -3, une commande inconnue a ete passee
            if cp:receive()["value"] == -3 then
                sock:send("ERR")
                return true
            end 
            local return_packet = cp:extract_args()
            if return_packet["error"] or return_packet["suart_command"] == nil then
                sock:send(return_packet["return_message"])
            elseif return_packet["return_message"] ~= nil then
                sock:send(return_packet["return_message"])
                suart:write(return_packet["suart_command"] .. "\n")
            end
            return return_packet["error"]
        end)
    end)
    uart:on("data", 1, function(data)
        print(data .. "SUART_R")
        if startswith(data, tostring(4)) then
            local cmd_name = "getPos"
            print(data)
            pos_recieved = true
            pos_deg = tonumber(split(data, ",")[1])
            pos_steps = tonumber(split(data, ",")[2])
            if global_sck ~= nil then
                global_sck:send(string.format("%sACK;%.1f;%d", cmd_name, pos_deg, pos_steps))
            end
        end
    end)
end

--- Initialiser la connexion serie de controle
---@return nil
function serial_init()
    -- RX1 ARDUINO <-> PIN 5 CARTE COMM
    -- TX1 ARDUINO <-> PIN 4 CARTE COMM
    suart = softuart.setup(9600, TX, RX)
    suart:on("data", 13, function(data)
        if startswith(data, tostring(4)) then
            local cmd_name = "getPos"
            print(data)
            pos_recieved = true
            pos_deg = tonumber(split(data, ",")[1])
            pos_steps = tonumber(split(data, ",")[2])
            to_send_fifo:queue(string.format("%sACK;%.1f;%d", cmd_name, pos_deg, pos_steps))
        end
    end)
end

-- serial_init()
open()
