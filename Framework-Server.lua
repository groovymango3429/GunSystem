-- SERVER: All core logic and validation is here. Never trust the client!

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Example weapon data. You should expand with your real data.
local WeaponData = {
	["TROY DEFENSE AR"] = {
		maxAmmo = 30,
		fireRate = 0.1, -- seconds per shot
		damage = 20,
		headshot = 40,
	},
	["G19 ROLAND SPECIAL"] = {
		maxAmmo = 15,
		fireRate = 0.18,
		damage = 18,
		headshot = 36,
	},
}

-- Default inventory (MUST match client order)
local DefaultInventory = {
	"TROY DEFENSE AR",
	"G19 ROLAND SPECIAL",
	"Knife",
	"Frag",
}

-- Per-player state
local playerStates = {}

local function getPlayerState(plr)
	if not playerStates[plr] then
		playerStates[plr] = {
			inventory = table.clone(DefaultInventory),
			currentSlot = 1,
			ammo = {},
			lastShotTime = {},
		}
		for _, weaponName in ipairs(DefaultInventory) do
			local data = WeaponData[weaponName]
			playerStates[plr].ammo[weaponName] = data and data.maxAmmo or 0
			playerStates[plr].lastShotTime[weaponName] = 0
		end
	end
	return playerStates[plr]
end

ReplicatedStorage.Events.LoadSlot.OnServerEvent:Connect(function(player, weaponName)
	local state = getPlayerState(player)
	for i, name in ipairs(state.inventory) do
		if name == weaponName then
			state.currentSlot = i
			break
		end
	end
end)

ReplicatedStorage.Events.RequestShoot.OnServerEvent:Connect(function(player, mouseHit)
	local state = getPlayerState(player)
	local weaponName = state.inventory[state.currentSlot]
	local weapon = WeaponData[weaponName]
	if not weapon then return end

	-- Validate cooldown
	local now = tick()
	if now - state.lastShotTime[weaponName] < weapon.fireRate then return end

	-- Validate ammo
	if state.ammo[weaponName] <= 0 then return end

	-- Validate character alive
	local char = player.Character
	if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return end

	-- Passed validation
	state.lastShotTime[weaponName] = now
	state.ammo[weaponName] = state.ammo[weaponName] - 1

	-- Bullet spawning and hit detection
	local bullet = Instance.new("Part")
	bullet.Name = "Bullet"
	bullet.Size = Vector3.new(.1, .1, 1)
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
	ReplicatedStorage.Events.ConfirmShoot:FireClient(player, state.currentSlot, state.ammo[weaponName])
end)

ReplicatedStorage.Events.RequestReload.OnServerEvent:Connect(function(player)
	local state = getPlayerState(player)
	local weaponName = state.inventory[state.currentSlot]
	local weapon = WeaponData[weaponName]
	if not weapon then return end
	state.ammo[weaponName] = weapon.maxAmmo
	ReplicatedStorage.Events.ConfirmReload:FireClient(player, state.currentSlot, state.ammo[weaponName])
end)

Players.PlayerRemoving:Connect(function(plr)
	playerStates[plr] = nil
end)
