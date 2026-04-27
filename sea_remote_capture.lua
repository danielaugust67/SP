-- Auto Reset Wave 51 (Minimal UI)
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local TARGET_WAVE = 51
local RESET_COUNT = 4
local CHECK_INTERVAL = 1
local RESET_DELAY = 2

local isRunning = true
local lastResetWave = -1

-- =====================
-- MINIMAL STATUS UI
-- =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WaveResetUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 160, 0, 54)
frame.Position = UDim2.new(0, 8, 0, 8)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local waveLabel = Instance.new("TextLabel")
waveLabel.Size = UDim2.new(1, -8, 0, 24)
waveLabel.Position = UDim2.new(0, 4, 0, 2)
waveLabel.BackgroundTransparency = 1
waveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
waveLabel.TextSize = 13
waveLabel.Font = Enum.Font.GothamBold
waveLabel.TextXAlignment = Enum.TextXAlignment.Left
waveLabel.Text = "Wave: --"
waveLabel.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -8, 0, 22)
statusLabel.Position = UDim2.new(0, 4, 0, 26)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Status: Watching..."
statusLabel.Parent = frame

-- =====================
-- HELPERS
-- =====================
local function getWaveFrame()
    local gui = localPlayer.PlayerGui:FindFirstChild("DungeonUI")
    if not gui then return nil end
    local content = gui:FindFirstChild("ContentFrame")
    if not content then return nil end
    return content:FindFirstChild("WaveFrame")
end

local function getCurrentWave()
    local wf = getWaveFrame()
    if not wf then return nil end
    for _, child in ipairs(wf:GetDescendants()) do
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
-- MAIN LOOP
-- =====================
task.spawn(function()
    while isRunning do
        task.wait(CHECK_INTERVAL)
        local wave = getCurrentWave()

        if wave then
            waveLabel.Text = "Wave: " .. wave

            if wave >= TARGET_WAVE and wave ~= lastResetWave then
                lastResetWave = wave
                for i = 1, RESET_COUNT do
                    if not isRunning then break end
                    statusLabel.Text = string.format("Resetting %d/%d...", i, RESET_COUNT)
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                    resetCharacter()
                    task.wait(RESET_DELAY)
                end
                statusLabel.Text = "Status: Watching..."
                statusLabel.TextColor3 = Color3.fromRGB(180, 255, 180)

            elseif wave < TARGET_WAVE then
                lastResetWave = -1
                statusLabel.Text = "Status: Watching..."
                statusLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
            end
        else
            waveLabel.Text = "Wave: N/A"
            statusLabel.Text = "WaveFrame not found"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
end)
