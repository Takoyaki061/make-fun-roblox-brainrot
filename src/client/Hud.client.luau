-- Hud.client.luau — Brainrot Bazaar: the whole HUD, built in code.
-- A ScreenGui over the 3D world. Nothing sits in the top-left corner —
-- Roblox's menu buttons live there. Text is huge and high-contrast
-- (GothamBold) so it stays readable in screenshots. All numbers refresh
-- from BrainrotState snapshots; feed lines arrive on BrainrotFeed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))
local BrainrotAction = ReplicatedStorage:WaitForChild("BrainrotAction")
local BrainrotState = ReplicatedStorage:WaitForChild("BrainrotState")
local BrainrotFeed = ReplicatedStorage:WaitForChild("BrainrotFeed")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(name, size, position, anchor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 40)
	stroke.Thickness = 2
	stroke.Parent = frame
	return frame
end

local function label(parent, name, size, position, text, textColor, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = textColor
	l.TextStrokeTransparency = 0
	l.TextScaled = false
	l.TextSize = textSize
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

-- ---------------------------------------------------------------------------
-- Top centre: objective panel (460 x 96)
-- ---------------------------------------------------------------------------

local objective = panel("Objective", UDim2.new(0, 460, 0, 96), UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
local objectiveTitle = label(objective, "Title", UDim2.new(1, 0, 0, 48), UDim2.new(0, 0, 0, 6), "COLLECT 6 BRAINROTS", Color3.fromRGB(255, 255, 255), 30)
local objectiveCount = label(objective, "Count", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 52), "0 / 6", Color3.fromRGB(255, 200, 40), 28)

-- ---------------------------------------------------------------------------
-- Top right: money panel (300 x 140)
-- ---------------------------------------------------------------------------

local moneyPanel = panel("Money", UDim2.new(0, 300, 0, 140), UDim2.new(1, -16, 0, 16), Vector2.new(1, 0))
local moneyLabel = label(moneyPanel, "Money", UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 8), "$100", Color3.fromRGB(80, 255, 120), 44)
local incomeLabel = label(moneyPanel, "Income", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 62), "+$0 / sec", Color3.fromRGB(255, 255, 255), 24)
local lockLabel = label(moneyPanel, "Lock", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 92), "", Color3.fromRGB(120, 200, 255), 20)
local progressLabel = label(moneyPanel, "Progress", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 116), "Rebirths 0 • Conveyor Lv 0", Color3.fromRGB(255, 220, 80), 18)

-- ---------------------------------------------------------------------------
-- Bottom centre: hint panel (560 x 52)
-- ---------------------------------------------------------------------------

local hints = panel("Hints", UDim2.new(0, 560, 0, 52), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
label(hints, "HintText", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "E — BUY  •  F — SLAP  •  L — LOCK BASE  •  U — UPGRADE  •  R — REBIRTH", Color3.fromRGB(255, 255, 255), 22)

-- ---------------------------------------------------------------------------
-- Bottom left: feed panel (460 x 60)
-- ---------------------------------------------------------------------------

local feedPanel = panel("Feed", UDim2.new(0, 460, 0, 60), UDim2.new(0, 16, 1, -16), Vector2.new(0, 1))
local feedLabel = label(feedPanel, "FeedText", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), "Welcome to Brainrot Bazaar!", Color3.fromRGB(255, 255, 255), 20)
feedLabel.TextXAlignment = Enum.TextXAlignment.Left
feedLabel.TextWrapped = true

-- ---------------------------------------------------------------------------
-- Bottom right: three big buttons (300 x 180)
-- ---------------------------------------------------------------------------

local buttons = panel("Buttons", UDim2.new(0, 300, 0, 180), UDim2.new(1, -16, 1, -16), Vector2.new(1, 1))

local function actionButton(name, position, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, -16, 0, 50)
	button.Position = position
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0
	button.TextSize = 24
	button.Font = Enum.Font.GothamBold
	button.Parent = buttons
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

local lockButton = actionButton("LockButton", UDim2.new(0, 8, 0, 8), "LOCK BASE (L)", Color3.fromRGB(60, 120, 255))
local upgradeButton = actionButton("UpgradeButton", UDim2.new(0, 8, 0, 66), "UPGRADE ($5,000)", Color3.fromRGB(200, 160, 40))
local rebirthButton = actionButton("RebirthButton", UDim2.new(0, 8, 0, 124), "REBIRTH ($25,000)", Color3.fromRGB(160, 60, 200))

lockButton.MouseButton1Click:Connect(function()
	BrainrotAction:FireServer("Lock")
end)
upgradeButton.MouseButton1Click:Connect(function()
	BrainrotAction:FireServer("Upgrade")
end)
rebirthButton.MouseButton1Click:Connect(function()
	BrainrotAction:FireServer("Rebirth")
end)

-- ---------------------------------------------------------------------------
-- Live updates
-- ---------------------------------------------------------------------------

local latest = nil

local function refresh()
	if not latest then
		return
	end
	moneyLabel.Text = Cast.formatMoney(latest.money)
	incomeLabel.Text = "+" .. Cast.formatMoney(latest.income) .. " / sec"
	if latest.lockLeft > 0 then
		lockLabel.Text = "BASE LOCKED — " .. latest.lockLeft .. "s"
		lockLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	elseif latest.lockCooldownLeft > 0 then
		lockLabel.Text = "Lock recharging — " .. latest.lockCooldownLeft .. "s"
		lockLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	else
		lockLabel.Text = "Base unlocked — press L to lock"
		lockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	progressLabel.Text = "Rebirths " .. latest.rebirths .. " • Conveyor Lv " .. latest.upgrade
	if latest.owned >= latest.slots then
		objectiveTitle.Text = "BASE FULL — REBIRTH!"
		objectiveTitle.TextColor3 = Color3.fromRGB(255, 200, 40)
	else
		objectiveTitle.Text = "COLLECT " .. latest.slots .. " BRAINROTS"
		objectiveTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	objectiveCount.Text = latest.owned .. " / " .. latest.slots
	upgradeButton.Text = "UPGRADE (" .. Cast.formatMoney(latest.upgradeCost) .. ")"
	rebirthButton.Text = "REBIRTH (" .. Cast.formatMoney(latest.rebirthCost) .. ")"
end

BrainrotState.OnClientEvent:Connect(function(snapshot)
	latest = snapshot
	refresh()
end)

BrainrotFeed.OnClientEvent:Connect(function(text)
	feedLabel.Text = text
end)
