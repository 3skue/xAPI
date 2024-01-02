![xAPI Logo|690x100](https://devforum-uploads.s3.us-east-2.amazonaws.com/uploads/original/5X/1/d/b/d/1dbda3c0c2dc8eaca48de1cf6573698f185b0cc2.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIATSAZKDNRF74OVZGC%2F20240102%2Fus-east-2%2Fs3%2Faws4_request&X-Amz-Date=20240102T114930Z&X-Amz-Expires=300&X-Amz-SignedHeaders=host&X-Amz-Signature=8c0c595b625ae78ca2901b262bc80183c58fa75c081157c6c8a25e1019653ec3)

xAPI
====

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
