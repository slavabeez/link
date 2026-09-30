--[[============================================================================
  meny.lua  —  ПУБЛИЧНОЕ меню-ключница (статичная ссылка для всех покупателей)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/slavabeez/link/main/meny.lua"))()

  ОДНО окно, внутри плавно сменяются страницы:
    [1] Ключ -> [2] Загрузка -> [3] TDS FARM -> [4] Настройки башен
  Всё строится синхронно (без отложенных вызовов), поэтому пустых экранов быть не может.
  Анимации — только на TweenService, без сторонних картинок (кроме значка шестерёнки).
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

-- палитра
local BG_A    = Color3.fromRGB(34, 31, 54)
local BG_B    = Color3.fromRGB(15, 14, 24)
local SURF    = Color3.fromRGB(33, 31, 50)
local SURF_H  = Color3.fromRGB(45, 42, 68)
local DEEP    = Color3.fromRGB(21, 20, 33)
local LINE    = Color3.fromRGB(68, 64, 102)
local ACCENT1 = Color3.fromRGB(150, 115, 255)
local ACCENT2 = Color3.fromRGB(95, 210, 255)
local GEMS_C  = Color3.fromRGB(165, 90, 245)
local MONEY_C = Color3.fromRGB(55, 210, 130)
local REC_C   = Color3.fromRGB(240, 110, 90)
local GOLD    = Color3.fromRGB(255, 208, 45)
local TXT     = Color3.fromRGB(245, 245, 252)
local SUB     = Color3.fromRGB(175, 182, 210)
local MUTED   = Color3.fromRGB(110, 113, 145)
local WARN_C  = Color3.fromRGB(245, 150, 90)
local ERR_C   = Color3.fromRGB(240, 130, 130)
local WHITE   = Color3.new(1, 1, 1)

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
local MARK_ID = "8418292821"
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

local EASE, EDIR = Enum.EasingStyle, Enum.EasingDirection
local function tween(o, t, props, style, dir)
    local tw = Tween:Create(o, TweenInfo.new(t, style or EASE.Quint, dir or EDIR.Out), props)
    tw:Play(); return tw
end
-- бесконечная анимация: pingpong — туда-обратно, иначе по кругу с начала
local function loop(o, t, props, pingpong, style)
    local tw = Tween:Create(o, TweenInfo.new(t, style or EASE.Sine, EDIR.InOut, -1, pingpong and true or false), props)
    tw:Play(); return tw
end

-- подписки и вечные анимации страницы: гасим, когда страница уходит или окно закрывается
local bin = {}
local function own(owner, x)
    bin[owner] = bin[owner] or {}
    table.insert(bin[owner], x)
    return x
end
local function clean(owner)
    local list = bin[owner]; bin[owner] = nil
    for _, x in ipairs(list or {}) do
        pcall(function()
            if typeof(x) == "RBXScriptConnection" then x:Disconnect() else x:Cancel() end
        end)
    end
end

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = (r == "full") and UDim.new(0.5, 0) or UDim.new(0, r)
    c.Parent = o; return c
end
local function stroke(o, col, th, tr)
    local s = Instance.new("UIStroke")
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = col; s.Thickness = th or 1; s.Transparency = tr or 0
    s.Parent = o; return s
end
-- colors: цвета равномерно по градиенту; trans: { {время, прозрачность}, ... }
local function grad(o, colors, rot, trans)
    local kp = {}
    for i, c in ipairs(colors) do kp[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c) end
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(kp); g.Rotation = rot or 0
    if trans then
        local tk = {}
        for i, p in ipairs(trans) do tk[i] = NumberSequenceKeypoint.new(p[1], p[2]) end
        g.Transparency = NumberSequence.new(tk)
    end
    g.Parent = o; return g
end
-- без color — прозрачный контейнер
local function frame(p, size, pos, color)
    local f = Instance.new("Frame")
    f.Size = size; f.Position = pos or UDim2.new(0, 0, 0, 0); f.BorderSizePixel = 0
    if color then f.BackgroundColor3 = color else f.BackgroundTransparency = 1 end
    f.Parent = p; return f
end
local function label(p, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size
    l.TextColor3 = color or TXT; l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = p
    return l
end
-- палочка для рисованных значков (крестик, стрелки)
local function stick(p, len, x, y, rot, color)
    local s = frame(p, UDim2.fromOffset(len, 2), UDim2.fromOffset(x, y), color or TXT)
    s.AnchorPoint = Vector2.new(0.5, 0.5); s.Rotation = rot
    corner(s, 1); return s
end
-- переливание градиентного текста
local function shimmer(owner, g)
    g.Offset = Vector2.new(-0.5, 0)
    own(owner, loop(g, 1.8, { Offset = Vector2.new(0.5, 0) }, true))
end
-- тряска (ошибка ввода)
local function shake(o)
    if o:GetAttribute("shaking") then return end
    o:SetAttribute("shaking", true)
    local p = o.Position
    task.spawn(function()
        for _, dx in ipairs({ -8, 7, -5, 4, -2, 0 }) do
            tween(o, 0.05, { Position = p + UDim2.fromOffset(dx, 0) }, EASE.Sine)
            task.wait(0.05)
        end
        o.Position = p
        o:SetAttribute("shaking", nil)
    end)
end

-- ---------- плавное появление / исчезание блоков ----------
-- то, что помечено атрибутом nofade (вместе со всем содержимым), появляется своей анимацией
local function fadeProps(o)
    local p = {}
    if o:IsA("GuiObject") then
        if o.BackgroundTransparency < 1 then p.BackgroundTransparency = o.BackgroundTransparency end
        if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
            if o.TextTransparency < 1 then p.TextTransparency = o.TextTransparency end
        elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
            if o.ImageTransparency < 1 then p.ImageTransparency = o.ImageTransparency end
        elseif o:IsA("ScrollingFrame") then
            if o.ScrollBarImageTransparency < 1 then p.ScrollBarImageTransparency = o.ScrollBarImageTransparency end
        end
    elseif o:IsA("UIStroke") then
        if o.Transparency < 1 then p.Transparency = o.Transparency end
    end
    return next(p) and p or nil
end
local function collect(o, out, all, top)
    if not all and not top and o:GetAttribute("nofade") then return out end
    local p = fadeProps(o)
    if p then out[#out + 1] = { o, p } end
    for _, c in ipairs(o:GetChildren()) do collect(c, out, all, false) end
    return out
end
local FADE = TweenInfo.new(0.3, EASE.Quad, EDIR.Out)
local function fadeIn(o, delay, alive)
    local list = collect(o, {}, false, true)
    for _, e in ipairs(list) do for k in pairs(e[2]) do e[1][k] = 1 end end
    task.delay(delay or 0, function()
        if alive and not alive() then return end
        for _, e in ipairs(list) do
            if e[1].Parent then Tween:Create(e[1], FADE, e[2]):Play() end
        end
    end)
end
local function fadeOut(o, t)
    local info = TweenInfo.new(t or 0.2, EASE.Quad, EDIR.Out)
    for _, e in ipairs(collect(o, {}, true, true)) do
        local goal = {}
        for k in pairs(e[2]) do goal[k] = 1 end
        Tween:Create(e[1], info, goal):Play()
    end
end

-- ===================== ЕДИНОЕ ОКНО =====================
-- holder: позиция/размер/масштаб окна; внутри мягкая тень и само окно (root)
local holder = frame(screen, UDim2.fromOffset(340, 282), UDim2.fromScale(0.5, 0.5))
holder.Name = "Window"; holder.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale"); scale.Scale = 0.88; scale.Parent = holder

-- мягкая тень из нескольких слоёв (без картинок)
for i = 1, 5 do
    local s = frame(holder, UDim2.new(1, i * 5, 1, i * 5), UDim2.new(0.5, 0, 0.5, 5), Color3.new(0, 0, 0))
    s.Name = "Shadow"; s.AnchorPoint = Vector2.new(0.5, 0.5)
    s.BackgroundTransparency = 0.78 + i * 0.04
    corner(s, 16 + i * 2)
end

local root = frame(holder, UDim2.fromScale(1, 1), nil, WHITE)
root.Name = "Body"; root.ZIndex = 2; root.ClipsDescendants = true
corner(root, 16); grad(root, { BG_A, BG_B }, 115)
-- рамка: по контуру бегут два световых блика
local rootStroke = stroke(root, WHITE, 1.5, 0)
local borderG = grad(rootStroke, { ACCENT1, ACCENT2, ACCENT1 }, 0, { { 0, 0.05 }, { 0.5, 0.85 }, { 1, 0.05 } })
own(root, loop(borderG, 6, { Rotation = 360 }, false, EASE.Linear))
-- «дышащее» свечение сверху окна
local glow = frame(root, UDim2.new(1, 0, 0, 120), nil, WHITE)
glow.Name = "Glow"; glow:SetAttribute("nofade", true)
grad(glow, { ACCENT1, ACCENT2 }, 70, { { 0, 0.8 }, { 1, 1 } })
own(root, loop(glow, 3.2, { BackgroundTransparency = 0.55 }, true))

-- перетаскивание окна (плавно догоняет курсор)
local drag = {}
local DRAG_T = TweenInfo.new(0.09, EASE.Quad, EDIR.Out)
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local function dragify(handle)
    handle.InputBegan:Connect(function(i)
        if isPress(i) then drag.on = true; drag.from = i.Position; drag.pos = holder.Position end
    end)
end
own(root, UIS.InputChanged:Connect(function(i)
    if drag.on and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d, p = i.Position - drag.from, drag.pos
        Tween:Create(holder, DRAG_T, { Position = UDim2.new(p.X.Scale, p.X.Offset + d.X, p.Y.Scale, p.Y.Offset + d.Y) }):Play()
    end
end))
own(root, UIS.InputEnded:Connect(function(i) if isPress(i) then drag.on = false end end))

-- ---------- смена страниц ----------
local MOVE = TweenInfo.new(0.45, EASE.Quint, EDIR.Out)
local curPage, closing
-- элементы новой страницы выезжают каскадом (сверху вниз) и проявляются
local function reveal(page, dir, alive)
    local kids = {}
    for _, c in ipairs(page:GetChildren()) do
        if c:IsA("GuiObject") and not c:GetAttribute("nofade") then kids[#kids + 1] = c end
    end
    local function y(c) return c.Position.Y.Scale * page.Size.Y.Offset + c.Position.Y.Offset end
    table.sort(kids, function(a, b)
        if y(a) ~= y(b) then return y(a) < y(b) end
        return a.Position.X.Offset < b.Position.X.Offset
    end)
    for i, c in ipairs(kids) do
        local d = math.min(i - 1, 8) * 0.04
        local p = c.Position
        c.Position = p + UDim2.fromOffset(dir * 22, 0)
        fadeIn(c, d, alive)
        task.delay(d, function()
            if c.Parent and alive() then tween(c, 0.5, { Position = p }) end
        end)
    end
end
-- builder(page) наполняет страницу СИНХРОННО; dir: 1 — вперёд, -1 — назад
local function showPage(w, h, dir, builder)
    if closing then return end
    dir = dir or 1
    local old = curPage
    if old then
        clean(old)
        fadeOut(old, 0.18)
        tween(old, 0.3, { Position = UDim2.fromOffset(-dir * 26, 0) }, EASE.Quad)
        task.delay(0.32, function() old:Destroy() end)
        Tween:Create(holder, MOVE, { Size = UDim2.fromOffset(w, h) }):Play()
    else
        holder.Size = UDim2.fromOffset(w, h)
    end

    local page = Instance.new("Frame")
    page.Name = "Page"; page.BackgroundTransparency = 1; page.ZIndex = 2
    page.Size = UDim2.fromOffset(w, h); page:SetAttribute("nofade", true)
    page.Parent = root
    curPage = page

    local ok, err = pcall(builder, page)
    if not ok then
        local e = label(page, "Ошибка меню:\n" .. tostring(err), 13, ERR_C, Enum.Font.Gotham)
        e.Size = UDim2.new(1, -24, 1, -24); e.Position = UDim2.fromOffset(12, 12)
        e.TextWrapped = true; e.TextYAlignment = Enum.TextYAlignment.Top
    end
    -- пока строили, уже открыли другую страницу (например, автовход по ключу)
    if curPage ~= page then return end
    reveal(page, dir, function() return curPage == page end)
end
local function closeAll()
    if closing then return end
    closing = true
    for owner in pairs(bin) do clean(owner) end
    curPage = nil
    fadeOut(holder, 0.22)
    tween(scale, 0.25, { Scale = 0.9 }, EASE.Back, EDIR.In)
    task.delay(0.27, function() screen:Destroy() end)
end

-- ---------- кнопки ----------
-- наведение: плавная смена цвета; возвращает set(base, hov) для смены цветов на лету
local function hoverify(b, base, hov)
    local st = { base = base, hov = hov, on = false }
    b.MouseEnter:Connect(function() st.on = true; tween(b, 0.18, { BackgroundColor3 = st.hov }, EASE.Quad) end)
    b.MouseLeave:Connect(function() st.on = false; tween(b, 0.18, { BackgroundColor3 = st.base }, EASE.Quad) end)
    return function(nb, nh)
        st.base = nb; st.hov = nh or nb
        tween(b, 0.2, { BackgroundColor3 = st.on and st.hov or st.base }, EASE.Quad)
    end
end
-- нажатие: кнопка проседает и пружинит обратно (у кнопки AnchorPoint по центру)
local function pressify(b, amount)
    local sc = Instance.new("UIScale"); sc.Parent = b
    b.MouseButton1Down:Connect(function() tween(sc, 0.09, { Scale = amount or 0.95 }, EASE.Quad) end)
    local function up() tween(sc, 0.4, { Scale = 1 }, EASE.Back) end
    b.MouseButton1Up:Connect(up); b.MouseLeave:Connect(up)
    return sc
end
-- блик, пробегающий по кнопке при наведении; возвращает функцию запуска
local function shine(b, r)
    local s = frame(b, UDim2.fromScale(1, 1), nil, WHITE)
    s.Name = "Shine"; s.ZIndex = 3
    corner(s, r)
    local g = grad(s, { WHITE, WHITE }, 20, { { 0, 1 }, { 0.4, 1 }, { 0.5, 0.75 }, { 0.6, 1 }, { 1, 1 } })
    g.Offset = Vector2.new(-1, 0)
    local function run()
        g.Offset = Vector2.new(-1, 0)
        tween(g, 0.7, { Offset = Vector2.new(1, 0) }, EASE.Quad, EDIR.InOut)
    end
    b.MouseEnter:Connect(run)
    return run
end
local function centered(pos, size)
    return UDim2.new(pos.X.Scale + size.X.Scale / 2, pos.X.Offset + math.floor(size.X.Offset / 2),
                     pos.Y.Scale + size.Y.Scale / 2, pos.Y.Offset + math.floor(size.Y.Offset / 2))
end
-- o: size, pos (левый верхний угол), c1/c2 — градиентная кнопка, иначе «стеклянная» (bg, hov, line, tc)
local function button(p, text, o)
    local b = Instance.new("TextButton")
    b.Text = ""; b.AutoButtonColor = false; b.BorderSizePixel = 0
    b.Size = o.size
    if o.pos then b.AnchorPoint = Vector2.new(0.5, 0.5); b.Position = centered(o.pos, o.size) end
    b.Parent = p
    local r = o.r or 10
    corner(b, r)
    local B = { btn = b }
    if o.c1 then
        -- белая подложка * градиент; при наведении подложка ярче
        local dim = Color3.fromRGB(222, 222, 222)
        b.BackgroundColor3 = dim
        grad(b, { o.c1, o.c2 or o.c1 }, 25)
        B.stroke = stroke(b, WHITE, 1, 0.82)
        B.set = hoverify(b, dim, WHITE)
    else
        b.BackgroundColor3 = o.bg or SURF
        B.stroke = stroke(b, o.line or LINE, 1, o.lineT or 0.35)
        B.set = hoverify(b, o.bg or SURF, o.hov or SURF_H)
    end
    B.text = label(b, text, o.ts or 14, o.tc or WHITE, Enum.Font.GothamBold)
    B.text.Size = UDim2.fromScale(1, 1); B.text.TextXAlignment = Enum.TextXAlignment.Center
    B.text.ZIndex = 2
    B.shine = shine(b, r)
    if o.pos then pressify(b) end
    return B
end

-- бегущая световая линия
local function flowLine(p, pos, size)
    local line = frame(p, size, pos, WHITE)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, LINE), ColorSequenceKeypoint.new(0.3, LINE),
        ColorSequenceKeypoint.new(0.45, ACCENT1), ColorSequenceKeypoint.new(0.55, ACCENT2),
        ColorSequenceKeypoint.new(0.7, LINE), ColorSequenceKeypoint.new(1, LINE),
    })
    g.Offset = Vector2.new(-1, 0); g.Parent = line
    return line, loop(g, 2.8, { Offset = Vector2.new(1, 0) }, false, EASE.Quad)
end

-- шапка страницы: акцентная метка, заголовок, бегущая линия; за неё таскается окно
local function header(page, title)
    local bar = frame(page, UDim2.new(1, 0, 0, 48))
    bar.Name = "Header"
    local mark = frame(bar, UDim2.fromOffset(4, 18), UDim2.fromOffset(16, 15), WHITE)
    corner(mark, 2); grad(mark, { ACCENT2, ACCENT1 }, 90)
    local t = label(bar, title, 16, TXT, Enum.Font.GothamBold)
    t.Size = UDim2.new(1, -120, 1, 0); t.Position = UDim2.fromOffset(28, 0)
    local _, fl = flowLine(bar, UDim2.new(0, 16, 1, -1), UDim2.new(1, -32, 0, 1))
    own(page, fl)
    dragify(bar)
    return bar
end
-- круглая кнопка в шапке: close / back / gear
local function headBtn(bar, kind, x, y)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.Size = UDim2.fromOffset(28, 28); b.Position = UDim2.new(1, x + 14, 0, (y or 10) + 14)
    b.BackgroundColor3 = SURF; b.Text = ""; b.AutoButtonColor = false; b.BorderSizePixel = 0
    b.Parent = bar
    corner(b, 8); stroke(b, LINE, 1, 0.4)
    local ico = frame(b, UDim2.fromOffset(14, 14), UDim2.fromScale(0.5, 0.5))
    ico.AnchorPoint = Vector2.new(0.5, 0.5)
    if kind == "close" then
        local a, c = stick(ico, 14, 7, 7, 45), stick(ico, 14, 7, 7, -45)
        hoverify(b, SURF, Color3.fromRGB(225, 70, 80))
        b.MouseEnter:Connect(function() tween(a, 0.35, { Rotation = 135 }, EASE.Back); tween(c, 0.35, { Rotation = 45 }, EASE.Back) end)
        b.MouseLeave:Connect(function() tween(a, 0.35, { Rotation = 45 }, EASE.Back); tween(c, 0.35, { Rotation = -45 }, EASE.Back) end)
    elseif kind == "back" then
        stick(ico, 8, 7, 4, -45); stick(ico, 8, 7, 10, 45)
        hoverify(b, SURF, SURF_H)
        b.MouseEnter:Connect(function() tween(ico, 0.25, { Position = UDim2.new(0.5, -2, 0.5, 0) }, EASE.Quad) end)
        b.MouseLeave:Connect(function() tween(ico, 0.25, { Position = UDim2.fromScale(0.5, 0.5) }, EASE.Quad) end)
    else
        local img = Instance.new("ImageLabel")
        img.AnchorPoint = Vector2.new(0.5, 0.5); img.Position = UDim2.fromScale(0.5, 0.5)
        img.Size = UDim2.fromOffset(18, 18); img.BackgroundTransparency = 1
        img.Image = "rbxassetid://6031280882"; img.ImageColor3 = TXT; img.Parent = b
        hoverify(b, SURF, SURF_H)
        b.MouseEnter:Connect(function() tween(img, 0.5, { Rotation = 90 }, EASE.Back) end)
        b.MouseLeave:Connect(function() tween(img, 0.5, { Rotation = 0 }, EASE.Back) end)
    end
    pressify(b, 0.88)
    return b
end

local showFarm, showSettings, showGate

-- ====================== ЗАГРУЗКА ======================
local function showLoading(titleText, worker)
    local w, h = 320, 178
    local setStatus
    showPage(w, h, 1, function(page)
        dragify(page)
        -- спиннер: дорожка + вращающаяся дуга + пульсирующее ядро
        local ring = frame(page, UDim2.fromOffset(48, 48), UDim2.new(0.5, 0, 0, 22))
        ring.AnchorPoint = Vector2.new(0.5, 0)
        local trackRing = frame(ring, UDim2.fromScale(1, 1))
        corner(trackRing, "full"); stroke(trackRing, LINE, 3, 0.45)
        local arc = frame(ring, UDim2.fromScale(1, 1))
        corner(arc, "full")
        local ag = grad(stroke(arc, WHITE, 3, 0), { ACCENT2, ACCENT1 }, 0, { { 0, 0 }, { 0.45, 0.25 }, { 0.6, 1 }, { 1, 1 } })
        own(page, loop(ag, 0.9, { Rotation = 360 }, false, EASE.Linear))
        local core = frame(ring, UDim2.fromOffset(14, 14), UDim2.fromScale(0.5, 0.5), WHITE)
        core.AnchorPoint = Vector2.new(0.5, 0.5); corner(core, "full"); grad(core, { ACCENT2, ACCENT1 }, 45)
        local cs = Instance.new("UIScale"); cs.Parent = core
        own(page, loop(cs, 0.6, { Scale = 0.6 }, true))

        local title = label(page, titleText or "ЗАГРУЗКА", 18, WHITE, Enum.Font.GothamBold)
        title.Size = UDim2.new(1, -32, 0, 24); title.Position = UDim2.fromOffset(16, 84)
        title.TextXAlignment = Enum.TextXAlignment.Center
        shimmer(page, grad(title, { ACCENT2, ACCENT1, ACCENT2 }, 0))

        local status = label(page, "Подключение", 13, SUB, Enum.Font.Gotham)
        status.Size = UDim2.new(1, -32, 0, 18); status.Position = UDim2.fromOffset(16, 110)
        status.TextXAlignment = Enum.TextXAlignment.Center

        local track = frame(page, UDim2.new(1, -96, 0, 3), UDim2.fromOffset(48, 142), LINE)
        track.BackgroundTransparency = 0.5; track.ClipsDescendants = true; corner(track, 2)
        local seg = frame(track, UDim2.fromScale(0.35, 1), UDim2.fromScale(-0.4, 0), WHITE)
        corner(seg, 2); grad(seg, { ACCENT1, ACCENT2 }, 0)
        own(page, loop(seg, 1.1, { Position = UDim2.fromScale(1.05, 0) }, false, EASE.Quad))

        local foot = label(page, "SCRIPT HUB", 10, MUTED, Enum.Font.GothamBold)
        foot.Size = UDim2.new(1, -32, 0, 14); foot.Position = UDim2.new(0, 16, 1, -24)
        foot.TextXAlignment = Enum.TextXAlignment.Center

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
    local w, h = 380, 472
    showPage(w, h, 1, function(page)
        local function alive() return curPage == page end
        local bar = header(page, "НАСТРОЙКИ БАШЕН")
        headBtn(bar, "close", -40).MouseButton1Click:Connect(closeAll)
        headBtn(bar, "back", -74).MouseButton1Click:Connect(function()
            showFarm(server, key, nil, -1)
        end)

        -- сегменты: сколько слотов из MAX_PICK занято
        local slots = frame(page, UDim2.new(1, -26, 0, 4), UDim2.fromOffset(13, 60))
        local segs = {}
        for i = 1, MAX_PICK do
            local s = frame(slots, UDim2.new(1 / MAX_PICK, -6, 1, 0), UDim2.new((i - 1) / MAX_PICK, 3, 0, 0), LINE)
            corner(s, 2); segs[i] = s
        end

        local info = label(page, "", 13, SUB, Enum.Font.Gotham)
        info.Size = UDim2.new(1, -32, 0, 34); info.Position = UDim2.fromOffset(16, 72)
        info.TextWrapped = true; info.TextYAlignment = Enum.TextYAlignment.Top

        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, -32, 0, 258); list.Position = UDim2.fromOffset(16, 110)
        list.BackgroundColor3 = DEEP; list.BackgroundTransparency = 0.2
        list.BorderSizePixel = 0; list.ScrollBarThickness = 3; list.ScrollBarImageColor3 = ACCENT1
        list.ScrollingDirection = Enum.ScrollingDirection.Y
        list.CanvasSize = UDim2.new(0, 0, 0, 0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.Parent = page; corner(list, 12); stroke(list, LINE, 1, 0.55)
        local lpad = Instance.new("UIPadding")
        lpad.PaddingTop = UDim.new(0, 7); lpad.PaddingBottom = UDim.new(0, 7)
        lpad.PaddingLeft = UDim.new(0, 7); lpad.PaddingRight = UDim.new(0, 7)
        lpad.Parent = list
        -- список строками (сетка в некоторых исполнителях не отрисовывается)
        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = list

        local hint = label(page, "", 11, SUB, Enum.Font.Gotham)
        hint.Size = UDim2.new(1, -32, 0, 16); hint.Position = UDim2.new(0, 16, 1, -30)
        hint.TextXAlignment = Enum.TextXAlignment.Center

        local saveB   = button(page, "СОХРАНИТЬ", { pos = UDim2.fromOffset(16, 380),  size = UDim2.fromOffset(112, 40), c1 = MONEY_C, c2 = Color3.fromRGB(30, 160, 120) })
        local rescanB = button(page, "ОБНОВИТЬ",  { pos = UDim2.fromOffset(134, 380), size = UDim2.fromOffset(112, 40) })
        local allB    = button(page, "ВСЕ",       { pos = UDim2.fromOffset(252, 380), size = UDim2.fromOffset(112, 40) })

        local selected = loadTowers()
        local showAll  = false
        local paints   = {}
        local function isSel(n) for _, v in ipairs(selected) do if v == n then return true end end return false end
        local function indexOf(n) for i, v in ipairs(selected) do if v == n then return i end end return nil end
        local function refreshInfo()
            info.Text = "Выбрано " .. #selected .. " / " .. MAX_PICK ..
                (#selected > 0 and ("  •  " .. table.concat(selected, ", ")) or "  •  ничего не выбрано")
            info.TextColor3 = #selected > 0 and MONEY_C or SUB
            for i, s in ipairs(segs) do
                tween(s, 0.35, { BackgroundColor3 = (i <= #selected) and GOLD or LINE }, EASE.Quad)
            end
        end
        -- перекрасить все строки (номера выбора сдвигаются); pop — строка, по которой кликнули
        local function repaint(pop) for n, f in pairs(paints) do f(n == pop) end end

        local function clearList()
            paints = {}
            for _, ch in ipairs(list:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        end
        local function showError(reason)
            clearList()
            info.Text = "Список башен не получен"; info.TextColor3 = ERR_C

            -- элементы просто становятся в поток UIListLayout
            local why = label(list, "Причина:\n" .. tostring(reason), 13, WARN_C, Enum.Font.Gotham)
            why.Size = UDim2.new(1, -6, 0, 120); why.LayoutOrder = 1
            why.TextWrapped = true; why.TextYAlignment = Enum.TextYAlignment.Top
            why:SetAttribute("nofade", true)

            local rj = button(list, "ПЕРЕЗАЙТИ В ИГРУ", { size = UDim2.new(1, -6, 0, 46), ts = 15,
                c1 = Color3.fromRGB(240, 115, 85), c2 = Color3.fromRGB(215, 75, 95) })
            rj.btn.LayoutOrder = 2; rj.btn:SetAttribute("nofade", true)
            rj.btn.MouseButton1Click:Connect(function()
                rj.text.Text = "ПЕРЕЗАХОД..."; hint.Text = "Идёт перезаход на сервер"
                task.spawn(rejoin)
            end)
            fadeIn(why, 0.05, alive); fadeIn(rj.btn, 0.12, alive)
            hint.Text = "Открой инвентарь башен и нажми ОБНОВИТЬ"
        end

        local function build(base)
            local okScan, towers, err = pcall(scanTowers, showAll)
            if not okScan then return showError("Ошибка скана:\n" .. tostring(towers)) end
            if not towers then return showError(err) end

            clearList()
            refreshInfo()
            hint.Text = (showAll and "Показаны ВСЕ: " or "Доступно: ") .. #towers .. "  •  максимум " .. MAX_PICK

            for i, t in ipairs(towers) do
                local name = t.name
                local d = (base or 0) + math.min(i - 1, 14) * 0.025
                -- строка: иконка слева, название, справа — номер в порядке выбора
                local cell = Instance.new("TextButton")
                cell.Size = UDim2.new(1, -6, 0, 46); cell.LayoutOrder = i
                cell.BackgroundColor3 = SURF
                cell.Text = ""; cell.BorderSizePixel = 0; cell.AutoButtonColor = false
                cell:SetAttribute("nofade", true)
                cell.Parent = list
                corner(cell, 10)
                local st = stroke(cell, LINE, 1.2, 0.3)

                local ic = Instance.new("ImageLabel")
                ic.Size = UDim2.fromOffset(34, 34); ic.Position = UDim2.fromOffset(6, 6)
                ic.BackgroundColor3 = DEEP; ic.BackgroundTransparency = 0.1
                ic.Image = t.icon or ""; ic.ScaleType = Enum.ScaleType.Fit
                ic.Parent = cell; corner(ic, 8)

                local nm = label(cell, name, 14, TXT, Enum.Font.GothamBold)
                nm.Size = UDim2.new(1, -96, 1, 0); nm.Position = UDim2.fromOffset(62, 0)
                nm.TextTruncate = Enum.TextTruncate.AtEnd

                local badge = frame(cell, UDim2.fromOffset(24, 24), UDim2.new(1, -10, 0.5, 0), DEEP)
                badge.AnchorPoint = Vector2.new(1, 0.5); corner(badge, "full")
                local bs = stroke(badge, LINE, 1.2, 0.1)
                local bt = label(badge, "+", 13, MUTED, Enum.Font.GothamBold)
                bt.Size = UDim2.fromScale(1, 1); bt.TextXAlignment = Enum.TextXAlignment.Center
                local bsc = Instance.new("UIScale"); bsc.Parent = badge

                local glow
                local function paint(pop)
                    local idx = indexOf(name)
                    if glow then glow:Cancel(); glow = nil end
                    if idx then
                        tween(cell, 0.2, { BackgroundColor3 = Color3.fromRGB(52, 46, 26) }, EASE.Quad)
                        st.Color = GOLD; st.Thickness = 2; st.Transparency = 0
                        nm.TextColor3 = Color3.fromRGB(255, 224, 120)
                        badge.BackgroundColor3 = GOLD; bs.Color = GOLD
                        bt.Text = tostring(idx); bt.TextColor3 = Color3.fromRGB(45, 35, 8)
                        -- мерцание рамки выбранной башни
                        glow = own(page, loop(st, 0.85, { Color = Color3.fromRGB(175, 125, 25) }, true))
                    else
                        tween(cell, 0.2, { BackgroundColor3 = SURF }, EASE.Quad)
                        st.Color = LINE; st.Thickness = 1.2; st.Transparency = 0.3
                        nm.TextColor3 = TXT
                        badge.BackgroundColor3 = DEEP; bs.Color = LINE
                        bt.Text = "+"; bt.TextColor3 = MUTED
                    end
                    if pop then bsc.Scale = 0.4; tween(bsc, 0.45, { Scale = 1 }, EASE.Back) end
                end
                paints[name] = paint
                paint(false)

                cell.MouseEnter:Connect(function()
                    if not isSel(name) then
                        tween(cell, 0.15, { BackgroundColor3 = SURF_H }, EASE.Quad)
                        tween(st, 0.15, { Color = ACCENT1, Transparency = 0 }, EASE.Quad)
                    end
                end)
                cell.MouseLeave:Connect(function()
                    if not isSel(name) then
                        tween(cell, 0.15, { BackgroundColor3 = SURF }, EASE.Quad)
                        tween(st, 0.15, { Color = LINE, Transparency = 0.3 }, EASE.Quad)
                    end
                end)
                cell.MouseButton1Click:Connect(function()
                    if isSel(name) then
                        for idx, v in ipairs(selected) do if v == name then table.remove(selected, idx) break end end
                    elseif #selected >= MAX_PICK then
                        hint.Text = "Максимум " .. MAX_PICK .. " — сними лишнюю"; hint.TextColor3 = WARN_C
                        shake(slots)
                        tween(st, 0.1, { Color = ERR_C, Transparency = 0 }, EASE.Quad)
                        task.delay(0.35, function()
                            if cell.Parent and not isSel(name) then tween(st, 0.3, { Color = ACCENT1 }, EASE.Quad) end
                        end)
                        return
                    else
                        table.insert(selected, name)
                    end
                    hint.TextColor3 = SUB; repaint(name); refreshInfo()
                end)

                -- строки проявляются лесенкой, название чуть выезжает
                fadeIn(cell, d, alive)
                task.delay(d, function()
                    if nm.Parent and alive() then tween(nm, 0.45, { Position = UDim2.fromOffset(50, 0) }) end
                end)
            end
        end

        saveB.btn.MouseButton1Click:Connect(function()
            selected = saveTowers(selected)
            hint.Text = #selected > 0 and ("Сохранено: " .. table.concat(selected, ", ")) or "Сохранено: без выбора"
            hint.TextColor3 = MONEY_C
            saveB.text.Text = "СОХРАНЕНО"; saveB.shine()
            task.delay(1.2, function() if saveB.btn.Parent then saveB.text.Text = "СОХРАНИТЬ" end end)
            repaint(); refreshInfo()
        end)
        rescanB.btn.MouseButton1Click:Connect(function()
            hint.TextColor3 = SUB; hint.Text = "Поиск..."
            local ok, e = pcall(build)
            if not ok then pcall(showError, "Ошибка: " .. tostring(e)) end
        end)
        allB.btn.MouseButton1Click:Connect(function()
            showAll = not showAll
            allB.text.Text = showAll and "ДОСТУПНЫЕ" or "ВСЕ"
            if showAll then
                allB.set(Color3.fromRGB(78, 60, 150), Color3.fromRGB(96, 76, 180))
                tween(allB.stroke, 0.2, { Color = ACCENT1, Transparency = 0 }, EASE.Quad)
            else
                allB.set(SURF, SURF_H)
                tween(allB.stroke, 0.2, { Color = LINE, Transparency = 0.35 }, EASE.Quad)
            end
            hint.TextColor3 = SUB
            local ok, e = pcall(build)
            if not ok then pcall(showError, "Ошибка: " .. tostring(e)) end
        end)

        refreshInfo()
        -- строим СРАЗУ, синхронно — без отложенных вызовов
        local ok, e = pcall(build, 0.15)
        if not ok then
            local shown = pcall(showError, "Ошибка: " .. tostring(e))
            if not shown then
                -- последняя страховка: пишем прямо на страницу, мимо списка
                local hard = label(page, "Ошибка меню:\n" .. tostring(e), 13, ERR_C, Enum.Font.Gotham)
                hard.Size = UDim2.new(1, -32, 0, 250); hard.Position = UDim2.new(0, 16, 0, 114)
                hard.TextWrapped = true; hard.TextYAlignment = Enum.TextYAlignment.Top; hard.ZIndex = 5
            end
        end
    end)
end

-- ====================== МЕНЮ TDS FARM ======================
-- значки плиток; возвращают реакцию на наведение (или nil)
local function glyphGem(ico)
    local d = frame(ico, UDim2.fromOffset(14, 14), UDim2.fromScale(0.5, 0.5), WHITE)
    d.AnchorPoint = Vector2.new(0.5, 0.5); d.Rotation = 45; corner(d, 3)
    return function(on) tween(d, 0.45, { Rotation = on and 135 or 45 }, EASE.Back) end
end
local function glyphMoney(ico)
    local t = label(ico, "$", 21, WHITE, Enum.Font.GothamBlack)
    t.Size = UDim2.fromScale(1, 1); t.TextXAlignment = Enum.TextXAlignment.Center
    return function(on) tween(t, 0.3, { TextSize = on and 25 or 21 }, EASE.Back) end
end
local function glyphRec(ico, page)
    local ring = frame(ico, UDim2.fromOffset(20, 20), UDim2.fromScale(0.5, 0.5))
    ring.AnchorPoint = Vector2.new(0.5, 0.5); corner(ring, "full"); stroke(ring, WHITE, 2, 0.35)
    local dot = frame(ico, UDim2.fromOffset(10, 10), UDim2.fromScale(0.5, 0.5), WHITE)
    dot.AnchorPoint = Vector2.new(0.5, 0.5); corner(dot, "full")
    local sc = Instance.new("UIScale"); sc.Parent = dot
    own(page, loop(sc, 0.7, { Scale = 0.65 }, true))
    return nil
end
-- плитка режима: значок, название, подпись, клавиша, стрелка
local function tile(page, y, title, subtitle, c1, c2, glyph, keycap)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.Size = UDim2.new(1, -32, 0, 58); b.Position = UDim2.new(0.5, 0, 0, y + 29)
    b.BackgroundColor3 = SURF; b.Text = ""; b.AutoButtonColor = false; b.BorderSizePixel = 0
    b.Parent = page
    corner(b, 12)
    local st = stroke(b, LINE, 1.2, 0.3)

    local ico = frame(b, UDim2.fromOffset(38, 38), UDim2.new(0, 10, 0.5, 0), WHITE)
    ico.AnchorPoint = Vector2.new(0, 0.5); corner(ico, 10)
    local ig = grad(ico, { c1, c2 }, 45)
    local isc = Instance.new("UIScale"); isc.Parent = ico
    local onHover = glyph(ico, page)

    local t = label(b, title, 15, TXT, Enum.Font.GothamBold)
    t.Size = UDim2.new(1, -130, 0, 18); t.Position = UDim2.new(0, 60, 0.5, -17)
    local s = label(b, subtitle, 11, SUB, Enum.Font.Gotham)
    s.Size = UDim2.new(1, -130, 0, 14); s.Position = UDim2.new(0, 60, 0.5, 3)
    s.TextTruncate = Enum.TextTruncate.AtEnd

    if keycap then
        local kc = frame(b, UDim2.fromOffset(28, 22), UDim2.new(1, -38, 0.5, 0), DEEP)
        kc.AnchorPoint = Vector2.new(1, 0.5); corner(kc, 6); stroke(kc, LINE, 1, 0.3)
        local kt = label(kc, keycap, 11, SUB, Enum.Font.GothamBold)
        kt.Size = UDim2.fromScale(1, 1); kt.TextXAlignment = Enum.TextXAlignment.Center
    end
    local arrow = frame(b, UDim2.fromOffset(14, 14), UDim2.new(1, -14, 0.5, 0))
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    local a1, a2 = stick(arrow, 8, 7, 4, 45, MUTED), stick(arrow, 8, 7, 10, -45, MUTED)

    hoverify(b, SURF, SURF_H)
    b.MouseEnter:Connect(function()
        tween(st, 0.2, { Color = c1, Transparency = 0 }, EASE.Quad)
        tween(isc, 0.35, { Scale = 1.1 }, EASE.Back)
        tween(ig, 0.6, { Rotation = 225 }, EASE.Quad)
        tween(arrow, 0.25, { Position = UDim2.new(1, -10, 0.5, 0) }, EASE.Quad)
        tween(a1, 0.2, { BackgroundColor3 = c1 }); tween(a2, 0.2, { BackgroundColor3 = c1 })
        if onHover then onHover(true) end
    end)
    b.MouseLeave:Connect(function()
        tween(st, 0.2, { Color = LINE, Transparency = 0.3 }, EASE.Quad)
        tween(isc, 0.3, { Scale = 1 }, EASE.Quad)
        tween(ig, 0.6, { Rotation = 45 }, EASE.Quad)
        tween(arrow, 0.25, { Position = UDim2.new(1, -14, 0.5, 0) }, EASE.Quad)
        tween(a1, 0.2, { BackgroundColor3 = MUTED }); tween(a2, 0.2, { BackgroundColor3 = MUTED })
        if onHover then onHover(false) end
    end)
    shine(b, 12); pressify(b, 0.97)
    return b
end

showFarm = function(server, key, errMsg, dir)
    local w, h = 320, 304
    showPage(w, h, dir or 1, function(page)
        local bar = header(page, "TDS FARM")
        headBtn(bar, "close", -40).MouseButton1Click:Connect(closeAll)
        headBtn(bar, "gear", -74).MouseButton1Click:Connect(function() showSettings(server, key) end)

        local gemsB  = tile(page, 60,  "GEMS FARM",  "Автофарм гемов", GEMS_C, Color3.fromRGB(110, 60, 220), glyphGem, "F1")
        local moneyB = tile(page, 126, "MONEY FARM", "Автофарм денег", MONEY_C, Color3.fromRGB(30, 160, 120), glyphMoney, "F2")
        local recB   = tile(page, 192, "RECORDER",   "Запись и повтор действий", REC_C, Color3.fromRGB(205, 70, 100), glyphRec)

        -- строка состояния: точка с «пульсом» + текст
        local picked = loadTowers()
        local dotC = errMsg and WARN_C or MONEY_C
        local pill = frame(page, UDim2.new(1, -32, 0, 28), UDim2.new(0, 16, 1, -42), DEEP)
        corner(pill, "full"); stroke(pill, LINE, 1, 0.5)
        local ping = frame(pill, UDim2.fromOffset(8, 8), UDim2.new(0, 15, 0.5, 0), dotC)
        ping.AnchorPoint = Vector2.new(0.5, 0.5); ping.BackgroundTransparency = 0.3
        ping:SetAttribute("nofade", true); corner(ping, "full")
        own(page, Tween:Create(ping, TweenInfo.new(1.4, EASE.Quad, EDIR.Out, -1),
            { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1 })):Play()
        local dot = frame(pill, UDim2.fromOffset(8, 8), UDim2.new(0, 15, 0.5, 0), dotC)
        dot.AnchorPoint = Vector2.new(0.5, 0.5); corner(dot, "full")
        local status = label(pill, "", 12, SUB, Enum.Font.Gotham)
        status.Size = UDim2.new(1, -42, 1, 0); status.Position = UDim2.fromOffset(28, 0)
        status.TextTruncate = Enum.TextTruncate.AtEnd
        status.Text = #picked > 0 and ("Башни: " .. table.concat(picked, ", ")) or "Готово к работе  •  F1 / F2"
        if errMsg then status.Text = "! " .. errMsg; status.TextColor3 = WARN_C end

        local active = false
        local function runFarm(kind)
            if active then return end
            active = true
            local titles = { gems = "GEMS FARM", money = "MONEY FARM", recorder = "RECORDER" }
            showLoading(titles[kind] or "ЗАГРУЗКА", function(setStatus)
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
        recB.MouseButton1Click:Connect(function() runFarm("recorder") end)
        own(page, UIS.InputBegan:Connect(function(input, gp)
            if gp or not page.Parent then return end
            if input.KeyCode == Enum.KeyCode.F1 then runFarm("gems")
            elseif input.KeyCode == Enum.KeyCode.F2 then runFarm("money") end
        end))
    end)
end

-- ====================== ВВОД КЛЮЧА ======================
showGate = function(presetKey, autostart, errMsg)
    local w, h = 340, 282
    showPage(w, h, -1, function(page)
        -- верх: логотип, название, крестик; за него таскается окно
        local top = frame(page, UDim2.new(1, 0, 0, 64))
        dragify(top)
        local logo = frame(top, UDim2.fromOffset(40, 40), UDim2.fromOffset(18, 16), WHITE)
        corner(logo, 12); stroke(logo, WHITE, 1, 0.75)
        own(page, loop(grad(logo, { ACCENT2, ACCENT1 }, 0), 4, { Rotation = 360 }, false, EASE.Linear))
        local lt = label(logo, "S", 22, WHITE, Enum.Font.GothamBlack)
        lt.Size = UDim2.fromScale(1, 1); lt.TextXAlignment = Enum.TextXAlignment.Center

        local title = label(top, "SCRIPT HUB", 21, WHITE, Enum.Font.GothamBlack)
        title.Size = UDim2.new(1, -130, 0, 24); title.Position = UDim2.fromOffset(68, 15)
        shimmer(page, grad(title, { ACCENT2, ACCENT1, ACCENT2 }, 0))
        local tag = label(top, "ДОСТУП ПО КЛЮЧУ", 10, MUTED, Enum.Font.GothamBold)
        tag.Size = UDim2.new(1, -130, 0, 14); tag.Position = UDim2.fromOffset(68, 40)
        headBtn(top, "close", -40, 22).MouseButton1Click:Connect(closeAll)

        local _, fl = flowLine(page, UDim2.fromOffset(18, 68), UDim2.new(1, -36, 0, 1))
        own(page, fl)

        local sub = label(page, errMsg or "Введите ключ для доступа", 13, errMsg and ERR_C or SUB, Enum.Font.Gotham)
        sub.Size = UDim2.new(1, -36, 0, 32); sub.Position = UDim2.fromOffset(18, 78)
        sub.TextWrapped = true; sub.TextYAlignment = Enum.TextYAlignment.Top

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -32, 0, 44); box.Position = UDim2.fromOffset(16, 116)
        box.BackgroundColor3 = DEEP; box.BorderSizePixel = 0; box.Font = Enum.Font.GothamMedium
        box.PlaceholderText = "XXXXX-XXXXX-XXXXX-XXXXX"; box.Text = presetKey or ""; box.TextSize = 15
        box.TextColor3 = TXT; box.PlaceholderColor3 = MUTED
        box.ClearTextOnFocus = false; box.Parent = page; corner(box, 10)
        local bxs = stroke(box, errMsg and ERR_C or LINE, 1.2, errMsg and 0.1 or 0.2)
        box.Focused:Connect(function()
            tween(bxs, 0.2, { Color = ACCENT1, Transparency = 0, Thickness = 1.8 }, EASE.Quad)
            tween(box, 0.2, { BackgroundColor3 = Color3.fromRGB(27, 25, 43) }, EASE.Quad)
        end)
        box.FocusLost:Connect(function()
            tween(bxs, 0.2, { Color = LINE, Transparency = 0.2, Thickness = 1.2 }, EASE.Quad)
            tween(box, 0.2, { BackgroundColor3 = DEEP }, EASE.Quad)
        end)

        local act = button(page, "Активировать", { pos = UDim2.fromOffset(16, 170), size = UDim2.new(1, -32, 0, 44),
            c1 = ACCENT1, c2 = Color3.fromRGB(95, 70, 220), ts = 15 })
        local buyb = button(page, "Купить ключ  (FunPay)", { pos = UDim2.fromOffset(16, 222), size = UDim2.new(1, -32, 0, 40),
            bg = Color3.fromRGB(24, 42, 38), hov = Color3.fromRGB(30, 60, 50), line = MONEY_C, lineT = 0.45, tc = MONEY_C })
        -- главная кнопка периодически «бликует», привлекая внимание
        task.spawn(function()
            while act.btn.Parent do
                task.wait(3)
                if act.btn.Parent and curPage == page then act.shine() end
            end
        end)

        local function activate()
            local key = trim(box.Text)
            if key == "" then sub.Text = "Введите ключ"; sub.TextColor3 = ERR_C; shake(box); return end
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
        act.btn.MouseButton1Click:Connect(activate)
        box.FocusLost:Connect(function(enter) if enter then activate() end end)
        buyb.btn.MouseButton1Click:Connect(function()
            if setclipboard then pcall(setclipboard, BUY_URL); sub.Text = "Ссылка скопирована — открой в браузере"
            else sub.Text = BUY_URL end
            sub.TextColor3 = ACCENT2
        end)

        -- ошибка: поле ввода вздрагивает, когда страница уже проявилась
        if errMsg then task.delay(0.7, function() if box.Parent and curPage == page then shake(box) end end) end
        if autostart and presetKey and presetKey ~= "" then task.spawn(activate) end
    end)
end

-- появление окна: пружинистый масштаб + проявление
fadeIn(holder, 0)
tween(scale, 0.6, { Scale = 1 }, EASE.Back)

local saved = loadKey()
showGate(saved or "", saved ~= nil and saved ~= "", nil)
