xAPI
====

xAPI is a fast, flexible and powerful exploit simulator for Roblox written in pure Luau.

It follows the [Unified Naming Convention](https://github.com/unified-naming-convention/NamingStandard/tree/main) and includes the following features:

- Raw metatable access,
- Function hooking,
- An integrated filesystem,
- [Instance wrapping](https://devforum.roblox.com/t/wrapping-with-metatables-or-how-to-alter-the-functionality-of-roblox-objects-without-touching-them/221611) and more!

You can use xAPI to test out your anticheat, Learn more about exploiting or strengthen your game's security.
You can also expand xAPI and change it to your liking easily with it's simplistic and super-flexible structure.

Installation
----

Go to Releases and get your preferred version.
Once you have acquired your desired release, go to the script you want to use it in and type the following:

```lua
require(Path.to.xAPI)()
```

The globals will automatically be loaded into your environment.

Why xAPI?
----

xAPI dynamically loads globals into a table and only exports the globals when you call the loader function for peak performance. On top of that, xAPI includes Type Checking and can import globals into standard libraries.
