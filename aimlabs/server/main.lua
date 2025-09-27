-- Server-side logic for Aim Labs will be here.
-- Server-side logic for Aim Labs

local highscores = {
    gridshot = {},
    tracking = {}
}
local highscoreFile = "highscores.json"
local maxHighscoresPerMode = 10

-- Load highscores from file on resource start
function LoadHighscores()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), highscoreFile)
    if fileContent and fileContent ~= "" then
        local success, data = pcall(json.decode, fileContent)
        if success and type(data) == "table" then
            highscores = data
            -- Ensure all modes have a table
            if not highscores.gridshot then highscores.gridshot = {} end
            if not highscores.tracking then highscores.tracking = {} end
            print("Aim Labs: Highscores loaded successfully.")
        else
            print("Aim Labs: Failed to parse highscores.json. Starting fresh.")
        end
    else
        print("Aim Labs: highscores.json not found. A new one will be created.")
    end
end

-- Save highscores to file
function SaveHighscores()
    local jsonString = json.encode(highscores)
    SaveResourceFile(GetCurrentResourceName(), highscoreFile, jsonString, -1)
    print("Aim Labs: Highscores saved.")
end

-- Add a new score, sort, and trim the list for a specific mode
function AddScore(mode, playerName, score)
    if not highscores[mode] then
        print("Aim Labs: Attempted to save score for an invalid mode: " .. mode)
        return
    end

    local modeScores = highscores[mode]
    table.insert(modeScores, { name = playerName, score = score, date = os.date("%Y-%m-%d") })

    table.sort(modeScores, function(a, b) return a.score > b.score end)

    while #modeScores > maxHighscoresPerMode do
        table.remove(modeScores)
    end

    SaveHighscores()
end

-- Event to save a player's score
RegisterNetEvent('aimlabs:saveScore', function(data)
    local playerName = GetPlayerName(source)
    local score = data.score
    local mode = data.mode

    if mode and score and type(score) == "number" and score > 0 then
        AddScore(mode, playerName, score)
    end
end)

-- Event to get highscores and send them back to the client
RegisterNetEvent('aimlabs:getHighscores', function()
    TriggerClientEvent('aimlabs:receiveHighscores', source, highscores)
end)

-- Initial load when the script starts
LoadHighscores()