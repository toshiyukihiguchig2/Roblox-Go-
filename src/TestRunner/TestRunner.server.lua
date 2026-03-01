local TestEZ = require(game.ReplicatedStorage.Packages.TestEZ)
local results = TestEZ.TestBootstrap:run({
    game.ServerScriptService.Server,
	game.ReplicatedStorage.Source
}, TestEZ.Reporters.TextReporter)
print("===== TestEZ Finished =====")
