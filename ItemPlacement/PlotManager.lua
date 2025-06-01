local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plotTemplate = game:GetService("ServerStorage").Plot
local PlotSpawnPool = require(script.Parent.PlotSpawnPool)
local placeableObjects = ReplicatedStorage.PlaceableObjects
local PlacementValidator = require(ReplicatedStorage.PlacementValidator)

local PlotManager = {}

local plots: {Model} = {}

function PlotManager.SpawnPlot(player: Player): Model
	local plot = plotTemplate:Clone()
	plot.Name = `{player.Name}'s Plot`
	plot:PivotTo(PlotSpawnPool.Get(player).CFrame)
	plot.Parent = workspace.Plots
	plots[player.UserId] = plot
	return plot
end

function PlotManager.Place(player: Player, name: string, targetCF: CFrame): boolean
	local object = placeableObjects:FindFirstChild(name)
	local plot = plots[player.UserId]
	
	if not object or not plot then 
		return false
	end
	local objectSize = object:GetExtentsSize()
	if not PlacementValidator.WithinBounds(plot, objectSize, targetCF)  
		or not PlacementValidator.NotIntersectingObjects(plot, objectSize, targetCF)
	then
		return false 
	end
	
	local newObject = object:Clone()
	newObject:PivotTo(targetCF)
	newObject.Parent = plot.Objects
	return true 
end

function PlotManager.Delete(player: Player, object: Part): boolean
	local plot = plots[player.UserId]
	if not plot or not object 
		or not object:IsDescendantOf(plot.Objects)	
	then
		return false
	end
	
	local actualObject = object
	while actualObject.Parent ~= plot.Objects do
		actualObject = actualObject:FindFirstAncestorWhichIsA("Model")
	end
	actualObject:Destroy()
	return true
end

function PlotManager.GetPlot(player: Player): Model
	return plots[player.UserId]
end

return PlotManager
