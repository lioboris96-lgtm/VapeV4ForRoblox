local run = function(func)
	if setthreadidentity then setthreadidentity(8) end
	local suc, err = pcall(func)
	if not suc and err then
		warn('[Vape] Game module error: '..tostring(err))
	end
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local httpService = cloneref(game:GetService('HttpService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local sessioninfo = vape.Libraries.sessioninfo
local entitylib = vape.Libraries.entity
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local tween = vape.Libraries.tween

-- Game-specific module references
local combatUtil = nil
local combatShared = nil
local combatController = nil
local function getCombatModules()
	if not combatUtil then
		pcall(function()
			combatUtil = require(lplr.PlayerScripts.Combat.Util)
		end)
	end
	if not combatShared then
		pcall(function()
			combatShared = require(replicatedStorage.Shared.Combat)
		end)
	end
	if not combatController then
		pcall(function()
			combatController = require(lplr.PlayerScripts.Combat.Controller)
		end)
	end
	return combatUtil, combatShared, combatController
end

-- Helper to get the current handler from controller state
local function getHandler()
	local util, shared, controller = getCombatModules()
	if not controller then return nil end
	local stateFn = controller.State
	if type(stateFn) ~= 'function' then return nil end
	local ok, uvs = pcall(debug.getupvalues, stateFn)
	if not ok or type(uvs) ~= 'table' then return nil end
	for i, v in uvs do
		if type(v) == 'table' and v.char ~= nil then
			return v.handler
		end
	end
	return nil
end

-- Helper: is teammate
local function isTeammate(plr)
	local util = getCombatModules()
	if util and util.IsTeammate then
		local ok, res = pcall(util.IsTeammate, plr and plr.Character)
		if ok then return res end
	end
	return false
end

-- Helper: is enemy
local function isEnemy(plr)
	local util = getCombatModules()
	if util and util.IsEnemy then
		local ok, res = pcall(util.IsEnemy, plr and plr.Character)
		if ok then return res end
	end
	return false
end

run(function()
	local SilentAim
	local Target
	local Range
	local HitChance
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local old

	local function Hook(origin)
		local util, shared, controller = getCombatModules()
		if not util or not shared then return old and old(origin) end

		local handler = getHandler()
		local entity = entitylib.EntityMouse({
			Range = Range.Value,
			Part = 'RootPart',
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if entity then
			local targetPart = entity.RootPart
			targetinfo.Targets[entity] = os.clock() + 1

			local projSpeed = 200
			local projGravity = 0
			if handler and type(handler.tuning) == 'table' then
				if handler.tuning.speedMult then projSpeed = handler.tuning.speedMult * 100 end
				if handler.tuning.speed then projSpeed = handler.tuning.speed end
				if handler.tuning.speedMax then projSpeed = handler.tuning.speedMax end
			end

			local calc = prediction.SolveTrajectory(origin, projSpeed, projGravity, targetPart.Position, entity.RootPart.AssemblyLinearVelocity)
			if calc then
				return (calc - origin).Unit
			end

			return (targetPart.Position - origin).Unit
		end

		if old then
			return old(origin)
		end
		return nil
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end

			if callback then
				local util = getCombatModules()
				if not util or not util.AimDirection then
					vape:CreateNotification('SilentAim', 'Combat.Util not found.', 10, 'alert')
					return
				end

				vape:CreateNotification('SilentAim', 'Hooking AimDirection...', 5)
				old = hookfunction(util.AimDirection, function(origin)
					return Hook(origin)
				end)

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
					task.wait()
				until not SilentAim.Enabled
			else
				if old then
					local util = getCombatModules()
					if util and util.AimDirection then
						if restorefunction then
							restorefunction(util.AimDirection)
						else
							hookfunction(util.AimDirection, old)
						end
					end
					old = nil
				end
			end
		end,
		ExtraText = function()
			return 'Tribes'
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local AutoBlock
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Particles, Boxes, AttackDelay = {}, {}, os.clock()

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		local handler = getHandler()
		if handler and handler.lastSwing then
			return handler.ctx and handler.ctx.tool
		end
		return nil
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local tool = getAttackData()
					local attacked = {}

					if tool then
						local handler = getHandler()
						if not handler then
							task.wait(0.5)
							continue
						end

						local entities = entitylib.AllPosition({
							Range = AttackRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})

						if #entities > 0 then
							local localPos = entitylib.character.RootPart.Position
							local localFacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, entity in entities do
								-- Team check: skip teammates
								if entity.Player and isTeammate(entity.Player) then
									continue
								end

								local delta = (entity.RootPart.Position - localPos)
								local angle = math.abs(localFacing:Angle(delta * Vector3.new(1, 0, 1)))
								if angle > (math.rad(AngleSlider.Value) / 2) then
									continue
								end

								targetinfo.Targets[entity] = os.clock() + 1
								table.insert(attacked, {
									Entity = entity,
									Check = BoxAttackColor
								})
							end

							if #attacked > 0 then
								local cmpPos = attacked[1].Entity.RootPart.Position
								local delta = (cmpPos - localPos)
								local angle = math.abs(localFacing:Angle(delta * Vector3.new(1, 0, 1)))
								if angle > math.rad(100) / 2 then
									entitylib.character.RootPart.CFrame = CFrame.lookAlong(localPos, delta * Vector3.new(1, 0, 1))
								end

								if AttackDelay < os.clock() then
									local targets = {}
									handler.lastSwing = os.clock()

									AttackDelay = os.clock() + (handler.tuning.cooldown or 0.5)
									for _, data in attacked do
										table.insert(targets, data.Entity.Character)
									end

									local util = getCombatModules()
									if util and util.PlayAnim and handler.ctx and handler.ctx.animator then
										pcall(util.PlayAnim, handler.ctx.animator, handler.preset.swingSound or '', 1, 0.05)
									end

									if handler.ctx and handler.ctx.send then
										pcall(handler.ctx.send, 'Swing', {
											dir = CFrame.lookAt(localPos, attacked[1].Entity.RootPart.Position).LookVector,
											tool = tool,
											hits = targets
										})
									end

									if vape.ThreadFix then
										setthreadidentity(8)
									end
								end
							end
						end
					end

					for index, box in Boxes do
						box.Adornee = attacked[index] and attacked[index].Entity.RootPart or nil
						if box.Adornee then
							box.Color3 = Color3.fromHSV(attacked[index].Check.Hue, attacked[index].Check.Sat, attacked[index].Check.Value)
							box.Transparency = 1 - attacked[index].Check.Opacity
						end
					end

					for index, particle in Particles do
						particle.Position = attacked[index] and attacked[index].Entity.RootPart.Position or Vector3.new(math.huge, math.huge, math.huge)
						particle.Parent = attacked[index] and gameCamera or nil
					end

					task.wait()
				until not Killaura.Enabled
			else
				for _, box in Boxes do
					box.Adornee = nil
				end

				for _, particle in Particles do
					particle.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 14,
		Default = 14,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 90
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({
		Name = 'Require mouse down'
	})
	AutoBlock = Killaura:CreateToggle({
		Name = 'AutoBlock'
	})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback

			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.Size = Vector3.new(3, 5, 3)
					box.ZIndex = 0
					box.Parent = coreGui
					Boxes[i] = box
				end
			else
				for _, box in Boxes do
					box:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback

			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, particle in Particles do
					particle:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, particle in Particles do
				particle.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, particle in Particles do
				particle.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, particle in Particles do
				particle.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, particle in Particles do
				particle.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
end)

-- Nametags module
run(function()
	local Nametags
	local ShowDistance
	local ShowHealth
	local TextColor
	local TextSize
	local TeamCheck
	local nametagObjects = {}

	local function createNametag(plr)
		if plr == lplr then return end
		if nametagObjects[plr] then return end

		local char = plr.Character
		if not char then return end
		local head = char:FindFirstChild('Head')
		if not head then return end

		local bb = Instance.new('BillboardGui')
		bb.Name = 'VapeNametag'
		bb.Size = UDim2.new(0, 200, 0, 50)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 500
		bb.Parent = head

		local nameLabel = Instance.new('TextLabel')
		nameLabel.Name = 'Name'
		nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = plr.Name
		nameLabel.TextColor3 = Color3.fromHSV(TextColor.Hue, TextColor.Sat, TextColor.Value)
		nameLabel.TextSize = TextSize.Value
		nameLabel.TextStrokeTransparency = 0
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = bb

		local infoLabel = Instance.new('TextLabel')
		infoLabel.Name = 'Info'
		infoLabel.Size = UDim2.new(1, 0, 0.4, 0)
		infoLabel.Position = UDim2.new(0, 0, 0.6, 0)
		infoLabel.BackgroundTransparency = 1
		infoLabel.Text = ''
		infoLabel.TextColor3 = Color3.new(1, 1, 1)
		infoLabel.TextSize = TextSize.Value - 2
		infoLabel.TextStrokeTransparency = 0
		infoLabel.Font = Enum.Font.Gotham
		infoLabel.Parent = bb

		nametagObjects[plr] = {bb = bb, nameLabel = nameLabel, infoLabel = infoLabel, char = char}
	end

	local function removeNametag(plr)
		if nametagObjects[plr] then
			pcall(function()
				nametagObjects[plr].bb:Destroy()
			end)
			nametagObjects[plr] = nil
		end
	end

	local function updateNametags()
		for plr, data in nametagObjects do
			if not plr or not plr.Parent or not data.char or not data.char.Parent then
				removeNametag(plr)
			else
				-- Team check coloring
				local color = Color3.fromHSV(TextColor.Hue, TextColor.Sat, TextColor.Value)
				if TeamCheck.Enabled then
					if isTeammate(plr) then
						color = Color3.fromRGB(0, 255, 0)
					elseif isEnemy(plr) then
						color = Color3.fromRGB(255, 0, 0)
					end
				end
				data.nameLabel.TextColor3 = color

				-- Info text
				local info = ''
				if ShowDistance.Enabled and lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart') and data.char:FindFirstChild('HumanoidRootPart') then
					local dist = (lplr.Character.HumanoidRootPart.Position - data.char.HumanoidRootPart.Position).Magnitude
					info = math.floor(dist) .. ' studs'
				end
				if ShowHealth.Enabled then
					local hum = data.char:FindFirstChildOfClass('Humanoid')
					if hum then
						if info ~= '' then info = info .. ' | ' end
						info = info .. math.floor(hum.Health) .. '/' .. math.floor(hum.MaxHealth) .. ' HP'
					end
				end
				data.infoLabel.Text = info
			end
		end
	end

	Nametags = vape.Categories.Render:CreateModule({
		Name = 'Nametags',
		Function = function(callback)
			if callback then
				-- Create nametags for existing players
				for _, plr in playersService:GetPlayers() do
					if plr ~= lplr then
						createNametag(plr)
					end
				end

				-- Listen for new players
				Nametags:Clean(playersService.PlayerAdded:Connect(function(plr)
					plr.CharacterAdded:Connect(function()
						task.wait(1)
						createNametag(plr)
					end)
					if plr.Character then
						createNametag(plr)
					end
				end))

				-- Listen for character changes
				for _, plr in playersService:GetPlayers() do
					if plr ~= lplr then
						Nametags:Clean(plr.CharacterAdded:Connect(function()
							task.wait(1)
							removeNametag(plr)
							createNametag(plr)
						end))
					end
				end

				-- Update loop
				Nametags:Clean(runService.RenderStepped:Connect(function()
					updateNametags()
				end))
			else
				for plr in nametagObjects do
					removeNametag(plr)
				end
				table.clear(nametagObjects)
			end
		end,
		Tooltip = 'Shows player names and info above their heads'
	})
	ShowDistance = Nametags:CreateToggle({
		Name = 'Show distance'
	})
	ShowHealth = Nametags:CreateToggle({
		Name = 'Show health'
	})
	TeamCheck = Nametags:CreateToggle({
		Name = 'Team check colors'
	})
	TextColor = Nametags:CreateColorSlider({
		Name = 'Text color',
		DefaultHue = 0,
		DefaultSat = 0,
		DefaultValue = 1
	})
	TextSize = Nametags:CreateSlider({
		Name = 'Text size',
		Min = 8,
		Max = 24,
		Default = 14
	})
end)

-- ESP module
run(function()
	local ESP
	local BoxColor
	local TracerColor
	local ShowBoxes
	local ShowTracers
	local ShowNames
	local TeamCheck
	local espObjects = {}

	local function createESP(plr)
		if plr == lplr then return end
		if espObjects[plr] then return end

		local drawings = {}
		-- Box
		local box = Drawing.new('Square')
		box.Visible = false
		box.Thickness = 1
		box.Filled = false
		box.Color = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
		drawings.box = box

		-- Tracer
		local tracer = Drawing.new('Line')
		tracer.Visible = false
		tracer.Thickness = 1
		tracer.Color = Color3.fromHSV(TracerColor.Hue, TracerColor.Sat, TracerColor.Value)
		drawings.tracer = tracer

		-- Name
		local name = Drawing.new('Text')
		name.Visible = false
		name.Size = 14
		name.Center = true
		name.Outline = true
		name.Color = Color3.new(1, 1, 1)
		drawings.name = name

		espObjects[plr] = {drawings = drawings, char = nil}
	end

	local function removeESP(plr)
		if espObjects[plr] then
			for _, d in espObjects[plr].drawings do
				pcall(function() d:Remove() end)
			end
			espObjects[plr] = nil
		end
	end

	local function updateESP()
		for plr, data in espObjects do
			if not plr or not plr.Parent then
				removeESP(plr)
			else
				local char = plr.Character
				if not char or not char.Parent or not char:FindFirstChild('HumanoidRootPart') then
					for _, d in data.drawings do
						d.Visible = false
					end
				else
					data.char = char
					local hrp = char.HumanoidRootPart
					local head = char:FindFirstChild('Head')
					local pos, onScreen = gameCamera:WorldToViewportPoint(hrp.Position)

					-- Team check
					local boxColor = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
					local tracerColor = Color3.fromHSV(TracerColor.Hue, TracerColor.Sat, TracerColor.Value)
					if TeamCheck.Enabled then
						if isTeammate(plr) then
							boxColor = Color3.fromRGB(0, 255, 0)
							tracerColor = Color3.fromRGB(0, 255, 0)
						elseif isEnemy(plr) then
							boxColor = Color3.fromRGB(255, 0, 0)
							tracerColor = Color3.fromRGB(255, 0, 0)
						end
					end

					if onScreen then
						-- Box
						if ShowBoxes.Enabled then
							local topPos = gameCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
							local bottomPos = gameCamera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
							local height = math.abs(topPos.Y - bottomPos.Y)
							local width = height * 0.6
							data.drawings.box.Size = Vector2.new(width, height)
							data.drawings.box.Position = Vector2.new(pos.X - width / 2, pos.Y - height / 2)
							data.drawings.box.Color = boxColor
							data.drawings.box.Visible = true
						else
							data.drawings.box.Visible = false
						end

						-- Tracer
						if ShowTracers.Enabled then
							data.drawings.tracer.From = Vector2.new(gameCamera.ViewportSize.X / 2, gameCamera.ViewportSize.Y)
							data.drawings.tracer.To = Vector2.new(pos.X, pos.Y)
							data.drawings.tracer.Color = tracerColor
							data.drawings.tracer.Visible = true
						else
							data.drawings.tracer.Visible = false
						end

						-- Name
						if ShowNames.Enabled then
							data.drawings.name.Text = plr.Name
							data.drawings.name.Position = Vector2.new(pos.X, pos.Y - 40)
							data.drawings.name.Color = boxColor
							data.drawings.name.Visible = true
						else
							data.drawings.name.Visible = false
						end
					else
						for _, d in data.drawings do
							d.Visible = false
						end
					end
				end
			end
		end
	end

	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			if callback then
				for _, plr in playersService:GetPlayers() do
					if plr ~= lplr then
						createESP(plr)
					end
				end

				ESP:Clean(playersService.PlayerAdded:Connect(function(plr)
					plr.CharacterAdded:Connect(function()
						task.wait(1)
						createESP(plr)
					end)
					if plr.Character then
						createESP(plr)
					end
				end))

				for _, plr in playersService:GetPlayers() do
					if plr ~= lplr then
						ESP:Clean(plr.CharacterAdded:Connect(function()
							task.wait(1)
							removeESP(plr)
							createESP(plr)
						end))
					end
				end

				ESP:Clean(runService.RenderStepped:Connect(function()
					updateESP()
				end))
			else
				for plr in espObjects do
					removeESP(plr)
				end
				table.clear(espObjects)
			end
		end,
		Tooltip = 'Shows player boxes and tracers through walls'
	})
	ShowBoxes = ESP:CreateToggle({
		Name = 'Boxes'
	})
	ShowTracers = ESP:CreateToggle({
		Name = 'Tracers'
	})
	ShowNames = ESP:CreateToggle({
		Name = 'Names'
	})
	TeamCheck = ESP:CreateToggle({
		Name = 'Team check'
	})
	BoxColor = ESP:CreateColorSlider({
		Name = 'Box color',
		DefaultHue = 0,
		DefaultSat = 1,
		DefaultOpacity = 1
	})
	TracerColor = ESP:CreateColorSlider({
		Name = 'Tracer color',
		DefaultHue = 0.6,
		DefaultSat = 1,
		DefaultOpacity = 1
	})
end)

run(function()
	local kills = sessioninfo:AddItem('Kills')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
end)
