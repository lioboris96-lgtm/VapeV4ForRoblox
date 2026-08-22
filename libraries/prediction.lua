--[[
	Prediction Library - Improved
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
	Improved for BedWars projectile prediction with aim modes and gravity handling
]]
local module = {}
local eps = 1e-9
local function isZero(d)
	return (d > -eps and d < eps)
end

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local s0, s1
	local p, q, D
	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q
	if isZero(D) then
		s0 = -p
		return s0
	elseif (D < 0) then
		return
	else
		local sqrt_D = math.sqrt(D)
		s0 = sqrt_D - p
		s1 = -sqrt_D - p
		return s0, s1
	end
end

local function solveCubic(c0, c1, c2, c3)
	local s0, s1, s2
	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D
	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)
	cb_p = p * p * p
	D = q * q + cb_p
	if isZero(D) then
		if isZero(q) then
			s0 = 0
			num = 1
		else
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)
		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)
		s0 = u + v
		num = 1
	end
	sub = (1 / 3) * A
	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end
	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	local s0, s1, s2, s3
	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num
	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0
	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D
	if isZero(r) then
		coeffs[3] = q
		coeffs[2] = p
		coeffs[1] = 0
		coeffs[0] = 1
		local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1
		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0
		u = z * z - r
		v = 2 * z - p
		if isZero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return
		end
		if isZero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return
		end
		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1
		do
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = #results
			s0, s1 = results[1], results[2]
		end
		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1
		if (num == 0) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s0, s1 = results[1], results[2]
		end
		if (num == 1) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s1, s2 = results[1], results[2]
		end
		if (num == 2) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s2, s3 = results[1], results[2]
		end
	end
	sub = 0.25 * A
	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end
	if (num > 3) then s3 = s3 - sub end
	return {s3, s2, s1, s0}
end

-- helper to get aim position for different modes
function module.GetAimPosition(ent, mode, origin)
	if not ent or not ent.Character then return nil end
	mode = mode or "RootPart"
	if mode == "Head" then
		local head = ent.Head or ent.Character:FindFirstChild("Head")
		return head and head.Position or ent.RootPart.Position
	elseif mode == "RootPart" or mode == "HumanoidRootPart" or mode == "Torso" then
		return ent.RootPart.Position
	elseif mode == "UpperTorso" then
		local p = ent.Character:FindFirstChild("UpperTorso")
		return p and p.Position or ent.RootPart.Position
	elseif mode == "Legs" then
		local l1 = ent.Character:FindFirstChild("LeftLowerLeg") or ent.Character:FindFirstChild("Left Leg")
		local l2 = ent.Character:FindFirstChild("RightLowerLeg") or ent.Character:FindFirstChild("Right Leg")
		if l1 and l2 then return (l1.Position + l2.Position) * 0.5 end
		return ent.RootPart.Position - Vector3.new(0, 2.5, 0)
	elseif mode == "Feet" then
		local f1 = ent.Character:FindFirstChild("LeftFoot") or ent.Character:FindFirstChild("Left Leg")
		local f2 = ent.Character:FindFirstChild("RightFoot") or ent.Character:FindFirstChild("Right Leg")
		if f1 and f2 then return (f1.Position + f2.Position) * 0.5 end
		return ent.RootPart.Position - Vector3.new(0, 3, 0)
	elseif mode == "Closest" then
		local closest, dist = nil, math.huge
		local o = origin or ent.RootPart.Position
		-- check head, root, torso, limbs
		local candidates = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"}
		for _, name in ipairs(candidates) do
			local part = ent.Character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local d = (part.Position - o).Magnitude
				if d < dist then dist = d; closest = part.Position end
			end
		end
		return closest or ent.RootPart.Position
	elseif mode == "Random" then
		local parts = {}
		for _, v in ipairs(ent.Character:GetChildren()) do
			if v:IsA("BasePart") then table.insert(parts, v) end
		end
		if #parts > 0 then return parts[math.random(1, #parts)].Position end
		return ent.RootPart.Position
	else
		-- default try to find part by name
		local p = ent.Character:FindFirstChild(mode)
		if p and p:IsA("BasePart") then return p.Position end
		return ent.RootPart.Position
	end
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
	if projectileSpeed <= 0 then return nil end
	local disp = targetPos - origin
	local dist = disp.Magnitude
	if dist < 1 then return targetPos end

	-- Use iterative lead calculation - more stable than quartic for moving targets
	-- Start with direct time, then refine with target motion and gravity
	local function getTargetAt(t)
		local base = targetPos + targetVelocity * t
		if playerGravity and playerGravity > 0 then
			-- account for target falling/jumping:预测 vertical with gravity
			-- playerHeight is HipHeight offset, playerJump is jump velocity if jumping
			local jt = playerJump or 0
			-- simple: target Y at t with gravity
			-- we already have targetVelocity.Y which includes current vertical speed, so just add gravity
			base = base + Vector3.new(0, -0.5 * playerGravity * t * t, 0)
			if jt > 0 then
				base = base + Vector3.new(0, jt * t * 0.1, 0)
			end
		end
		return base
	end

	local bestAim, bestErr, bestT = nil, math.huge, nil
	-- try numeric search for t that makes required speed match projectileSpeed
	-- search t in 0.02 .. 3 seconds
	for t = 0.05, 3, 0.05 do
		local pred = getTargetAt(t)
		local d = pred - origin
		-- required velocity to hit pred at time t with gravity
		-- v0 = (d - 0.5*g*t^2)/t, g = (0,-gravity,0)
		local gVec = Vector3.new(0, -gravity, 0)
		local v0 = (d - 0.5 * gVec * t * t) / t
		local speed = v0.Magnitude
		local err = math.abs(speed - projectileSpeed)
		if err < bestErr then
			-- also check if trajectory is not too steep (e < 200)
			local e = v0.Y
			if math.abs(e) < projectileSpeed * 1.2 then
				bestErr = err
				bestT = t
				bestAim = origin + v0 * t + 0.5 * gVec * t * t
			end
		end
		if err < projectileSpeed * 0.02 then break end
	end

	if bestAim and bestErr < projectileSpeed * 0.15 then
		-- raycast check if path blocked, if blocked try next best? For now return best
		if params then
			local dir = bestAim - origin
			local ray = workspace:Raycast(origin, dir, params)
			if ray and (ray.Position - bestAim).Magnitude > 5 then
				-- blocked, try linear fallback
			else
				return bestAim
			end
		else
			return bestAim
		end
	end

	-- Fallback to quartic for exact solution
	local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
	local h, j, k = disp.X, disp.Y, disp.Z
	local l = -.5 * gravity
	local solutions = module.solveQuartic(
		l*l,
		-2*q*l,
		q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
		2*j*q + 2*h*p + 2*k*r,
		j*j + h*h + k*k
	)

	local function tryRoot(t)
		if not t or t <= 0 or t > 5 then return nil end
		local d = (h + p*t)/t
		local e = (j + q*t - l*t*t)/t
		local f = (k + r*t)/t
		local vel = Vector3.new(d, e, f).Magnitude
		if math.abs(vel - projectileSpeed) > projectileSpeed * 0.05 then return nil end
		-- prefer low arc (small t) and not too high e
		if math.abs(e) > projectileSpeed then return nil end
		return origin + Vector3.new(d, e, f)
	end

	if solutions then
		local posRoots = {}
		for _, v in ipairs(solutions) do
			if v and v > 0 and v < 10 then table.insert(posRoots, v) end
		end
		table.sort(posRoots, function(a,b) return a < b end)
		-- try smallest first (fastest), but also try others if raycast blocks
		for _, t in ipairs(posRoots) do
			local aim = tryRoot(t)
			if aim then
				-- optional raycast check for blockage to target? use params if provided
				if params then
					-- quick check: if line from origin to aim is blocked, try next root (higher arc)
					local dir = aim - origin
					-- we don't want to reject immediately, just prefer unblocked; try to see if any root gives unblocked
					local ray = workspace:Raycast(origin, dir, params)
					if ray and (ray.Position - aim).Magnitude > 3 then
						-- blocked, try next higher arc
					else
						return aim
					end
				else
					return aim
				end
			end
		end
		-- if all blocked, return first
		if #posRoots > 0 then return tryRoot(posRoots[1]) end
	elseif gravity == 0 then
		local t = disp.Magnitude / projectileSpeed
		if t > 0 and t < 10 then
			local d = (h + p*t)/t
			local e = (j + q*t - l*t*t)/t
			local f = (k + r*t)/t
			return origin + Vector3.new(d, e, f)
		end
	end

	-- Fallback: linear prediction
	local t = disp.Magnitude / projectileSpeed
	if t > 0 and t < 5 then
		local pred = targetPos + targetVelocity * t
		-- add small gravity compensation for fallback
		if gravity ~= 0 then
			pred = pred - Vector3.new(0, 0.5 * gravity * t * t * 0.2, 0)
		end
		return pred
	end
	return nil
end

-- wrapper with aim mode
function module.SolveTrajectoryWithAim(origin, projectileSpeed, gravity, ent, mode, targetVelocity, playerGravity, playerHeight, playerJump, params)
	local targetPos = module.GetAimPosition(ent, mode, origin)
	if not targetPos then return nil end
	-- for legs/feet, adjust height slightly
	return module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity or (ent.RootPart and ent.RootPart.Velocity or Vector3.zero), playerGravity, playerHeight, playerJump, params)
end

return module
