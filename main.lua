repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

-- why do exploits fail to implement anything correctly? Is it really that hard?
-- wave and volt suck ass
if identifyexecutor then
	if table.find({'Argon', 'Volt', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		local commit = 'main'
		pcall(function() commit = readfile('newvape/profiles/commit.txt') end)
		if not commit or commit == '' then commit = 'main' end
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/lioboris96-lgtm/VapeV4ForRoblox/'..commit..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

		local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					local c='main' pcall(function() c=readfile('newvape/profiles/commit.txt') end) if not c or c=='' then c='main' end
					loadstring(game:HttpGet('https://raw.githubusercontent.com/lioboris96-lgtm/VapeV4ForRoblox/'..c..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
if setthreadidentity then setthreadidentity(8) end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
if setthreadidentity then setthreadidentity(8) end
local usrc = downloadFile('newvape/games/universal.lua')
local ufn, uerr = loadstring(usrc, 'universal')
if ufn then ufn() else if vape then vape:CreateNotification('Vape', 'Universal load failed: '..tostring(uerr), 30, 'alert') end end
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		if setthreadidentity then setthreadidentity(8) end
		local src = readfile('newvape/games/'..game.PlaceId..'.lua')
		local fn, err = loadstring(src, tostring(game.PlaceId))
		if fn then fn(...) else if vape then vape:CreateNotification('Vape', 'Game load failed: '..tostring(err), 30, 'alert') end end
	else
		if not shared.VapeDeveloper then
			local commit = 'main'
			pcall(function() commit = readfile('newvape/profiles/commit.txt') end)
			if not commit or commit == '' then commit = 'main' end
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/lioboris96-lgtm/VapeV4ForRoblox/'..commit..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				if setthreadidentity then setthreadidentity(8) end
				local src = downloadFile('newvape/games/'..game.PlaceId..'.lua')
				local fn, err = loadstring(src, tostring(game.PlaceId))
				if fn then fn(...) else if vape then vape:CreateNotification('Vape', 'Game load failed: '..tostring(err), 30, 'alert') end end
			end
		end
	end
	if setthreadidentity then setthreadidentity(8) end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
