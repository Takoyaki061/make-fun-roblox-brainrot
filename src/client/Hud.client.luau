-- Hud.client.luau
-- Builds the whole HUD in code (a ScreenGui, no top-left corner --
-- Roblox's menu buttons live there). Text is huge and high-contrast
-- (GothamBold) so it stays readable in screenshots.
--
--   Top centre:  objective panel (what to do next)
--   Top right:   money panel (cash, income, lock, progression)
--   Bottom centre: hint panel (the keys)
--   Bottom left: feed panel (the latest announcement)
--   Bottom right: action buttons (Lock / Upgrade / Rebirth)
--
-- Every number refreshes from BrainrotState snapshots; feed lines
-- arrive on BrainrotFeed. The client never computes money itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))
local StateRemote = ReplicatedStorage:WaitForChild("BrainrotState")
local FeedRemote = ReplicatedStorage:WaitForChild("BrainrotFeed")
local ActionRemote = ReplicatedStorage:WaitForChild("BrainrotAction")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(name, size, anchor, position, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.6
	stroke.Thickness = 2
	stroke.Parent = frame
	return frame
end

local function label(parent, name, size, position, text, textColor, textSize)
	local lab = Instance.new("TextLabel")
	lab.Name = name
	lab.Size = size
	lab.Position = position
	lab.BackgroundTransparency = 1
	lab.Text = text
	lab.TextColor3 = textColor
	lab.TextScaled = false
	lab.TextSize = textSize
	lab.Font = Enum.Font.GothamBold
	lab.TextStrokeTransparency = 0.2
	lab.Parent = parent
	return lab
end

-- ---------------------------------------------------------------------------
-- Top centre: objective
-- ---------------------------------------------------------------------------

local objectivePanel = panel("ObjectivePanel",
	UDim2.fromOffset(460, 96), Vector2.new(0.5, 0),
	UDim2.new(0.5, 0, 0, 16), Color3.fromRGB(40, 40, 60))
local objectiveTitle = label(objectivePanel, "ObjectiveTitle",
	UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0.05, 0),
	"COLLECT 6 BRAINROTS", Color3.fromRGB(255, 220, 100), 32)
local objectiveCount = label(objectivePanel, "ObjectiveCount",
	UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.55, 0),
	"0 / 6", Color3.fromRGB(255, 255, 255), 28)

-- ---------------------------------------------------------------------------
-- Top right: money
-- ---------------------------------------------------------------------------

local moneyPanel = panel("MoneyPanel",
	UDim2.fromOffset(300, 140), Vector2.new(1, 0),
	UDim2.new(1, -16, 0, 16), Color3.fromRGB(20, 60, 30))
local moneyLabel = label(moneyPanel, "Money",
	UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.04, 0),
	"$100", Color3.fromRGB(80, 255, 120), 44)
local incomeLabel = label(moneyPanel, "Income",
	UDim2.new(1, 0, 0.22, 0), UDim2.new(0, 0, 0.44, 0),
	"+$0 / sec", Color3.fromRGB(180, 255, 180), 24)
local lockLabel = label(moneyPanel, "Lock",
	UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.66, 0),
	"Base unlocked", Color3.fromRGB(255, 255, 255), 20)
local progressLabel = label(moneyPanel, "Progress",
	UDim2.new(1, 0, 0.16, 0), UDim2.new(0, 0, 0.84, 0),
	"Rebirths 0 • Conveyor Lv 0", Color3.fromRGB(200, 220, 255), 18)

-- ---------------------------------------------------------------------------
-- Bottom centre: hints
-- ---------------------------------------------------------------------------

local hintPanel = panel("HintPanel",
	UDim2.fromOffset(560, 52), Vector2.new(0.5, 1),
	UDim2.new(0.5, 0, 1, -16), Color3.fromRGB(40, 40, 60))
label(hintPanel, "Hint",
	UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
	"E — BUY  •  F — SLAP  •  L — LOCK BASE  •  U — UPGRADE  •  R — REBIRTH",
	Color3.fromRGB(255, 255, 255), 22)

-- ---------------------------------------------------------------------------
-- Bottom left: feed
-- ---------------------------------------------------------------------------

local feedPanel = panel("FeedPanel",
	UDim2.fromOffset(460, 60), Vector2.new(0, 1),
	UDim2.new(0, 16, 1, -16), Color3.fromRGB(30, 30, 45))
local feedLabel = label(feedPanel, "Feed",
	UDim2.new(1, -20, 1, -10), UDim2.new(0, 10, 0, 5),
	"Welcome to Brainrot Bazaar! Buy brainrots off the conveyor.",
	Color3.fromRGB(255, 255, 255), 20)
feedLabel.TextWrapped = true

-- ---------------------------------------------------------------------------
-- Bottom right: action buttons
-- ---------------------------------------------------------------------------

local buttonPanel = panel("ButtonPanel",
	UDim2.fromOffset(300, 180), Vector2.new(1, 1),
	UDim2.new(1, -16, 1, -16), Color3.fromRGB(30, 30, 45))

local function actionButton(name, text, color, y)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, -20, 0, 48)
	button.Position = UDim2.new(0, 10, 0, y)
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 24
	button.Font = Enum.Font.GothamBold
	button.TextStrokeTransparency = 0.2
	button.Parent = buttonPanel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

local lockButton = actionButton("LockButton", "LOCK BASE  (L)", Color3.fromRGB(60, 120, 220), 10)
local upgradeButton = actionButton("UpgradeButton", "UPGRADE  ($5,000)", Color3.fromRGB(220, 160, 40), 66)
local rebirthButton = actionButton("RebirthButton", "REBIRTH  ($25,000)", Color3.fromRGB(200, 60, 120), 122)

lockButton.MouseButton1Click:Connect(function()
	ActionRemote:FireServer("Lock")
end)
upgradeButton.MouseButton1Click:Connect(function()
	ActionRemote:FireServer("Upgrade")
end)
rebirthButton.MouseButton1Click:Connect(function()
	ActionRemote:FireServer("Rebirth")
end)

-- ---------------------------------------------------------------------------
-- Updates
-- ---------------------------------------------------------------------------

local function refresh(snapshot)
	if not snapshot then
		return
	end
	moneyLabel.Text = Cast.formatMoney(snapshot.money)
	incomeLabel.Text = "+" .. Cast.formatMoney(snapshot.income) .. " / sec"
	if snapshot.lockLeft > 0 then
		lockLabel.Text = "Base LOCKED: " .. math.ceil(snapshot.lockLeft) .. "s left"
		lockLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	elseif snapshot.lockCooldownLeft > 0 then
		lockLabel.Text = "Lock recharging: " .. math.ceil(snapshot.lockCooldownLeft) .. "s"
		lockLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	else
		lockLabel.Text = "Base unlocked"
		lockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	progressLabel.Text = "Rebirths " .. snapshot.rebirths .. " • Conveyor Lv " .. snapshot.upgrade

	if snapshot.owned >= snapshot.slots then
		objectiveTitle.Text = "BASE FULL — REBIRTH!"
		objectiveTitle.TextColor3 = Color3.fromRGB(255, 120, 140)
	else
		objectiveTitle.Text = "COLLECT " .. snapshot.slots .. " BRAINROTS"
		objectiveTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	end
	objectiveCount.Text = snapshot.owned .. " / " .. snapshot.slots

	upgradeButton.Text = "UPGRADE  (" .. Cast.formatMoney(snapshot.upgradeCost) .. ")"
	rebirthButton.Text = "REBIRTH  (" .. Cast.formatMoney(snapshot.rebirthCost) .. ")"
end

StateRemote.OnClientEvent:Connect(refresh)

FeedRemote.OnClientEvent:Connect(function(message)
	feedLabel.Text = message
end)
