local module = {}

const chunky = require(script.Parent.chunky)

local customVolume = {
    byteLength = 1,
    read_func = @native function(self: chunky.chunkyPrimativeType, b: buffer, offset: number): (number,number)
        return math.min(buffer.readu8(b, offset), 100), self.byteLength
    end,
    write_func = @native function(self: chunky.chunkyPrimativeType, b: buffer, offset: number, value: number): number
        buffer.writeu8(b, offset, math.min(value,100)); return self.byteLength
    end,
    type = "generic"
} :: chunky.chunkyPrimativeType

module.userSchema = chunky.Schema({
    userId = chunky.types.U32,
    username = chunky.types.String16,
    avatarUrl = chunky.types.String32,
    displayname = chunky.types.String16,
    accountAgeMinutes = chunky.types.U32,
    serialized_array = chunky.types.buffer16,
    settingsTable = chunky.types.Table({
        showPlayers = chunky.types.BOOL,
        lowGraphics = chunky.types.BOOL,
        volume = customVolume
    })
})


function module.getRandomUser()
    local buf = buffer.create(2^14)
    buffer.fill(buf, 0, 10)
    return {
        userId = math.random(1, 2^28),
        username = "user_"..math.random(1, 2^13),
        avatarUrl = "user_"..math.random(1, 2^28),
        displayname = "user_"..math.random(1, 2^13),
        accountAgeMinutes = math.random(1, 2^13),
        serialized_array = buf,
        settingsTable = {
            showPlayers = (math.random(1,2) == 1),
            lowGraphics = (math.random(1,2) == 1),
            volume = math.random(1, 99)
        }
    }
end

function module.getRandomUsers(n: number)
    local users = {}
    for i = n, 1, -1 do
        table.insert(users, module.getRandomUser())
    end
    return users
end

function module.serializeUsers(users)
    local serialized = {}
    for i,v in ipairs(users) do
        serialized[i] = chunky.serialize(module.userSchema, v)
    end
    return serialized
end

function module.deserializeUsers(users)
    local deserialized = {}
    for i,v in ipairs(users) do
        deserialized[i] = chunky.deserialize(module.userSchema, v)
    end
    return deserialized
end

return module