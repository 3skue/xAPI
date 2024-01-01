local Hashlib = require(script:WaitForChild("HashLib"))

return {
	hashlib = Hashlib,
	base64 = {
		b64_encode = Hashlib.base64_encode,
		b64_decode = Hashlib.base64_decode
	}
}
