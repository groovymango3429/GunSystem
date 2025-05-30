--[[
  Secure Server Framework for Gun System
  - All weapon logic, validation, and damage is handled here
  - Never trusts the client for ammo, rate, or damage
  - Uses server-side hitscan (raycast)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WeaponModules = {
	["TROY DEFENSE AR"] = require(ReplicatedStorage.Modules["TROY DEFENSE AR"]),
	["G19 ROLAND SPECIAL"] = require(ReplicatedStorage.Modules["G19 ROLAND SPECIAL"]),
}

local PlayerWeaponState = {}

local function getEquippedWeaponName(player)
	local char = player.Character
	if not char then return nil end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and WeaponModules[tool.Name] then
			return tool.Name
		end
	end
	return nil
end

local function getWeaponState(player, weaponName)
	if not PlayerWeaponState[player] then PlayerWeaponState[player] = {} end
	local state = PlayerWeaponState[player][weaponName]
	if not state then
		local config = WeaponModules[weaponName]
		state = {
			ammo = config and config.ammo or 0,
			lastFire = 0,
			reloading = false,
		}
		PlayerWeaponState[player][weaponName] = state
	end
	return state
end

Players.PlayerAdded:Connect(function(player)
	PlayerWeaponState[player] = {}
	player.CharacterAdded:Connect(function()
		PlayerWeaponState[player] = {}
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerWeaponState[player] = nil
end)

ReplicatedStorage.Events.Shoot.OnServerEvent:Connect(function(player, aimPos)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local weaponName = getEquippedWeaponName(player)
	if not weaponName then return end
	local config = WeaponModules[weaponName]
	if not config then return end

	local state = getWeaponState(player, weaponName)
	if state.reloading then return end

	local now = tick()
	if now - state.lastFire < config.fireRate then return end
	if state.ammo <= 0 then return end

	if typeof(aimPos) ~= "Vector3" then return end
	local muzzle = char:FindFirstChild("Muzzle", true)
	local origin = (muzzle and muzzle.Position) or root.Position
	if (aimPos - origin).Magnitude > 1000 then return end

	local direction = (aimPos - origin).Unit * 500
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {char}
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	local result = workspace:Raycast(origin, direction, rayParams)

	if result and result.Instance and result.Instance.Parent then
		local humanoid = result.Instance.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid ~= char:FindFirstChildOfClass("Humanoid") then
			local isHeadshot = (result.Instance.Name == "Head")
			humanoid:TakeDamage(isHeadshot and config.headshot or config.damage)
		end
	end

	-- Play fire sound (optional, or inform client for FX)
	local fireSound = Instance.new("Sound")
	fireSound.SoundId = config.fireSound.SoundId
	fireSound.Volume = config.fireSound.Volume
	fireSound.Parent = char.UpperTorso or char.PrimaryPart
	fireSound:Play()
	game:GetService("Debris"):AddItem(fireSound, 2)

	state.ammo = state.ammo - 1
	state.lastFire = now
end)

ReplicatedStorage.Events.Reload.OnServerEvent:Connect(function(player)
	local weaponName = getEquippedWeaponName(player)
	if not weaponName then return end
	local config = WeaponModules[weaponName]
	if not config then return end

	local state = getWeaponState(player, weaponName)
	if state.reloading then return end
	state.reloading = true

	task.spawn(function()
		task.wait(config.reloadTime)
		state.ammo = config.maxAmmo
		state.reloading = false
	end)
end)

ReplicatedStorage.Events.QueryAmmo.OnServerInvoke = function(player)
	local weaponName = getEquippedWeaponName(player)
	if not weaponName then return 0, 0 end
	local config = WeaponModules[weaponName]
	local state = getWeaponState(player, weaponName)
	return state.ammo, config.maxAmmo
end
