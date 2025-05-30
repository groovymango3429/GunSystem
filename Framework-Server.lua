game.ReplicatedStorage.Events.LoadSlot.OnServerEvent:Connect(function(player, SoundId, Volume)
	if player.Character then
		for i, v in pairs(player.Character.UpperTorso:GetChildren()) do
			if v.Name == "FireSound" then
				v:Destroy()
			end
		end

		local fireSound = Instance.new("Sound")
		fireSound.Parent = player.Character.UpperTorso
		fireSound.Name = "FireSound"
		fireSound.Volume = Volume
		fireSound.SoundId = SoundId
	end
end)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		game.ReplicatedStorage.Events.PlayerAdded:FireClient(player, character)
	end)
end)

game.ReplicatedStorage.Events.Shoot.OnServerEvent:Connect(function(player, MuzzlePos, lookPos, damage, headshot)
	if player.Character then
		local sound = player.Character.UpperTorso:FindFirstChild("FireSound")

		if sound then
			sound:Play()
		end

		local bullet = Instance.new("Part")
		bullet.Name = "Bullet"
		bullet.Parent = game.Workspace
		bullet.CanCollide = false
		bullet.Anchored = false
		bullet.Size = Vector3.new(.1, .1, 1)
		bullet.CFrame = CFrame.new(MuzzlePos, lookPos)
		bullet.Material = Enum.Material.Neon
		bullet.BrickColor = BrickColor.new("Cool yellow")

		bullet:SetNetworkOwner(player)

		local bodyVelo = Instance.new("BodyVelocity")
		bodyVelo.Parent = bullet
		bodyVelo.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelo.Velocity = (bullet.CFrame.LookVector * 250)

		bullet.Touched:Connect(function(hit)
			if hit.Parent ~= player.Character then
				bullet:Destroy()

				if hit then
					if hit.Parent:FindFirstChild("Humanoid") then
						if hit.Name == "Head" then
							hit.Parent:FindFirstChild("Humanoid"):TakeDamage(headshot)
						else
							hit.Parent:FindFirstChild("Humanoid"):TakeDamage(damage/2)
						end
					end
				end
			end
		end)

		wait(10)
		bullet:Destroy()
	end
end)
