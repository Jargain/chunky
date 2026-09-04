const ReplicatedStorage = game:GetService("ReplicatedStorage")
const chunky = require(ReplicatedStorage.Shared.chunky)
print("Hello world, from client!")
const Remote = ReplicatedStorage.Remote :: RemoteEvent

local schema = chunky.Schema({
    number1 = chunky.types.S8,
    table1 = chunky.types.Table({
        number2 = chunky.types.S8,
        table2 = chunky.types.Table({
            number3 = chunky.types.S8,
            bool1 = chunky.types.BOOL,
            string1 = chunky.types.String16,
            color1 = chunky.types.Color3,
            vector1 = chunky.types.Vector3,
            cframe1 = chunky.types.CFrame
        })
    })
})

Remote.OnClientEvent:Connect(function(value)
    if typeof(value) == "buffer" then
        print(chunky.deserialize(schema, value))
        return
    end
    print(value)
end)
