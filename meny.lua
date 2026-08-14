local URL_FILE  = "https://raw.githubusercontent.com/slavabeez/link/main/link.lua"
local BUY_URL   = "https://funpay.com/users/6883431/"
local KEYFILE   = "protecthub_key.txt"
local TOWERFILE = "protecthub_towers.txt"   -- выбранные башни (читает money.lua)
local MAX_PICK  = 4

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local HttpSvc = game:GetService("HttpService")
local LP      = Players.LocalPlayer
local userId  = tostring(LP and LP.UserId or 0)
local placeId = tostring(game.PlaceId)

-- палитра
local CARD_A  = Color3.fromRGB(52, 50, 78)
local CARD_B  = Color3.fromRGB(34, 33, 50)
local ACCENT1 = Color3.fromRGB(150, 115, 255)
local ACCENT2 = Color3.fromRGB(95, 210, 255)
local GEMS_C  = Color3.fromRGB(165, 90, 245)
local MONEY_C = Color3.fromRGB(55, 210, 130)
local TXT     = Color3.fromRGB(245, 245, 252)
local SUB     = Color3.fromRGB(175, 182, 210)
local WARN_C  = Color3.fromRGB(245, 150, 90)
local ERR_C   = Color3.fromRGB(240, 130, 130)

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

-- ---------- выбранные башни ----------
local function loadTowers()
    local out = {}
    pcall(function()
        local g = (getgenv and getgenv()) or _G
        if type(g.TDSTowers) == "table" then
            for _, v in ipairs(g.TDSTowers) do if type(v) == "string" and v ~= "" then table.insert(out, v) end end
        end
        if #out == 0 and hasFiles and isfile(TOWERFILE) then
            local d = HttpSvc:JSONDecode(readfile(TOWERFILE))
            if type(d) == "table" then
                for _, v in ipairs(d) do if type(v) == "string" and v ~= "" then table.insert(out, v) end end
            end
        end
    end)
    return out
end
local function saveTowers(list)
    pcall(function() local g = (getgenv and getgenv()) or _G; g.TDSTowers = list end)
    if hasFiles then pcall(function() writefile(TOWERFILE, HttpSvc:JSONEncode(list)) end) end
end

-- ---------- сканирование башен в инвентаре ----------
-- "доступна" = у неё main.topThing НЕВИДИМ (Visible = false или полностью прозрачен)
local function isHidden(o)
    local ok, res = pcall(function()
        if o:IsA("GuiObject") and o.Visible == false then return true end
        if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.ImageTransparency >= 0.95 then return true end
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.TextTransparency >= 0.95 then return true end
        return false
    end)
    return ok and res or false
end

-- возвращает: список башен  ИЛИ  nil, причина
local function scanTowers()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil, "PlayerGui не найден" end

    local node, chain = pg, { "ReactUniversalInventoryView", "Holder", "windowFrame", "towersInventoryFrame", "towerContainer" }
    for _, name in ipairs(chain) do
        local nxt = node:FindFirstChild(name)
        if not nxt then
            return nil, "Не прогрузилось: нет «" .. name .. "»\nОткрой инвентарь башен в игре или перезайди."
        end
        node = nxt
    end

    local scrolls, found, seen = 0, {}, {}
    for _, sc in ipairs(node:GetChildren()) do
        if tostring(sc.Name):lower():find("scrolling") then
            scrolls = scrolls + 1
            for _, tw in ipairs(sc:GetChildren()) do
                local ok = pcall(function()
                    local main = tw:FindFirstChild("main")
                    local top = main and main:FindFirstChild("topThing")
                    if top and isHidden(top) and not seen[tw.Name] then
                        seen[tw.Name] = true
                        table.insert(found, tw.Name)
                    end
                end)
                if not ok then end
            end
        end
    end

    if scrolls == 0 then
        return nil, "В towerContainer нет ни одной вкладки «scrolling».\nИнвентарь не прогрузился — нужно перезайти."
    end
    if #found == 0 then
        return nil, "Просмотрено вкладок: " .. scrolls .. ", доступных башен не найдено\n(у всех topThing видим). Попробуй перезайти."
    end
    table.sort(found)
    return found
end

local function rejoin()
    local TS = game:GetService("TeleportService")
    local ok, err = pcall(function() TS:Teleport(game.PlaceId, LP) end)
    if not ok then
        pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    end
    return ok, err
end

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
local function label(parentObj, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size
    l.TextColor3 = color or TXT; l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parentObj
    return l
end
local function center(w, h) return UDim2.new(0.5, -w / 2, 0.5, -h / 2) end
local function hoverify(btn, base, hov)
    btn.MouseEnter:Connect(function() Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hov }):Play() end)
    btn.MouseLeave:Connect(function() Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = base }):Play() end)
end
local function pulse(stroke)
    task.spawn(function()
        while stroke.Parent do
            local a = Tween:Create(stroke, TweenInfo.new(1.1), { Transparency = 0.15 }); a:Play(); a.Completed:Wait()
            if not stroke.Parent then break end
            local b = Tween:Create(stroke, TweenInfo.new(1.1), { Transparency = 0.6 }); b:Play(); b.Completed:Wait()
        end
    end)
end
local function newCard(w, h)
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(w, h); f.Position = center(w, h)
    f.BackgroundColor3 = CARD_B; f.BorderSizePixel = 0; f.Parent = screen
    corner(f, 16); grad(f, CARD_A, CARD_B, 125)
    local st = Instance.new("UIStroke"); st.Color = ACCENT1; st.Thickness = 1.8; st.Transparency = 0.35; st.Parent = f
    pulse(st)
    return f
end
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

-- квадратная кнопка в шапке (иконка — только ASCII, чтобы не было «квадратов»)
local function iconBtn(parentObj, text, xOffset, bg, hov, fg)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28); b.Position = UDim2.new(1, xOffset, 0, 9)
    b.BackgroundColor3 = bg; b.Text = text; b.TextColor3 = fg or Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 15; b.BorderSizePixel = 0; b.ZIndex = 2
    b.AutoButtonColor = false; b.Parent = parentObj
    corner(b, 8); hoverify(b, bg, hov)
    return b
end

local cur
local function swap(card)
    if cur then cur:Destroy() end
    cur = card
    local home = card.Position
    card.Position = home + UDim2.fromOffset(0, 30)
    Tween:Create(card, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = home }):Play()
end
local function closeAll()
    if cur then Tween:Create(cur, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        { Position = cur.Position + UDim2.fromOffset(0, 30) }):Play() end
    task.delay(0.22, function() screen:Destroy() end)
end

local showFarm  -- forward

-- ====================== [2] ЭКРАН ЗАГРУЗКИ ======================
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

    task.spawn(function()
        while track.Parent do
            seg.Position = UDim2.new(-0.45, 0, 0, 0)
            local tw = Tween:Create(seg, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                { Position = UDim2.new(1.05, 0, 0, 0) })
            tw:Play(); tw.Completed:Wait()
            if not track.Parent then break end
        end
    end)

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

-- ====================== [4] НАСТРОЙКИ БАШЕН ======================
local function showSettings(server, key)
    local w, h = 360, 400
    local card = newCard(w, h)

    -- шапка
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 46); bar.BackgroundColor3 = ACCENT1; bar.BorderSizePixel = 0; bar.Parent = card
    corner(bar, 16); grad(bar, GEMS_C, ACCENT1, 25)
    local barFix = Instance.new("Frame")
    barFix.Size = UDim2.new(1, 0, 0, 16); barFix.Position = UDim2.new(0, 0, 1, -16)
    barFix.BackgroundColor3 = ACCENT1; barFix.BorderSizePixel = 0; barFix.Parent = bar
    grad(barFix, GEMS_C, ACCENT1, 25)

    local ttl = label(bar, "НАСТРОЙКИ БАШЕН", 17, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
    ttl.Size = UDim2.new(1, -90, 1, 0); ttl.Position = UDim2.new(0, 16, 0, 0); ttl.ZIndex = 2

    iconBtn(bar, "X", -36, Color3.fromRGB(225, 70, 80), Color3.fromRGB(245, 95, 105)).MouseButton1Click:Connect(closeAll)
    iconBtn(bar, "<", -70, Color3.fromRGB(70, 65, 100), Color3.fromRGB(95, 88, 130)).MouseButton1Click:Connect(function()
        showFarm(server, key)
    end)
    dragify(bar, card)

    local info = label(card, "", 13, SUB, Enum.Font.Gotham)
    info.Size = UDim2.new(1, -32, 0, 34); info.Position = UDim2.new(0, 16, 0, 52)
    info.TextWrapped = true; info.TextYAlignment = Enum.TextYAlignment.Top

    -- список
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -32, 0, 212); list.Position = UDim2.new(0, 16, 0, 92)
    list.BackgroundColor3 = Color3.fromRGB(26, 25, 38); list.BackgroundTransparency = 0.25
    list.BorderSizePixel = 0; list.ScrollBarThickness = 4; list.ScrollBarImageColor3 = ACCENT1
    list.CanvasSize = UDim2.new(0, 0, 0, 0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = card; corner(list, 10)
    local lay = Instance.new("UIListLayout", list); lay.Padding = UDim.new(0, 4); lay.SortOrder = Enum.SortOrder.LayoutOrder
    local lpad = Instance.new("UIPadding", list); lpad.PaddingTop = UDim.new(0, 6); lpad.PaddingLeft = UDim.new(0, 6); lpad.PaddingRight = UDim.new(0, 6)

    local function bigBtn(text, y, col, wide)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(wide or 0.5, wide and -32 or -20, 0, 40)
        b.Position = UDim2.new(0, 16, 0, y)
        b.BackgroundColor3 = col; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Parent = card
        corner(b, 9); hoverify(b, col, col:Lerp(Color3.new(1, 1, 1), 0.16))
        return b
    end

    local selected = loadTowers()
    local function isSel(n) for _, v in ipairs(selected) do if v == n then return true end end return false end

    local saveB = bigBtn("СОХРАНИТЬ", 316, MONEY_C)
    saveB.Size = UDim2.new(0.5, -20, 0, 40)
    local rescanB = bigBtn("ОБНОВИТЬ", 316, Color3.fromRGB(70, 65, 100))
    rescanB.Position = UDim2.new(0.5, 4, 0, 316); rescanB.Size = UDim2.new(0.5, -20, 0, 40)

    local hint = label(card, "", 11, SUB, Enum.Font.Gotham)
    hint.Size = UDim2.new(1, -32, 0, 16); hint.Position = UDim2.new(0, 16, 1, -22)
    hint.TextXAlignment = Enum.TextXAlignment.Center

    local function refreshInfo()
        info.Text = "Выбрано " .. #selected .. " / " .. MAX_PICK ..
            (#selected > 0 and ("  •  " .. table.concat(selected, ", ")) or "  •  ничего не выбрано")
        info.TextColor3 = #selected > 0 and MONEY_C or SUB
    end

    local build   -- forward (перерисовка списка)

    local function showError(reason)
        for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        info.Text = "Не удалось получить список башен"; info.TextColor3 = ERR_C

        local why = label(list, "Причина:\n" .. tostring(reason), 13, WARN_C, Enum.Font.Gotham)
        why.Size = UDim2.new(1, -12, 0, 96); why.TextWrapped = true
        why.TextYAlignment = Enum.TextYAlignment.Top

        local rj = Instance.new("TextButton")
        rj.Size = UDim2.new(1, -12, 0, 44); rj.BackgroundColor3 = Color3.fromRGB(235, 105, 80)
        rj.Text = "ПЕРЕЗАЙТИ В ИГРУ"; rj.TextColor3 = Color3.new(1, 1, 1)
        rj.Font = Enum.Font.GothamBold; rj.TextSize = 15; rj.BorderSizePixel = 0; rj.AutoButtonColor = false
        rj.Parent = list; corner(rj, 9)
        hoverify(rj, Color3.fromRGB(235, 105, 80), Color3.fromRGB(250, 130, 105))
        rj.MouseButton1Click:Connect(function()
            rj.Text = "ПЕРЕЗАХОД..."
            hint.Text = "Идёт перезаход на сервер"
            task.spawn(rejoin)
        end)
        hint.Text = "Открой инвентарь башен, затем нажми ОБНОВИТЬ"
    end

    build = function()
        for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        local towers, err = scanTowers()
        if not towers then return showError(err) end

        refreshInfo()
        hint.Text = "Доступно башен: " .. #towers .. "  •  максимум " .. MAX_PICK
        for i, name in ipairs(towers) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -12, 0, 34); row.LayoutOrder = i
            row.BackgroundColor3 = isSel(name) and Color3.fromRGB(46, 120, 82) or Color3.fromRGB(44, 42, 62)
            row.Text = (isSel(name) and "[X]  " or "[  ]  ") .. name
            row.TextColor3 = TXT; row.Font = Enum.Font.Gotham; row.TextSize = 14
            row.TextXAlignment = Enum.TextXAlignment.Left; row.BorderSizePixel = 0; row.AutoButtonColor = false
            row.Parent = list; corner(row, 7)
            local rp = Instance.new("UIPadding", row); rp.PaddingLeft = UDim.new(0, 10)

            row.MouseButton1Click:Connect(function()
                if isSel(name) then
                    for idx, v in ipairs(selected) do if v == name then table.remove(selected, idx) break end end
                elseif #selected >= MAX_PICK then
                    hint.Text = "Максимум " .. MAX_PICK .. " башни — сними лишнюю"
                    hint.TextColor3 = WARN_C
                    return
                else
                    table.insert(selected, name)
                end
                hint.TextColor3 = SUB
                row.BackgroundColor3 = isSel(name) and Color3.fromRGB(46, 120, 82) or Color3.fromRGB(44, 42, 62)
                row.Text = (isSel(name) and "[X]  " or "[  ]  ") .. name
                refreshInfo()
            end)
        end
    end

    saveB.MouseButton1Click:Connect(function()
        saveTowers(selected)
        hint.Text = #selected > 0 and ("Сохранено: " .. table.concat(selected, ", ")) or "Сохранено: без выбора (по умолчанию)"
        hint.TextColor3 = MONEY_C
        saveB.Text = "СОХРАНЕНО"
        task.delay(1.2, function() if saveB.Parent then saveB.Text = "СОХРАНИТЬ" end end)
    end)
    rescanB.MouseButton1Click:Connect(function()
        hint.TextColor3 = SUB; hint.Text = "Поиск башен..."
        task.defer(build)
    end)

    refreshInfo()
    swap(card)
    task.defer(build)
end

-- ====================== [3] МЕНЮ TDS FARM ======================
showFarm = function(server, key, errMsg)
    local w, h = 300, 210
    local card = newCard(w, h)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 46); bar.BackgroundColor3 = ACCENT1; bar.BorderSizePixel = 0; bar.Parent = card
    corner(bar, 16); grad(bar, GEMS_C, ACCENT1, 25)
    local barFix = Instance.new("Frame")
    barFix.Size = UDim2.new(1, 0, 0, 16); barFix.Position = UDim2.new(0, 0, 1, -16)
    barFix.BackgroundColor3 = ACCENT1; barFix.BorderSizePixel = 0; barFix.Parent = bar
    grad(barFix, GEMS_C, ACCENT1, 25)

    local ttl = label(bar, "TDS FARM", 19, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
    ttl.Size = UDim2.new(1, -90, 1, 0); ttl.Position = UDim2.new(0, 16, 0, 0); ttl.ZIndex = 2

    -- закрыть (ASCII "X" — раньше был символ, который рисовался квадратом)
    iconBtn(bar, "X", -36, Color3.fromRGB(225, 70, 80), Color3.fromRGB(245, 95, 105)).MouseButton1Click:Connect(closeAll)

    -- шестерёнка: иконка-картинка, а под ней ASCII-фолбэк на случай, если картинка не загрузится
    local gear = iconBtn(bar, "*", -70, Color3.fromRGB(70, 65, 100), Color3.fromRGB(95, 88, 130))
    local gearImg = Instance.new("ImageLabel")
    gearImg.Size = UDim2.new(1, -8, 1, -8); gearImg.Position = UDim2.fromOffset(4, 4)
    gearImg.BackgroundTransparency = 1; gearImg.Image = "rbxassetid://6031280882"
    gearImg.ImageColor3 = Color3.new(1, 1, 1); gearImg.ZIndex = 3; gearImg.Parent = gear
    gear.MouseButton1Click:Connect(function() showSettings(server, key) end)

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
    local gemsB  = farmBtn("GEMS FARM",  62,  GEMS_C,  Color3.fromRGB(130, 70, 215))
    local moneyB = farmBtn("MONEY FARM", 120, MONEY_C, Color3.fromRGB(42, 175, 108))

    local picked = loadTowers()
    local status = label(card, "", 12, SUB, Enum.Font.Gotham)
    status.Size = UDim2.new(1, -32, 0, 18); status.Position = UDim2.new(0, 16, 1, -26)
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.Text = #picked > 0 and ("Башни: " .. table.concat(picked, ", ")) or "Готово к работе  •  F1 / F2"
    if errMsg then status.Text = "! " .. errMsg; status.TextColor3 = WARN_C end

    dragify(bar, card)

    local active = false
    local function runFarm(kind)
        if active then return end
        active = true
        showLoading((kind == "gems" and "GEMS FARM" or "MONEY FARM"), function(setStatus)
            setStatus("Подключение к серверу")
            task.wait(0.25)
            setStatus("Загрузка скрипта")
            local ok = runScript(server, key, kind)
            if ok then
                setStatus("Запуск"); task.wait(0.3); closeAll()
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

    local sub = label(card, errMsg or "Введите ключ для доступа", 13, errMsg and ERR_C or SUB, Enum.Font.Gotham)
    sub.Size = UDim2.new(1, -32, 0, 32); sub.Position = UDim2.new(0, 18, 0, 50)
    sub.TextWrapped = true; sub.TextYAlignment = Enum.TextYAlignment.Top

    local cls = Instance.new("TextButton")
    cls.Size = UDim2.fromOffset(28, 28); cls.Position = UDim2.new(1, -36, 0, 14)
    cls.BackgroundColor3 = Color3.fromRGB(52, 52, 64); cls.Text = "X"; cls.TextColor3 = Color3.fromRGB(230, 230, 235)
    cls.Font = Enum.Font.GothamBold; cls.TextSize = 15; cls.BorderSizePixel = 0
    cls.AutoButtonColor = false; cls.Parent = card; corner(cls, 8)
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
        if key == "" then sub.Text = "Введите ключ"; sub.TextColor3 = ERR_C; return end
        showLoading("ПРОВЕРКА КЛЮЧА", function(setStatus)
            setStatus("Подключение к серверу")
            local server = getServer()
            if not server then return showGate(key, false, "Сервер недоступен (бот выключен?)") end
            setStatus("Проверка ключа")
            local ok, reason = checkKey(server, key)
            if ok then saveKey(key); showFarm(server, key)
            else clearKey(); showGate(key, false, tostring(reason)) end
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

local saved = loadKey()
showGate(saved or "", saved ~= nil and saved ~= "", nil)
