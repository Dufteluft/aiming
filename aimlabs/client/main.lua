-- Client-side logic for Aim Labs will be here.
-- Client-side logic for Aim Labs

-- State Management
local trainingActive = false
local currentMode = nil
local currentSettings = { targetSize = 1.0 }
local score = 0
local timeLeft = 60
local targetObjects = {}
local isMenuOpen = false

-- Config
local trainingAreaCenter = vector3(1717.0, 3277.0, 41.0)
local targetModel = `prop_cs_bowling_ball`
local gridshotTargetCount = 3
local trackingMoveSpeed = 2.0

-- =================================================================
-- UI Functions (unchanged)
-- =================================================================
function SetUIVisible(visible)
    SetNuiFocus(visible, visible)
    isMenuOpen = visible
    SendNUIMessage({ action = (visible and "showMenu") or "hideAll" })
end

function UpdateHud()
    SendNUIMessage({ action = "updateHud", score = score, time = timeLeft })
end

-- =================================================================
-- Game Logic
-- =================================================================

-- General Start/Stop
function StartTraining(mode)
    currentMode = mode
    trainingActive = true
    score = 0
    timeLeft = 60
    targetObjects = {}

    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, trainingAreaCenter.x, trainingAreaCenter.y - 15, trainingAreaCenter.z)

    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    SendNUIMessage({ action = "showHud" })
    UpdateHud()

    if mode == 'gridshot' then
        StartGridshot()
    elseif mode == 'tracking' then
        StartTracking()
    end

    -- General Timer Loop
    CreateThread(function()
        while trainingActive and timeLeft > 0 do
            Wait(1000)
            if trainingActive then
                timeLeft = timeLeft - 1
                UpdateHud()
            end
        end
        if trainingActive then
            StopTraining()
        end
    end)
end

function StopTraining()
    if not trainingActive then return end
    trainingActive = false

    PlaySoundFrontend(-1, "FocusOut", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    if score > 0 then
        TriggerServerEvent('aimlabs:saveScore', { mode = currentMode, score = score })
    end

    SendNUIMessage({ action = "showResults", score = score })
    SetNuiFocus(true, true)

    for _, obj in ipairs(targetObjects) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
    targetObjects = {}
    currentMode = nil
end

-- Gridshot Mode
function StartGridshot()
    for i = 1, gridshotTargetCount do
        spawnGridTarget()
    end
end

function spawnGridTarget()
    RequestModel(targetModel)
    while not HasModelLoaded(targetModel) do Wait(100) end
    local randomPos = trainingAreaCenter + vector3(math.random(-8, 8), math.random(-8, 8), math.random(0, 5))
    local newTarget = CreateObject(targetModel, randomPos, true, true, true)
    SetEntityScale(newTarget, currentSettings.targetSize, currentSettings.targetSize, currentSettings.targetSize)
    PlaceObjectOnGroundProperly(newTarget)
    FreezeEntityPosition(newTarget, true)
    table.insert(targetObjects, newTarget)
end

-- Tracking Mode
function StartTracking()
    RequestModel(targetModel)
    while not HasModelLoaded(targetModel) do Wait(100) end
    local startPos = trainingAreaCenter + vector3(0, 0, 2.0)
    local target = CreateObject(targetModel, startPos, true, true, true)
    SetEntityScale(target, currentSettings.targetSize, currentSettings.targetSize, currentSettings.targetSize)
    table.insert(targetObjects, target)

    -- Movement Loop
    CreateThread(function()
        local direction = 1
        while trainingActive and DoesEntityExist(target) do
            local currentPos = GetEntityCoords(target)
            local newX = currentPos.x + (trackingMoveSpeed * direction * 0.02) -- 0.02 is approx time per frame
            if newX > trainingAreaCenter.x + 8.0 then direction = -1 end
            if newX < trainingAreaCenter.x - 8.0 then direction = 1 end
            SetEntityCoords(target, newX, currentPos.y, currentPos.z)
            Wait(0)
        end
    end)
end

-- =================================================================
-- Commands and Events
-- =================================================================
RegisterCommand('startaim', function()
    local newMenuState = not isMenuOpen
    SetUIVisible(newMenuState)
    if newMenuState then
        TriggerServerEvent('aimlabs:getHighscores')
    end
end, false)

RegisterNUICallback('startGame', function(data, cb)
    SetUIVisible(false)
    if data.settings and data.settings.targetSize then
        currentSettings.targetSize = data.settings.targetSize
    else
        currentSettings.targetSize = 1.0 -- Default
    end
    StartTraining(data.mode)
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb) SetUIVisible(false); cb('ok') end)

RegisterNUICallback('closeResults', function(data, cb)
    SetUIVisible(true)
    TriggerServerEvent('aimlabs:getHighscores')
    cb('ok')
end)

RegisterNetEvent('aimlabs:receiveHighscores', function(highscores)
    SendNUIMessage({ action = "updateHighscores", highscores = highscores })
end)

-- =================================================================
-- Main Game Loop (replaces old hit detection)
-- =================================================================
CreateThread(function()
    local lastTrackingScoreTime = 0
    while true do
        Wait(0)
        if trainingActive then
            if currentMode == 'gridshot' then
                for i = #targetObjects, 1, -1 do
                    local obj = targetObjects[i]
                    if DoesEntityExist(obj) and GetEntityHealth(obj) < GetEntityMaxHealth(obj) then
                        score = score + 1
                        PlaySoundFrontend(-1, "Hit", "HUD_LIQUOR_STORE_SOUNDSET", true)
                        UpdateHud()
                        DeleteObject(obj)
                        table.remove(targetObjects, i)
                        spawnGridTarget()
                    end
                end
            elseif currentMode == 'tracking' then
                if IsPlayerFreeAiming(PlayerId()) then
                    local _, hit, _, _, hitEntity = GetGameplayCamRot(2)
                    if hit and DoesEntityExist(targetObjects[1]) and hitEntity == targetObjects[1] then
                        local currentTime = GetGameTimer()
                        if (currentTime - lastTrackingScoreTime) > 100 then -- Score every 100ms
                            score = score + 10 -- Give a more satisfying score increment
                            lastTrackingScoreTime = currentTime
                            PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                            UpdateHud()
                        end
                    end
                end
            end
        end
    end
end)