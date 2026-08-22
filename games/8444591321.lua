local vape = shared.vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then 
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert') 
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function() 
		return readfile(file) 
	end)
	return suc and res ~= nil and res ~= ''
end
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

vape.Place = 6872274481
if isfile('newvape/games/'..vape.Place..'.lua') then
	local src = readfile('newvape/games/'..vape.Place..'.lua')
	local fn, err = loadstring(src, 'bedwars')
	if fn then fn() else if vape then vape:CreateNotification('Vape', 'BedWars load failed: '..tostring(err), 30, 'alert') end end
else
	if not shared.VapeDeveloper then
		local commit = 'main'
		pcall(function() commit = readfile('newvape/profiles/commit.txt') end)
		if not commit or commit == '' then commit = 'main' end
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/lioboris96-lgtm/VapeV4ForRoblox/'..commit..'/games/'..vape.Place..'.lua', true) 
		end)
		if suc and res ~= '404: Not Found' then
			local src = downloadFile('newvape/games/'..vape.Place..'.lua')
			local fn, err = loadstring(src, 'bedwars')
			if fn then fn() else if vape then vape:CreateNotification('Vape', 'BedWars load failed: '..tostring(err), 30, 'alert') end end
		end
	end
end
