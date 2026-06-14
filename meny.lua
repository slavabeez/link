--[[============================================================================
  meny.lua  —  ПУБЛИЧНОЕ меню-ключница (статичная ссылка для всех покупателей)
  Запуск (одна неизменная ссылка):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/slavabeez/link/main/meny.lua"))()

   - читает ТЕКУЩИЙ адрес твоего ПК из репо link/link.lua (его бот меняет сам);
   - спрашивает ключ, запоминает его через writefile/readfile;
   - отправляет ключ боту (/check); при верном ключе даёт выбрать продукт;
   - грузит выбранный скрипт с бота (/get). Код в открытом виде сюда НЕ попадает.
============================================================================]]--

local URL_FILE = "https://raw.githubusercontent.com/slavabeez/link/main/link.lua"
local BUY_URL  = "https://funpay.com/users/6883431/"
local KEYFILE  = "protecthub_key.txt"

-- продукты (один ключ валиден для всех)
local PRODUCTS = {
    { id = "money", label = "💰 Money" },
    { id = "gems",  label = "💎 Gems" },
}

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local LP      = Players.LocalPlayer
local userId  = tostring(LP and LP.UserId or 0)
local placeId = tostring(game.PlaceId)

-- ---------- надёжный HTTP ----------
-- экзекьюторы по-разному называют функцию запроса; пробуем все + game:HttpGet
local httpRequest = (syn and syn.request) or (http and http.request)
    or http_request or (fluxus and fluxus.request) or request

local function trim(s) return (tostring(s or "")):gsub("^%s+", ""):gsub("%s+$", "") end

local function httpGetOnce(u)
    -- 1) game:HttpGet
    local ok, res = pcall(function() return game:HttpGet(u) end)
    if ok and res and res ~= "" then return res end
    -- 2) request() экзекьютора (надёжнее с туннелями)
    if httpRequest then
        local ok2, resp = pcall(function() return httpRequest({ Url = u, Method = "GET" }) end)
        if ok2 and resp and resp.Body and resp.Body ~= "" then return resp.Body end
    end
    return nil
end

-- с ретраями (туннель/кэш иногда отвечают не сразу)
local function httpGet(u)
    for i = 1, 3 do
        local r = httpGetOnce(u)
        if r then return r end
        task.wait(0.6)
    end
    return nil
end

-- файловые функции есть не во всех экзекьюторах
local hasFiles = (writefile and readfile and isfile) and true or false
local function saveKey(k) if hasFiles then pcall(writefile, KEYFILE, k) end end
local function loadKey()
    if hasFiles and isfile(KEYFILE) then local ok, r = pcall(readfile, KEYFILE); if ok then return trim(r) end end
    return nil
end
local function clearKey() if hasFiles and isfile(KEYFILE) then pcall(delfile, KEYFILE) end end

-- текущий адрес сервера (ПК) из репо link
local function getServer()
    local raw = httpGet(URL_FILE .. "?t=" .. tostring(os.time()) .. tostring(math.random(1, 99999)))
    if not raw then return nil end
    raw = trim(raw)
    if raw == "" or raw:find("CHANGE%-ME") or raw:find("PENDING") then return nil end
    return (raw:gsub("/+$", ""))
end

local REASON = {
    badkey = "Неверный ключ", revoked = "Ключ отозван", noaccess = "У ключа нет доступа",
    wronguser = "Ключ привязан к другому аккаунту", ratelimit = "Слишком много попыток, подожди минуту",
}

local function checkKey(server, key)
    local resp = httpGet(server .. "/check?key=" .. key .. "&user=" .. userId .. "&place=" .. placeId)
    if not resp then return nil, "NET" end
    local status, val = trim(resp):match("([^|]+)|?(.*)")
    if status == "OK" then return true end
    return false, REASON[val] or "Доступ запрещён"
end

local function runScript(server, key, name)
    local code = httpGet(server .. "/get?script=" .. name .. "&key=" .. key .. "&user=" .. userId .. "&place=" .. placeId)
    if not code then return false end
    local fn = loadstring(code)
    if not fn then return false end
    return pcall(fn)
end

-- ---------- интерфейс ----------
local parent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function() if parent:FindFirstChild("ProtectHub") then parent.ProtectHub:Destroy() end end)

local gui = Instance.new("ScreenGui")
gui.Name = "ProtectHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 360, 0, 250)
main.Position = UDim2.new(0.5, -180, 0.5, -125)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 12)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(70, 90, 160); stroke.Thickness = 1.5; stroke.Parent = main

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -20, 0, 40); title.Position = UDim2.new(0, 12, 0, 8)
title.Font = Enum.Font.GothamBold; title.Text = "SCRIPT HUB"; title.TextSize = 22
title.TextColor3 = Color3.fromRGB(235, 235, 245); title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 28); close.Position = UDim2.new(1, -34, 0, 12)
close.BackgroundColor3 = Color3.fromRGB(50, 50, 60); close.Text = "X"
close.Font = Enum.Font.GothamBold; close.TextSize = 14; close.TextColor3 = Color3.fromRGB(230, 230, 230)
close.Parent = main; corner(close, 8)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, -24, 0, 34); status.Position = UDim2.new(0, 12, 0, 48)
status.Font = Enum.Font.Gotham; status.Text = "Введите ключ для доступа"; status.TextSize = 13
status.TextColor3 = Color3.fromRGB(170, 180, 200); status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top; status.TextWrapped = true
status.Parent = main

-- зона ввода ключа
local keyArea = Instance.new("Frame"); keyArea.BackgroundTransparency = 1
keyArea.Size = UDim2.new(1, 0, 0, 150); keyArea.Position = UDim2.new(0, 0, 0, 88); keyArea.Parent = main

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -24, 0, 40); box.Position = UDim2.new(0, 12, 0, 0)
box.BackgroundColor3 = Color3.fromRGB(38, 38, 48); box.Font = Enum.Font.Gotham
box.PlaceholderText = "XXXXX-XXXXX-XXXXX-XXXXX"; box.Text = ""; box.TextSize = 15
box.TextColor3 = Color3.fromRGB(235, 235, 245); box.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
box.ClearTextOnFocus = false; box.Parent = keyArea; corner(box, 8)

local activate = Instance.new("TextButton")
activate.Size = UDim2.new(1, -24, 0, 42); activate.Position = UDim2.new(0, 12, 0, 52)
activate.BackgroundColor3 = Color3.fromRGB(60, 110, 230); activate.Font = Enum.Font.GothamBold
activate.Text = "Активировать"; activate.TextSize = 16; activate.TextColor3 = Color3.fromRGB(255, 255, 255)
activate.Parent = keyArea; corner(activate, 8)

local buy = Instance.new("TextButton")
buy.Size = UDim2.new(1, -24, 0, 38); buy.Position = UDim2.new(0, 12, 0, 102)
buy.BackgroundColor3 = Color3.fromRGB(40, 160, 90); buy.Font = Enum.Font.GothamBold
buy.Text = "Купить ключ (FunPay)"; buy.TextSize = 15; buy.TextColor3 = Color3.fromRGB(255, 255, 255)
buy.Parent = keyArea; corner(buy, 8)

-- зона выбора продукта (показывается после верного ключа)
local pickArea = Instance.new("Frame"); pickArea.BackgroundTransparency = 1
pickArea.Size = UDim2.new(1, 0, 0, 150); pickArea.Position = UDim2.new(0, 0, 0, 88)
pickArea.Visible = false; pickArea.Parent = main

-- перетаскивание
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function setStatus(t, c) status.Text = t; status.TextColor3 = c or Color3.fromRGB(170, 180, 200) end

local validServer, validKey

local function launch(name)
    setStatus("Загрузка " .. name .. "...", Color3.fromRGB(120, 220, 140))
    task.spawn(function()
        local ran = runScript(validServer, validKey, name)
        if ran then gui:Destroy()
        else setStatus("Не удалось загрузить скрипт. Попробуй ещё раз.", Color3.fromRGB(230, 180, 90)) end
    end)
end

-- построить кнопки выбора продукта
local function showPicker()
    keyArea.Visible = false
    pickArea.Visible = true
    for _, ch in ipairs(pickArea:GetChildren()) do ch:Destroy() end
    setStatus("✅ Ключ принят. Выбери, что запустить:", Color3.fromRGB(120, 220, 140))
    if #PRODUCTS == 1 then launch(PRODUCTS[1].id); return end
    local y = 4
    for _, p in ipairs(PRODUCTS) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -24, 0, 44); b.Position = UDim2.new(0, 12, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(60, 110, 230); b.Font = Enum.Font.GothamBold
        b.Text = p.label; b.TextSize = 17; b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Parent = pickArea; corner(b, 8)
        b.MouseButton1Click:Connect(function() launch(p.id) end)
        y = y + 52
    end
end

local busy = false
local function tryKey(key, fromSave)
    if busy then return end
    key = trim(key)
    if key == "" then setStatus("Введите ключ", Color3.fromRGB(230, 120, 120)); return end
    busy = true; activate.Text = "Проверка..."

    task.spawn(function()
        local server = getServer()
        if not server then
            setStatus("Сервер сейчас недоступен (бот выключен или туннель не поднялся).", Color3.fromRGB(230, 120, 120))
            activate.Text = "Активировать"; busy = false; return
        end
        local ok, reason = checkKey(server, key)
        if ok then
            saveKey(key); validServer = server; validKey = key
            showPicker()
        else
            if fromSave then clearKey() end
            if reason == "NET" then
                setStatus("Не достучался до сервера (ПК/туннель). Адрес: " .. server, Color3.fromRGB(230, 120, 120))
            else
                setStatus("❌ " .. tostring(reason), Color3.fromRGB(230, 120, 120))
            end
            activate.Text = "Активировать"; busy = false
        end
    end)
end

activate.MouseButton1Click:Connect(function() tryKey(box.Text, false) end)
box.FocusLost:Connect(function(enter) if enter then tryKey(box.Text, false) end end)
buy.MouseButton1Click:Connect(function()
    if setclipboard then pcall(setclipboard, BUY_URL); setStatus("Ссылка скопирована — открой в браузере:\n" .. BUY_URL, Color3.fromRGB(120, 200, 230))
    else setStatus("Купить ключ: " .. BUY_URL, Color3.fromRGB(120, 200, 230)) end
end)

-- автологин по сохранённому ключу
local saved = loadKey()
if saved and saved ~= "" then
    box.Text = saved
    setStatus("Найден сохранённый ключ, проверяю...", Color3.fromRGB(170, 180, 200))
    tryKey(saved, true)
end
