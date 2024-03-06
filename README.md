![xAPI Logo|690x100](https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/6/d/f/5/6df5d571c93d17dc7d7db717f8cb15248defd552.png)

xAPI
====

> The revamp is going to be released later. By later I mean maybe a few months later.
>
> The revamp is going to be more of an actual pentesting/debugging tool inside of Roblox as opposed to being just an interface to port scripts from Synapse X to Studio.
> Here's an rough timeline if anyone is a little unpatient:

- [X] Metamethod hooks
- [ ] Function decompiler (W.I.P)
- [ ] Metatable hooks (Maybe)

> "Meta*method* hook" means being able to fire seperate raw metamethods without having to invoke for example the dot (a.b) or table index (a[b]) operator for __index, while "meta*table* hook" means being able to intercept metamethods

> Current decompilation progress:

- [X] Hello, World
```lua
print(decomp.func(function()
	print("Hello, world!")
end))

local _1 = print;
_1("Hello, world!");
```
- [ ] Simple Math
- [ ] Keywords (math operators, while, for, if, etc.)

xAPI is a fast, flexible and powerful exploit simulator for Roblox written in pure Luau.

It follows the [Unified Naming Convention](https://github.com/unified-naming-convention/NamingStandard/tree/main) and includes...

- Raw metatable access,
- Function hooking,
- An integrated filesystem,
- [Instance wrapping](https://devforum.roblox.com/t/wrapping-with-metatables-or-how-to-alter-the-functionality-of-roblox-objects-without-touching-them/221611) and more!

You can use xAPI to test out your anticheat, Learn more about exploiting or discover security weaknesses in your games.
You can also expand xAPI and change it to your liking easily with it's simplistic and super-flexible structure.

Installation
----

1. Go to [releases](https://github.com/3skue/xAPI/releases/) and download the latest version or get the [Roblox module](https://create.roblox.com/marketplace/asset/15836677813/)
2. Insert the module in your game, preferrably inside ReplicatedStorage
3. Write at the top of your script:
   
   ```lua
   require(game.ReplicatedStorage.xAPI)()
   ```
4. The globals will automatically load in, and you're done!

Contributing
----

- Go [here](https://github.com/3skue/xAPI/pulls) for improvements
- Go [here](https://github.com/3skue/xAPI/issues) for bugs and questions

License
----

Distributed under the MIT License. See `LICENSE` for more information.

xAPI is not produced, developed or otherwise maintained by the Roblox Corporation.
