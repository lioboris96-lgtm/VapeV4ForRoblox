--[[

  $$$$$$$\                            $$\                           $$\    $$\                              
  $$  __$$\                           $$ |                          $$ |   $$ |                             
  $$ |  $$ | $$$$$$\  $$$$$$$\   $$$$$$$ | $$$$$$\   $$$$$$\        $$ |   $$ |$$$$$$\   $$$$$$\   $$$$$$\  
  $$$$$$$  |$$  __$$\ $$  __$$\ $$  __$$ |$$  __$$\ $$  __$$\       \$$\  $$  |\____$$\ $$  __$$\ $$  __$$\ 
  $$  __$$< $$$$$$$$ |$$ |  $$ |$$ /  $$ |$$$$$$$$ |$$ |  \__|       \$$\$$  / $$$$$$$ |$$ /  $$ |$$$$$$$$ |
  $$ |  $$ |$$   ____|$$ |  $$ |$$ |  $$ |$$   ____|$$ |              \$$$  / $$  __$$ |$$ |  $$ |$$   ____|
  $$ |  $$ |\$$$$$$$\ $$ |  $$ |\$$$$$$$ |\$$$$$$$\ $$ |               \$  /  \$$$$$$$ |$$$$$$$  |\$$$$$$$\ 
  \__|  \__| \_______|\__|  \__| \_______| \_______|\__|                \_/    \_______|$$  ____/  \_______|
                                                                                      $$ |                
                                                                                      $$ |                
                                                                                      \__|   
   A very sexy and overpowered vape mod created at Render Intents  
   /lib/ramcleaner.lua - SystemXVoid/BlankedVoid            
   https://renderintents.xyz                                                                                                                                                                                                                                                                     
]]
   
local Performance: table = {};
Performance.__index = Performance;

local taskenums: table = {
    [1] = 'Removed Instances',
    [2] = 'Table Size',
    [4] = 'Expiration'
};

function Performance.new(args: table | nil, nocachearray: boolean | nil): table
    assert(args == nil or typeof(args) == 'table', `table expected for Argument #1, got {typeof(args)}.`);
    local args: table = args or {};
    local mode: number = 1;
    local iter: number = 0;
    local array: table = setmetatable({}, {});
    local meta: table = getmetatable(array);
    local onclean: table = {};
    local lastclean: number = tick();
    local cleanerevent: table = setmetatable({}, {
        __index = {
            Fire = function(self: table, ...)
                for i,v in onclean do 
                    task.spawn(v, ...)
                end
            end,
            Connect = function(self: table, func: () -> (any))
                local pos: number = #onclean + 1;
                assert(typeof(func) == 'function', `function expected for argument #1, got {typeof(func)}`);
                onclean[pos] = func;
                return setmetatable({}, {
                    __index = {
                        Connected = false,
                        Disconnect = function(self: table)
                            onclean[pos] = nil;
                            self.Connected = false;
                        end
                    }
                });
            end,
            Wait = function(self: table)
                local args: table = {};
                local argsfetched: boolean = false;
                local pos: number = #onclean + 1;
                onclean[pos] = function(...)
                    args = {(...)};
                    argsfetched = true;
                end;
                repeat task.wait() until argsfetched;
                onclean[pos] = nil;
                return unpack(args)
            end
        }
    });

    local cachearray: table = nocachearray and setmetatable({}, {}) or Performance.new(nil, true);
    local cleanerthread: thread = task.spawn(function()
        repeat 
            for i: Instance | number?, v: Instance? in array do
                iter += 1;
                if mode == 1 and (typeof(v) == 'Instance' and v.Parent == nil or typeof(i) == 'Instance' and i.Parent == nil) then 
                    array[i] = nil;
                    cachearray[i] = nil;
                    cleanerevent:Fire(v, i);
                end;
                if mode == 2 and iter > (args.maxamount and tonumber(args.maxamount) or 4000) then 
                    array[i] = nil;
                    cachearray[i] = nil;
                    if args.purge then 
                        meta:clear();
                        cleanerevent:Fire();
                    else
                        cleanerevent:Fire(v, i);
                    end;
                end;
                if mode == 3 and (tick() - cachearray[i]) >= (args.maxdir and tonumber(args.maxdir) or 60) then 
                    array[i] = nil;
                    cachearray[i] = nil;
                    cleanerevent:Fire(v, i);
                    if args.purge then 
                        cleanerevent:Fire();
                        meta:clear();
                    else
                        cleanerevent:Fire(v, i);
                    end;
                end;
            end;
            task.wait(mode == 3 and 0 or args.jobdelay and tonumber(args.jobdelay) or 5);
        until false;
    end);

    getmetatable(cachearray).__index = function(self: table, index: any)
        return (rawget(self, index) or rawset(self, index, tick()) and tick())
    end;

    meta.__index = function(self: table, index: string?)
        local data: any = rawget(self, index);
        if data ~= nil then 
            cachearray[index] = tick();
            return data
        end; 
        return meta[index]
    end;

    meta.oncleanevent = cleanerevent;

    meta.setcleanermode = function(self: table, enum: number, args: table | nil)
        assert(args == nil or typeof(args) == 'table', `table expected for Argument #2, got {typeof(args)}.`);
        mode = enum;
    end;

    meta.len = function(self: table): number
        local iter: number = 0;
        for i: Instance | number?, v: Instance? in array do
            iter += 1 
        end;
        return iter
    end;

    meta.clear = function(self: table, func: (object: any, index: any) -> ()?)
        assert(func == nil or typeof(func) == 'function', `function expected for argument #1, got {typeof(func)}`);
        for i,v in array do 
            array[i] = nil;
            if func then 
                task.spawn(func, v, i);
            end;
        end;
        table.clear(cachearray);
    end;

    meta.getplainarray = function(self: table)
        local tab: table = {};
        local iter: number = 0;
        for i: Instance | number?, v: Instance? in array do
            table.insert(tab, v)
        end;
        return tab
    end;

    meta.shutdown = function(self: table)
        self:clear();
        pcall(task.cancel, cleanerthread);
        cleanerthread = nil;
        table.clear(meta);
        table.clear(onclean);
        onclean = nil;
    end;

    return array
end;

if getgenv then 
    getgenv().Performance = Performance 
end;

return Performance
