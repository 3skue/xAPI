local compile	= require(script:WaitForChild("Yueliang"))
local interpret	= require(script:WaitForChild("LBI")).load_bytecode

return {
	loadstring = function(source: string, chunkName: string): () -> ()
		return interpret(compile(source, chunkName))
	end,
}
