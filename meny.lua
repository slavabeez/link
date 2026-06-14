local URL_FILE = "https://raw.githubusercontent.com/slavabeez/link/main/link.lua"
local BUY_URL  = "https://funpay.com/users/6883431/"
local KEYFILE  = "protecthub_key.txt"

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local LP      = Players.LocalPlayer
local userId  = tostring(LP and LP.UserId or 0)
local placeId = tostring(game.PlaceId)

local httpRequest = (syn and syn.request) or (http and http.request)
    or http_request or (fluxus and fluxus.request) or request
local function trim(s) return (tostring(s or "")):gsub("^%s+", ""):gsub("%s+$", "") end
local function httpGetOnce(u)
    local ok, res = pcall(function() return game:HttpGet(u) end)
    if ok and res and res ~= "" then return res end
    if httpRequest then
        local ok2, resp = pcall(function() return httpRequest({ Url = u, Method = "GET" }) end)
        if ok2 and resp and resp.Body and resp.Body ~= "" then return resp.Body end
    end
    return nil
end
local function httpGet(u)
    for _ = 1, 3 do local r = httpGetOnce(u); if r then return r end; task.wait(0.6) end
    return nil
end

local hasFiles = (writefile and readfile and isfile) and true or false
local function saveKey(k) if hasFiles then pcall(writefile, KEYFILE, k) end end
local function loadKey()
    if hasFiles and isfile(KEYFILE) then local ok, r = pcall(readfile, KEYFILE); if ok then return trim(r) end end
    return nil
end
local function clearKey() if hasFiles and isfile(KEYFILE) then pcall(delfile, KEYFILE) end end

local function getServer()
    local raw = httpGet(URL_FILE .. "?t=" .. tostring(os.time()) .. tostring(math.random(1, 99999)))
    if not raw then return nil end
    raw = trim(raw)
    if raw == "" or raw:find("CHANGE%-ME") or raw:find("PENDING") then return nil end
    return (raw:gsub("/+$", ""))
end

local REASON = {
    badkey = "Неверный ключ", revoked = "Ключ отозван", noaccess = "У ключа нет доступа",
    wronguser = "Ключ привязан к другому аккаунту", ratelimit = "Много попыток, подожди минуту",
}
local function checkKey(server, key)
    local resp = httpGet(server .. "/check?key=" .. key .. "&user=" .. userId .. "&place=" .. placeId)
    if not resp then return nil, "NET" end
    local st, val = trim(resp):match("([^|]+)|?(.*)")
    if st == "OK" then return true end
    return false, REASON[val] or "Доступ запрещён"
end

local function runScript(server, key, name)
    local code = httpGet(server .. "/get?script=" .. name .. "&key=" .. key .. "&user=" .. userId .. "&place=" .. placeId)
    if not code then return false end
    local fn = loadstring(code)
    if not fn then return false end
    return pcall(fn)
end

local parent = (gethui and gethui()) or game:GetService("CoreGui")
local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c end
local function dragify(handle, frame)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function buildFarmMenu(server, key)
    pcall(function() if parent:FindFirstChild("TDSFarmMenu") then parent.TDSFarmMenu:Destroy() end end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TDSFarmMenu"; ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.Parent = parent

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 250, 0, 160); Frame.Position = UDim2.new(0.5, -125, 0.5, -80)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40); Frame.BorderSizePixel = 0
    Frame.ClipsDescendants = true; Frame.BackgroundTransparency = 0.1; Frame.Parent = ScreenGui
    local grad = Instance.new("UIGradient"); grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30)) })
    grad.Rotation = 45; grad.Parent = Frame
    corner(Frame, 12)
    local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(100, 50, 200); st.Thickness = 2; st.Transparency = 0.3; st.Parent = Frame

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40); TitleBar.BackgroundColor3 = Color3.fromRGB(80, 40, 180)
    TitleBar.BorderSizePixel = 0; TitleBar.Parent = Frame; corner(TitleBar, 12)
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -50, 1, 0); Title.Position = UDim2.new(0, 10, 0, 0); Title.BackgroundTransparency = 1
    Title.Text = "⚔️ TDS FARM ⚔️"; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Parent = TitleBar

    local function mkBtn(text, pos, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.9, 0, 0, 40); b.Position = pos; b.BackgroundColor3 = color; b.BackgroundTransparency = 0.1
        b.Text = text; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.TextSize = 14; b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0; b.Parent = Frame; corner(b, 8)
        local s = Instance.new("UIStroke", b); s.Thickness = 2; s.Transparency = 0.3; s.Color = color:Lerp(Color3.new(1,1,1), 0.3)
        return b
    end
    local GemsButton  = mkBtn("💎 ЗАПУСТИТЬ GEMS FARM",  UDim2.new(0.05, 0, 0, 50), Color3.fromRGB(120, 40, 200))
    local MoneyButton = mkBtn("💰 ЗАПУСТИТЬ MONEY FARM", UDim2.new(0.05, 0, 0, 100), Color3.fromRGB(40, 180, 80))

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 20); Status.Position = UDim2.new(0, 10, 1, -25); Status.BackgroundTransparency = 1
    Status.Text = "Готово к работе"; Status.TextColor3 = Color3.fromRGB(200, 200, 255); Status.TextSize = 12
    Status.Font = Enum.Font.Gotham; Status.Parent = Frame

    dragify(TitleBar, Frame)

    local function closeMenu()
        task.spawn(function()
            Tween:Create(Frame, TweenInfo.new(0.3), { BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0) }):Play()
            task.wait(0.3); ScreenGui:Destroy()
        end)
    end

    local active = false
    local function runFarm(kind)
        if active then return end
        active = true
        local btn = (kind == "gems") and GemsButton or MoneyButton
        local old = btn.Text
        btn.Text = "⏳ ЗАГРУЗКА..."; Status.Text = "Запуск кода с сервера..."
        task.spawn(function()
            local ok = runScript(server, key, kind)   -- грузим С БОТА (приватный репо)
            if ok then btn.Text = "✅ ЗАПУЩЕНО"; task.wait(0.4); closeMenu()
            else btn.Text = "❌ ОШИБКА СЕТИ"; Status.Text = "Сервер не ответил"; task.wait(2); btn.Text = old; Status.Text = "Готово к работе" end
            active = false
        end)
    end

    GemsButton.MouseButton1Click:Connect(function() runFarm("gems") end)
    MoneyButton.MouseButton1Click:Connect(function() runFarm("money") end)

    local Close = Instance.new("TextButton", Frame)
    Close.Size = UDim2.new(0, 30, 0, 30); Close.Position = UDim2.new(1, -35, 0, 5)
    Close.BackgroundColor3 = Color3.fromRGB(200, 60, 60); Close.Text = "✖️"; Close.TextColor3 = Color3.new(1,1,1)
    Close.BorderSizePixel = 0; Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 15)
    Close.MouseButton1Click:Connect(closeMenu)

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F1 then runFarm("gems")
        elseif input.KeyCode == Enum.KeyCode.F2 then runFarm("money")
        elseif input.KeyCode == Enum.KeyCode.R then Frame.Position = UDim2.new(0.5, -125, 0.5, -80) end
    end)

    Frame.Position = UDim2.new(0.5, -125, 0.4, -80)
    Tween:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, -125, 0.5, -80) }):Play()
end

pcall(function() if parent:FindFirstChild("ProtectHub") then parent.ProtectHub:Destroy() end end)
local gui = Instance.new("ScreenGui")
gui.Name = "ProtectHub"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = parent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 360, 0, 250); main.Position = UDim2.new(0.5, -180, 0.5, -125)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 30); main.BorderSizePixel = 0; main.Parent = gui
corner(main, 12)
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(70, 90, 160); stroke.Thickness = 1.5; stroke.Parent = main

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1; title.Size = UDim2.new(1, -20, 0, 40); title.Position = UDim2.new(0, 12, 0, 8)
title.Font = Enum.Font.GothamBold; title.Text = "SCRIPT HUB"; title.TextSize = 22
title.TextColor3 = Color3.fromRGB(235, 235, 245); title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 28); close.Position = UDim2.new(1, -34, 0, 12)
close.BackgroundColor3 = Color3.fromRGB(50, 50, 60); close.Text = "X"; close.Font = Enum.Font.GothamBold
close.TextSize = 14; close.TextColor3 = Color3.fromRGB(230, 230, 230); close.Parent = main; corner(close, 8)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1; status.Size = UDim2.new(1, -24, 0, 34); status.Position = UDim2.new(0, 12, 0, 48)
status.Font = Enum.Font.Gotham; status.Text = "Введите ключ для доступа"; status.TextSize = 13
status.TextColor3 = Color3.fromRGB(170, 180, 200); status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top; status.TextWrapped = true; status.Parent = main

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -24, 0, 40); box.Position = UDim2.new(0, 12, 0, 88)
box.BackgroundColor3 = Color3.fromRGB(38, 38, 48); box.Font = Enum.Font.Gotham
box.PlaceholderText = "XXXXX-XXXXX-XXXXX-XXXXX"; box.Text = ""; box.TextSize = 15
box.TextColor3 = Color3.fromRGB(235, 235, 245); box.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
box.ClearTextOnFocus = false; box.Parent = main; corner(box, 8)

local activate = Instance.new("TextButton")
activate.Size = UDim2.new(1, -24, 0, 42); activate.Position = UDim2.new(0, 12, 0, 140)
activate.BackgroundColor3 = Color3.fromRGB(60, 110, 230); activate.Font = Enum.Font.GothamBold
activate.Text = "Активировать"; activate.TextSize = 16; activate.TextColor3 = Color3.fromRGB(255, 255, 255)
activate.Parent = main; corner(activate, 8)

local buy = Instance.new("TextButton")
buy.Size = UDim2.new(1, -24, 0, 38); buy.Position = UDim2.new(0, 12, 0, 190)
buy.BackgroundColor3 = Color3.fromRGB(40, 160, 90); buy.Font = Enum.Font.GothamBold
buy.Text = "Купить ключ (FunPay)"; buy.TextSize = 15; buy.TextColor3 = Color3.fromRGB(255, 255, 255)
buy.Parent = main; corner(buy, 8)

dragify(title, main)
local function setStatus(t, c) status.Text = t; status.TextColor3 = c or Color3.fromRGB(170, 180, 200) end

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
            saveKey(key)
            gui:Destroy()
            buildFarmMenu(server, key)   -- показываем старое меню TDS FARM
        else
            if fromSave then clearKey() end
            if reason == "NET" then setStatus("Не достучался до сервера: " .. server, Color3.fromRGB(230, 120, 120))
            else setStatus("❌ " .. tostring(reason), Color3.fromRGB(230, 120, 120)) end
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

local saved = loadKey()
if saved and saved ~= "" then
    box.Text = saved
    setStatus("Найден сохранённый ключ, проверяю...", Color3.fromRGB(170, 180, 200))
    tryKey(saved, true)
end
