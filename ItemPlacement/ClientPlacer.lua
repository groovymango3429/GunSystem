local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:WaitForChild("Events")
local boxOutlineTemplate = ReplicatedStorage.BoxOutline
local placeableObjects = ReplicatedStorage:WaitForChild("PlaceableObjects")
local tryPlace = Events:WaitForChild("TryPlace")
local tryDelete = Events:WaitForChild("TryDelete")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local PlacementValidator = require(ReplicatedStorage.PlacementValidator)

local PREVIEW_RENDER = "RenderPreview"
local PLACE_ACTION = "Place"
local ROTATE_ACTION = "Rotate"
local DELETE_ACTION = "Delete"
local CYCLE_ACTION = "Cycle"
local SNAP_ACTION = "Snap"

local function snapToGrid(pos, gridSize)
	return Vector3.new(
		math.round(pos.X / gridSize) * gridSize,
		pos.Y,
		math.round(pos.Z / gridSize) * gridSize
	)
end

local function castMouse()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	-- Set up filter to ignore the player's own character
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	-- Assuming 'game.Players.LocalPlayer' is accessible here, otherwise pass it in
	raycastParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}

	return workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
end

local ClientPlacer = {}
ClientPlacer.__index = ClientPlacer

function ClientPlacer.new(plot: Model)
	local self = setmetatable({
		Plot = plot,	
		Preview = nil,
		PreviewIndex = 1,
		GridSize = 0,
		Rotation = 0,
	}, ClientPlacer)
	
	self:InitiateRenderPreview()
	
	ContextActionService:BindAction(PLACE_ACTION, function(...) self:TryPlaceBlock(...) end, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction(ROTATE_ACTION, function(...) self:RotateBlock(...) end, false, Enum.KeyCode.R)
	ContextActionService:BindAction(DELETE_ACTION, function(...) self:TryDeleteBlock(...) end, false, Enum.KeyCode.X)
	ContextActionService:BindAction(SNAP_ACTION, function(...) self:ToggleGrid(...) end, false, Enum.KeyCode.G)
	ContextActionService:BindAction(CYCLE_ACTION, function(...) self:CycleObject(...) end, false, Enum.KeyCode.E, Enum.KeyCode.Q)
	return self
end

function ClientPlacer:InitiateRenderPreview()
	self:PreparePreviewModel(placeableObjects:GetChildren()[self.PreviewIndex])
	RunService:BindToRenderStep(PREVIEW_RENDER, Enum.RenderPriority.Camera.Value, function(...) self:RenderPreview(...) end)
end

function ClientPlacer:PreparePreviewModel(model: Model)
	if self.Preview then 
		self.Preview:Destroy()
	end
	
	self.Preview = model:Clone()
	local boxOutline = boxOutlineTemplate:Clone()
	boxOutline.Adornee = self.Preview 
	boxOutline.Parent = self.Preview
	
	for _, part in self.Preview:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.Transparency = 0.5
		end
	end
	
	self.Preview.Parent = workspace
end

function ClientPlacer:RenderPreview()
	local cast = castMouse()
	if cast and cast.Position then
		local position = if self.GridSize > 0 then snapToGrid(cast.Position, self.GridSize) else cast.Position		
		local cf = CFrame.new(position) * CFrame.Angles(0, self.Rotation, 0)
		self.Preview:PivotTo(cf)
		
		local size = self.Preview:GetExtentsSize()
		self.Preview.BoxOutline.Color3 = 
			if PlacementValidator.WithinBounds(self.Plot, size, cf) 
			and PlacementValidator.NotIntersectingObjects(self.Plot, size, cf)
			then Color3.new(0, 0.666667, 1) 
			else Color3.new(1, 0, 0)
	end
end

function ClientPlacer:TryPlaceBlock(_, state, _)
	if state ~= Enum.UserInputState.Begin then
		return
	end
	
	local success = tryPlace:InvokeServer(self.Preview.Name, self.Preview:GetPivot())
end

function ClientPlacer:RotateBlock(_, state, _)
	if state == Enum.UserInputState.Begin then 
		self.Rotation += math.pi / 2 -- 90 degrees 
	end
end

function ClientPlacer:TryDeleteBlock(_, state, _)
	if state == Enum.UserInputState.Begin then 
		local cast = castMouse()
		if cast and cast.Instance then 
			local success = tryDelete:InvokeServer(cast.Instance)
		end
	end
end

function ClientPlacer:CycleObject(_, state, obj)
	if state == Enum.UserInputState.Begin then
		local objects = placeableObjects:GetChildren()
		local direction = if obj.KeyCode == Enum.KeyCode.E then 1 else -1
		self.PreviewIndex = (self.PreviewIndex - 1 + direction) % #objects + 1
		self:PreparePreviewModel(objects[self.PreviewIndex])
	end
end

function ClientPlacer:ToggleGrid(_, state, _)
	if state == Enum.UserInputState.Begin then 
		self.GridSize = if self.GridSize == 0 then 4 else 0
	end
end

function ClientPlacer:Destroy()
	if self.Preview then 
		self.Preview:Destroy()
	end
	RunService:UnbindFromRenderStep(PREVIEW_RENDER)
	
	ContextActionService:UnbindAction(PLACE_ACTION)
	ContextActionService:UnbindAction(ROTATE_ACTION)
	ContextActionService:UnbindAction(DELETE_ACTION)
	ContextActionService:UnbindAction(CYCLE_ACTION)
	ContextActionService:UnbindAction(SNAP_ACTION)
end

return ClientPlacer
