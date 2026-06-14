--[[============================================================================
  meny.lua  —  ПУБЛИЧНОЕ меню-ключница (статичная ссылка для всех покупателей)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/slavabeez/link/main/meny.lua"))()

  Экраны с плавными переходами:
    [1] Ввод ключа  ->  [2] Анимированная загрузка  ->  [3] Меню TDS FARM
  Кнопки грузят настоящий код С БОТА (приватный репо). user id проверяет сервер.
============================================================================]]--

local URL_FILE = "https://raw.githubusercontent.com/slavabeez/link/main/link.lua"
local BUY_URL  = "https://funpay.com/users/6883431/"
local KEYFILE  = "protecthub_key.txt"

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local LP      = Players.LocalPlayer
local userId  = tostring(LP and LP.UserId or 0)
local placeId = tostring(game.PlaceId)

-- палитра
local BG      = Color3.fromRGB(22, 22, 31)
local CARD_A  = Color3.fromRGB(36, 34, 56)
local CARD_B  = Color3.fromRGB(20, 20, 30)
local ACCENT1 = Color3.fromRGB(130, 95, 255)
local ACCENT2 = Color3.fromRGB(70, 200, 255)
local GEMS_C  = Color3.fromRGB(150, 70, 235)
local MONEY_C = Color3.fromRGB(45, 195, 110)
local TXT     = Color3.fromRGB(238, 238, 248)
local SUB     = Color3.fromRGB(155, 162, 190)

-- ---------- надёжный HTTP ----------
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
    if not resp then return nil, "Сервер недоступен" end
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

-- ---------- UI-хелперы ----------
local parent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function() if parent:FindFirstChild("ProtectHub") then parent.ProtectHub:Destroy() end end)
local screen = Instance.new("ScreenGui")
screen.Name = "ProtectHub"; screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.IgnoreGuiInset = true; screen.Parent = parent

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c end
local function grad(o, a, b, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) })
    g.Rotation = rot or 90; g.Parent = o; return g
end
local function pad(o, p)
    local u = Instance.new("UIPadding"); u.PaddingLeft = UDim.new(0, p); u.PaddingRight = UDim.new(0, p)
    u.PaddingTop = UDim.new(0, p); u.PaddingBottom = UDim.new(0, p); u.Parent = o; return u
end
local function label(parentObj, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size
    l.TextColor3 = color or TXT; l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parentObj
    return l
end
local function center(w, h) return UDim2.new(0.5, -w / 2, 0.5, -h / 2) end

-- ховер-анимация кнопки (только цвет — без сдвига размера, чтобы ничего не «уезжало»)
local function hoverify(btn, base, hov)
    btn.MouseEnter:Connect(function() Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hov }):Play() end)
    btn.MouseLeave:Connect(function() Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = base }):Play() end)
end

-- пульсация свечения рамки
local function pulse(stroke)
    task.spawn(function()
        while stroke.Parent do
            local a = Tween:Create(stroke, TweenInfo.new(1.1), { Transparency = 0.15 }); a:Play(); a.Completed:Wait()
            if not stroke.Parent then break end
            local b = Tween:Create(stroke, TweenInfo.new(1.1), { Transparency = 0.6 }); b:Play(); b.Completed:Wait()
        end
    end)
end

-- карточка (CanvasGroup -> можно плавно гасить целиком)
local function newCard(w, h)
    local cg = Instance.new("CanvasGroup")
    cg.Size = UDim2.fromOffset(w, h); cg.Position = center(w, h)
    cg.BackgroundColor3 = CARD_B; cg.GroupTransparency = 1; cg.BorderSizePixel = 0; cg.Parent = screen
    corner(cg, 16); grad(cg, CARD_A, CARD_B, 125)
    local st = Instance.new("UIStroke"); st.Color = ACCENT1; st.Thickness = 1.6; st.Transparency = 0.4; st.Parent = cg
    pulse(st)
    return cg
end

-- перетаскивание
local function dragify(handle, card)
    local dragging, ds, sp
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; ds = i.Position; sp = card.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            card.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- переход: гасим старую карту, плавно показываем новую
local cur
local function swap(card)
    local old = cur; cur = card
    local home = card.Position
    card.Position = home + UDim2.fromOffset(0, 22)
    Tween:Create(card, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { GroupTransparency = 0, Position = home }):Play()
    if old then
        Tween:Create(old, TweenInfo.new(0.22, Enum.EasingStyle.Quad),
            { GroupTransparency = 1, Position = old.Position - UDim2.fromOffset(0, 22) }):Play()
        task.delay(0.24, function() if old then old:Destroy() end end)
    end
end
local function closeAll()
    if cur then
        Tween:Create(cur, TweenInfo.new(0.25), { GroupTransparency = 1, Position = cur.Position + UDim2.fromOffset(0, 22) }):Play()
    end
    task.delay(0.27, function() screen:Destroy() end)
end

-- ====================== [2] ЭКРАН ЗАГРУЗКИ ======================
-- worker(setStatus) -> вызывается асинхронно; setStatus меняет подпись
local function showLoading(titleText, worker)
    local w, h = 330, 148
    local card = newCard(w, h)

    local title = label(card, titleText or "ЗАГРУЗКА", 19, TXT, Enum.Font.GothamBold)
    title.Size = UDim2.new(1, -32, 0, 28); title.Position = UDim2.new(0, 16, 0, 20)
    title.TextXAlignment = Enum.TextXAlignment.Center
    grad(title, ACCENT2, ACCENT1, 0)

    local status = label(card, "Подключение", 13, SUB, Enum.Font.Gotham)
    status.Size = UDim2.new(1, -32, 0, 20); status.Position = UDim2.new(0, 16, 0, 56)
    status.TextXAlignment = Enum.TextXAlignment.Center

    -- индикатор-полоса
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -56, 0, 10); track.Position = UDim2.new(0, 28, 0, 90)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 60); track.BorderSizePixel = 0
    track.ClipsDescendants = true; track.Parent = card; corner(track, 5)
    local seg = Instance.new("Frame")
    seg.Size = UDim2.new(0.4, 0, 1, 0); seg.Position = UDim2.new(-0.45, 0, 0, 0)
    seg.BorderSizePixel = 0; seg.Parent = track; corner(seg, 5)
    grad(seg, ACCENT1, ACCENT2, 0)

    local foot = label(card, "SCRIPT HUB", 11, Color3.fromRGB(95, 100, 130), Enum.Font.GothamBold)
    foot.Size = UDim2.new(1, -32, 0, 16); foot.Position = UDim2.new(0, 16, 1, -26)
    foot.TextXAlignment = Enum.TextXAlignment.Center

    -- бесконечная анимация полосы
    task.spawn(function()
        while track.Parent do
            seg.Position = UDim2.new(-0.45, 0, 0, 0)
            local tw = Tween:Create(seg, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                { Position = UDim2.new(1.05, 0, 0, 0) })
            tw:Play(); tw.Completed:Wait()
            if not track.Parent then break end
        end
    end)

    -- анимация точек у статуса
    local statusText = "Подключение"
    task.spawn(function()
        local n = 0
        while status.Parent do
            status.Text = statusText .. string.rep(".", n)
            n = (n + 1) % 4; task.wait(0.35)
        end
    end)
    local function setStatus(t) statusText = t end

    swap(card)
    task.spawn(function() worker(setStatus) end)
end

-- ====================== [3] МЕНЮ TDS FARM ======================
local function showFarm(server, key, errMsg)
    local w, h = 300, 210
    local card = newCard(w, h)

    -- шапка
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 46); bar.BackgroundColor3 = ACCENT1; bar.BorderSizePixel = 0; bar.Parent = card
    corner(bar, 16); grad(bar, GEMS_C, ACCENT1, 25)
    local barFix = Instance.new("Frame") -- скрыть нижнее скругление шапки
    barFix.Size = UDim2.new(1, 0, 0, 16); barFix.Position = UDim2.new(0, 0, 1, -16)
    barFix.BackgroundColor3 = ACCENT1; barFix.BorderSizePixel = 0; barFix.Parent = bar
    grad(barFix, GEMS_C, ACCENT1, 25)

    local ttl = label(bar, "⚔️  TDS FARM", 19, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
    ttl.Size = UDim2.new(1, -60, 1, 0); ttl.Position = UDim2.new(0, 16, 0, 0); ttl.ZIndex = 2

    local cls = Instance.new("TextButton")
    cls.Size = UDim2.fromOffset(28, 28); cls.Position = UDim2.new(1, -36, 0, 9)
    cls.BackgroundColor3 = Color3.fromRGB(225, 70, 80); cls.Text = "✕"; cls.TextColor3 = Color3.new(1, 1, 1)
    cls.Font = Enum.Font.GothamBold; cls.TextSize = 15; cls.BorderSizePixel = 0; cls.ZIndex = 2; cls.Parent = bar
    corner(cls, 8)
    cls.MouseButton1Click:Connect(closeAll)
    hoverify(cls, Color3.fromRGB(225, 70, 80), Color3.fromRGB(245, 95, 105))

    local function farmBtn(text, y, c1, c2)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -32, 0, 50); b.Position = UDim2.new(0, 16, 0, y)
        b.BackgroundColor3 = c1; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold; b.TextSize = 15; b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = card
        corner(b, 10); grad(b, c1, c2, 35)
        local s = Instance.new("UIStroke", b); s.Thickness = 1.4; s.Transparency = 0.45; s.Color = c1:Lerp(Color3.new(1, 1, 1), 0.4)
        hoverify(b, c1, c1:Lerp(Color3.new(1, 1, 1), 0.18))
        return b
    end
    local gemsB  = farmBtn("💎   GEMS FARM",  62,  GEMS_C,  Color3.fromRGB(95, 45, 175))
    local moneyB = farmBtn("💰   MONEY FARM", 120, MONEY_C, Color3.fromRGB(30, 150, 85))

    local status = label(card, "Готово к работе  •  F1 / F2", 12, SUB, Enum.Font.Gotham)
    status.Size = UDim2.new(1, -32, 0, 18); status.Position = UDim2.new(0, 16, 1, -26)
    status.TextXAlignment = Enum.TextXAlignment.Center
    if errMsg then status.Text = "⚠ " .. errMsg; status.TextColor3 = Color3.fromRGB(245, 150, 90) end

    dragify(bar, card)

    local active = false
    local function runFarm(kind)
        if active then return end
        active = true
        showLoading((kind == "gems" and "💎 GEMS FARM" or "💰 MONEY FARM"), function(setStatus)
            setStatus("Подключение к серверу")
            task.wait(0.25)
            setStatus("Загрузка скрипта")
            local ok = runScript(server, key, kind)
            if ok then
                setStatus("Запуск")
                task.wait(0.3)
                closeAll()
            else
                showFarm(server, key, "Сервер не ответил, попробуй ещё раз")
            end
            active = false
        end)
    end

    gemsB.MouseButton1Click:Connect(function() runFarm("gems") end)
    moneyB.MouseButton1Click:Connect(function() runFarm("money") end)
    UIS.InputBegan:Connect(function(input, gp)
        if gp or not card.Parent then return end
        if input.KeyCode == Enum.KeyCode.F1 then runFarm("gems")
        elseif input.KeyCode == Enum.KeyCode.F2 then runFarm("money") end
    end)

    swap(card)
end

-- ====================== [1] ВВОД КЛЮЧА ======================
local function showGate(presetKey, autostart, errMsg)
    local w, h = 340, 250
    local card = newCard(w, h)

    local title = label(card, "SCRIPT HUB", 23, TXT, Enum.Font.GothamBold)
    title.Size = UDim2.new(1, -32, 0, 30); title.Position = UDim2.new(0, 18, 0, 16)
    grad(title, ACCENT2, ACCENT1, 0)

    local sub = label(card, errMsg or "Введите ключ для доступа", 13, errMsg and Color3.fromRGB(240, 130, 130) or SUB, Enum.Font.Gotham)
    sub.Size = UDim2.new(1, -32, 0, 32); sub.Position = UDim2.new(0, 18, 0, 50)
    sub.TextWrapped = true; sub.TextYAlignment = Enum.TextYAlignment.Top

    local cls = Instance.new("TextButton")
    cls.Size = UDim2.fromOffset(28, 28); cls.Position = UDim2.new(1, -36, 0, 14)
    cls.BackgroundColor3 = Color3.fromRGB(52, 52, 64); cls.Text = "✕"; cls.TextColor3 = Color3.fromRGB(230, 230, 235)
    cls.Font = Enum.Font.GothamBold; cls.TextSize = 14; cls.BorderSizePixel = 0; cls.Parent = card; corner(cls, 8)
    cls.MouseButton1Click:Connect(closeAll)
    hoverify(cls, Color3.fromRGB(52, 52, 64), Color3.fromRGB(70, 70, 84))

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -32, 0, 42); box.Position = UDim2.new(0, 16, 0, 92)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 52); box.Font = Enum.Font.Gotham
    box.PlaceholderText = "XXXXX-XXXXX-XXXXX-XXXXX"; box.Text = presetKey or ""; box.TextSize = 15
    box.TextColor3 = TXT; box.PlaceholderColor3 = Color3.fromRGB(120, 120, 138)
    box.ClearTextOnFocus = false; box.Parent = card; corner(box, 9)
    local bxs = Instance.new("UIStroke", box); bxs.Color = ACCENT1; bxs.Thickness = 1; bxs.Transparency = 0.5
    box.Focused:Connect(function() Tween:Create(bxs, TweenInfo.new(0.15), { Transparency = 0.05 }):Play() end)
    box.FocusLost:Connect(function() Tween:Create(bxs, TweenInfo.new(0.15), { Transparency = 0.5 }):Play() end)

    local act = Instance.new("TextButton")
    act.Size = UDim2.new(1, -32, 0, 44); act.Position = UDim2.new(0, 16, 0, 146)
    act.BackgroundColor3 = ACCENT1; act.Text = "Активировать"; act.TextColor3 = Color3.new(1, 1, 1)
    act.Font = Enum.Font.GothamBold; act.TextSize = 16; act.BorderSizePixel = 0; act.AutoButtonColor = false; act.Parent = card
    corner(act, 9); grad(act, ACCENT1, Color3.fromRGB(95, 70, 220), 35)
    hoverify(act, ACCENT1, ACCENT1:Lerp(Color3.new(1, 1, 1), 0.15))

    local buyb = Instance.new("TextButton")
    buyb.Size = UDim2.new(1, -32, 0, 40); buyb.Position = UDim2.new(0, 16, 0, 198)
    buyb.BackgroundColor3 = MONEY_C; buyb.Text = "Купить ключ  (FunPay)"; buyb.TextColor3 = Color3.new(1, 1, 1)
    buyb.Font = Enum.Font.GothamBold; buyb.TextSize = 14; buyb.BorderSizePixel = 0; buyb.AutoButtonColor = false; buyb.Parent = card
    corner(buyb, 9); grad(buyb, MONEY_C, Color3.fromRGB(30, 150, 85), 35)
    hoverify(buyb, MONEY_C, MONEY_C:Lerp(Color3.new(1, 1, 1), 0.15))

    dragify(title, card)

    local function activate()
        local key = trim(box.Text)
        if key == "" then sub.Text = "Введите ключ"; sub.TextColor3 = Color3.fromRGB(240, 130, 130); return end
        showLoading("ПРОВЕРКА КЛЮЧА", function(setStatus)
            setStatus("Подключение к серверу")
            local server = getServer()
            if not server then return showGate(key, false, "Сервер недоступен (бот выключен?)") end
            setStatus("Проверка ключа")
            local ok, reason = checkKey(server, key)
            if ok then saveKey(key); showFarm(server, key)
            else clearKey(); showGate(key, false, "❌ " .. tostring(reason)) end
        end)
    end

    act.MouseButton1Click:Connect(activate)
    box.FocusLost:Connect(function(enter) if enter then activate() end end)
    buyb.MouseButton1Click:Connect(function()
        if setclipboard then pcall(setclipboard, BUY_URL); sub.Text = "Ссылка скопирована — открой в браузере"; sub.TextColor3 = ACCENT2
        else sub.Text = BUY_URL; sub.TextColor3 = ACCENT2 end
    end)

    swap(card)
    if autostart and presetKey and presetKey ~= "" then task.defer(activate) end
end

-- старт: если есть сохранённый ключ — сразу проверяем
local saved = loadKey()
showGate(saved or "", saved ~= nil and saved ~= "", nil)
