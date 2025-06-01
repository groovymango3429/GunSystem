local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local GetPlot = ReplicatedStorage:WaitForChild("GetPlot")
local ClientPlacer = require(script.Parent:WaitForChild("ClientPlacer"))

local placer = nil

local function setPlacementActive(_, state, _)
	if state ~= Enum.UserInputState.Begin then 
		return
	end
	
	if not placer then 
		local plot = GetPlot:InvokeServer()
		placer = ClientPlacer.new(plot)
	else 
		placer:Destroy()
		placer = nil
	end
end

ContextActionService:BindAction("ActivatePlacement", setPlacementActive, false, Enum.KeyCode.B)