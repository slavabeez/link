--[[============================================================================
  meny.lua  —  ПУБЛИЧНОЕ меню-ключница (статичная ссылка для всех покупателей)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/slavabeez/link/main/meny.lua"))()

  ОДНО окно, внутри плавно сменяются страницы:
    [1] Ключ -> [2] Загрузка -> [3] TDS FARM -> [4] Настройки башен
  Всё строится синхронно (без отложенных вызовов), поэтому пустых экранов быть не может.
============================================================================]]--

local URL_FILE = "https://raw.githubusercontent.com/slavabeez/link/main/link.lua"
local BUY_URL  = "https://funpay.com/users/6883431/"
local KEYFILE   = "protecthub_key.txt"
local TOWERFILE = "protecthub_towers.txt"
local MAX_PICK  = 4

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local HttpSvc = game:GetService("HttpService")
local LP      = Players.LocalPlayer
local userId  = tostring(LP and LP.UserId or 0)
local placeId = tostring(game.PlaceId)

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

-- ---------- HTTP ----------
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

-- ---------- выбранные башни (всегда без повторов) ----------
local function uniq(src)
    local out, seen = {}, {}
    for _, v in ipairs(src or {}) do
        if type(v) == "string" and v ~= "" and not seen[v] then seen[v] = true; table.insert(out, v) end
    end
    while #out > MAX_PICK do table.remove(out) end
    return out
end
local function loadTowers()
    local out = {}
    pcall(function()
        local g = (getgenv and getgenv()) or _G
        if type(g.TDSTowers) == "table" then out = uniq(g.TDSTowers) end
        if #out == 0 and hasFiles and isfile(TOWERFILE) then
            local d = HttpSvc:JSONDecode(readfile(TOWERFILE))
            if type(d) == "table" then out = uniq(d) end
        end
    end)
    return out
end
local function saveTowers(list)
    local clean = uniq(list)
    pcall(function() local g = (getgenv and getgenv()) or _G; g.TDSTowers = clean end)
    if hasFiles then pcall(function() writefile(TOWERFILE, HttpSvc:JSONEncode(clean)) end) end
    return clean
end

-- ---------- поиск башен в инвентаре ----------
-- картинка-маркер в topThing.icon: такая башня доступна ВНЕ ЗАВИСИМОСТИ от видимости
local MARK_ID = "8418293221"
local function hasMarker(top)
    local ok, res = pcall(function()
        local icon = top:FindFirstChild("icon", true)
        if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton"))
           and tostring(icon.Image or ""):find(MARK_ID, 1, true) then
            return true
        end
        -- запасной вариант: маркер в любой картинке внутри topThing
        for _, d in ipairs(top:GetDescendants()) do
            if (d:IsA("ImageLabel") or d:IsA("ImageButton"))
               and tostring(d.Image or ""):find(MARK_ID, 1, true) then
                return true
            end
        end
        return false
    end)
    return ok and res or false
end
local function isHidden(o)
    local ok, res = pcall(function()
        if o:IsA("GuiObject") and o.Visible == false then return true end
        if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.ImageTransparency >= 0.95 then return true end
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.TextTransparency >= 0.95 then return true end
        return false
    end)
    return ok and res or false
end
local function findIcon(root)
    local best
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image and d.Image ~= "" then
                local n = tostring(d.Name):lower()
                if n:find("icon") or n:find("image") or n:find("tower") or n:find("thumb") then best = d.Image return end
                best = best or d.Image
            end
        end
    end)
    return best
end
local function findContainer()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil, "PlayerGui не найден" end
    local view = pg:FindFirstChild("ReactUniversalInventoryView")
    if view then
        local tc = view:FindFirstChild("towerContainer", true)
        if tc then return tc end
    end
    local tc = pg:FindFirstChild("towerContainer", true)
    if tc then return tc end
    return nil, "Инвентарь не открыт (towerContainer не найден).\nОткрой вкладку с башнями и нажми ОБНОВИТЬ."
end
-- карточки берём напрямую: towerContainer["4scrolling"].Hacker
local function scanTowers(showAll)
    local node, err = findContainer()
    if not node then return nil, err end
    local scrolls, cells, withTop, withMark, found, seen = 0, 0, 0, 0, {}, {}
    for _, sc in ipairs(node:GetChildren()) do
        if tostring(sc.Name):lower():find("scrolling") then
            scrolls = scrolls + 1
            for _, tw in ipairs(sc:GetChildren()) do
                pcall(function()
                    if not tw:IsA("GuiObject") then return end
                    cells = cells + 1
                    local top = tw:FindFirstChild("topThing", true)
                    local mark = false
                    if top then
                        withTop = withTop + 1
                        mark = hasMarker(top)
                        if mark then withMark = withMark + 1 end
                    end
                    -- доступна: маркер-картинка ИЛИ невидимый topThing (либо topThing нет вовсе)
                    local ok = showAll or (not top) or mark or isHidden(top)
                    if ok and not seen[tw.Name] then
                        seen[tw.Name] = true
                        table.insert(found, { name = tw.Name, icon = findIcon(tw) })
                    end
                end)
            end
        end
    end
    if scrolls == 0 then
        return nil, "Вкладок «scrolling» нет (детей: " .. #node:GetChildren() .. ").\nОткрой вкладку с башнями и нажми ОБНОВИТЬ."
    end
    if #found == 0 then
        return nil, "Вкладок: " .. scrolls .. ", карточек: " .. cells .. ", с topThing: " .. withTop ..
            ", с маркером: " .. withMark .. "\nНичего не подошло — нажми «ВСЕ»."
    end
    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

local function rejoin()
    local TS = game:GetService("TeleportService")
    local ok = pcall(function() TS:Teleport(game.PlaceId, LP) end)
    if not ok then pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end) end
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

-- ---------- UI ----------
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
local function label(p, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size
    l.TextColor3 = color or TXT; l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = p
    return l
end
local function hoverify(btn, base, hov)
    btn.MouseEnter:Connect(function() Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hov }):Play() end)
    btn.MouseLeave:Connect(function() Tween:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = base }):Play() end)
end

-- ===================== ЕДИНОЕ ОКНО =====================
local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(340, 250)
root.BackgroundColor3 = CARD_B; root.BorderSizePixel = 0
root.ClipsDescendants = true; root.Parent = screen
corner(root, 16); grad(root, CARD_A, CARD_B, 125)
local rootStroke = Instance.new("UIStroke", root)
rootStroke.Color = ACCENT1; rootStroke.Thickness = 1.8; rootStroke.Transparency = 0.35
task.spawn(function()
    while rootStroke.Parent do
        local a = Tween:Create(rootStroke, TweenInfo.new(1.1), { Transparency = 0.15 }); a:Play(); a.Completed:Wait()
        if not rootStroke.Parent then break end
        local b = Tween:Create(rootStroke, TweenInfo.new(1.1), { Transparency = 0.6 }); b:Play(); b.Completed:Wait()
    end
end)

-- появление окна
root.Size = UDim2.fromOffset(300, 220)
Tween:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(340, 250) }):Play()

local MOVE = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local curPage
-- builder(page) наполняет страницу СИНХРОННО; dir: 1 — вперёд, -1 — назад
local function showPage(w, h, dir, builder)
    dir = dir or 1
    local page = Instance.new("Frame")
    page.BackgroundTransparency = 1
    page.Size = UDim2.fromOffset(w, h)
    page.Position = UDim2.fromOffset(dir * w, 0)
    page.Parent = root

    local ok, err = pcall(builder, page)
    if not ok then
        local e = label(page, "Ошибка меню:\n" .. tostring(err), 13, ERR_C, Enum.Font.Gotham)
        e.Size = UDim2.new(1, -24, 1, -24); e.Position = UDim2.fromOffset(12, 12)
        e.TextWrapped = true; e.TextYAlignment = Enum.TextYAlignment.Top
    end

    Tween:Create(root, MOVE, { Size = UDim2.fromOffset(w, h) }):Play()
    Tween:Create(page, MOVE, { Position = UDim2.fromOffset(0, 0) }):Play()

    local old = curPage
    curPage = page
    if old then
        local t = Tween:Create(old, MOVE, { Position = UDim2.fromOffset(-dir * w, 0) })
        t.Completed:Connect(function() if old then old:Destroy() end end)
        t:Play()
    end
end
local function closeAll()
    local t = Tween:Create(root, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        { Size = UDim2.fromOffset(math.floor(root.Size.X.Offset * 0.85), math.floor(root.Size.Y.Offset * 0.85)) })
    t.Completed:Connect(function() screen:Destroy() end)
    t:Play()
end

-- перетаскивание всего окна за шапку
local function dragify(handle)
    local dragging, ds, sp
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; ds = i.Position; sp = root.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            root.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function header(page, title, w)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 46); bar.BackgroundColor3 = ACCENT1; bar.BorderSizePixel = 0; bar.Parent = page
    corner(bar, 16); grad(bar, GEMS_C, ACCENT1, 25)
    local fix = Instance.new("Frame")
    fix.Size = UDim2.new(1, 0, 0, 16); fix.Position = UDim2.new(0, 0, 1, -16)
    fix.BackgroundColor3 = ACCENT1; fix.BorderSizePixel = 0; fix.Parent = bar
    grad(fix, GEMS_C, ACCENT1, 25)
    local t = label(bar, title, 17, Color3.new(1, 1, 1), Enum.Font.GothamBold)
    t.Size = UDim2.new(1, -100, 1, 0); t.Position = UDim2.new(0, 16, 0, 0); t.ZIndex = 2
    dragify(bar)
    return bar
end
local function iconBtn(bar, text, xOffset, bg, hov)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28); b.Position = UDim2.new(1, xOffset, 0, 9)
    b.BackgroundColor3 = bg; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 15; b.BorderSizePixel = 0; b.ZIndex = 2
    b.AutoButtonColor = false; b.Parent = bar
    corner(b, 8); hoverify(b, bg, hov)
    return b
end

local showFarm, showSettings, showGate

-- ====================== ЗАГРУЗКА ======================
local function showLoading(titleText, worker)
    local w, h = 330, 148
    local setStatus
    showPage(w, h, 1, function(page)
        local title = label(page, titleText or "ЗАГРУЗКА", 19, TXT, Enum.Font.GothamBold)
        title.Size = UDim2.new(1, -32, 0, 28); title.Position = UDim2.new(0, 16, 0, 20)
        title.TextXAlignment = Enum.TextXAlignment.Center
        grad(title, ACCENT2, ACCENT1, 0)

        local status = label(page, "Подключение", 13, SUB, Enum.Font.Gotham)
        status.Size = UDim2.new(1, -32, 0, 20); status.Position = UDim2.new(0, 16, 0, 56)
        status.TextXAlignment = Enum.TextXAlignment.Center

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -56, 0, 10); track.Position = UDim2.new(0, 28, 0, 90)
        track.BackgroundColor3 = Color3.fromRGB(45, 45, 60); track.BorderSizePixel = 0
        track.ClipsDescendants = true; track.Parent = page; corner(track, 5)
        local seg = Instance.new("Frame")
        seg.Size = UDim2.new(0.4, 0, 1, 0); seg.Position = UDim2.new(-0.45, 0, 0, 0)
        seg.BorderSizePixel = 0; seg.Parent = track; corner(seg, 5)
        grad(seg, ACCENT1, ACCENT2, 0)

        local foot = label(page, "SCRIPT HUB", 11, Color3.fromRGB(95, 100, 130), Enum.Font.GothamBold)
        foot.Size = UDim2.new(1, -32, 0, 16); foot.Position = UDim2.new(0, 16, 1, -26)
        foot.TextXAlignment = Enum.TextXAlignment.Center

        task.spawn(function()
            while track.Parent do
                seg.Position = UDim2.new(-0.45, 0, 0, 0)
                local tw = Tween:Create(seg, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Position = UDim2.new(1.05, 0, 0, 0) })
                tw:Play(); tw.Completed:Wait()
            end
        end)
        local statusText = "Подключение"
        task.spawn(function()
            local n = 0
            while status.Parent do status.Text = statusText .. string.rep(".", n); n = (n + 1) % 4; task.wait(0.35) end
        end)
        setStatus = function(t) statusText = t end
    end)
    task.spawn(function() worker(setStatus or function() end) end)
end

-- ====================== НАСТРОЙКИ БАШЕН ======================
showSettings = function(server, key)
    local w, h = 380, 460
    showPage(w, h, 1, function(page)
        local bar = header(page, "НАСТРОЙКИ БАШЕН", w)
        iconBtn(bar, "X", -36, Color3.fromRGB(225, 70, 80), Color3.fromRGB(245, 95, 105)).MouseButton1Click:Connect(closeAll)
        iconBtn(bar, "<", -70, Color3.fromRGB(70, 65, 100), Color3.fromRGB(95, 88, 130)).MouseButton1Click:Connect(function()
            showFarm(server, key, nil, -1)
        end)

        local info = label(page, "", 13, SUB, Enum.Font.Gotham)
        info.Size = UDim2.new(1, -32, 0, 34); info.Position = UDim2.new(0, 16, 0, 52)
        info.TextWrapped = true; info.TextYAlignment = Enum.TextYAlignment.Top

        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, -32, 0, 268); list.Position = UDim2.new(0, 16, 0, 92)
        list.BackgroundColor3 = Color3.fromRGB(26, 25, 38); list.BackgroundTransparency = 0.25
        list.BorderSizePixel = 0; list.ScrollBarThickness = 4; list.ScrollBarImageColor3 = ACCENT1
        list.CanvasSize = UDim2.new(0, 0, 0, 0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.Parent = page; corner(list, 10)
        local lpad = Instance.new("UIPadding", list)
        lpad.PaddingTop = UDim.new(0, 8); lpad.PaddingBottom = UDim.new(0, 8)
        lpad.PaddingLeft = UDim.new(0, 8); lpad.PaddingRight = UDim.new(0, 8)
        -- список строками (сетка в некоторых исполнителях не отрисовывается)
        local grid = Instance.new("UIListLayout", list)
        grid.Padding = UDim.new(0, 5); grid.SortOrder = Enum.SortOrder.LayoutOrder

        local hint = label(page, "", 11, SUB, Enum.Font.Gotham)
        hint.Size = UDim2.new(1, -32, 0, 16); hint.Position = UDim2.new(0, 16, 1, -22)
        hint.TextXAlignment = Enum.TextXAlignment.Center

        local function btn(text, x, col)
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(x, 372); b.Size = UDim2.fromOffset(112, 40)
            b.BackgroundColor3 = col; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
            b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.BorderSizePixel = 0
            b.AutoButtonColor = false; b.Parent = page
            corner(b, 9); hoverify(b, col, col:Lerp(Color3.new(1, 1, 1), 0.16))
            return b
        end
        local saveB   = btn("СОХРАНИТЬ", 16, MONEY_C)
        local rescanB = btn("ОБНОВИТЬ", 134, Color3.fromRGB(70, 65, 100))
        local allB    = btn("ВСЕ", 252, Color3.fromRGB(70, 65, 100))

        local selected = loadTowers()
        local showAll  = false
        local function isSel(n) for _, v in ipairs(selected) do if v == n then return true end end return false end
        local function refreshInfo()
            info.Text = "Выбрано " .. #selected .. " / " .. MAX_PICK ..
                (#selected > 0 and ("  •  " .. table.concat(selected, ", ")) or "  •  ничего не выбрано")
            info.TextColor3 = #selected > 0 and MONEY_C or SUB
        end

        local function clearList()
            for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        end
        local function showError(reason)
            clearList()
            info.Text = "Список башен не получен"; info.TextColor3 = ERR_C

            -- элементы просто становятся в поток UIListLayout
            local why = label(list, "Причина:\n" .. tostring(reason), 13, WARN_C, Enum.Font.Gotham)
            why.Size = UDim2.new(1, -12, 0, 120); why.LayoutOrder = 1
            why.TextWrapped = true; why.TextYAlignment = Enum.TextYAlignment.Top

            local rj = Instance.new("TextButton")
            rj.LayoutOrder = 2; rj.Size = UDim2.new(1, -12, 0, 46)
            rj.BackgroundColor3 = Color3.fromRGB(235, 105, 80); rj.Text = "ПЕРЕЗАЙТИ В ИГРУ"
            rj.TextColor3 = Color3.new(1, 1, 1); rj.Font = Enum.Font.GothamBold; rj.TextSize = 15
            rj.BorderSizePixel = 0; rj.AutoButtonColor = false; rj.Parent = list
            corner(rj, 9); hoverify(rj, Color3.fromRGB(235, 105, 80), Color3.fromRGB(250, 130, 105))
            rj.MouseButton1Click:Connect(function()
                rj.Text = "ПЕРЕЗАХОД..."; hint.Text = "Идёт перезаход на сервер"
                task.spawn(rejoin)
            end)
            hint.Text = "Открой инвентарь башен и нажми ОБНОВИТЬ"
        end

        local function build()
            local okScan, towers, err = pcall(scanTowers, showAll)
            if not okScan then return showError("Ошибка скана:\n" .. tostring(towers)) end
            if not towers then return showError(err) end

            clearList()
            refreshInfo()
            hint.Text = (showAll and "Показаны ВСЕ: " or "Доступно: ") .. #towers .. "  •  максимум " .. MAX_PICK

            for i, t in ipairs(towers) do
                local name = t.name
                -- строка: иконка слева, отметка и название — правее, без наложения
                local cell = Instance.new("TextButton")
                cell.Size = UDim2.new(1, -12, 0, 42); cell.LayoutOrder = i
                cell.BackgroundColor3 = Color3.fromRGB(38, 37, 52)
                cell.Text = ""; cell.BorderSizePixel = 0; cell.AutoButtonColor = false
                cell.Parent = list
                corner(cell, 8)
                local st = Instance.new("UIStroke", cell)
                st.Thickness = 1.5; st.Color = Color3.fromRGB(72, 70, 98); st.Transparency = 0.15

                local ic = Instance.new("ImageLabel")
                ic.Size = UDim2.fromOffset(32, 32); ic.Position = UDim2.fromOffset(6, 5)
                ic.BackgroundColor3 = Color3.fromRGB(26, 25, 38); ic.BackgroundTransparency = 0.25
                ic.Image = t.icon or ""; ic.ScaleType = Enum.ScaleType.Fit
                ic.Parent = cell; corner(ic, 6)

                local nm = Instance.new("TextLabel")
                nm.BackgroundTransparency = 1
                nm.Size = UDim2.new(1, -52, 1, 0); nm.Position = UDim2.fromOffset(46, 0)
                nm.Text = name; nm.Font = Enum.Font.GothamBold; nm.TextSize = 14
                nm.TextColor3 = TXT; nm.TextTruncate = Enum.TextTruncate.AtEnd
                nm.TextXAlignment = Enum.TextXAlignment.Left; nm.Parent = cell

                local glow
                local function paint()
                    local on = isSel(name)
                    if glow then glow:Cancel(); glow = nil end
                    if on then
                        cell.BackgroundColor3 = Color3.fromRGB(58, 52, 28)
                        st.Color = Color3.fromRGB(255, 208, 45); st.Thickness = 2.5; st.Transparency = 0
                        nm.TextColor3 = Color3.fromRGB(255, 224, 120)
                        glow = Tween:Create(st, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                            { Transparency = 0.45 })
                        glow:Play()
                    else
                        cell.BackgroundColor3 = Color3.fromRGB(38, 37, 52)
                        st.Color = Color3.fromRGB(72, 70, 98); st.Thickness = 1.5; st.Transparency = 0.15
                        nm.TextColor3 = TXT
                    end
                end
                paint()

                cell.MouseEnter:Connect(function()
                    if not isSel(name) then Tween:Create(st, TweenInfo.new(0.15), { Color = ACCENT1, Transparency = 0 }):Play() end
                end)
                cell.MouseLeave:Connect(function()
                    if not isSel(name) then Tween:Create(st, TweenInfo.new(0.15), { Color = Color3.fromRGB(72, 70, 98), Transparency = 0.15 }):Play() end
                end)
                cell.MouseButton1Click:Connect(function()
                    if isSel(name) then
                        for idx, v in ipairs(selected) do if v == name then table.remove(selected, idx) break end end
                    elseif #selected >= MAX_PICK then
                        hint.Text = "Максимум " .. MAX_PICK .. " — сними лишнюю"; hint.TextColor3 = WARN_C
                        return
                    else
                        table.insert(selected, name)
                    end
                    hint.TextColor3 = SUB; paint(); refreshInfo()
                end)
            end
        end

        saveB.MouseButton1Click:Connect(function()
            selected = saveTowers(selected)
            hint.Text = #selected > 0 and ("Сохранено: " .. table.concat(selected, ", ")) or "Сохранено: без выбора"
            hint.TextColor3 = MONEY_C
            saveB.Text = "СОХРАНЕНО"
            task.delay(1.2, function() if saveB.Parent then saveB.Text = "СОХРАНИТЬ" end end)
            refreshInfo()
        end)
        rescanB.MouseButton1Click:Connect(function()
            hint.TextColor3 = SUB; hint.Text = "Поиск..."
            local ok, e = pcall(build)
            if not ok then pcall(showError, "Ошибка: " .. tostring(e)) end
        end)
        allB.MouseButton1Click:Connect(function()
            showAll = not showAll
            allB.Text = showAll and "ДОСТУПНЫЕ" or "ВСЕ"
            allB.BackgroundColor3 = showAll and ACCENT1 or Color3.fromRGB(70, 65, 100)
            hint.TextColor3 = SUB
            local ok, e = pcall(build)
            if not ok then pcall(showError, "Ошибка: " .. tostring(e)) end
        end)

        refreshInfo()
        -- строим СРАЗУ, синхронно — без отложенных вызовов
        local ok, e = pcall(build)
        if not ok then
            local shown = pcall(showError, "Ошибка: " .. tostring(e))
            if not shown then
                -- последняя страховка: пишем прямо на страницу, мимо списка
                local hard = label(page, "Ошибка меню:\n" .. tostring(e), 13, ERR_C, Enum.Font.Gotham)
                hard.Size = UDim2.new(1, -32, 0, 260); hard.Position = UDim2.new(0, 16, 0, 96)
                hard.TextWrapped = true; hard.TextYAlignment = Enum.TextYAlignment.Top; hard.ZIndex = 5
            end
        end
    end)
end

-- ====================== МЕНЮ TDS FARM ======================
showFarm = function(server, key, errMsg, dir)
    local w, h = 300, 210
    showPage(w, h, dir or 1, function(page)
        local bar = header(page, "TDS FARM", w)
        iconBtn(bar, "X", -36, Color3.fromRGB(225, 70, 80), Color3.fromRGB(245, 95, 105)).MouseButton1Click:Connect(closeAll)
        local gear = iconBtn(bar, "*", -70, Color3.fromRGB(70, 65, 100), Color3.fromRGB(95, 88, 130))
        local gearImg = Instance.new("ImageLabel")
        gearImg.Size = UDim2.new(1, -8, 1, -8); gearImg.Position = UDim2.fromOffset(4, 4)
        gearImg.BackgroundTransparency = 1; gearImg.Image = "rbxassetid://6031280882"
        gearImg.ZIndex = 3; gearImg.Parent = gear
        gear.MouseButton1Click:Connect(function() showSettings(server, key) end)

        local function farmBtn(text, y, c1, c2)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -32, 0, 50); b.Position = UDim2.new(0, 16, 0, y)
            b.BackgroundColor3 = c1; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
            b.Font = Enum.Font.GothamBold; b.TextSize = 15; b.BorderSizePixel = 0
            b.AutoButtonColor = false; b.Parent = page
            corner(b, 10); grad(b, c1, c2, 35)
            local s = Instance.new("UIStroke", b); s.Thickness = 1.4; s.Transparency = 0.45
            s.Color = c1:Lerp(Color3.new(1, 1, 1), 0.4)
            hoverify(b, c1, c1:Lerp(Color3.new(1, 1, 1), 0.18))
            return b
        end
        local gemsB  = farmBtn("GEMS FARM",  62,  GEMS_C,  Color3.fromRGB(130, 70, 215))
        local moneyB = farmBtn("MONEY FARM", 120, MONEY_C, Color3.fromRGB(42, 175, 108))

        local picked = loadTowers()
        local status = label(page, "", 12, SUB, Enum.Font.Gotham)
        status.Size = UDim2.new(1, -32, 0, 18); status.Position = UDim2.new(0, 16, 1, -26)
        status.TextXAlignment = Enum.TextXAlignment.Center
        status.Text = #picked > 0 and ("Башни: " .. table.concat(picked, ", ")) or "Готово к работе  •  F1 / F2"
        if errMsg then status.Text = "! " .. errMsg; status.TextColor3 = WARN_C end

        local active = false
        local function runFarm(kind)
            if active then return end
            active = true
            showLoading((kind == "gems" and "GEMS FARM" or "MONEY FARM"), function(setStatus)
                setStatus("Подключение к серверу"); task.wait(0.25)
                setStatus("Загрузка скрипта")
                local ok = runScript(server, key, kind)
                if ok then setStatus("Запуск"); task.wait(0.3); closeAll()
                else showFarm(server, key, "Сервер не ответил, попробуй ещё раз", -1) end
                active = false
            end)
        end
        gemsB.MouseButton1Click:Connect(function() runFarm("gems") end)
        moneyB.MouseButton1Click:Connect(function() runFarm("money") end)
        UIS.InputBegan:Connect(function(input, gp)
            if gp or not page.Parent then return end
            if input.KeyCode == Enum.KeyCode.F1 then runFarm("gems")
            elseif input.KeyCode == Enum.KeyCode.F2 then runFarm("money") end
        end)
    end)
end

-- ====================== ВВОД КЛЮЧА ======================
showGate = function(presetKey, autostart, errMsg)
    local w, h = 340, 250
    showPage(w, h, -1, function(page)
        local title = label(page, "SCRIPT HUB", 23, TXT, Enum.Font.GothamBold)
        title.Size = UDim2.new(1, -32, 0, 30); title.Position = UDim2.new(0, 18, 0, 16)
        grad(title, ACCENT2, ACCENT1, 0)
        dragify(title)

        local sub = label(page, errMsg or "Введите ключ для доступа", 13, errMsg and ERR_C or SUB, Enum.Font.Gotham)
        sub.Size = UDim2.new(1, -32, 0, 32); sub.Position = UDim2.new(0, 18, 0, 50)
        sub.TextWrapped = true; sub.TextYAlignment = Enum.TextYAlignment.Top

        local cls = Instance.new("TextButton")
        cls.Size = UDim2.fromOffset(28, 28); cls.Position = UDim2.new(1, -36, 0, 14)
        cls.BackgroundColor3 = Color3.fromRGB(52, 52, 64); cls.Text = "X"
        cls.TextColor3 = Color3.fromRGB(230, 230, 235); cls.Font = Enum.Font.GothamBold
        cls.TextSize = 15; cls.BorderSizePixel = 0; cls.AutoButtonColor = false; cls.Parent = page
        corner(cls, 8); hoverify(cls, Color3.fromRGB(52, 52, 64), Color3.fromRGB(70, 70, 84))
        cls.MouseButton1Click:Connect(closeAll)

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -32, 0, 42); box.Position = UDim2.new(0, 16, 0, 92)
        box.BackgroundColor3 = Color3.fromRGB(40, 40, 52); box.Font = Enum.Font.Gotham
        box.PlaceholderText = "XXXXX-XXXXX-XXXXX-XXXXX"; box.Text = presetKey or ""; box.TextSize = 15
        box.TextColor3 = TXT; box.PlaceholderColor3 = Color3.fromRGB(120, 120, 138)
        box.ClearTextOnFocus = false; box.Parent = page; corner(box, 9)
        local bxs = Instance.new("UIStroke", box); bxs.Color = ACCENT1; bxs.Thickness = 1; bxs.Transparency = 0.5
        box.Focused:Connect(function() Tween:Create(bxs, TweenInfo.new(0.15), { Transparency = 0.05 }):Play() end)
        box.FocusLost:Connect(function() Tween:Create(bxs, TweenInfo.new(0.15), { Transparency = 0.5 }):Play() end)

        local act = Instance.new("TextButton")
        act.Size = UDim2.new(1, -32, 0, 44); act.Position = UDim2.new(0, 16, 0, 146)
        act.BackgroundColor3 = ACCENT1; act.Text = "Активировать"; act.TextColor3 = Color3.new(1, 1, 1)
        act.Font = Enum.Font.GothamBold; act.TextSize = 16; act.BorderSizePixel = 0
        act.AutoButtonColor = false; act.Parent = page
        corner(act, 9); grad(act, ACCENT1, Color3.fromRGB(95, 70, 220), 35)
        hoverify(act, ACCENT1, ACCENT1:Lerp(Color3.new(1, 1, 1), 0.15))

        local buyb = Instance.new("TextButton")
        buyb.Size = UDim2.new(1, -32, 0, 40); buyb.Position = UDim2.new(0, 16, 0, 198)
        buyb.BackgroundColor3 = MONEY_C; buyb.Text = "Купить ключ  (FunPay)"; buyb.TextColor3 = Color3.new(1, 1, 1)
        buyb.Font = Enum.Font.GothamBold; buyb.TextSize = 14; buyb.BorderSizePixel = 0
        buyb.AutoButtonColor = false; buyb.Parent = page
        corner(buyb, 9); grad(buyb, MONEY_C, Color3.fromRGB(30, 150, 85), 35)
        hoverify(buyb, MONEY_C, MONEY_C:Lerp(Color3.new(1, 1, 1), 0.15))

        local function activate()
            local key = trim(box.Text)
            if key == "" then sub.Text = "Введите ключ"; sub.TextColor3 = ERR_C; return end
            showLoading("ПРОВЕРКА КЛЮЧА", function(setStatus)
                setStatus("Подключение к серверу")
                local server = getServer()
                if not server then return showGate(key, false, "Сервер недоступен (бот выключен?)") end
                setStatus("Проверка ключа")
                local ok, reason = checkKey(server, key)
                if ok then saveKey(key); showFarm(server, key, nil, 1)
                else clearKey(); showGate(key, false, tostring(reason)) end
            end)
        end
        act.MouseButton1Click:Connect(activate)
        box.FocusLost:Connect(function(enter) if enter then activate() end end)
        buyb.MouseButton1Click:Connect(function()
            if setclipboard then pcall(setclipboard, BUY_URL); sub.Text = "Ссылка скопирована — открой в браузере"
            else sub.Text = BUY_URL end
            sub.TextColor3 = ACCENT2
        end)

        if autostart and presetKey and presetKey ~= "" then task.spawn(activate) end
    end)
end

local saved = loadKey()
showGate(saved or "", saved ~= nil and saved ~= "", nil)
