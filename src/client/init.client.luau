const ReplicatedStorage = game:GetService("ReplicatedStorage")
const schemas = require(ReplicatedStorage.Shared.schemas)
local remote1 = ReplicatedStorage.Remote1 :: RemoteEvent
local remote2 = ReplicatedStorage.Remote2 :: RemoteEvent
local manageRemote = ReplicatedStorage.ManageRemote :: RemoteEvent
const iris = require(ReplicatedStorage.Packages.iris).Init()

local total_time = 0

local function handle_remote1(data)
    print("[Chunky-Test-R1]: Unserialized data recieved:")
    print(data)
end

local function handle_remote2(data)
    print("[Chunky-Test-R2]: Serialized data recieved:")
    print(schemas.deserializeUsers(data))
end

local function handle_manage(request: string, value: number?)
    if request == "finishedTest" then
        total_time = value
    end
end

remote1.OnClientEvent:Connect(handle_remote1)
remote2.OnClientEvent:Connect(handle_remote2)
manageRemote.OnClientEvent:Connect(handle_manage)
iris:Connect(function()
iris.Window({ "Testing window "})
do
    iris.Text({"Run user Test"})

    local user_input_count = iris.State(0)
    local inputCount = iris.InputNum({"Users"})
    iris.Separator()
    local users_drag = iris.DragNum({"Users"})
    if inputCount:numberChanged() then
        user_input_count:set(inputCount.state.number:get())
        users_drag.state.number:set(inputCount.state.number:get())
    end
    if users_drag:numberChanged() then
        user_input_count:set(users_drag.state.number:get())
        inputCount.number:set(users_drag.state.number:get())
    end

    local run_button = iris.Button({"Run test with "..user_input_count:get() .. " users"})
    if run_button.clicked() then
        manageRemote:FireServer("userTest", user_input_count:get() or 1)
    end

    iris.Text({"Last total time: "..total_time})

end
iris.End()
end)
