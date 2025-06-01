local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotManager = require(script.Parent.PlotManager)
local PlotStorage = require(script.Parent.PlotStorage)
local GetPlot = ReplicatedStorage.GetPlot
local TryPlace = ReplicatedStorage.TryPlace
local TryDelete = ReplicatedStorage.TryDelete

Players.PlayerAdded:Connect(PlotStorage.Load)
Players.PlayerRemoving:Connect(PlotStorage.Save)
game:BindToClose(PlotStorage.WaitForSave)

GetPlot.OnServerInvoke = PlotManager.GetPlot
TryPlace.OnServerInvoke = PlotManager.Place
TryDelete.OnServerInvoke = PlotManager.Delete