getgenv().ZenithLoader = getgenv().ZenithLoader or false
if getgenv().ZenithLoader then return end
getgenv().ZenithLoader = true

local GAMES = {
    ["13772394625"] = "bladeball.lua",
    ["142823291"]   = "mm2z.lua",
    ["920587237"]   = "adoptme.lua",
    ["109983668079237"] = "sab.lua",
    ["99606176102979"]  = "sab.lua",
    ["79906538690694"]  = "sab.lua",
    ["119594317142884"] = "sab.lua",
    ["126884695634066"] = "gag2.lua",
    ["8737899170"]      = "ps99.lua",
}

local scriptName = GAMES[tostring(game.PlaceId)]
if not scriptName then
    warn("[Zenith] Unsupported PlaceId: " .. game.PlaceId)
    return
end

local body = game:HttpGet("https://raw.githubusercontent.com/PreZ-z/Zen/main/" .. scriptName, true)
if not body or #body == 0 then
    warn("[Zenith] Failed to fetch " .. scriptName)
    return
end

local chunk, err = loadstring(body, "@zenith_" .. scriptName)
if not chunk then
    warn("[Zenith] Compile error: " .. tostring(err))
    return
end

pcall(chunk)
print("[Zenith] " .. scriptName .. " loaded")
