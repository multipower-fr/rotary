---@diagnostic disable: lowercase-global
dofile("utils.lua")

-- Initialiser

-- Port TCP utilise pour le socket
---@type number
tcp_port = 1234

-- TX et RX pour l'UART Arduino
---@type number|nil
TX, RX = 2, nil

-- Steps per rev du moteur
---@type integer
STEPS_PER_REV = 2048

local net = require "net"
local softuart = require "softuart"

MOTOR = {
    -- Steps per rev du moteur
    ---@type integer
    steps_per_rev = STEPS_PER_REV,
    -- Nombre de steps par degres
    ---@type number
    steps_per_deg = STEPS_PER_REV / 360.0,
    -- Position en degrees
    ---@type number
    pos_deg = 0.0,
    -- Position en steps
    ---@type integer
    pos_steps = 0
}

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
        verFirCom = -1
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
        ctrl_angle = 360,
        -- Vitesse max
        ---@type number
        ctrl_speed = 15
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
    -- Iterer dans la table commands pour verifier sa validite
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
    local ctrl_angle = tonumber(split(self.payload, ";")[2]) or nil
    local shifted_steps_dest = 0
    local function calc()
        local ctrl_angle_steps, oneeighty
        if ctrl_angle ~= 0 then
            -- Conversion en steps de la commande
            ctrl_angle_steps = round(ctrl_angle * MOTOR["steps_per_deg"])
            -- Si le moteur est encore a sa position initiale
            if MOTOR["pos_steps"] == 0 then
                if ctrl_angle > 180 then
                    shifted_steps_dest = -(MOTOR["steps_per_rev"] - ctrl_angle_steps)
                else
                    shifted_steps_dest = ctrl_angle_steps
                end
            else
                -- Trouver le cadran de la commande
                oneeighty = (MOTOR["pos_steps"] < MOTOR["steps_per_rev"] / 2 and
                                {MOTOR["pos_steps"] + (MOTOR["steps_per_rev"] / 2)} or
                                {MOTOR["pos_steps"] - (MOTOR["steps_per_rev"] / 2)})[1]
                if oneeighty > MOTOR["pos_steps"] then
                    if ctrl_angle_steps > oneeighty then
                        shifted_steps_dest = -((MOTOR["steps_per_rev"] - ctrl_angle_steps) + MOTOR["pos_steps"])
                    else
                        shifted_steps_dest = ctrl_angle_steps - MOTOR["pos_steps"]
                    end
                else
                    if ctrl_angle_steps < oneeighty then
                        shifted_steps_dest = (MOTOR["steps_per_rev"] - MOTOR["pos_steps"]) + ctrl_angle_steps
                    else
                        shifted_steps_dest = ctrl_angle_steps - MOTOR["pos_steps"]
                    end
                end
            end
            MOTOR["pos_steps"] = ctrl_angle_steps
        else
            -- Retour a 0
            if math.abs(MOTOR["pos_steps"]) < math.abs(MOTOR["steps_per_rev"] - MOTOR["pos_steps"]) then
                shifted_steps_dest = -MOTOR["pos_steps"]
            else
                shifted_steps_dest = math.abs(MOTOR["steps_per_rev"] - MOTOR["pos_steps"])
            end
            MOTOR["pos_steps"] = 0
        end

    end
    if ctrl_angle ~= nil or ctrl_angle < self.constraints["ctrl_angle"] then
        calc()
        self.suart_command = string.format("1,0.0,0,%d", shifted_steps_dest)
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
    local ctrl_steps = tonumber(split(self.payload, ";")[2]) or nil
    local next_pos = nil
    local function calc()
        next_pos = MOTOR["pos_steps"] + ctrl_steps
        if next_pos >= MOTOR["steps_per_rev"] then
            next_pos = next_pos - MOTOR["steps_per_rev"]
        end
        MOTOR["pos_steps"] = next_pos
    end
    local function comm()
        if ctrl_steps ~= nil then
            self.suart_command = string.format("%d,0.0,0,%d", self.ran_command["value"], ctrl_steps)
            self.return_message = string.format("%sACK", self.ran_command["name"])
            self.err = false
        else
            self.suart_command = nil
            self.return_message = string.format("%sERR", self.ran_command["name"])
            self.err = true
            return
        end
    end
    if ctrl_steps ~= nil then
        calc()
        comm()
    end
end

--- Assumer que le 0 est a la position actuelle
---@return nil
function CommandParser:setZero()
    self.suart_command = nil
    self.return_message = string.format("%sACK", self.ran_command["name"])
    MOTOR["pos_deg"], MOTOR["pos_steps"] = 0.0, 0
end

--- Vitesse de rotation des prochaines commandes
---@return nil
function CommandParser:setSpeed()
    -- Commande de vitesse
    ---@type number|nil
    local ctrl_speed = tonumber(split(self.payload, ";")[2]) or nil
    if ctrl_speed ~= nil and ctrl_speed <= self.constraints["ctrl_speed"] and ctrl_speed > 0 then
        self.suart_command = string.format("%d,0.0,%d,0", self.ran_command["value"], ctrl_speed)
        self.return_message = string.format("%sACK", self.ran_command["name"])
        self.err = false
    else
        self.suart_command = nil
        self.return_message = string.format("%sERR", self.ran_command["name"])
        self.err = true
    end
end

--- Recuperer la position
function CommandParser:getPos()
    local function calc()
        -- Prevoir le cas eventuel ou pos_steps est negatif
        MOTOR["pos_deg"] = (MOTOR["pos_steps"] > 0 and {MOTOR["pos_steps"] / MOTOR["steps_per_deg"]} or {0})[1]
    end
    calc()
    self.suart_command = nil
    self.return_message = string.format("%sACK;%.1f;%d", self.ran_command["name"], MOTOR["pos_deg"], MOTOR["pos_steps"])
end

--[=====[
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
--]=====]

--- Open the TCP socket on port tcp_port
function open()
    -- Variables d'initialisation
    local server = net.createServer(net.TCP, 28800)
    suart = softuart.setup(9600, TX, RX)

    print("Established on IP 192.168.4.1:" .. tcp_port)
    -- Initier le callback
    server:listen(tcp_port, function(sck)
        sck:on("receive", function(sock, payload)
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
end

open()
