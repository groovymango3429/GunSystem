--[[ 
  SECURE CLIENT FRAMEWORK 
  All sensitive logic (ammo, firing rate, cooldown, damage, bullet physics) is handled on the server!
  The client only requests actions and handles visuals/UI.
]]

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local camera = game.Workspace.CurrentCamera
local mouse = player:GetMouse()

local playerGui = player.PlayerGui
local gui = playerGui:WaitForChild("Inventory")
local invF = gui:WaitForChild("Inventory")
local hud = player.PlayerGui:WaitForChild("HUD")

-- Visual/animation state
local isAiming, isShooting, isReloading, isSprinting = false, false, false, false
local canShoot, canInspect = true, true
local debounce = false

local bobOffset = CFrame.new()
local currentSwayAMT = -.3
local swayAMT = -.3
local aimSwayAMT = .2
local swayCF = CFrame.new()
local lastCameraCF = CFrame.new()
local aimCF = CFrame.new()

local fireAnim, equipAnim, deequipAnim, emptyfireAnim, reloadAnim, emptyReloadAnim, InspectAnim, idleAnim = nil, nil, nil, nil, nil, nil, nil, nil

local framework = {
	inventory = {
		"TROY DEFENSE AR";
		"G19 ROLAND SPECIAL";
		"Knife";
		"Frag";
	},
	module = nil,
	viewmodel = nil,
	currentSlot = 1
}

-- Loads weapon visuals/animations (ammo and logic handled by server)
function loadSlot(Item)
	local viewmodelFolder = game.ReplicatedStorage.Viewmodels
	local moduleFolder = game.ReplicatedStorage.Modules

	canShoot = false
	canInspect = false

	for i,v in pairs(camera:GetChildren()) do
		if v:IsA("Model") then
			if deequipAnim then deequipAnim:Play() end
			repeat task.wait() until not (deequipAnim and deequipAnim.IsPlaying)
			v:Destroy()
		end
	end

	if moduleFolder:FindFirstChild(Item) then
		framework.module = require(moduleFolder:FindFirstChild(Item))

		if viewmodelFolder:FindFirstChild(Item) then
			framework.viewmodel = viewmodelFolder:FindFirstChild(Item):Clone()
			framework.viewmodel.Parent = camera

			-- Setup Animations
			local function setupAnim(animName, animId)
				if animId then
					local anim = Instance.new("Animation")
					anim.Parent = framework.viewmodel
					anim.Name = animName
					anim.AnimationId = animId
					return framework.viewmodel.AnimationController.Animator:LoadAnimation(anim)
				end
			end

			fireAnim = setupAnim("Fire", framework.module.fireAnim)
			emptyfireAnim = setupAnim("EmptyFire", framework.module.emptyfireAnim)
			equipAnim = setupAnim("Equip", framework.module.equipAnim)
			deequipAnim = setupAnim("Deequip", framework.module.deequipAnim)
			reloadAnim = setupAnim("Reload", framework.module.reloadAnim)
			emptyReloadAnim = setupAnim("EmptyReload", framework.module.emptyReloadAnim)
			InspectAnim = setupAnim("Inspect", framework.module.InspectAnim)
			idleAnim = setupAnim("Idle", framework.module.idleAnim)

			-- Hide parts for animation transition, then reveal
			for i, v in pairs(framework.viewmodel:GetDescendants()) do
				if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("BasePart") then
					v.Transparency = 1
				end
			end
			equipAnim:Play()
			task.wait(.1)
			for i, v in pairs(framework.viewmodel:GetDescendants()) do
				if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("BasePart") then
					if not (v.Name == "Main" or v.Name == "Muzzle" or v.Name == "FakeCamera" or v.Name == "AimPart" or v.Name == "HumanoidRootPart") then
						v.Transparency = 0
					end
				end
			end
			canShoot = true
			canInspect = true
		end
	end

	-- Notify server of weapon swap for sound setup, etc.
	game.ReplicatedStorage.Events.LoadSlot:FireServer(Item)
end

-- Requests to shoot; server will validate and process
function Shoot()
	if not (character and framework.viewmodel and framework.module and not isReloading and canShoot and not invF.Visible and not debounce) then return end
	debounce = true
	game.ReplicatedStorage.Events.RequestShoot:FireServer(mouse.Hit.p)
end

function Inspect()
	if canInspect and InspectAnim then
		idleAnim:Stop()
		InspectAnim:Play()
		repeat task.wait() until InspectAnim.IsPlaying == false
	end
end

function Reload()
	if not isReloading then
		canShoot = false
		canInspect = false
		isReloading = true
		if reloadAnim then reloadAnim:Play() end
		game.ReplicatedStorage.Events.RequestReload:FireServer()
	end
end

-- Animate camera shake for realism
local oldCamCF = CFrame.new()
function updateCameraShake()
	if framework.viewmodel and framework.viewmodel:FindFirstChild("FakeCamera") and framework.viewmodel.PrimaryPart then
		local newCamCF = framework.viewmodel.FakeCamera.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
		camera.CFrame = camera.CFrame * newCamCF:ToObjectSpace(oldCamCF)
		oldCamCF = newCamCF
	end
end

-- Update HUD ammo and visuals from server confirmation
game.ReplicatedStorage.Events.ConfirmShoot.OnClientEvent:Connect(function(slot, ammo)
	if framework.module then
		if ammo == 0 and emptyfireAnim then
			fireAnim:Stop()
			emptyfireAnim:Play()
		elseif fireAnim then
			emptyfireAnim:Stop()
			fireAnim:Play()
		end
	end
	if hud then
		hud.Ammo.Text = ammo
		hud.GunName.Text = framework.inventory[slot]
	end
	debounce = false
end)

game.ReplicatedStorage.Events.ConfirmReload.OnClientEvent:Connect(function(slot, ammo)
	if reloadAnim then
		reloadAnim:Play()
		task.wait(framework.module and framework.module.reloadTime or 1)
	end
	if hud then
		hud.Ammo.Text = ammo
	end
	canShoot = true
	canInspect = true
	isReloading = false
	debounce = false
end)

-- Maintain visuals/HUD
RunService.RenderStepped:Connect(function()
	mouse.TargetFilter = framework.viewmodel
	if humanoid then
		local rot = camera.CFrame:ToObjectSpace(lastCameraCF)
		local X,Y,Z = rot:ToOrientation()
		swayCF = swayCF:Lerp(CFrame.Angles(math.sin(X) * currentSwayAMT, math.sin(Y) * currentSwayAMT, 0), .1)
		lastCameraCF = camera.CFrame

		if hud and framework.viewmodel and framework.module then
			hud.GunName.Text = framework.inventory[framework.currentSlot]
			-- Ammo is set by server events
		end

		-- Bobbing, aiming, sprinting, etc.
		if framework.viewmodel ~= nil and framework.module ~= nil then
			if humanoid.MoveDirection.Magnitude > 0 then
				if humanoid.WalkSpeed == 17 then
					bobOffset = bobOffset:Lerp(CFrame.new(math.cos(tick() * 4) * .05, -humanoid.CameraOffset.Y/3, -humanoid.CameraOffset.Z/3) * CFrame.Angles(0, math.sin(tick() * -4) * -.05, math.cos(tick() * -4) * -.05), .1)
					isSprinting = false
				elseif humanoid.WalkSpeed == 30 then
					bobOffset = bobOffset:Lerp(CFrame.new(math.cos(tick() * 8) * .1, -humanoid.CameraOffset.Y/3, -humanoid.CameraOffset.Z/3) * CFrame.Angles(0, math.sin(tick() * -8) * -.1, math.cos(tick() * -8) * -.1), .1)
					isSprinting = true
				end
			else
				bobOffset = bobOffset:Lerp(CFrame.new(0, -humanoid.CameraOffset.Y/3, 0), .1)
				isSprinting = false
			end
		end

		for i, v in pairs(camera:GetChildren()) do
			if v:IsA("Model") then
				v:SetPrimaryPartCFrame(camera.CFrame * swayCF * aimCF * bobOffset)
				updateCameraShake()
				if idleAnim and not (fireAnim and fireAnim.IsPlaying or emptyfireAnim and emptyfireAnim.IsPlaying or emptyReloadAnim and emptyReloadAnim.IsPlaying or reloadAnim and reloadAnim.IsPlaying or InspectAnim and InspectAnim.IsPlaying or equipAnim and equipAnim.IsPlaying or deequipAnim and deequipAnim.IsPlaying) then
					if not idleAnim.IsPlaying then
						idleAnim:Play()
					end
				elseif idleAnim then
					idleAnim:Stop()
				end
			end
		end

		if framework.viewmodel ~= nil then
			if isAiming and framework.module and framework.module.canAim and not isSprinting then
				local offset = framework.viewmodel.AimPart.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
				aimCF = aimCF:Lerp(offset, framework.module.aimSmooth)
				currentSwayAMT = aimSwayAMT
			else
				local offset = CFrame.new()
				aimCF = aimCF:Lerp(offset, framework.module and framework.module.aimSmooth or 0.2)
				currentSwayAMT = swayAMT
			end
		end
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.One then
		if framework.currentSlot ~= 1 and not isReloading then
			loadSlot(framework.inventory[1])
			framework.currentSlot = 1
		end
	end
	if input.KeyCode == Enum.KeyCode.Two then
		if framework.currentSlot ~= 2 and not isReloading then
			loadSlot(framework.inventory[2])
			framework.currentSlot = 2
		end
	end
	if input.KeyCode == Enum.KeyCode.Three then
		if framework.currentSlot ~= 3 and not isReloading then
			loadSlot(framework.inventory[3])
			framework.currentSlot = 3
		end
	end
	if input.KeyCode == Enum.KeyCode.Four then
		if framework.currentSlot ~= 4 and not isReloading then
			loadSlot(framework.inventory[4])
			framework.currentSlot = 4
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = true
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Shoot()
	end
	if input.KeyCode == Enum.KeyCode.R then
		Reload()
	end
	if input.KeyCode == Enum.KeyCode.F then
		Inspect()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = false
	end
end)

game.ReplicatedStorage.Events.PlayerAdded.OnClientEvent:Connect(function(ply, char)
	player = game.Players.LocalPlayer
	character = player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	framework.inventory[1] = "TROY DEFENSE AR"
	framework.inventory[2] = "G19 ROLAND SPECIAL"
	framework.inventory[3] = "Knife"
	framework.inventory[4] = "Frag"
	framework.module = nil
	framework.viewmodel = nil
	framework.currentSlot = 1
	loadSlot(framework.inventory[1])
	humanoid.Died:Connect(function()
		if framework.viewmodel then
			framework.viewmodel:Destroy()
		end
		player, character, humanoid = nil, nil, nil
		aimCF = CFrame.new()
		isAiming, isShooting, isReloading, isSprinting, canShoot = false, false, false, false, true
		bobOffset = CFrame.new()
		debounce = false
		currentSwayAMT, swayAMT, aimSwayAMT = -.3, -.3, .2
		swayCF = CFrame.new()
		lastCameraCF = CFrame.new()
		fireAnim = nil
	end)
end)

-- Auto-load default weapon
loadSlot(framework.inventory[1])
