const ReplicatedStorage = game:GetService("ReplicatedStorage")
local chunky = require(ReplicatedStorage.Shared.chunky)
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

local dataTest = {
    number1 = 1,
    table1 = {
        number2 = 2,
        table2 = {
            number3 = 3,
            bool1 = true,
            color1 = Color3.fromRGB(255,255,255),
            string1 = "Hello world!",
            vector1 = Vector3.new(1,1,1),
            cframe1 = CFrame.new(1,20,1)
        }
    }
}



while true do
    print(dataTest)
    print(schema)
    local b = chunky.serialize(schema, dataTest)
    print(b)
    print(chunky.deserialize(schema, b))
    Remote:FireAllClients(b)
    Remote:FireAllClients(dataTest)
    task.wait(1)
end

