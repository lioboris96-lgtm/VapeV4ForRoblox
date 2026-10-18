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

local tribesReady = false
task.spawn(function()
	for i = 1, 60 do
		if typeof(tribes) == 'table' and tribes.Util and tribes.State then
			tribesReady = true
			vape:CreateNotification('Tribes', 'Game functions detected.', 5)
			return
		end
		task.wait(1)
	end
	vape:CreateNotification('Tribes', 'Warning: tribes global not found after 60s.', 10, 'alert')
end)

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

	local function Hook(...)
		local handler

		for _, obj in debug.getstack(3) do
			if type(obj) == 'table' and rawget(obj, 'tuning') then
				handler = obj
				break
			end
		end

		if handler then
			local entity = entitylib.EntityMouse({
				Range = Range.Value,
				Part = 'RootPart',
				Players = Target.Players.Enabled,
				NPCs = Target.NPCs.Enabled
			})

			if entity then
				local targetPart = entity.RootPart
				local origin = ... or gameCamera.CFrame.Position
				local projSpeed = handler.tuning.speed or (handler.tuning.speedMax or 200)

				if handler.drawStart then
					projSpeed = select(2, tribes.Combat.DrawnShot(handler.tuning, debug.getstack(3, 4)))
				end

				local calc = prediction.SolveTrajectory(origin, projSpeed, math.abs(handler.tuning.gravity or (handler.spreadNow and 0 or 60)), targetPart.Position, entity.RootPart.AssemblyLinearVelocity)
				if calc then
					local lookDir = CFrame.lookAt(origin, calc).LookVector
					targetinfo.Targets[entity] = os.clock() + 1

					if handler.lastThrow then
						return (lookDir - Vector3.new(0, ((handler.kind == 'Bomb') and 0.16) or (((handler.kind == 'Sling') and 0.05) or (((handler.kind ~= 'Javelin') and 0.01) or 0.04)), 0)).Unit
					end

					if handler.lastShot and handler.kind ~= 'Blunderbuss' then
						local spread
						if handler.kind == 'Crossbow' then
							spread = 0
						elseif handler:Aimed() then
							spread = handler.tuning.spreadAim or 0
						else
							spread = handler.tuning.spreadHip or 0
						end

						local spreadDir = tribes.Combat.SpreadDir(lookDir, spread, handler:Seed(tribes.State.shotId + 1), 0)
						return (CFrame.lookAt(Vector3.zero, lookDir) * CFrame.lookAt(Vector3.zero, lookDir):ToObjectSpace(CFrame.lookAt(Vector3.zero, spreadDir)):Inverse()).LookVector
					end

					return lookDir
				end
			end
		end

		return old(...)
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end

			if callback then
				if typeof(tribes) ~= 'table' or not tribes.Util or not tribes.Util.AimDirection then
					vape:CreateNotification('SilentAim', 'tribes.Util.AimDirection not found. Is the game fully loaded?', 10, 'alert')
					return
				end

				vape:CreateNotification('SilentAim', 'Hooking tribes.Util.AimDirection...', 5)

				old = hookfunction(tribes.Util.AimDirection, function(...)
					return Hook(...)
				end)

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end

					task.wait()
				until not SilentAim.Enabled
			else
				if old then
					if restorefunction then
						restorefunction(tribes.Util.AimDirection)
					else
						hookfunction(tribes.Util.AimDirection, old)
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
	local SwingRange
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

		if tribes.State and tribes.State.handler and tribes.State.handler.lastSwing then
			return tribes.State.tool
		end
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if typeof(tribes) ~= 'table' or not tribes.State then
					vape:CreateNotification('Killaura', 'tribes.State not found. Is the game fully loaded?', 10, 'alert')
					return
				end

				repeat
					local tool = getAttackData()
					local attacked = {}

					if tool then
						local handler = tribes.State.handler
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

								if AttackDelay < os.clock() and (AutoBlock.Enabled or not handler.blocking) then
									local targets = {}
									handler.lastSwing = os.clock()

									AttackDelay = os.clock() + (handler.tuning.cooldown or 0.5)
									for _, data in attacked do
										table.insert(targets, data.Entity.Character)
									end

									if AutoBlock.Enabled and handler.tuning.block then
										handler:SetBlock(false)
									end

									local oneHanded = handler:OneHanded()
									local comboTable = oneHanded and (handler.tuning.oneHanded.combo or {1}) or (handler.tuning.combo or {1})
									local animTable = oneHanded and handler.preset.oneSwings or handler.preset.swings or {}
									handler.combo = (handler.combo % #comboTable) + 1
									local finisher = (#comboTable > 2) and (handler.combo == #comboTable)
									tribes.Util.PlayAnim(handler.ctx.animator, animTable[((handler.combo - 1) % math.max(1, #animTable)) + 1], (handler.preset.swingSpeed or 1) * (finisher and 0.95 or 1), 0.05)

									handler.ctx.emit('Swing', {
										step = handler.combo,
										finisher = finisher,
										hitDelay = handler.preset.hitDelay or 0.1,
										oneHanded = oneHanded
									})

									handler.ctx.send('Swing', {
										dir = CFrame.lookAt(localPos, attacked[1].Entity.RootPart.Position).LookVector,
										tool = tool,
										hits = targets
									})

									if AutoBlock.Enabled and handler.tuning.block then
										handler:SetBlock(true)
									end

									if vape.ThreadFix then
										setthreadidentity(8)
									end
								end
							end
						elseif AutoBlock.Enabled and handler.tuning.block then
							if tribes.Util.CanAct() then
								handler:SetBlock(true)
							end

							if vape.ThreadFix then
								setthreadidentity(8)
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
					box.Parent = vape.holder
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

run(function()
	local kills = sessioninfo:AddItem('Kills')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
end)
