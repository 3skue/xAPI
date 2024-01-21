-- Optimized from Synapse X
-- If saveinstance doesn't properly work, blame Synapse
-- https://github.com/Acrillis/SynapseX/blob/9b58c725c768aeb5cc00aba73254bc02ca289bc7/Synapse%20Scripts/InitScript.lua#L740

saveinstance = function(xAPI, ...)
	local buffersize
	local placename
	local savebuffer
	
	local b64encode = xAPI.Env.crypt.b64encode
	
	local OPTIONS = {
		mode = 'optimized',
		noscripts = false,
		scriptcache = true,
		decomptype = "legacy",
		timeout = 30
	}

	do
		local tab_op = (...)
		if type(tab_op) == 'table' then
			for idx, opt in tab_op do
				if OPTIONS[idx] ~= nil then
					OPTIONS[idx] = opt
				end
			end
		end
	end

	local pnolist = {
		Instance = {
			Archivable = true,
			ClassName = true,
			DataCost = true,
			Parent = true,
			RobloxLocked = true
		},
		BasePart = {
			Position = true,
			Rotation = true
		},
		BaseScript = {
			LinkedSource = true
		}
	}

	local pesplist = {
		UnionOperation = {
			AssetId = 'Content',
			ChildData = 'BinaryString',
			FormFactor = 'Token',
			InitialSize = 'Vector3',
			MeshData = 'BinaryString',
			PhysicsData = 'BinaryString'
		},
		MeshPart = {
			InitialSize = 'Vector3',
			PhysicsData = 'BinaryString'
		},
		Terrain = {
			SmoothGrid = 'BinaryString',
			MaterialColors = 'BinaryString'
		}
	}
	local ldecompile = function()
		return "-- Cannot decompile scripts within Roblox"
	end
	local slist
	do
		local mode = tostring(OPTIONS.mode):lower()
		local tmp = { }
		if mode == 'full' then
			local _list_0 = game:GetChildren()
			for _index_0 = 1, #_list_0 do
				local x = _list_0[_index_0]
				table.insert(tmp, x)
			end
		elseif mode == 'optimized' then
			local _list_0 = {
				'Chat',
				'InsertService',
				'JointsService',
				'Lighting',
				'ReplicatedFirst',
				'ReplicatedStorage',
				'ServerStorage',
				'StarterGui',
				'StarterPack',
				'StarterPlayer',
				'Teams',
				'Workspace'
			}
			for _index_0 = 1, #_list_0 do
				local x = _list_0[_index_0]
				table.insert(tmp, game:FindService(x))
			end
		elseif mode == 'scripts' then
			local hier = game:GetDescendants()
			local cache = { }
			for i, s in hier do
				if s.ClassName == 'LocalScript' or s.ClassName == 'ModuleScript' then
					local top = s
					while top.Parent and top.Parent ~= game do
						top = top.Parent
					end
					if top.Parent then
						cache[top] = true
					end
				end
			end
			
			for i in cache do
				table.insert(tmp, i)
			end
		end
		slist = tmp
	end
	
	local ilist
	
	do
		local t = { }

		for _, v in {
			'BubbleChat',
			'Camera',
			'CameraScript',
			'ChatScript',
			'ControlScript',
			'ClientChatModules',
			'ChatServiceRunner',
			'ChatModules'
			} do
			t[v] = true
		end

		ilist = t
	end

	local pattern = '["&<>\']'

	local escapes = {
		['"'] = '&quot;',
		['&'] = '&amp;',
		['<'] = '&lt;',
		['>'] = '&gt;',
		['\''] = '&apos;'
	}

	local getData = function()
		local classes = require(script.ApiDump).Classes
		local classData = { }

		for i0, v0 in classes do
			local members = v0.Members
			local data = { }

			data.Name = v0.Name
			data.Superclass = v0.Superclass
			data.Properties = { }
			classData[v0.Name] = data

			for i1, v1 in members do
				if v1.MemberType == 'Property' then
					local serialized = v1.Serialization

					if serialized.CanLoad then
						local useless = false

						if v1.Tags then
							local tags = v1.Tags
							useless = table.find(tags, "Deprecated") or table.find(tags, "NotScriptable")
						end

						if not useless then
							table.insert(data.Properties, {
								Name = v1.Name,
								ValueType = v1.ValueType.Name,
								Special = false
							})
						end
					end
				end
			end
		end

		for i, v in pesplist do
			local properties = classData[i].Properties

			for name, value in v do
				table.insert(properties, {
					Name = name,
					ValueType = value,
					Special = true
				})
			end
		end

		return classData
	end
	local plist
	
	do
		local ran, result = pcall(getData)
		if ran then
			plist = result
		else
			return result
		end
	end
	
	local properties = setmetatable({ }, {
		__index = function(self, name)
			local proplist = { }
			local layer = plist[name]
			while layer do
				local _list_0 = layer.Properties
				for _index_0 = 1, #_list_0 do
					local p = _list_0[_index_0]
					table.insert(proplist, p)
				end
				layer = plist[layer.Superclass]
			end
			table.sort(proplist, function(a, b)
				return a.Name < b.Name
			end)
			self[name] = proplist
			return proplist
		end
	})
	local identifiers = setmetatable({
		count = 0
	}, {
		__index = function(self, obj)
			self.count = self.count + 1
			local rbxi = 'RBX' .. self.count
			self[obj] = rbxi
			return rbxi
		end
	})
	local typesizeround
	typesizeround = function(s)
		return math.floor(buffersize / (0x400 ^ s) * 10) / 10
	end
	local getsizeformat
	getsizeformat = function()
		local res
		for i, v in ipairs({
			'b',
			'kb',
			'mb',
			'gb',
			'tb'
			}) do
			if buffersize < 0x400 ^ i then
				res = typesizeround(i - 1) .. v
				break
			end
		end
		return res
	end
	local getsafeproperty
	getsafeproperty = function(i, name)
		return i[name]
	end
	
	local getplacename = function()
		return tostring(game.GameId)..".rbxlx"
	end
	
	local savecache
	savecache = function()
		local savestr = table.concat(savebuffer)

		buffersize = buffersize + #savestr
		savebuffer = { }

		xAPI.Env.appendfile(placename, savestr)

		return task.wait()
	end

	local savehierarchy
	savehierarchy = function(h)
		local savepr = #savebuffer

		if savepr > 0x1600 then
			savecache()
		end

		for i0, v0 in h do
			local _continue_0 = false

			repeat
				local sprops
				local clsname = v0.ClassName

				if ilist[v0.Name] or not plist[clsname] then
					_continue_0 = true
					break
				end

				local props = properties[clsname]
				savebuffer[#savebuffer + 1] = '<Item class="' .. clsname .. '" referent="' .. identifiers[v0] .. '"><Properties>'

				for i1, v1 in props do
					local _continue_1 = false
					repeat
						local value
						local tag
						local raw
						if v1.Special then
							if not sprops then
								sprops = {}
							end
							raw = sprops[v1.Name]
							if raw == nil then
								_continue_1 = true
								break
							end
						else
							local isok = v1.Ok
							local _exp_0 = isok
							if nil == _exp_0 then
								local ok, what = pcall(getsafeproperty, v0, v1.Name)
								v1.Ok = ok
								if ok then
									raw = what
								else
									_continue_1 = true
									break
								end
							elseif true == _exp_0 then
								raw = v0[v1.Name]
							elseif false == _exp_0 then
								_continue_1 = true
								break
							end
						end
						local _exp_0 = v1.ValueType
						if 'BrickColor' == _exp_0 then
							tag = 'int'
							value = raw.Number
						elseif 'Color3' == _exp_0 then
							tag = 'Color3'
							value = '<R>' .. raw.r .. '</R><G>' .. raw.g .. '</G><B>' .. raw.b .. '</B>'
						elseif 'ColorSequence' == _exp_0 then
							tag = 'ColorSequence'
							local ob = { }
							local _list_0 = raw.Keypoints
							for i2, v2 in _list_0 do
								ob[#ob + 1] = v2.Time .. ' ' .. v2.Value.r .. ' ' .. v2.Value.g .. ' ' .. v2.Value.b .. ' 0'
							end
							value = table.concat(ob, ' ')
						elseif 'Content' == _exp_0 then
							tag = 'Content'
							value = '<url>' .. raw:gsub(pattern, escapes) .. '</url>'
						elseif 'BinaryString' == _exp_0 then
							tag = 'BinaryString'
							if v1.Name == "SmoothGrid" or v1.Name == "MaterialColors" then
								value = "<![CDATA[" .. b64encode(raw) .. "]]>"
							else
								value = b64encode(raw)
							end
						elseif 'CoordinateFrame' == _exp_0 then
							local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:components()
							tag = 'CoordinateFrame'
							value = '<X>' .. X .. '</X>' .. '<Y>' .. Y .. '</Y>' .. '<Z>' .. Z .. '</Z>' .. '<R00>' .. R00 .. '</R00>' .. '<R01>' .. R01 .. '</R01>' .. '<R02>' .. R02 .. '</R02>' .. '<R10>' .. R10 .. '</R10>' .. '<R11>' .. R11 .. '</R11>' .. '<R12>' .. R12 .. '</R12>' .. '<R20>' .. R20 .. '</R20>' .. '<R21>' .. R21 .. '</R21>' .. '<R22>' .. R22 .. '</R22>'
						elseif 'NumberRange' == _exp_0 then
							tag = 'NumberRange'
							value = raw.Min .. ' ' .. raw.Max
						elseif 'NumberSequence' == _exp_0 then
							tag = 'NumberSequence'
							local ob = { }
							local _list_0 = raw.Keypoints
							for _index_2 = 1, #_list_0 do
								local v = _list_0[_index_2]
								ob[#ob + 1] = v.Time .. ' ' .. v.Value .. ' ' .. v.Envelope
							end
							value = table.concat(ob, ' ')
						elseif 'PhysicalProperties' == _exp_0 then
							tag = 'PhysicalProperties'
							if raw then
								value = '<CustomPhysics>true</CustomPhysics>' .. '<Density>' .. raw.Density .. '</Density>' .. '<Friction>' .. raw.Friction .. '</Friction>' .. '<Elasticity>' .. raw.Elasticity .. '</Elasticity>' .. '<FrictionWeight>' .. raw.FrictionWeight .. '</FrictionWeight>' .. '<ElasticityWeight>' .. raw.ElasticityWeight .. '</ElasticityWeight>'
							else
								value = '<CustomPhysics>false</CustomPhysics>'
							end
						elseif 'ProtectedString' == _exp_0 then
							tag = 'ProtectedString'
							if v1.Name == 'Source' then
								if v0.ClassName == 'Script' then
									value = '-- Server scripts can NOT be decompiled\n'
								else
									value = '-- Cannot decompile scripts'
								end
							else
								value = raw
							end
							value = value:gsub(pattern, escapes)
						elseif 'Rect2D' == _exp_0 then
							tag = 'Rect2D'
							value = '<min>' .. '<X>' .. raw.Min.X .. '</X>' .. '<Y>' .. raw.Min.Y .. '</Y>' .. '</min>' .. '<max>' .. '<X>' .. raw.Max.X .. '</X>' .. '<Y>' .. raw.Max.Y .. '</Y>' .. '</max>'
						elseif 'UDim2' == _exp_0 then
							tag = 'UDim2'
							value = '<XS>' .. raw.X.Scale .. '</XS>' .. '<XO>' .. raw.X.Offset .. '</XO>' .. '<YS>' .. raw.Y.Scale .. '</YS>' .. '<YO>' .. raw.Y.Offset .. '</YO>'
						elseif 'Vector2' == _exp_0 then
							tag = 'Vector2'
							value = '<X>' .. raw.x .. '</X>' .. '<Y>' .. raw.y .. '</Y>'
						elseif 'Vector3' == _exp_0 then
							tag = 'Vector3'
							value = '<X>' .. raw.x .. '</X>' .. '<Y>' .. raw.y .. '</Y>' .. '<Z>' .. raw.z .. '</Z>'
						elseif 'bool' == _exp_0 then
							tag = 'bool'
							value = tostring(raw)
						elseif 'double' == _exp_0 then
							tag = 'float'
							value = raw
						elseif 'float' == _exp_0 then
							tag = 'float'
							value = raw
						elseif 'int' == _exp_0 then
							tag = 'int'
							value = raw
						elseif 'string' == _exp_0 then
							tag = 'string'
							value = raw:gsub(pattern, escapes)
						else
							if v1.ValueType:sub(1, 6) == 'Class:' then
								tag = 'Ref'
								if raw then
									value = identifiers[raw]
								else
									value = 'null'
								end
							elseif typeof(raw) == 'EnumItem' then
								tag = 'token'
								value = raw.Value
							end
						end
						if tag then
							savebuffer[#savebuffer + 1] = '<' .. tag .. ' name="' .. v1.Name .. '">' .. value .. '</' .. tag .. '>'
						end
						_continue_1 = true
					until true
					if not _continue_1 then
						break
					end
				end
				savebuffer[#savebuffer + 1] = '</Properties>'
				local chl = v0:GetChildren()
				if #chl ~= 0 then
					savehierarchy(chl, savebuffer)
				end
				savebuffer[#savebuffer + 1] = '</Item>'
				_continue_0 = true
			until true
			if not _continue_0 then
				break
			end
		end
	end
	local savefolder = function(n, h)
		local Ref = identifiers[Instance.new('Folder')]
		table.insert(savebuffer, '<Item class="Folder" referent="' .. Ref .. '"><Properties><string name="Name">' .. n .. '</string></Properties>')
		savehierarchy(h)
		return table.insert(savebuffer, '</Item>')
	end
	local savegame = function()
		local plr = game:GetService('Players').LocalPlayer:GetChildren()
		local _nil = xAPI.Env.getnilinstances()
		for i, v in next, _nil do
			if v == game then
				table.remove(_nil, i)
				break
			end
		end

		xAPI.Env.writefile(placename, '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4"><External>null</External><External>nil</External>')
		savehierarchy(slist)
		savefolder('localplayer', plr)
		savefolder('nil', _nil)
		table.insert(savebuffer, '</roblox>')
		return savecache()
	end
	do
		local plys = game:GetService('Players')
		local loc = plys.LocalPlayer
		local _list_0 = plys:GetPlayers()
		for _index_0 = 1, #_list_0 do
			local p = _list_0[_index_0]
			if p ~= loc then
				ilist[p.Name] = true
			end
		end
	end
	do
		placename = getplacename()
		buffersize = 0
		savebuffer = { }

		savegame()
	end
end

return saveinstance