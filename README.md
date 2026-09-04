# chunky

A lightweight serialization library for Roblox Luau that converts structured data into compact binary buffers.

## Features

- **Binary serialization** - Convert Lua tables into compact buffer objects
- **Schema-based** - Define data structure once, reuse everywhere
- **Type-safe** - Built-in type checking with Luau's strict type system
- **Nested tables** - Support for complex nested data structures
- **Custom types** - Create your own serializable types with custom read/write functions

## Supported Types

| Type | Description |
|------|-------------|
| `S8`, `U8` | Signed/unsigned 8-bit integers |
| `S16`, `U16` | Signed/unsigned 16-bit integers |
| `S32`, `U32` | Signed/unsigned 32-bit integers |
| `F32` | 32-bit float values |
| `BOOL` | Boolean values |
| `Vector3` | Roblox Vector3 |
| `CFrame` | Roblox CFrame |
| `Color3` | Roblox Color3 |
| `String8` | String with 8-bit length prefix (max 255 chars) |
| `String16` | String with 16-bit length prefix (max 65,535 chars) |
| `String32` | String with 32-bit length prefix |
| `buffer8`, `buffer16`, `buffer32` | Binary buffer data |
| `Table` | Nested table schema |

## Usage

```lua
local chunky = require(path.to.chunky)

-- Define a schema
local playerSchema = chunky.Schema({
    userId = chunky.types.U32,
    username = chunky.types.String16,
    position = chunky.types.Vector3,
    isActive = chunky.types.BOOL,
    settings = chunky.types.Table({
        volume = chunky.types.U8,
        showPlayers = chunky.types.BOOL
    })
})

-- Serialize data
local data = {
    userId = 12345,
    username = "player1",
    position = Vector3.new(1, 2, 3),
    isActive = true,
    settings = {
        volume = 80,
        showPlayers = true
    }
}

local buffer = chunky.serialize(playerSchema, data)

-- Deserialize data
local restored = chunky.deserialize(playerSchema, buffer)
print(restored.username) -- "player1"
```

## Create custom types!
```lua
local customVolume = {
    byteLength = 1,
    read_func = function(self, buffer, offset)
        return math.min(buffer.readu8(buffer, offset), 100), self.byteLength
    end,
    write_func = function(self, buffer, offset, value)
        buffer.writeu8(buffer, offset, math.min(value, 100))
        return self.byteLength
    end,
    type = "generic"
}
```

### Notes

- Custom types need a predifined bytelength for buffer initialization, offset is returned by the read and write function
- Field names must match between schema and data
- Nested tables require explicit `chunky.types.Table` schemas