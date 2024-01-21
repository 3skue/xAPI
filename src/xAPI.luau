--[[

 / xAPI III	- A Powerful Exploit Simulator
 / Author	- Eskue (@SQLanguage)
 / Credits	->
 	Libraries	
 		stravant										- Signal module
 		metatablecat									- LZ4 module
 		
 		Egor Skriptunoff, boatbomber, and howmanysmall	- Hashlib
 		
 		kosuke14										- vLuau
 			TheGreatSageEqualToHeaven and Rerumu		- Fiu (Luau bytecode interpreter)
 			RealEthanPlayzDev and Rerumu				- LuauInLuau (Luau compiler)
 		
]]

---- Init
local Services			= setmetatable({}, {
	__index = function(self, key)
		return rawget(self, key) or (function()
			self[key] = game:GetService(key)
			return rawget(self, key)
		end)()
	end,
})

local wrap, customBehaviour

local xAPI				= {}

xAPI.Env				= {
	debug				= {},
	crypt				= {},
	cache				= {},
	WebSocket			= {},
	Instance			= {},
	coroutine			= {},
	task				= {}
}

xAPI.Libraries			= {
	Bytecode			= require(script:WaitForChild("Bytecode")),
	Crypt				= require(script:WaitForChild("Crypt")),
	LZ4					= require(script:WaitForChild("LZ4")),
	Signal				= require(script:WaitForChild("Signal")),
	Saveinstance		= require(script:WaitForChild("SaveInstance"))
}

xAPI.AddGlobal			= function(names: {string}, value: any, places: {any}?)
	local places = places or {xAPI.Env}

	for _, place in places do
		for _, name in names do
			if type(value) == "function" then
				place[name] = function(...)
					return value(name, ...)
				end

				continue
			end

			place[name] = value
		end

		if place ~= xAPI.Env then
			task.defer(function()
				place = setmetatable(place, {
					__newindex = function()
						error("attempt to modify a readonly table", 2)
					end,
				})
			end)
		end
	end
end

xAPI.TypeCheck			= function(argPos, value: any, allowedTypes: {string}, optional: boolean?)
	if value == nil then
		if optional then
			return
		end
		
		error(("missing argument #%d (expected %s)"):format(argPos, table.concat(allowedTypes, " or ")), 4)
	end
	
	if not (table.find(allowedTypes, type(value)) or table.find(allowedTypes, typeof(value)) or table.find(allowedTypes, "any")) then
		error(("invalid argument #%d (expected %s, got %s)"):format(argPos, table.concat(allowedTypes, " or "), typeof(value)), 4)
	end

	return value
end

xAPI.Data				= {
	Instances			= {},
	Metatables			= {},
	InstanceReferences	= {},
	GC					= {},
	Wrapped				= {},
	Connections			= {},
	LoadedModules		= {script},
	AssetCache			= {},
	CallbackValues		= {},
	Workspace			= {},
	GEnv				= {},
	Threads				= {},
	IsWindowActive		= true,
	FPS_Cap				= 0, -- 0- means uncapped, 1+ gets capped
	UI					= Services.Players.LocalPlayer.PlayerGui
}

local assert			= function(value: boolean | nil, errorMessage: string)
	if not value then
		error(errorMessage, 4)
	end
end

---- Functions

-- Metatables
-- a: {metatable, protected}
local shareMetatable	= function(meta, protected)
	if not (meta and meta[1]) then
		return nil
	end

	local metatable = getmetatable(meta[1]) or meta[1]

	return setmetatable(metatable, {
		__newindex = function(self, key, value)
			if key == "__metatable" then
				meta[2] = value
			else
				meta[1][key] = value
			end
		end,
		__index = function(self, key)
			if key == "__metatable" then
				return meta[2]
			else
				return rawget(meta[1], key)
			end
		end,
	})
end

xAPI.AddGlobal({"getmetatable"}, function(self, t: any): {any}
	local metatable = xAPI.Data.Metatables[t]

	if not metatable then
		return nil
	end

	if metatable[2] then
		return metatable[2]
	end

	return shareMetatable(metatable)
end)

xAPI.AddGlobal({"setmetatable"}, function(self, t: {any}, newMeta: {any}): {any}
	xAPI.TypeCheck(1, t, {"table"})
	xAPI.TypeCheck(2, newMeta, {"table"}, true)

	local metatable = xAPI.Data.Metatables[t]

	if (metatable and metatable[2] ~= nil) then
		error("cannot change a protected metatable", 3)
		return
	elseif metatable == nil then
		xAPI.Data.Metatables[t] = {}
		metatable = xAPI.Data.Metatables[t]
	end

	local __metatable = newMeta["__metatable"]

	if __metatable then
		newMeta["__metatable"] = nil
	end

	xAPI.Data.Metatables[t][1] = setmetatable(t, newMeta)
	xAPI.Data.Metatables[t][2] = __metatable

	return xAPI.Data.Metatables[t][1]
end)

xAPI.AddGlobal({"setrawmetatable"}, function(self, t: {any}, newMeta: {any}): {any}
	xAPI.TypeCheck(1, t, {"table"})
	xAPI.TypeCheck(2, newMeta, {"table"}, true)

	local metatable = xAPI.Data.Metatables[t]

	if metatable == nil then
		xAPI.Data.Metatables[t] = {}
		metatable = xAPI.Data.Metatables[t]
	end

	local __metatable = newMeta["__metatable"]

	if __metatable then
		newMeta["__metatable"] = nil
	end

	xAPI.Data.Metatables[t][1] = setmetatable(t, newMeta)
	xAPI.Data.Metatables[t][2] = __metatable

	return xAPI.Data.Metatables[t][1]
end)

xAPI.AddGlobal({"getrawmetatable"}, function(self, t: {any} | userdata): {any}
	local metatable = xAPI.Data.Metatables[t]

	if not metatable then
		return nil
	end

	return shareMetatable(metatable)
end)

xAPI.AddGlobal({"newproxy"}, function(self, addMetatable: boolean): userdata
	xAPI.TypeCheck(1, addMetatable, {"boolean"}, true)

	local newProxy = newproxy(addMetatable)
	xAPI.Data.Metatables[newProxy] = {newProxy}

	return newProxy
end)

xAPI.AddGlobal({"hookmetamethod"}, function(self, object: {any} | userdata, method: string, hook: (...any) -> ()): (...any) -> (...any)
	xAPI.TypeCheck(1, object, {"table", "userdata"})
	xAPI.TypeCheck(2, method, {"string"})
	xAPI.TypeCheck(3, hook, {"function"})

	local rawMetatable = xAPI.Env.getrawmetatable(object)

	if not rawMetatable then
		error("Metatable not found", 3)
	end

	local oldMethod = rawMetatable[method]

	rawMetatable[method] = hook

	return oldMethod
end)

xAPI.AddGlobal({"isreadonly"}, function(self, t: {any}): {any}
	xAPI.TypeCheck(1, t, {"table"})

	local originalKey = t[1]

	local isNotFrozen = pcall(function()
		t[1] = 0
	end)

	if isNotFrozen or t[1] ~= originalKey then
		pcall(function()
			t[1] = originalKey
		end)

		return false
	end

	return true
end)

xAPI.AddGlobal({"getloadedmodules"}, function(self): {ModuleScript}
	return xAPI.Data.LoadedModules
end)

xAPI.AddGlobal({"require"}, function(self, target: ModuleScript): any
	xAPI.TypeCheck(1, target, {"Instance", "userdata"})

	table.insert(xAPI.Data.LoadedModules, target)
	return require(xAPI.Data.Wrapped[target] or target)
end)

-- Cache
xAPI.AddGlobal({"replace"}, function(self, object: Instance, newObject: Instance)
	xAPI.TypeCheck(1, object, {"Instance", "userdata"})
	xAPI.TypeCheck(2, newObject, {"Instance", "userdata"})

	xAPI.Data.Wrapped[object] = newObject
end, {xAPI.Env.cache})

xAPI.AddGlobal({"invalidate"}, function(self, object: Instance)
	xAPI.TypeCheck(1, object, {"Instance", "userdata"})

	xAPI.Data.Wrapped[object] = nil
end, {xAPI.Env.cache})

xAPI.AddGlobal({"iscached"}, function(self, object: Instance)
	xAPI.TypeCheck(1, object, {"Instance", "userdata"})

	return xAPI.Data.Wrapped[object] ~= nil
end, {xAPI.Env.cache})

xAPI.AddGlobal({"getcustomasset"}, function(self, asset: string)
	xAPI.TypeCheck(1, asset, {"string"})

	local data = (xAPI.Data.AssetCache[asset]) or xAPI.Env.readfile(asset)

	assert(data, "Asset not found")

	xAPI.Data.AssetCache[asset] = data

	return "rbxasset://custom_assets/"..asset
end)

-- Closures
xAPI.AddGlobal({"loadstring"}, function(self, source: string, chunkName: string?): () -> (...any)
	xAPI.TypeCheck(1, source, {"string"})
	xAPI.TypeCheck(2, chunkName, {"string"}, true)

	local chunkName = chunkName or xAPI.Env.crypt.random(8)

	return xAPI.Libraries.Bytecode.loadstring(source, chunkName)
end)

xAPI.AddGlobal({"dumpstring"}, function(self, source: string): string
	xAPI.TypeCheck(1, source, {"string"})

	local chunkName = xAPI.Env.crypt.random(8)

	return xAPI.Libraries.Bytecode.dumpstring(source, chunkName)
end)

xAPI.AddGlobal({"hookfunction", "replaceclosure"}, function(self, old: (...any) -> (...any), new: (...any) -> (...any)): (...any) -> (...any)
	xAPI.TypeCheck(1, old, {"function"})
	xAPI.TypeCheck(2, new, {"function"}, true)

	local old_name = debug.info(old, "n")

	assert(old_name ~= "", "Cannot hook anonymous functions")
	assert(getfenv(3)[old_name], "Cannot hook local functions")

	getfenv(3)[old_name] = new

	return old
end)

xAPI.AddGlobal({"newcclosure"}, function(self, closure: (...any) -> (...any)): (...any) -> (...any)
	xAPI.TypeCheck(1, closure, {"function"})

	return coroutine.wrap(function(...)
		while true do
			coroutine.yield(closure(...))
		end
	end)
end)

xAPI.AddGlobal({"newlclosure"}, function(self, closure: (...any) -> (...any)): (...any) -> (...any)
	xAPI.TypeCheck(1, closure, {"function"})

	return function(...)
		return closure(...)
	end
end)

xAPI.AddGlobal({"iscclosure"}, function(self, closure: (...any) -> (...any)): (...any) -> (...any)
	xAPI.TypeCheck(1, closure, {"function"})

	return debug.info(closure, "s") == "[C]"
end)

xAPI.AddGlobal({"islclosure"}, function(self, closure: (...any) -> (...any)): (...any) -> (...any)
	xAPI.TypeCheck(1, closure, {"function"})

	return debug.info(closure, "s") ~= "[C]"
end)

xAPI.AddGlobal({"checkcaller"}, function(self): boolean
	return debug.info(4, "f") == xAPI.Data.UserFunction
end)

xAPI.AddGlobal({"clonefunction"}, function(self, func: (...any) -> (...any)): (...any) -> (...any)
	xAPI.TypeCheck(1, func, {"function"})

	return function(...)
		return func(...)
	end
end)

xAPI.AddGlobal({"getrenv"}, function(self): {any}
	return getfenv(1)
end)

xAPI.AddGlobal({"getgenv"}, function(self): {any}
	return setmetatable(table.clone(xAPI.Env), {
		__index = function(self, key)
			return xAPI.Data.GEnv
		end,
		__newindex = function(self, key, value)
			xAPI.Data.GEnv[key] = value
			getfenv(2)[key] = value
		end,
	})
end)

xAPI.AddGlobal({"isexecutorclosure", "checkclosure", "isourclosure"}, function(self, func: (...any) -> (...any)): boolean
	xAPI.TypeCheck(1, func, {"function"})

	local funcName = debug.info(func, "n")
	return funcName == "" or xAPI.Env.getrenv()[funcName] == nil
end)

xAPI.AddGlobal({"getcallingscript"}, function(self): LocalScript | ModuleScript
	local function getObject(fullName: string)
		local current = game

		for _, nextPath in fullName:split(".") do
			current = current:FindFirstChild(nextPath)
		end

		return current
	end

	return getObject(debug.info(3, "s"))
end)

xAPI.AddGlobal({"getthreadidentity", "getidentity", "getthreadcontext"}, function(self): number
	local identity, connection

	connection = Services.LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		local _identity = tonumber(message:sub(21))
		if not identity and _identity then
			identity = _identity
			connection:Disconnect()
		end
	end)

	printidentity()

	task.wait(.1)

	return identity
end)

xAPI.AddGlobal({"getallthreads"}, function(self): {thread}
	return xAPI.Data.Threads
end)

local function insertThread(thread: thread)
	table.insert(xAPI.Data.Threads, thread)
end

for _, func in {"create", "wrap"} do
	xAPI.Env.coroutine[func] = function(f: (...any) -> (...any), ...): thread
		xAPI.TypeCheck(1, f, {"function"})
		local t = coroutine[func](f, ...)
		
		insertThread(t)
		
		return t
	end
end

for _, func in {"spawn", "defer", "delay"} do
	xAPI.Env.task[func] = function(f: (...any) -> (...any), ...): thread
		xAPI.TypeCheck(1, f, {"function"})
		local t = task[func](f, ...)

		insertThread(t)

		return t
	end
end

-- debug
xAPI.AddGlobal({"getinfo"}, function(self, func: (...any) -> (...any)): {
	source: string,
	short_src: string,
	func: (...any) -> (...any),
	what: ("Lua" | "C"),
	currentline: number,
	name: string,
	nups: number,
	numparams: number,
	is_vararg: boolean
}

	local source, line, name, args, isVariadic, f = debug.info(func, "slnaf")
	local what = (source == "[C]" and "C") or "Lua"
	local is_variadic = (isVariadic and 1) or 0
	local short_source = ""

	for _, char in utf8.codes(source or "") do
		short_source ..= string.char(math.clamp(char, 32, 127))
	end

	return {
		source = debug.info(func, "s"),
		short_src = short_source,
		func = f,
		what = what,
		currentline = line,
		name = name,
		nups = -1,
		numparams = args,
		is_vararg = is_variadic
	}
end, {xAPI.Env.debug, xAPI.Env})

xAPI.AddGlobal({"isvalidlevel"}, function(self, level: number)
	xAPI.TypeCheck(1, level, {"number"})

	local isValidLevel = pcall(function()
		getfenv(2 + level)
	end)

	return isValidLevel
end, {xAPI.Env.debug, xAPI.Env})

-- Instances
xAPI.AddGlobal({"saveinstance"}, function(self, ...): string
	xAPI.Libraries.Saveinstance(xAPI, ...)
	local path = tostring(game.GameId)..".rbxlx"
	
	return path
end)

xAPI.AddGlobal({"getinstances"}, function(self): {Instance}
	return xAPI.Data.Instances
end)

xAPI.AddGlobal({"getnilinstances"}, function(self): {Instance}
	local _nil = {}

	for _, instance in xAPI.Data.Instances do
		if instance.Parent == nil then
			table.insert(_nil, instance)
		end
	end

	return _nil
end)

xAPI.AddGlobal({"getscripts"}, function(self): {ModuleScript | LocalScript}
	local scripts = {}

	for _, instance in xAPI.Data.Instances do
		if instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
			table.insert(scripts, instance)
		end
	end

	return scripts
end)

xAPI.AddGlobal({"getmodules"}, function(self): {ModuleScript}
	local modules = {}

	for _, instance in xAPI.Data.Instances do
		if instance:IsA("ModuleScript") then
			table.insert(modules, instance)
		end
	end

	return modules
end)

xAPI.AddGlobal({"cloneref"}, function(self, object: Instance): Instance
	xAPI.TypeCheck(1, object, {"Instance", "userdata"})

	local clone = {}
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)

	meta.__newindex = function(self, key, value)
		object[key] = value
		clone[key] = value
	end

	meta.__index = function(self, key, value)
		local index = object[key]

		if type(index) == "function" then
			return function(self, ...)
				return index(self, ...)
			end
		end

		return index
	end

	meta.__tostring = function(self)
		return tostring(object)
	end

	xAPI.Data.InstanceReferences[object] = clone

	return proxy
end)

xAPI.AddGlobal({"compareinstances"}, function(self, a: Instance, b:Instance): boolean
	xAPI.TypeCheck(1, a, {"Instance", "userdata"})
	xAPI.TypeCheck(2, b, {"Instance", "userdata"})

	local ref_a = xAPI.Data.InstanceReferences[a]
	local ref_b = xAPI.Data.InstanceReferences[b]

	return not (ref_a == b or ref_b == a)
end)

xAPI.AddGlobal({"isscriptable"}, function(self, object: Instance, property: string): boolean
	xAPI.TypeCheck(1, object, {"Instance", "userdata"})
	xAPI.TypeCheck(2, property, {"string"})

	local objectProperty
	pcall(function()
		objectProperty = object[property]
	end)

	if objectProperty ~= nil then
		return true
	end

	return false
end)

xAPI.AddGlobal({"gethui"}, function(self): Instance
	return xAPI.Data.UI
end)

xAPI.AddGlobal({"getconnections"}, function(self, signal: RBXScriptSignal): {
	Disable: () -> (),
	Enable: () -> (),
	Enabled: false,
	Fire: (...any) -> (...any),
	Function: (...any) -> (...any)
}

	xAPI.TypeCheck(1, signal, {"RBXScriptSignal", "userdata"})

	return xAPI.Data.Connections[signal]
end)

xAPI.AddGlobal({"getcallbackvalue"}, function(self, object: Instance, property: string)
	xAPI.TypeCheck(1, object, {"Instance", "userdata"})
	xAPI.TypeCheck(2, property, {"string"})

	return (xAPI.Data.CallbackValues[xAPI.Data.Wrapped[object]])[property]
end)

-- Miscellaneous
xAPI.AddGlobal({"setfpscap"}, function(self, newFPS: number)
	xAPI.TypeCheck(1, newFPS, {"number"})

	if newFPS <= 0 then newFPS = math.huge end

	xAPI.Data.FPS_Cap = math.clamp(newFPS, 0, math.huge)
end)

xAPI.AddGlobal({"identifyexecutor", "getexecutorname"}, function(self): (string, string)
	return "xAPI", "v3.6.3"
end)

xAPI.AddGlobal({"_G", "shared"}, {})

xAPI.AddGlobal({"getgc"}, function(self, includeTables: boolean): {any}
	xAPI.TypeCheck(1, includeTables, {"boolean"}, true)

	if includeTables == false then
		local gc = {}

		for globalName, globalValue in xAPI.Data.GC do
			if type(globalValue) == "table" or type(globalValue) == "userdata" then
				continue
			end

			gc[globalName] = globalValue
		end
	end

	return xAPI.Data.GC
end)

xAPI.AddGlobal({"lz4compress"}, function(self, data: string)
	xAPI.TypeCheck(1, data, {"string"})

	return xAPI.Libraries.LZ4.compress(data)
end)

xAPI.AddGlobal({"lz4decompress"}, function(self, data: string)
	xAPI.TypeCheck(1, data, {"string"})

	return xAPI.Libraries.LZ4.decompress(data)
end)

xAPI.AddGlobal({"iswindowactive", "isrbxactive", "isgameactive"}, function(self)
	return xAPI.Data.IsWindowActive
end)

-- Crypt
xAPI.AddGlobal({"base64encode", "base64_encode"}, function(self, data: string): string
	xAPI.TypeCheck(1, data, {"string"})

	return xAPI.Libraries.Crypt.base64.b64_encode(data)
end, {xAPI.Env.crypt})

xAPI.AddGlobal({"base64decode", "base64_decode"}, function(self, data: string): string
	xAPI.TypeCheck(1, data, {"string"})

	return xAPI.Libraries.Crypt.base64.b64_decode(data)
end, {xAPI.Env.crypt})

xAPI.AddGlobal({"random"}, function(self, size: number): string
	xAPI.TypeCheck(1, size, {"number"})

	local result = ""

	for _ = 1, size do
		result ..= string.char(math.random(0, 255))
	end

	return result
end, {xAPI.Env.crypt})

xAPI.AddGlobal({"generatebytes"}, function(self, size: number): string
	xAPI.TypeCheck(1, size, {"number"})

	return xAPI.Env.crypt.base64_encode(xAPI.Env.crypt.random(size))
end, {xAPI.Env.crypt})

xAPI.AddGlobal({"hash"}, function(self, data: string, algorithm: string): string
	xAPI.TypeCheck(1, data, {"string"})
	xAPI.TypeCheck(2, algorithm, {"string"})

	local algorithm = xAPI.Libraries.Crypt.hashlib[algorithm:lower():gsub("-", "_")]

	assert(algorithm, "Encryption algorithm not found")

	return algorithm(data)
end, {xAPI.Env.crypt})

-- File system
local function parsePath(path: string): {any}
	local current = xAPI.Data.Workspace
	local history = ""

	for _, subPath in path:split("/") do
		local found = current[subPath]
		if found then
			if found.type == "file" then
				return found
			else
				current = found
			end
		else
			return current
		end

		history ..= "/"..subPath
	end

	return current
end

xAPI.AddGlobal({"isfile"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local file = parsePath(path)

	if not file or (file and file.type ~= "file") then
		return false
	end

	return true
end)

xAPI.AddGlobal({"isfolder"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local folder = parsePath(path)

	local filename = path:split("/")
	filename = filename[#filename]

	if path == filename and (folder and folder.type == "folder") then
		return true
	else
		return false
	end
end)

xAPI.AddGlobal({"writefile"}, function(self, path: string, data: string)
	xAPI.TypeCheck(1, path, {"string"})
	xAPI.TypeCheck(2, data, {"string"})

	local filename = path:split("/")
	filename = filename[#filename]

	local path = path:split("/")
	path[#path] = nil

	parsePath(table.concat(path, "/"))[filename] = {
		type	= "file",
		name	= filename,
		content	= data,
		path	= table.concat(path, "/").."/"..filename
	}
end)

xAPI.AddGlobal({"readfile"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local path = parsePath(path)

	return path.content
end)

xAPI.AddGlobal({"listfiles"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local path = parsePath(path)

	if path.type == "file" then
		error("Cannot traverse file", 3)
	end

	local function traverse(a)
		local files = {}

		for _, obj in a do
			if obj.type == "folder" then
				table.insert(files, table.concat(traverse(obj), "/"))
			else
				table.insert(files, obj.path)
			end
		end

		return files
	end

	return traverse(path)
end)

xAPI.AddGlobal({"makefolder"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local filename = path:split("/")
	filename = filename[#filename]

	parsePath(path)[filename] = {
		type = "folder",
		name = filename,
		path = path.."/"..filename
	}
end)

xAPI.AddGlobal({"appendfile"}, function(self, path: string, data: string)
	xAPI.TypeCheck(1, path, {"string"})

	local filename = path:split("/")
	filename = filename[#filename]

	local path = parsePath(path)

	if (path and path.type ~= "file") then
		error("Path is not a file", 3)
	end

	path.content ..= data
end)

xAPI.AddGlobal({"delfolder"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local foldername = path:split("/")
	foldername = foldername[#foldername]

	local path = path:split("/")
	path[#path] = nil

	parsePath(table.concat(path, "/"))[foldername] = nil
end)

xAPI.AddGlobal({"delfile"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local filename = path:split("/")
	filename = filename[#filename]

	local path = path:split("/")
	path[#path] = nil

	parsePath(table.concat(path, "/"))[filename] = nil
end)

xAPI.AddGlobal({"loadfile", "dofile"}, function(self, path: string)
	xAPI.TypeCheck(1, path, {"string"})

	local path = parsePath(path)

	if (path and path.type == "file") then
		return xAPI.Env.loadstring(path.content)
	end
end)

-- WebSocket
do
	local WebSocketClass = {}
	WebSocketClass.__index		= WebSocketClass
	WebSocketClass.Closed		= false
	WebSocketClass.Send			= function(self, message: string)
		assert((self and self.OnMessage), "Expected ':' not '.' calling member function Send")
		assert(self.Closed == false, "Connection already closed")

		xAPI.TypeCheck(1, message, {"string"})

		self.OnMessage:Fire(message)
	end

	WebSocketClass.Close		= function(self)
		assert((self and self.OnClose), "Expected ':' not '.' calling member function Close")
		assert(self.Closed == false, "Connection already closed")

		self.Closed = true

		self.OnClose:Fire()
	end

	WebSocketClass.new			= function()
		local closeConnection = xAPI.Libraries.Signal.new()
		local messageConnection = xAPI.Libraries.Signal.new()

		return setmetatable({
			OnClose = closeConnection,
			OnMessage = messageConnection
		}, WebSocketClass)
	end

	xAPI.AddGlobal({"connect"}, function(self)
		return WebSocketClass.new()
	end, {xAPI.Env.WebSocket})
end

-- Loops and connections
task.spawn(function()
	local tick = os.clock()
	while true do
		if xAPI.Data.FPS_Cap <= 0 then task.wait() continue end
		repeat until os.clock() - tick >= 1 / xAPI.Data.FPS_Cap
		tick = os.clock()
		task.wait()
	end
end)

game.DescendantAdded:Connect(function(desc)
	table.insert(xAPI.Data.Instances, desc)
end)

for _, desc in game:GetDescendants() do
	table.insert(xAPI.Data.Instances, desc)
end

Services.UserInputService.WindowFocused:Connect(function()
	xAPI.Data.IsWindowActive = true
end)

Services.UserInputService.WindowFocusReleased:Connect(function()
	xAPI.Data.IsWindowActive = false
end)

---- Wrapping

-- Connection class
local ConnectionClass 		= {}
ConnectionClass.__index 	= ConnectionClass

ConnectionClass.Enabled 	= true
ConnectionClass.Fire		= function(self, ...)
	assert((self and self.Function), "Expected ':' not '.' calling member function Fire")

	return self.Function(...)
end
ConnectionClass.Defer		= function(self, ...)
	assert((self and self.Function), "Expected ':' not '.' calling member function Defer")

	local args = {...}
	task.defer(function()
		self.Function(unpack(args))
	end)
end
ConnectionClass.Disconnect	= function(self)
	assert((self and self.Disconnected ~= nil), "Expected ':' not '.' calling member function Disconnect")

	self.Disconnected = true
end
ConnectionClass.Disable		= function(self)
	assert((self and self.Enabled ~= nil), "Expected ':' not '.' calling member function Disable")

	self.Enabled = false
end
ConnectionClass.Enable		= function(self)
	assert((self and self.Enabled ~= nil), "Expected ':' not '.' calling member function Enable")

	self.Enabled = true
end

ConnectionClass.new			= function(signal: RBXScriptSignal, oldConnection: RBXScriptConnection, func: (...any) -> ())
	oldConnection:Disconnect()
	local connection, newClass
	connection = task.spawn(function()
		while true do
			local args = {signal:Wait()}

			if (newClass and newClass.Enabled == true and not newClass.Disconnected) then
				func(unpack(args))
			elseif (newClass and newClass.Disconnected == true) then
				break
			end
		end
	end)

	newClass = setmetatable({
		Connection = oldConnection,
		Thread = connection,
		Function = func,
		ForeignState = false,
		LuaConnection = xAPI.Data.UserFunction == debug.info(4, "f")
	}, ConnectionClass)

	return newClass
end

-- Instance wrapper
wrap = function(a: Instance | any)
	if type(a) == "userdata" then
		for _, wrapped in xAPI.Data.Wrapped do
			if wrapped == a then
				return wrapped
			end
		end

		local proxy = newproxy(true)
		local meta = getmetatable(proxy)

		xAPI.Data.Wrapped[proxy] = a

		meta.__index = function(self, key)
			self = xAPI.Data.Wrapped[self]
			local target = self[key]

			if typeof(self) == "Instance" then
				for type, value in customBehaviour do
					if self:IsA(type) then
						if value[key] ~= nil then
							return wrap(value[key])
						end
					end
				end
			elseif typeof(self) == "RBXScriptSignal" and key:lower() == "connect" then
				return function(self, func)
					self = xAPI.Data.Wrapped[self]

					local connection = self:Connect(func)

					if not xAPI.Data.Connections[self] then
						xAPI.Data.Connections[self] = {}
					end

					table.insert(xAPI.Data.Connections[self], ConnectionClass.new(self, connection, func))
				end
			end

			if type(target) == "function" then
				return function(self, ...)
					self = xAPI.Data.Wrapped[self]

					return wrap(target(self, ...))
				end
			end

			return wrap(target)
		end

		meta.__tostring = function(self)
			self = xAPI.Data.Wrapped[self]

			return tostring(self)
		end

		meta.__newindex = function(self, key, value)
			self = xAPI.Data.Wrapped[self]

			if type(value) == "string" then
				local customAssetPrefix = "rbxasset://custom_assets/"
				if value:sub(1, #customAssetPrefix) == customAssetPrefix then
					local id = value:sub(#customAssetPrefix + 1)
					value = xAPI.Data.AssetCache[id]
				end
			end

			self[key] = xAPI.Data.Wrapped[value] or value 

			if type(value) == "function" then
				if not xAPI.Data.CallbackValues[self] then
					xAPI.Data.CallbackValues[self] = {}
				end

				xAPI.Data.CallbackValues[self][key] = value
			end
		end

		meta.__typeof = typeof(a)

		xAPI.Data.Metatables[proxy] = {meta, "The metatable is locked"}

		return proxy
	else
		return a
	end
end

customBehaviour = {
	DataModel = {
		GetService = function(self, serviceName: string): Instance
			self = xAPI.Data.Wrapped[self]

			if serviceName == "CoreGui" then
				return wrap(xAPI.Data.UI)
			end

			return wrap(self:GetService(serviceName))
		end,

		Shutdown = function(self)
			self = xAPI.Data.Wrapped[self]

			self:GetService("Players").LocalPlayer:Kick("Shutdown")
		end,

		CoreGui = wrap(xAPI.Data.UI)
	},
	UserInputService = {
		GetPlatform = function(self)
			self = xAPI.Data.Wrapped[self]
			-- https://devforum.roblox.com/t/best-method-of-detecting-the-players-platform-eg-mobile-xbox-computer/248835/6
			local options = {}
			
			if Services.GuiService:IsTenFootInterface() then
				options = {Enum.Platform.XBoxOne, Enum.Platform.PS4, Enum.Platform.XBox360, Enum.Platform.PS5, Enum.Platform.PS3}
			elseif self.TouchEnabled and not self.MouseEnabled then
				options = {Enum.Platform.Android, Enum.Platform.IOS}
			else
				options = {Enum.Platform.Windows, Enum.Platform.OSX, Enum.Platform.UWP}
			end
			
			return options[math.random(1, #options)]
		end,
	}
}

xAPI.AddGlobal({"new"}, function(self, className, parent)
	local newInstance = Instance.new(className, xAPI.Data.Wrapped[parent])
	table.insert(xAPI.Data.Instances, newInstance)
	
	return wrap(newInstance)
end, {xAPI.Env.Instance})

xAPI.AddGlobal({"decompile"}, function(self, target: userdata | (...any) -> (...any) | string | proto)
	return "-- Cannot decompile scripts within Roblox"
end)

do
	local w_workspace = wrap(workspace)
	xAPI.AddGlobal({"game"}, wrap(game))
	xAPI.AddGlobal({"workspace"}, w_workspace)
	xAPI.AddGlobal({"Workspace"}, w_workspace)
end

xAPI.AddGlobal({"typeof"}, function(self, value: any): string
	local meta = getmetatable(value)

	return (meta and meta.__typeof) or typeof(value)
end)

---- Export globals

return function()
	xAPI.Data.UserFunction = debug.info(3, "f")
	local Env = getfenv(2)

	if Env.script then
		Env.script = wrap(Env.script)
	end

	local count = 0
	for globalName, globalValue in xAPI.Env do
		if Env[globalName] then
			if type(Env[globalName]) == "table" then
				local old = Env[globalName]

				Env[globalName] = table.clone(old)

				for name, value in globalValue do
					Env[globalName][name] = value
				end
				continue
			end
		end

		Env[globalName] = globalValue
		count += 1
	end

	task.spawn(function()
		while task.wait() do
			for globalName, globalValue in Env do
				xAPI.Data.GC[globalName] = globalValue
			end
		end
	end)

	print(("/ xAPI III / Loaded %d globals!"):format(count))

	task.wait(0.1) -- wait for everything to initialize
end