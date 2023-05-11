---@diagnostic disable: lowercase-global
---@diagnostic disable: undefined-global

-- Utilitaires
--- Split on tokens
---@param inputstr string Chaine de caracteres d'entree
---@param sep string Separateur pour le split
---@return table
function split(inputstr, sep)
    sep = sep or ";"
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

--- Recuperer le nom d'une valeur dans une table
---@param t table
---@param value any
---@return any|nil
function get_key_for_value(t, value)
    for k, v in ipairs(t) do
        if v == value then
            return k
        end
    end
    return nil
end

--- Comparer le début d'un string
---@param String string
---@param Start string
function startswith(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end
