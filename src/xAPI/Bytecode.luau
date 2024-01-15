local vLuau = require(script.vLuau).luau_execute

return {
	loadstring = function(source: string, chunkName: string): () -> ()
		return vLuau(source, getfenv(4), chunkName or "xAPI")
	end,
}
