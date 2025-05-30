local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local humanoid = character:WaitForChild("Humanoid")

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local camera = game.Workspace.CurrentCamera

local dof = game.Lighting.DepthOfField

local aimCF = CFrame.new()

local mouse = player:GetMouse()

local playerGui = player.PlayerGui
local gui = playerGui:WaitForChild("Inventory")
local invF = gui:WaitForChild("Inventory")

local isAiming = false
local isShooting = false
local isReloading = false
local isSprinting = false
local canShoot = true
local canInspect = true

local bobOffset = CFrame.new()

local debounce = false

local currentSwayAMT = -.3
local swayAMT = -.3
local aimSwayAMT = .2
local swayCF = CFrame.new()
local lastCameraCF = CFrame.new()

local fireAnim = nil
local equipAnim = nil
local deequipAnim = nil
local emptyfireAnim = nil
local reloadAnim = nil
local emptyReloadAnim = nil
local InspectAnim = nil
local idleAnim = nil

local framework = {
	inventory = {
		"TROY DEFENSE AR";
		"G19 ROLAND SPECIAL";
		"Knife";
		"Frag";
	};

	module = nil;
	viewmodel = nil;
	currentSlot = 1; 
}

function loadSlot(Item)
	local viewmodelFolder = game.ReplicatedStorage.Viewmodels
	local moduleFolder = game.ReplicatedStorage.Modules

	canShoot = false
	canInspect = false

	for i,v in pairs(camera:GetChildren()) do
		if v:IsA("Model") then
			equipAnim:Stop()
			fireAnim:Stop()
			emptyfireAnim:Stop()
			reloadAnim:Stop()
			emptyReloadAnim:Stop()
			InspectAnim:Stop()
			idleAnim:Stop()
			deequipAnim:Play()
			repeat task.wait() until deequipAnim.IsPlaying == false
			v:Destroy()
		end
	end

	if moduleFolder:FindFirstChild(Item) then
		framework.module = require(moduleFolder:FindFirstChild(Item))

		if viewmodelFolder:FindFirstChild(Item) then
			framework.viewmodel = viewmodelFolder:FindFirstChild(Item):Clone()
			framework.viewmodel.Parent = camera

			if framework.viewmodel and framework.module and character then
				fireAnim = Instance.new("Animation")
				fireAnim.Parent = framework.viewmodel
				fireAnim.Name = "Fire"
				fireAnim.AnimationId = framework.module.fireAnim
				fireAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(fireAnim)

				emptyfireAnim = Instance.new("Animation")
				emptyfireAnim.Parent = framework.viewmodel
				emptyfireAnim.Name = "Fire"
				emptyfireAnim.AnimationId = framework.module.emptyfireAnim
				emptyfireAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(emptyfireAnim)

				equipAnim = Instance.new("Animation")
				equipAnim.Parent = framework.viewmodel
				equipAnim.Name = "Equip"
				equipAnim.AnimationId = framework.module.equipAnim
				equipAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(equipAnim)

				deequipAnim = Instance.new("Animation")
				deequipAnim.Parent = framework.viewmodel
				deequipAnim.Name = "Deequip"
				deequipAnim.AnimationId = framework.module.deequipAnim
				deequipAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(deequipAnim)

				reloadAnim = Instance.new("Animation")
				reloadAnim.Parent = framework.viewmodel
				reloadAnim.Name = "Reload"
				reloadAnim.AnimationId = framework.module.reloadAnim
				reloadAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(reloadAnim)

				emptyReloadAnim = Instance.new("Animation")
				emptyReloadAnim.Parent = framework.viewmodel
				emptyReloadAnim.Name = "EmptyReload"
				emptyReloadAnim.AnimationId = framework.module.emptyReloadAnim
				emptyReloadAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(emptyReloadAnim)

				InspectAnim = Instance.new("Animation")
				InspectAnim.Parent = framework.viewmodel
				InspectAnim.Name = "Inspect"
				InspectAnim.AnimationId = framework.module.InspectAnim
				InspectAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(InspectAnim)

				idleAnim = Instance.new("Animation")
				idleAnim.Parent = framework.viewmodel
				idleAnim.Name = "Idle"
				idleAnim.AnimationId = framework.module.idleAnim
				idleAnim = framework.viewmodel.AnimationController.Animator:LoadAnimation(idleAnim)

				game.ReplicatedStorage.Events.LoadSlot:FireServer(framework.module.fireSound.SoundId, framework.module.fireSound.Volume)

				if framework.viewmodel then
					for i, v in pairs(framework.viewmodel:GetDescendants()) do
						if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("BasePart") then
							v.Transparency = 1
						end
					end
				end

				equipAnim:Play()

				task.wait(.1)

				if framework.viewmodel then
					for i, v in pairs(framework.viewmodel:GetDescendants()) do
						if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("BasePart") then
							if v.Name == "Main" or v.Name == "Muzzle" or v.Name == "FakeCamera" or v.Name == "AimPart" or v.Name == "HumanoidRootPart" then

							else
								v.Transparency = 0
							end
						end
					end
				end

				canShoot = true
				canInspect = true
			end
		end
	end
end

function Shoot()
	if framework.module.fireMode == "Semi" then
		equipAnim:Stop()
		reloadAnim:Stop()
		emptyReloadAnim:Stop()
		InspectAnim:Stop()
		idleAnim:Stop()

		if framework.module.ammo == 1 then
			fireAnim:Stop()
			emptyfireAnim:Play()
		else
			emptyfireAnim:Stop()
			fireAnim:Play()
		end

		framework.module.ammo -= 1


		game.ReplicatedStorage.Events.Shoot:FireServer(framework.viewmodel.Muzzle.Position, mouse.Hit.p, framework.module.damage, framework.module.headshot)

		if framework.module.ammo == 0 then
			task.wait(.5)
			Reload()
			repeat task.wait() until emptyReloadAnim.IsPlaying == false
			debounce = false
		else
			debounce = true

			wait(framework.module.debounce)

			debounce = false
		end
	end

	if framework.module.fireMode == "Full Auto" then
		isShooting = true
	end
end

function Inspect()
	if canInspect then
		idleAnim:Stop()
		dof.FarIntensity = 1
		dof.FocusDistance = 10.44
		dof.InFocusRadius = 25.215
		dof.NearIntensity = 0.183
		InspectAnim:Play()

		repeat task.wait() until InspectAnim.IsPlaying == false

		dof.FarIntensity = 0.1
		dof.FocusDistance = 0.05
		dof.InFocusRadius = 30
		dof.NearIntensity = 0
	end
end

function Reload()
	if isReloading == false then
		canShoot = false
		canInspect = false
		isReloading = true

		fireAnim:Stop()
		emptyfireAnim:Stop()
		equipAnim:Stop()
		InspectAnim:Stop()
		idleAnim:Stop()

		if framework.module.ammo > 0 then
			reloadAnim:Play()
		else
			emptyReloadAnim:Play()
		end

		wait(framework.module.reloadTime)

		canShoot = true
		canInspect = true
		isReloading = false
		framework.module.ammo = framework.module.maxAmmo
	end
end

local oldCamCF = CFrame.new()

function updateCameraShake()
	local newCamCF = framework.viewmodel.FakeCamera.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
	camera.CFrame = camera.CFrame * newCamCF:ToObjectSpace(oldCamCF)
	oldCamCF = newCamCF
end

local hud = player.PlayerGui:WaitForChild("HUD")

RunService.RenderStepped:Connect(function()

	mouse.TargetFilter = framework.viewmodel

	if humanoid then
		local rot = camera.CFrame:ToObjectSpace(lastCameraCF)
		local X,Y,Z = rot:ToOrientation()
		swayCF = swayCF:Lerp(CFrame.Angles(math.sin(X) * currentSwayAMT, math.sin(Y) * currentSwayAMT, 0), .1)
		lastCameraCF = camera.CFrame

		if hud and humanoid then
			if framework.viewmodel and framework.module then
				hud.GunName.Text = framework.inventory[framework.currentSlot]
				hud.Ammo.Text = framework.module.ammo
				hud.Ammo.MaxAmmo.Text = framework.module.maxAmmo
			end
		end

		if framework.viewmodel ~= nil and framework.module ~= nil then
			if humanoid.MoveDirection.Magnitude > 0 then
				if humanoid.WalkSpeed == 17 then
					bobOffset = bobOffset:Lerp(CFrame.new(math.cos(tick() * 4) * .05, -humanoid.CameraOffset.Y/3, -humanoid.CameraOffset.Z/3) * CFrame.Angles(0, math.sin(tick() * -4) * -.05, math.cos(tick() * -4) * .05), .1)
					isSprinting = false
				elseif humanoid.WalkSpeed == 30 then
					bobOffset = bobOffset:Lerp(CFrame.new(math.cos(tick() * 8) * .1, -humanoid.CameraOffset.Y/3, -humanoid.CameraOffset.Z/3) * CFrame.Angles(0, math.sin(tick() * -8) * -.1, math.cos(tick() * -8) * .1) * framework.module.sprintCF, .1)
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

				if not fireAnim.IsPlaying and not emptyfireAnim.IsPlaying and not emptyReloadAnim.IsPlaying and not reloadAnim.IsPlaying and not InspectAnim.IsPlaying and not equipAnim.IsPlaying and not deequipAnim.IsPlaying then
					if idleAnim.IsPlaying == false then
						idleAnim:Play()
					end
				else
					idleAnim:Stop()
				end

			end
		end

		if framework.viewmodel ~= nil then
			if isAiming and framework.module.canAim and isSprinting == false then
				local offset = framework.viewmodel.AimPart.CFrame:ToObjectSpace(framework.viewmodel.PrimaryPart.CFrame)
				aimCF = aimCF:Lerp(offset, framework.module.aimSmooth)
				currentSwayAMT = aimSwayAMT
			else
				local offset = CFrame.new()
				aimCF = aimCF:Lerp(offset, framework.module.aimSmooth)
				currentSwayAMT = swayAMT
			end
		end
	end
end)

--UserInputService.MouseEnabled = false

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.One then
		if framework.currentSlot ~= 1 and isReloading == false then
			loadSlot(framework.inventory[1])
			framework.currentSlot = 1
		end
	end

	if input.KeyCode == Enum.KeyCode.Two then
		if framework.currentSlot ~= 2 and isReloading == false then
			loadSlot(framework.inventory[2])
			framework.currentSlot = 2
		end
	end

	if input.KeyCode == Enum.KeyCode.Three then
		if framework.currentSlot ~= 3 and isReloading == false then
			loadSlot(framework.inventory[3])
			framework.currentSlot = 3
		end
	end

	if input.KeyCode == Enum.KeyCode.Four then
		if framework.currentSlot ~= 4 and isReloading == false then
			loadSlot(framework.inventory[4])
			framework.currentSlot = 4
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = true
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if character and framework.viewmodel and framework.module and framework.module.ammo > 0 and debounce == false and isReloading ~= true and canShoot == true and invF.Visible == false then
			Shoot()
		end
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

	framework.module.ammo = framework.module.maxAmmo

	framework.module = nil
	framework.viewmodel = nil
	framework.currentSlot = 1

	loadSlot(framework.inventory[1])

	humanoid.Died:Connect(function()

		if framework.viewmodel then
			framework.viewmodel:Destroy()
		end

		player = nil
		character = nil
		humanoid = nil

		local aimCF = CFrame.new()

		local isAiming = false
		local isShooting = false
		local isReloading = false
		local isSprinting = false
		local canShoot = true

		local bobOffset = CFrame.new()

		local debounce = false

		local currentSwayAMT = -.3
		local swayAMT = -.3
		local aimSwayAMT = .2
		local swayCF = CFrame.new()
		local lastCameraCF = CFrame.new()

		local fireAnim = nil
	end)
end)

loadSlot(framework.inventory[1])

while wait() do
	if isShooting and framework.module.ammo > 0 and isReloading ~= true and canShoot == true then
		equipAnim:Stop()
		reloadAnim:Stop()
		emptyReloadAnim:Stop()
		InspectAnim:Stop()
		idleAnim:Stop()

		if framework.module.ammo == 1 then
			fireAnim:Stop()
			emptyfireAnim:Play()
		else
			emptyfireAnim:Stop()
			fireAnim:Play()
		end

		framework.module.ammo -= 1


		game.ReplicatedStorage.Events.Shoot:FireServer(framework.viewmodel.Muzzle.Position, mouse.Hit.p, framework.module.damage, framework.module.headshot)

		if framework.module.ammo == 0 then
			task.wait(.5)
			Reload()
		end

		mouse.Button1Up:Connect(function()
			isShooting = false

		end)

		wait(framework.module.fireRate)
	end

end