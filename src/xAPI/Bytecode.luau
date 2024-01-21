local vLuau = require(script.vLuau)

return {
	loadstring = function(source: string, chunkName: string): () -> ()
		return vLuau(source, getfenv(4), chunkName or "xAPI")
	end,
	
	dumpstring = function(source: string, chunkName: string): string
		return vLuau.luau_compile(source, chunkName)
	end,
}