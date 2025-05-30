-- SECURE, DYNAMIC INVENTORY SERVER FRAMEWORK

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Weapon definitions. Add all valid weapon names here.
local WeaponData = {
	["TROY DEFENSE AR"] = {maxAmmo = 30, fireRate = 0.1, damage = 20, headshot = 40},
	["G19 ROLAND SPECIAL"] = {maxAmmo = 15, fireRate = 0.18, damage = 18, headshot = 36},
	-- Add more weapons as needed
}

-- Per-player state: ammo and cooldown per weapon
local playerStates = {}

local function getPlayerState(player)
	if not playerStates[player] then
		playerStates[player] = {
			ammo = {},          -- [weaponName] = currentAmmo
			lastShotTime = {},  -- [weaponName] = lastShotTimestamp
		}
	end
	return playerStates[player]
end

-- Utility: Get equipped weapon Tool and name if valid
local function getEquippedWeapon(player)
	local char = player.Character
	if not char then return nil, nil end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and WeaponData[child.Name] then
			return child, child.Name
		end
	end
	return nil, nil
end

-- SHOOTING
ReplicatedStorage.Events.RequestShoot.OnServerEvent:Connect(function(player, mouseHit)
	local state = getPlayerState(player)
	local char = player.Character
	if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return end

	local tool, weaponName = getEquippedWeapon(player)
	if not weaponName then return end
	local weapon = WeaponData[weaponName]
	if not weapon then return end

	-- Initialize ammo/cooldown if new
	if state.ammo[weaponName] == nil then state.ammo[weaponName] = weapon.maxAmmo end
	if state.lastShotTime[weaponName] == nil then state.lastShotTime[weaponName] = 0 end

	-- Validate cooldown (fireRate)
	local now = tick()
	if now - state.lastShotTime[weaponName] < weapon.fireRate then return end

	-- Validate ammo
	if state.ammo[weaponName] <= 0 then return end

	-- Passed validation
	state.lastShotTime[weaponName] = now
	state.ammo[weaponName] = state.ammo[weaponName] - 1

	-- Bullet logic (replace with your own effects/hit detection as needed)
	local bullet = Instance.new("Part")
	bullet.Name = "Bullet"
	bullet.Size = Vector3.new(0.1, 0.1, 1)
	bullet.CFrame = CFrame.new(char.Head.Position, mouseHit)
	bullet.CanCollide = false
	bullet.Anchored = false
	bullet.BrickColor = BrickColor.new("Cool yellow")
	bullet.Material = Enum.Material.Neon
	bullet.Parent = workspace

	local bodyVelo = Instance.new("BodyVelocity")
	bodyVelo.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelo.Velocity = (mouseHit - char.Head.Position).Unit * 250
	bodyVelo.Parent = bullet

	bullet.Touched:Connect(function(hit)
		if hit.Parent ~= char and hit.Parent:FindFirstChild("Humanoid") then
			local isHead = (hit.Name == "Head")
			local damage = isHead and weapon.headshot or weapon.damage
			hit.Parent.Humanoid:TakeDamage(damage)
			bullet:Destroy()
		end
	end)

	game.Debris:AddItem(bullet, 5)

	-- Notify client for UI/animation
	ReplicatedStorage.Events.ConfirmShoot:FireClient(player, weaponName, state.ammo[weaponName])
end)

-- RELOADING
ReplicatedStorage.Events.RequestReload.OnServerEvent:Connect(function(player)
	local state = getPlayerState(player)
	local _, weaponName = getEquippedWeapon(player)
	if not weaponName then return end
	local weapon = WeaponData[weaponName]
	if not weapon then return end
	state.ammo[weaponName] = weapon.maxAmmo
	ReplicatedStorage.Events.ConfirmReload:FireClient(player, weaponName, state.ammo[weaponName])
end)

-- CLEANUP
Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)
