local TestEZ = require(game.ReplicatedStorage.Packages.TestEZ)
local results = TestEZ.TestBootstrap:run({
    game.ReplicatedStorage.Source.tests
}, TestEZ.Reporters.TextReporter)
print("===== TestEZ Finished =====")