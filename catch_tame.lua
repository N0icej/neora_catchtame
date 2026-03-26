--[[
  NEBULA | CATCH & TAME – WORKING VERSION
  Uses the simple GUI that worked, adds all features as buttons.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local function notify(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Nebula",
            Text = msg,
            Duration = 2
        })
    end)
    print("[Nebula] " .. msg)
end

-- ========== STATE ==========
local State = {
    ESP = false,
    AutoCatch = false,
    AutoTame = false,
    AutoFarm = false,
    AutoCash = false,
    AutoClaim = false,
    AutoQuest = false,
    AutoSell = false,
    AutoBuy = false,
    AutoHatch = false,
    AutoTrain = false,
    Fly = false,
    CatchRange = 30,
    TameRange = 15,
    FarmRange = 20,
    CashRange = 20,
    Speed = 16,
    JumpPower = 50,
    ESPObjects = {}
}

-- ========== CACHE & SCAN (performance) ==========
local rootPartCache, humanoidCache, lastCacheRefresh = nil, nil, 0
local function getRootPart()
    local now = tick()
    if now - lastCacheRefresh > 0.5 or not rootPartCache or not rootPartCache.Parent then
        local char = LocalPlayer.Character
        rootPartCache = char and char:FindFirstChild("HumanoidRootPart")
        humanoidCache = char and char:FindFirstChild("Humanoid")
        lastCacheRefresh = now
    end
    return rootPartCache
end
local function getHumanoid()
    getRootPart()
    return humanoidCache
end

local lastScan = 0
local creatures, resources, cash = {}, {}, {}
local scanInterval = 0.5
local function scan()
    local now = tick()
    if now - lastScan < scanInterval then return end
    lastScan = now
    creatures = {}; resources = {}; cash = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then table.insert(creatures, obj) end
        end
        local name = obj.Name
        if obj:IsA("BasePart") or obj:IsA("Model") then
            for _, kw in ipairs({"Cash","Coin","Money","Gem","Diamond","Crystal","Wood","Stone","Berry","Meat","Bone","Candy","Apple","Fish","Egg","Milk","Carrot","Wheat","Gold","Silver","Ruby","Emerald","Sapphire"}) do
                if name:find(kw) then
                    table.insert(resources, obj)
                    if kw:match("Cash|Coin|Money|Gem|Diamond|Gold|Silver|Ruby|Emerald|Sapphire|Crystal") then
                        table.insert(cash, obj)
                    end
                    break
                end
            end
        end
        if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
            local p = obj.Parent
            if p and not table.find(resources, p) then table.insert(resources, p) end
        end
    end
end

local function nearest(list, getPos)
    local root = getRootPart()
    if not root then return nil, math.huge end
    local best, bestDist = nil, math.huge
    for _, item in ipairs(list) do
        local pos = getPos and getPos(item) or (item:IsA("BasePart") and item.Position or (item:FindFirstChildWhichIsA("BasePart") and item:FindFirstChildWhichIsA("BasePart").Position))
        if pos then
            local d = (root.Position - pos).Magnitude
            if d < bestDist then bestDist = d; best = item end
        end
    end
    return best, bestDist
end

local function nearestCreature()
    scan()
    return nearest(creatures, function(c) return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") end)
end
local function nearestResource()
    scan()
    return nearest(resources)
end
local function nearestCash()
    scan()
    return nearest(cash)
end
local function bestPet()
    scan()
    local best, bestScore = nil, -1
    local rarity = {Mythic=100, Legendary=80, Epic=60, Rare=40, Uncommon=20, Common=10}
    for _, p in ipairs(creatures) do
        local s = 0
        for k, v in pairs(rarity) do if p.Name:find(k) then s = v; break end end
        if s == 0 then s = math.min(#p.Name, 50) end
        local lvl = p:FindFirstChild("Level")
        if lvl and lvl:IsA("NumberValue") then s = s + lvl.Value * 2 end
        local val = p:FindFirstChild("Value")
        if val and val:IsA("NumberValue") then s = s + val.Value end
        if s > bestScore then bestScore = s; best = p end
    end
    return best
end
local function teleport(part)
    local root = getRootPart()
    if root and part then root.CFrame = part.CFrame + Vector3.new(0,5,0) end
end

-- ========== REMOTES & ACTIONS ==========
local function fireRemote(pattern, ...)
    local args = {...}
    for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
        if r.Name:lower():find(pattern:lower()) then
            if r:IsA("RemoteEvent") then pcall(r.FireServer, r, unpack(args)); return true
            elseif r:IsA("RemoteFunction") then pcall(r.InvokeServer, r, unpack(args)); return true end
        end
    end
    return false
end

local function catch(creature)
    if not creature then return end
    fireRemote("catch", creature) or fireRemote("capture", creature) or fireRemote("throw", creature)
    local cd = creature:FindFirstChildWhichIsA("ClickDetector")
    if cd then pcall(cd.FireClick, cd) end
    local prompt = creature:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then pcall(prompt.InputHold, prompt) end
end

local function getTamingItem()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    local taming = {"Bone","Candy","Meat","Berry","Apple","Fish","Egg","Milk","Carrot","Wheat"}
    local function check(cont)
        if not cont then return end
        for _, it in ipairs(cont:GetChildren()) do
            if it:IsA("Tool") then
                for _, n in ipairs(taming) do if it.Name:find(n) then return it end end
            end
        end
    end
    return check(backpack) or check(char)
end

local function tame(creature, tool)
    if not creature or not tool then return end
    local orig = tool.Parent
    tool.Parent = LocalPlayer.Character
    wait(0.2)
    fireRemote("tame", creature, tool) or fireRemote("feed", creature, tool) or fireRemote("train", creature)
    pcall(tool.Activate, tool)
    local prompt = creature:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then pcall(prompt.InputHold, prompt) end
    wait(1)
    tool.Parent = orig
end

local function farm(res)
    if not res then return end
    fireRemote("harvest", res) or fireRemote("collect", res) or fireRemote("gather", res)
    local cd = res:FindFirstChildWhichIsA("ClickDetector")
    if cd then pcall(cd.FireClick, cd) end
    local prompt = res:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then pcall(prompt.InputHold, prompt) end
end

local function collectCash(cashItem)
    if not cashItem then return end
    fireRemote("collect", cashItem) or fireRemote("pickup", cashItem) or fireRemote("claim", cashItem)
    local root = getRootPart()
    if root and cashItem:IsA("BasePart") then cashItem.CFrame = root.CFrame + Vector3.new(0,3,0) end
end

-- ========== FLY ==========
local flying = false
local vel, gyro
local function toggleFly()
    local hum = getHumanoid()
    local root = getRootPart()
    if not hum or not root then return end
    if not flying then
        flying = true
        hum.PlatformStand = true
        vel = Instance.new("BodyVelocity")
        vel.MaxForce = Vector3.new(1,1,1)*10000
        vel.Parent = root
        gyro = Instance.new("BodyGyro")
        gyro.MaxTorque = Vector3.new(1,1,1)*10000
        gyro.CFrame = root.CFrame
        gyro.Parent = root
        notify("Flight ON")
    else
        flying = false
        hum.PlatformStand = false
        if vel then vel:Destroy() end
        if gyro then gyro:Destroy() end
        notify("Flight OFF")
    end
end

-- ========== ESP ==========
local function clearESP()
    for _, obj in pairs(State.ESPObjects) do pcall(obj.Destroy, obj) end
    State.ESPObjects = {}
end

local function updateESP()
    if not State.ESP then clearESP(); return end
    scan()
    for id, obj in pairs(State.ESPObjects) do
        if not obj.Parent or not obj.Parent:IsDescendantOf(Workspace) then
            pcall(obj.Destroy, obj)
            State.ESPObjects[id] = nil
        end
    end
    for _, c in ipairs(creatures) do
        local id = "c_" .. tostring(c)
        if not State.ESPObjects[id] then
            local hl = Instance.new("Highlight")
            hl.Adornee = c
            hl.FillColor = Color3.fromRGB(255,50,50)
            hl.OutlineColor = Color3.fromRGB(255,200,100)
            hl.FillTransparency = 0.6
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = c
            State.ESPObjects[id] = hl
            local bill = Instance.new("BillboardGui")
            bill.Size = UDim2.new(0,120,0,35)
            bill.Adornee = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head") or c.PrimaryPart
            bill.AlwaysOnTop = true
            bill.Parent = c
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = c.Name .. " 🐾"
            lbl.TextColor3 = Color3.fromRGB(255,100,100)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Parent = bill
            State.ESPObjects["bill_" .. id] = bill
        end
    end
    for _, r in ipairs(resources) do
        local part = r:IsA("BasePart") and r or r:FindFirstChildWhichIsA("BasePart")
        if part then
            local id = "r_" .. tostring(r)
            if not State.ESPObjects[id] then
                local bill = Instance.new("BillboardGui")
                bill.Size = UDim2.new(0,100,0,30)
                bill.Adornee = part
                bill.AlwaysOnTop = true
                bill.Parent = part
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1,0,1,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "✨ " .. r.Name .. " ✨"
                lbl.TextColor3 = Color3.fromRGB(100,255,100)
                lbl.TextScaled = true
                lbl.Font = Enum.Font.Gotham
                lbl.Parent = bill
                State.ESPObjects[id] = bill
            end
        end
    end
    for _, ca in ipairs(cash) do
        local part = ca:IsA("BasePart") and ca or ca:FindFirstChildWhichIsA("BasePart")
        if part then
            local id = "cash_" .. tostring(ca)
            if not State.ESPObjects[id] then
                local bill = Instance.new("BillboardGui")
                bill.Size = UDim2.new(0,90,0,30)
                bill.Adornee = part
                bill.AlwaysOnTop = true
                bill.Parent = part
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1,0,1,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "💰 " .. ca.Name .. " 💰"
                lbl.TextColor3 = Color3.fromRGB(255,215,0)
                lbl.TextScaled = true
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = bill
                State.ESPObjects[id] = bill
            end
        end
    end
end

-- ========== MAIN LOOP ==========
local last = {catch=0, tame=0, farm=0, cash=0, claim=0, quest=0, sell=0, buy=0, hatch=0, train=0, esp=0}
local function onTick()
    local now = tick()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = State.Speed
        hum.JumpPower = State.JumpPower
    end

    if State.ESP and now - last.esp >= 1.5 then
        last.esp = now
        updateESP()
    elseif not State.ESP then
        clearESP()
    end

    if State.AutoCatch and now - last.catch >= 1 then
        last.catch = now
        local c, d = nearestCreature()
        if c and d <= State.CatchRange then catch(c) end
    end
    if State.AutoTame and now - last.tame >= 2 then
        last.tame = now
        local tool = getTamingItem()
        if tool then
            local c, d = nearestCreature()
            if c and d <= State.TameRange then tame(c, tool) end
        end
    end
    if State.AutoFarm and now - last.farm >= 1 then
        last.farm = now
        local r, d = nearestResource()
        if r and d <= State.FarmRange then farm(r) end
    end
    if State.AutoCash and now - last.cash >= 0.8 then
        last.cash = now
        local c, d = nearestCash()
        if c and d <= State.CashRange then collectCash(c) end
    end
    if State.AutoClaim and now - last.claim >= 60 then
        last.claim = now
        fireRemote("claimdaily") or fireRemote("dailyreward")
    end
    if State.AutoQuest and now - last.quest >= 30 then
        last.quest = now
        fireRemote("acceptquest") or fireRemote("completequest")
    end
    if State.AutoSell and now - last.sell >= 60 then
        last.sell = now
        fireRemote("sellall") or fireRemote("sell")
    end
    if State.AutoBuy and now - last.buy >= 15 then
        last.buy = now
        fireRemote("buy", "Basic Ball")
    end
    if State.AutoHatch and now - last.hatch >= 20 then
        last.hatch = now
        fireRemote("hatchegg") or fireRemote("hatch")
    end
    if State.AutoTrain and now - last.train >= 30 then
        last.train = now
        fireRemote("trainpet") or fireRemote("levelup")
    end

    if State.Fly and flying then
        local root = getRootPart()
        if root then
            local move = Vector3.new()
            local cam = Workspace.CurrentCamera
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
            if move.Magnitude > 0 then
                move = move.Unit
                if vel then vel.Velocity = move * 100 end
                if gyro then gyro.CFrame = CFrame.lookAt(root.Position, root.Position + move) end
            elseif vel then
                vel.Velocity = Vector3.new()
            end
        end
    end
end

-- ========== GUI (Same as Test – Visible Red Frame) ==========
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Nebula"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 300, 0, 500)
    main.Position = UDim2.new(0.5, -150, 0.5, -250)
    main.BackgroundColor3 = Color3.fromRGB(200, 50, 50)   -- visible red
    main.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    title.Text = "⚡ NEBULA | CATCH & TAME"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.Parent = main

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 26, 0, 26)
    close.Position = UDim2.new(1, -30, 0.5, -13)
    close.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255,255,255)
    close.Font = Enum.Font.Gotham
    close.TextSize = 14
    close.BorderSizePixel = 0
    close.Parent = title
    close.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        clearESP()
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -40)
    scroll.Position = UDim2.new(0, 5, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.Parent = main
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local function addButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = scroll
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    -- Toggle buttons
    addButton("ESP (Wallhack)", function()
        State.ESP = not State.ESP
        notify("ESP " .. (State.ESP and "ON" or "OFF"))
    end)
    addButton("Auto Catch", function()
        State.AutoCatch = not State.AutoCatch
        notify("Auto Catch " .. (State.AutoCatch and "ON" or "OFF"))
    end)
    addButton("Auto Tame", function()
        State.AutoTame = not State.AutoTame
        notify("Auto Tame " .. (State.AutoTame and "ON" or "OFF"))
    end)
    addButton("Auto Farm", function()
        State.AutoFarm = not State.AutoFarm
        notify("Auto Farm " .. (State.AutoFarm and "ON" or "OFF"))
    end)
    addButton("Auto Cash", function()
        State.AutoCash = not State.AutoCash
        notify("Auto Cash " .. (State.AutoCash and "ON" or "OFF"))
    end)
    addButton("Auto Claim", function()
        State.AutoClaim = not State.AutoClaim
        notify("Auto Claim " .. (State.AutoClaim and "ON" or "OFF"))
    end)
    addButton("Auto Quest", function()
        State.AutoQuest = not State.AutoQuest
        notify("Auto Quest " .. (State.AutoQuest and "ON" or "OFF"))
    end)
    addButton("Auto Sell", function()
        State.AutoSell = not State.AutoSell
        notify("Auto Sell " .. (State.AutoSell and "ON" or "OFF"))
    end)
    addButton("Auto Buy", function()
        State.AutoBuy = not State.AutoBuy
        notify("Auto Buy " .. (State.AutoBuy and "ON" or "OFF"))
    end)
    addButton("Auto Hatch", function()
        State.AutoHatch = not State.AutoHatch
        notify("Auto Hatch " .. (State.AutoHatch and "ON" or "OFF"))
    end)
    addButton("Auto Train", function()
        State.AutoTrain = not State.AutoTrain
        notify("Auto Train " .. (State.AutoTrain and "ON" or "OFF"))
    end)
    addButton("Fly Mode (F)", function()
        State.Fly = not State.Fly
        toggleFly()
    end)

    -- Increment buttons
    local speedBtn = addButton("Speed: " .. State.Speed, nil)
    speedBtn.MouseButton1Click:Connect(function()
        State.Speed = State.Speed + 5
        if State.Speed > 200 then State.Speed = 16 end
        speedBtn.Text = "Speed: " .. State.Speed
        notify("Speed set to " .. State.Speed)
    end)
    local jumpBtn = addButton("Jump: " .. State.JumpPower, nil)
    jumpBtn.MouseButton1Click:Connect(function()
        State.JumpPower = State.JumpPower + 10
        if State.JumpPower > 200 then State.JumpPower = 50 end
        jumpBtn.Text = "Jump: " .. State.JumpPower
        notify("Jump set to " .. State.JumpPower)
    end)
    local catchRangeBtn = addButton("Catch Range: " .. State.CatchRange, nil)
    catchRangeBtn.MouseButton1Click:Connect(function()
        State.CatchRange = State.CatchRange + 5
        if State.CatchRange > 50 then State.CatchRange = 5 end
        catchRangeBtn.Text = "Catch Range: " .. State.CatchRange
        notify("Catch Range set to " .. State.CatchRange)
    end)
    local tameRangeBtn = addButton("Tame Range: " .. State.TameRange, nil)
    tameRangeBtn.MouseButton1Click:Connect(function()
        State.TameRange = State.TameRange + 5
        if State.TameRange > 45 then State.TameRange = 5 end
        tameRangeBtn.Text = "Tame Range: " .. State.TameRange
        notify("Tame Range set to " .. State.TameRange)
    end)
    local farmRangeBtn = addButton("Farm Range: " .. State.FarmRange, nil)
    farmRangeBtn.MouseButton1Click:Connect(function()
        State.FarmRange = State.FarmRange + 5
        if State.FarmRange > 45 then State.FarmRange = 5 end
        farmRangeBtn.Text = "Farm Range: " .. State.FarmRange
        notify("Farm Range set to " .. State.FarmRange)
    end)
    local cashRangeBtn = addButton("Cash Range: " .. State.CashRange, nil)
    cashRangeBtn.MouseButton1Click:Connect(function()
        State.CashRange = State.CashRange + 5
        if State.CashRange > 45 then State.CashRange = 5 end
        cashRangeBtn.Text = "Cash Range: " .. State.CashRange
        notify("Cash Range set to " .. State.CashRange)
    end)

    -- Teleport buttons
    addButton("🐾 To Nearest Creature", function()
        local c, _ = nearestCreature()
        if c and c:FindFirstChild("HumanoidRootPart") then teleport(c.HumanoidRootPart) end
    end)
    addButton("🏆 To Best Pet", function()
        local p = bestPet()
        if p and p:FindFirstChild("HumanoidRootPart") then teleport(p.HumanoidRootPart) end
    end)
    addButton("💰 To Nearest Cash", function()
        local c, _ = nearestCash()
        if c then
            local part = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart")
            if part then teleport(part) end
        end
    end)
    addButton("🏠 To Spawn", function()
        local spawn = Workspace:FindFirstChild("SpawnLocation")
        if spawn then teleport(spawn) end
    end)
    addButton("🔄 Rejoin Game", function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)

    -- Dragging
    local drag, dragStart, frameStart = false
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dragStart = i.Position
            frameStart = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - dragStart
            main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)

    notify("GUI ready")
end

-- ========== START ==========
local function start()
    repeat wait() until LocalPlayer.Character
    createGUI()
    RunService.Heartbeat:Connect(onTick)
    notify("Nebula loaded. Press F for flight.")
end

spawn(start)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.F then
        State.Fly = not State.Fly
        toggleFly()
    end
end)
