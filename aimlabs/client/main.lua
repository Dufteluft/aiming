-- =============================================================== --
--                         AIM LABS by Jules                         --
-- =============================================================== --

-- Configuration Table
local Config = {
    Entrance = vector3(1730.2, 3280.5, 41.1),
    TrainingAreaCenter = vector3(1717.0, 3277.0, 41.0),
    TargetModel = `prop_cs_bowling_ball`,
    GridshotTargetCount = 3,
    TrackingMoveSpeed = 2.0,
    Weapon = `weapon_pistol`,
    WeaponAmmo = 250
}

-- State Management
local trainingActive = false
local currentMode = nil
local currentSettings = { targetSize = 1.0 }
local score = 0
local timeLeft = 60
local targetObjects = {}
local isMenuOpen = false
local lastPlayerWeapon = nil

-- =============================================================== --
-- UI FUNCTIONS
-- =============================================================== --
function SetUIVisible(visible)
    isMenuOpen = visible
    SetNuiFocus(visible, visible)
    SendNUIMessage({ action = (visible and "showMenu") or "hideAll" })
end

function UpdateHud()
    SendNUIMessage({ action = "updateHud", score = score, time = timeLeft })
end

-- =============================================================== --
-- GAME LOGIC
-- =============================================================== --

-- Gives a weapon and saves the old one
function GiveTrainingWeapon()
    local playerPed = PlayerPedId()
    lastPlayerWeapon = GetSelectedPedWeapon(playerPed)
    GiveWeaponToPed(playerPed, Config.Weapon, Config.WeaponAmmo, false, true)
    SetCurrentPedWeapon(playerPed, Config.Weapon, true)
end

-- Restores the old weapon
function RestorePlayerWeapon()
    local playerPed = PlayerPedId()
    RemoveWeaponFromPed(playerPed, Config.Weapon)
    if lastPlayerWeapon and lastPlayerWeapon ~= GetHashKey("WEAPON_UNARMED") then
        SetCurrentPedWeapon(playerPed, lastPlayerWeapon, true)
    end
    lastPlayerWeapon = nil
end

-- Spawns a single target for Gridshot
function spawnGridTarget()
    RequestModel(Config.TargetModel)
    while not HasModelLoaded(Config.TargetModel) do Wait(50) end
    local randomPos = Config.TrainingAreaCenter + vector3(math.random(-8, 8), math.random(-8, 8), math.random(0, 5))
    local newTarget = CreateObject(Config.TargetModel, randomPos, true, true, true)
    SetEntityScale(newTarget, currentSettings.targetSize, currentSettings.targetSize, currentSettings.targetSize)
    PlaceObjectOnGroundProperly(newTarget)
    FreezeEntityPosition(newTarget, true)
    table.insert(targetObjects, newTarget)
end

-- Spawns the moving target for Tracking
function spawnTrackingTarget()
    RequestModel(Config.TargetModel)
    while not HasModelLoaded(Config.TargetModel) do Wait(50) end
    local startPos = Config.TrainingAreaCenter + vector3(0, 0, 2.0)
    local target = CreateObject(Config.TargetModel, startPos, true, true, true)
    SetEntityScale(target, currentSettings.targetSize, currentSettings.targetSize, currentSettings.targetSize)
    table.insert(targetObjects, target)
end

-- General function to start a training session
function StartTraining(mode)
    currentMode = mode
    trainingActive = true
    score = 0
    timeLeft = 60
    targetObjects = {}

    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, Config.TrainingAreaCenter.x, Config.TrainingAreaCenter.y - 15, Config.TrainingAreaCenter.z)
    GiveTrainingWeapon()

    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    SendNUIMessage({ action = "showHud" })
    UpdateHud()

    if mode == 'gridshot' then
        for i = 1, Config.GridshotTargetCount do
            spawnGridTarget()
        end
    elseif mode == 'tracking' then
        spawnTrackingTarget()
    end
end

-- General function to stop a training session
function StopTraining()
    if not trainingActive then return end
    trainingActive = false

    PlaySoundFrontend(-1, "FocusOut", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    if score > 0 then
        TriggerServerEvent('aimlabs:saveScore', { mode = currentMode, score = score })
    end

    RestorePlayerWeapon()
    SendNUIMessage({ action = "showResults", score = score })
    SetNuiFocus(true, true) -- Show cursor for results screen

    for _, obj in ipairs(targetObjects) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
    targetObjects = {}
    currentMode = nil
end

-- =============================================================== --
-- NUI CALLBACKS & EVENTS
-- =============================================================== --
RegisterNetEvent('aimlabs:receiveHighscores', function(highscores)
    SendNUIMessage({ action = "updateHighscores", highscores = highscores })
end)

RegisterNUICallback('startGame', function(data, cb)
    SetUIVisible(false)
    if data.settings and data.settings.targetSize then
        currentSettings.targetSize = data.settings.targetSize
    else
        currentSettings.targetSize = 1.0
    end
    StartTraining(data.mode)
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetUIVisible(false)
    cb('ok')
end)

RegisterNUICallback('closeResults', function(data, cb)
    -- Return to the main menu from the results screen
    SetUIVisible(true)
    TriggerServerEvent('aimlabs:getHighscores')
    cb('ok')
end)

-- =============================================================== --
-- BLIP & 3D TEXT
-- =============================================================== --
CreateThread(function()
    local blip = AddBlipForCoord(Config.Entrance)
    SetBlipSprite(blip, 460)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Aim Labs")
    EndTextCommandSetBlipName(blip)
end)

function Draw3DText(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- =============================================================== --
-- MAIN CLIENT THREAD (The "Heartbeat")
-- =============================================================== --
CreateThread(function()
    local lastGameTime = GetGameTimer()
    local lastTrackingScoreTime = 0
    local trackingDirection = 1

    while true do
        Wait(0) -- Run every frame
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        if not trainingActive then
            -- Handle interaction point when not in training
            local distance = #(playerCoords - Config.Entrance)
            if distance < 10.0 then
                DrawMarker(1, Config.Entrance.x, Config.Entrance.y, Config.Entrance.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, 0, 150, 255, 100, false, true, 2, nil, nil, false)
                if distance < 3.0 then
                    Draw3DText(Config.Entrance.x, Config.Entrance.y, Config.Entrance.z, 'Drücke [E] um das Aim Lab zu starten')
                    if IsControlJustReleased(0, 38) then -- Key E
                        SetUIVisible(true)
                        TriggerServerEvent('aimlabs:getHighscores')
                    end
                end
            end
        else
            -- --- THIS IS THE CORE GAMEPLAY LOOP ---

            -- 1. Timer Logic (runs once per second)
            if GetGameTimer() - lastGameTime >= 1000 then
                timeLeft = timeLeft - 1
                UpdateHud()
                lastGameTime = GetGameTimer()
                if timeLeft <= 0 then
                    StopTraining()
                end
            end

            -- 2. Game Mode Logic (runs every frame)
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
                local target = targetObjects[1]
                if DoesEntityExist(target) then
                    -- Move the target
                    local currentPos = GetEntityCoords(target)
                    local newX = currentPos.x + (Config.TrackingMoveSpeed * trackingDirection * 0.02) -- Frame-rate independent movement
                    if newX > Config.TrainingAreaCenter.x + 8.0 then trackingDirection = -1 end
                    if newX < Config.TrainingAreaCenter.x - 8.0 then trackingDirection = 1 end
                    SetEntityCoords(target, newX, currentPos.y, currentPos.z, false, false, false, true)

                    -- Check for score
                    if IsPlayerFreeAiming(PlayerId()) then
                        local _, hit, _, _, hitEntity = GetGameplayCamRot(2)
                        if hit and hitEntity == target then
                            if (GetGameTimer() - lastTrackingScoreTime) > 100 then
                                score = score + 10
                                lastTrackingScoreTime = GetGameTimer()
                                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                UpdateHud()
                            end
                        end
                    end
                end
            end
        end
    end
end)