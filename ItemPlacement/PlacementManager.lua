-- Place this script in StarterPlayerScripts or as a ModuleScript required by a LocalScript

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Path to your placement system modules
local ClientPlacer = require(script.Parent:WaitForChild("ClientPlacer"))
local GetPlot = ReplicatedStorage.Events:WaitForChild("GetPlot")

local currentPlacer = nil

local function tryActivatePlacement(tool)
	if tool and tool:GetAttribute("IsPlaceable") == true then
		if not currentPlacer then
			local plot = GetPlot:InvokeServer()
			currentPlacer = ClientPlacer.new(plot)
		end
	else
		if currentPlacer then
			currentPlacer:Destroy()
			currentPlacer = nil
		end
	end
end

local function onCharacterAdded(char)
	-- Listen for tool equipped/unequipped
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			tryActivatePlacement(child)
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			-- Check if a different placeable is still equipped
			local stillHoldingPlaceable = false
			for _, t in ipairs(char:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("IsPlaceable") == true then
					stillHoldingPlaceable = true
					tryActivatePlacement(t)
					break
				end
			end
			if not stillHoldingPlaceable then
				tryActivatePlacement(nil)
			end
		end
	end)
	-- Also check any tools already equipped at spawn
	local tool = char:FindFirstChildOfClass("Tool")
	tryActivatePlacement(tool)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
