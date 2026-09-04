const ReplicatedStorage = game:GetService("ReplicatedStorage")
const schemas = require(ReplicatedStorage.Shared.schemas)
local remote1 = ReplicatedStorage.Remote1 :: RemoteEvent
local remote2 = ReplicatedStorage.Remote2 :: RemoteEvent
local manageRemote = ReplicatedStorage.ManageRemote :: RemoteEvent

local function run_userstest(n: number)
    local start_time = time()
    local users = schemas.getRandomUsers(n)
    print("[Chunky-Test]Got randomized user table:")
    print(users)
    local serialized = schemas.serializeUsers(users)
    remote1:FireAllClients(
        users
    )
    remote2:FireAllClients(
        serialized
    )

    manageRemote:FireAllClients("finishedTest",time() - start_time)
end

local function handle_manage(player: Player, request: string, value: number?)
    if request == "userTest" then
        run_userstest(value)
    end
end

local function handle_remote1(player: Player, data)
    print("[Chunky-Test-R1]: Unserialized data recieved:")
    print(data)
end

local function handle_remote2(player: Player, data)
    print("[Chunky-Test-R2]: Serialized data recieved:")
    print(schemas.deserializeUsers(data))
end

remote1.OnServerEvent:Connect(handle_remote1)
remote2.OnServerEvent:Connect(handle_remote2)
manageRemote.OnServerEvent:Connect(handle_manage)