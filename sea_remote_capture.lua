-- Wave Monitor + Orbit CrystalModel
-- Rayfield UI

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

-- =====================
-- CONFIG
-- =====================
local TARGET_WAVE = 51
local RESET_COUNT = 4
local CHECK_INTERVAL = 1
local RESET_DELAY = 2

-- =====================
-- STATE
-- =====================
local isRunning = false
local hasReset = false
local monitorThread = nil
local orbitEnabled = false
local orbitThread = nil
local orbitRadius = 8
local orbitSpeed = 1.5
local orbitHeight = 0
local movementType = "Tween"
local tweenSpeed = 180

-- =====================
-- CORE: GET CRYSTAL TARGET
-- =====================
local function getCrystalCFrame()
    local model = workspace:FindFirstChild("CrystalModel")
    if not model then return nil end

    -- Coba pivot dulu, fallback ke PrimaryPart, lalu BasePart
    if model.PrimaryPart then
        return model:GetPivot()
    end

    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            return v.CFrame
        end
    end

    return nil
end

local function getCrystalPosition()
    local cf = getCrystalCFrame()
    return cf and cf.Position or nil
end

-- =====================
-- CORE: WAVE FUNCTIONS
-- =====================
local function getWaveFrame()
    local gui = localPlayer.PlayerGui:FindFirstChild("DungeonUI")
    if not gui then return nil end
    local content = gui:FindFirstChild("ContentFrame")
    if not content then return nil end
    return content:FindFirstChild("WaveFrame")
end

local function getCurrentWave()
    local waveFrame = getWaveFrame()
    if not waveFrame then return nil end
    for _, child in ipairs(waveFrame:GetDescendants()) do
        if child:IsA("TextLabel") then
            local num = tonumber(child.Text:match("%d+"))
            if num then return num end
        end
    end
    return nil
end

local function resetCharacter()
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end

-- =====================
-- CORE: MOVE FUNCTION
-- =====================
local function MoveToTarget(root, targetCF)
    if not root then return end
    local gap = (root.Position - targetCF.Position).Magnitude

    if movementType == "Teleport" then
        root.CFrame = targetCF
    else
        if gap > 0.1 then
            local duration = math.max(gap / tweenSpeed, 0.03)
            TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Linear),
                { CFrame = targetCF }
            ):Play()
        end
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

-- =====================
-- CORE: ORBIT LOGIC
-- =====================
local function stopOrbit()
    orbitEnabled = false
    if orbitThread then
        task.cancel(orbitThread)
        orbitThread = nil
    end
end

local function startOrbit()
    stopOrbit()
    orbitEnabled = true

    orbitThread = task.spawn(function()
        while orbitEnabled do
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local crystalPos = getCrystalPosition()

            if root and crystalPos then
                local ang = tick() * orbitSpeed

                local orbitOffset = Vector3.new(
                    math.cos(ang) * orbitRadius,
                    orbitHeight,
                    math.sin(ang) * orbitRadius
                )

                local finalPos = crystalPos + orbitOffset
                local targetCF = CFrame.lookAt(finalPos, crystalPos)

                MoveToTarget(root, targetCF)
            end

            task.wait(0.03)
        end
    end)
end

-- =====================
-- RAYFIELD WINDOW
-- =====================
local Window = Rayfield:CreateWindow({
    Name = "Wave Monitor",
    Icon = 0,
    LoadingTitle = "Wave Monitor",
    LoadingSubtitle = "Crystal Defense",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
})

local MonitorTab = Window:CreateTab("Monitor", 4483362458)
local OrbitTab = Window:CreateTab("Orbit", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- =====================
-- MONITOR TAB
-- =====================
MonitorTab:CreateSection("Wave Info")
local waveLabel = MonitorTab:CreateLabel("Current Wave: --")
local statusLabel = MonitorTab:CreateLabel("Status: Idle")
MonitorTab:CreateDivider()

MonitorTab:CreateSection("Control")
MonitorTab:CreateToggle({
    Name = "Auto Reset at Wave " .. TARGET_WAVE,
    CurrentValue = false,
    Flag = "WaveMonitorToggle",
    Callback = function(value)
        isRunning = value
        if isRunning then
            hasReset = false
            statusLabel:Set("Status: Running...")
            monitorThread = task.spawn(function()
                while isRunning do
                    task.wait(CHECK_INTERVAL)
                    local wave = getCurrentWave()
                    if wave then
                        waveLabel:Set("Current Wave: " .. wave)
                        if wave == TARGET_WAVE and not hasReset then
                            hasReset = true
                            for i = 1, RESET_COUNT do
                                if not isRunning then break end
                                statusLabel:Set(string.format("Status: Resetting %d/%d", i, RESET_COUNT))
                                Rayfield:Notify({
                                    Title = "Wave Monitor",
                                    Content = string.format("Reset %d/%d - Wave %d!", i, RESET_COUNT, TARGET_WAVE),
                                    Duration = 2,
                                    Image = 4483362458,
                                })
                                resetCharacter()
                                task.wait(RESET_DELAY)
                            end
                            statusLabel:Set("Status: Done! Watching...")
                        elseif wave ~= TARGET_WAVE then
                            hasReset = false
                            statusLabel:Set("Status: Running...")
                        end
                    else
                        waveLabel:Set("Current Wave: N/A")
                        statusLabel:Set("Status: WaveFrame not found!")
                    end
                end
            end)
        else
            if monitorThread then
                task.cancel(monitorThread)
                monitorThread = nil
            end
            waveLabel:Set("Current Wave: --")
            statusLabel:Set("Status: Idle")
        end
    end,
})

MonitorTab:CreateDivider()
MonitorTab:CreateSection("Manual")

MonitorTab:CreateButton({
    Name = "Reset Character Now",
    Callback = function()
        resetCharacter()
        Rayfield:Notify({ Title = "Wave Monitor", Content = "Character manually reset!", Duration = 2, Image = 4483362458 })
    end,
})

MonitorTab:CreateButton({
    Name = "Debug: Print WaveFrame Labels",
    Callback = function()
        local wf = getWaveFrame()
        if not wf then
            Rayfield:Notify({ Title = "Debug", Content = "WaveFrame not found!", Duration = 3, Image = 4483362458 })
            return
        end
        for _, v in ipairs(wf:GetDescendants()) do
            if v:IsA("TextLabel") then
                print("[Debug]", v.ClassName, v.Name, "|", v.Text)
            end
        end
        Rayfield:Notify({ Title = "Debug", Content = "Check console for labels.", Duration = 3, Image = 4483362458 })
    end,
})

-- =====================
-- ORBIT TAB
-- =====================
OrbitTab:CreateSection("Target")
local crystalStatusLabel = OrbitTab:CreateLabel("Target: workspace.CrystalModel")
OrbitTab:CreateDivider()

OrbitTab:CreateSection("Orbit Control")

OrbitTab:CreateButton({
    Name = "Teleport to Crystal",
    Callback = function()
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local crystalPos = getCrystalPosition()
        if root and crystalPos then
            root.CFrame = CFrame.new(crystalPos + Vector3.new(0, 0, orbitRadius))
            Rayfield:Notify({ Title = "Orbit", Content = "Teleported to CrystalModel!", Duration = 2, Image = 4483362458 })
        else
            Rayfield:Notify({ Title = "Orbit", Content = "CrystalModel not found!", Duration = 3, Image = 4483362458 })
        end
    end,
})

OrbitTab:CreateToggle({
    Name = "Enable Orbit",
    CurrentValue = false,
    Flag = "OrbitToggle",
    Callback = function(value)
        if value then
            local crystalPos = getCrystalPosition()
            if not crystalPos then
                Rayfield:Notify({ Title = "Orbit", Content = "CrystalModel not found in workspace!", Duration = 3, Image = 4483362458 })
                return
            end
            startOrbit()
            Rayfield:Notify({ Title = "Orbit", Content = "Orbiting CrystalModel!", Duration = 2, Image = 4483362458 })
        else
            stopOrbit()
            Rayfield:Notify({ Title = "Orbit", Content = "Orbit stopped.", Duration = 2, Image = 4483362458 })
        end
    end,
})

OrbitTab:CreateDivider()
OrbitTab:CreateSection("Orbit Settings")

OrbitTab:CreateSlider({
    Name = "Orbit Radius",
    Range = {2, 30},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = orbitRadius,
    Flag = "OrbitRadius",
    Callback = function(v) orbitRadius = v end,
})

OrbitTab:CreateSlider({
    Name = "Orbit Speed",
    Range = {1, 10},
    Increment = 1,
    Suffix = "x",
    CurrentValue = orbitSpeed,
    Flag = "OrbitSpeed",
    Callback = function(v) orbitSpeed = v end,
})

OrbitTab:CreateSlider({
    Name = "Height Offset",
    Range = {-10, 10},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = orbitHeight,
    Flag = "OrbitHeight",
    Callback = function(v) orbitHeight = v end,
})

OrbitTab:CreateDivider()
OrbitTab:CreateSection("Movement Type")

OrbitTab:CreateDropdown({
    Name = "Movement Mode",
    Options = {"Tween", "Teleport"},
    CurrentOption = {"Tween"},
    Flag = "MovementMode",
    Callback = function(opt)
        movementType = opt[1]
    end,
})

OrbitTab:CreateSlider({
    Name = "Tween Speed",
    Range = {50, 500},
    Increment = 10,
    Suffix = " studs/s",
    CurrentValue = tweenSpeed,
    Flag = "TweenSpeed",
    Callback = function(v) tweenSpeed = v end,
})

-- =====================
-- SETTINGS TAB
-- =====================
SettingsTab:CreateSection("Wave Configuration")

SettingsTab:CreateSlider({
    Name = "Target Wave",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = TARGET_WAVE,
    Flag = "TargetWave",
    Callback = function(v)
        TARGET_WAVE = v
        hasReset = false
    end,
})

SettingsTab:CreateSlider({
    Name = "Reset Count",
    Range = {1, 10},
    Increment = 1,
    Suffix = "x",
    CurrentValue = RESET_COUNT,
    Flag = "ResetCount",
    Callback = function(v) RESET_COUNT = v end,
})

SettingsTab:CreateSlider({
    Name = "Reset Delay",
    Range = {1, 10},
    Increment = 1,
    Suffix = "s",
    CurrentValue = RESET_DELAY,
    Flag = "ResetDelay",
    Callback = function(v) RESET_DELAY = v end,
})

SettingsTab:CreateSlider({
    Name = "Check Interval",
    Range = {1, 5},
    Increment = 1,
    Suffix = "s",
    CurrentValue = CHECK_INTERVAL,
    Flag = "CheckInterval",
    Callback = function(v) CHECK_INTERVAL = v end,
})

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Danger Zone")

SettingsTab:CreateButton({
    Name = "Unload Script",
    Callback = function()
        isRunning = false
        stopOrbit()
        if monitorThread then task.cancel(monitorThread) end
        Rayfield:Destroy()
    end,
})

-- Init
Rayfield:Notify({
    Title = "Wave Monitor Loaded",
    Content = "Monitor & Crystal Orbit ready!",
    Duration = 4,
    Image = 4483362458,
})
