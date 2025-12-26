-- Emergency Scenarios System
-- Random maintenance failures that require pilot skill to handle
local QBCore = exports['qb-core']:GetCoreObject()

local ActiveEmergency = nil
local EmergencyHandled = false
local EmergencyStartTime = 0
local LastEmergencyCheck = 0

-- =====================================
-- EMERGENCY TYPES
-- =====================================

local EmergencyTypes = {
    engine_fire = {
        label = 'ENGINE FIRE',
        description = 'Engine #1 is on fire! Reduce speed and land immediately!',
        icon = 'fas fa-fire',
        severity = 'critical',
        timeLimit = 120000, -- 2 minutes to land
        effects = {
            smokeParticle = true,
            reducedPower = 0.6,
            engineDamage = true
        },
        successRep = 10,
        failRep = -25,
        chance = 0.001 -- 0.1% per check
    },
    gear_failure = {
        label = 'LANDING GEAR FAILURE',
        description = 'Landing gear is jammed! Manual override required.',
        icon = 'fas fa-cog',
        severity = 'warning',
        timeLimit = 0, -- No time limit, but harder landing
        effects = {
            gearStuck = true,
            hardLandingRequired = true
        },
        successRep = 8,
        failRep = -15,
        chance = 0.002
    },
    fuel_leak = {
        label = 'FUEL LEAK DETECTED',
        description = 'Fuel is leaking rapidly! Find the nearest airport!',
        icon = 'fas fa-gas-pump',
        severity = 'critical',
        timeLimit = 180000, -- 3 minutes
        effects = {
            fuelDrain = true,
            drainRate = 5 -- % per 10 seconds
        },
        successRep = 8,
        failRep = -20,
        chance = 0.0015
    },
    electrical_failure = {
        label = 'ELECTRICAL FAILURE',
        description = 'Electrical systems failing! Instruments unreliable.',
        icon = 'fas fa-bolt',
        severity = 'warning',
        timeLimit = 0,
        effects = {
            flickerHUD = true,
            noRadar = true
        },
        successRep = 5,
        failRep = -10,
        chance = 0.003
    },
    hydraulic_failure = {
        label = 'HYDRAULIC FAILURE',
        description = 'Hydraulic pressure lost! Controls sluggish.',
        icon = 'fas fa-water',
        severity = 'warning',
        timeLimit = 0,
        effects = {
            reducedControl = true,
            controlMultiplier = 0.5
        },
        successRep = 7,
        failRep = -15,
        chance = 0.002
    },
    bird_strike = {
        label = 'BIRD STRIKE',
        description = 'Bird strike on windshield! Visibility impaired.',
        icon = 'fas fa-dove',
        severity = 'minor',
        timeLimit = 0,
        effects = {
            crackedWindshield = true,
            reducedVisibility = true
        },
        successRep = 3,
        failRep = -5,
        chance = 0.005
    }
}

-- =====================================
-- EMERGENCY CHECK LOOP
-- =====================================

CreateThread(function()
    while true do
        Wait(10000) -- Check every 10 seconds

        if CurrentFlight and CurrentPlane and DoesEntityExist(CurrentPlane) and not ActiveEmergency then
            local ped = PlayerPedId()
            if IsPedInVehicle(ped, CurrentPlane, false) then
                local heightAboveGround = GetEntityHeightAboveGround(CurrentPlane)

                -- Only trigger emergencies while airborne
                if heightAboveGround > 100 then
                    -- Check for random emergency
                    local now = GetGameTimer()
                    if now - LastEmergencyCheck > 30000 then -- At least 30 seconds between checks
                        LastEmergencyCheck = now
                        TryTriggerEmergency()
                    end
                end
            end
        end
    end
end)

function TryTriggerEmergency()
    -- Don't trigger if emergencies are disabled or already active
    if not Config.Emergencies or not Config.Emergencies.enabled then return end
    if ActiveEmergency then return end

    -- Random chance for each emergency type
    for emergencyId, emergency in pairs(EmergencyTypes) do
        local adjustedChance = emergency.chance * (Config.Emergencies.multiplier or 1.0)

        if math.random() < adjustedChance then
            TriggerEmergency(emergencyId)
            return -- Only one emergency at a time
        end
    end
end

-- =====================================
-- TRIGGER EMERGENCY
-- =====================================

function TriggerEmergency(emergencyId)
    local emergency = EmergencyTypes[emergencyId]
    if not emergency then return end

    ActiveEmergency = {
        id = emergencyId,
        data = emergency,
        startTime = GetGameTimer(),
        handled = false
    }

    EmergencyStartTime = GetGameTimer()
    EmergencyHandled = false

    -- Alert the pilot
    PlayEmergencyAlert(emergency)

    -- Start emergency effects
    StartEmergencyEffects(emergencyId, emergency)

    -- Notify server
    TriggerServerEvent('dps-airlines:server:emergencyStarted', emergencyId)

    -- Start monitoring thread
    MonitorEmergency(emergencyId, emergency)
end

function PlayEmergencyAlert(emergency)
    -- Audio alarm
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)

    -- Visual alert
    lib.notify({
        title = 'EMERGENCY',
        description = emergency.label,
        type = 'error',
        duration = 10000,
        icon = emergency.icon
    })

    -- Full screen flash
    CreateThread(function()
        for i = 1, 3 do
            SetTimecycleModifier('damage')
            Wait(200)
            ClearTimecycleModifier()
            Wait(200)
        end
    end)

    -- Show alert dialog
    CreateThread(function()
        Wait(500)
        lib.alertDialog({
            header = emergency.label,
            content = emergency.description .. '\n\n**Severity:** ' .. emergency.severity:upper(),
            centered = true,
            cancel = false
        })
    end)
end

-- =====================================
-- EMERGENCY EFFECTS
-- =====================================

function StartEmergencyEffects(emergencyId, emergency)
    local effects = emergency.effects
    if not effects then return end

    -- Engine fire - smoke particles and reduced power
    if effects.smokeParticle then
        CreateThread(function()
            RequestNamedPtfxAsset('core')
            while not HasNamedPtfxAssetLoaded('core') do Wait(10) end

            while ActiveEmergency and ActiveEmergency.id == emergencyId do
                if CurrentPlane and DoesEntityExist(CurrentPlane) then
                    UseParticleFxAssetNextCall('core')
                    local engineBone = GetEntityBoneIndexByName(CurrentPlane, 'engine')
                    if engineBone == -1 then engineBone = 0 end

                    local coords = GetWorldPositionOfEntityBone(CurrentPlane, engineBone)
                    StartParticleFxLoopedAtCoord('exp_grd_bzgas_smoke', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.5, false, false, false, false)
                end
                Wait(2000)
            end
        end)
    end

    -- Reduced engine power
    if effects.reducedPower then
        CreateThread(function()
            while ActiveEmergency and ActiveEmergency.id == emergencyId do
                if CurrentPlane and DoesEntityExist(CurrentPlane) then
                    local currentSpeed = GetEntitySpeed(CurrentPlane)
                    local maxSpeed = currentSpeed * effects.reducedPower
                    -- Gradually reduce speed
                    if currentSpeed > maxSpeed + 5 then
                        SetEntityMaxSpeed(CurrentPlane, maxSpeed)
                    end
                end
                Wait(1000)
            end
            -- Reset max speed when emergency ends
            if CurrentPlane and DoesEntityExist(CurrentPlane) then
                SetEntityMaxSpeed(CurrentPlane, 100.0)
            end
        end)
    end

    -- Fuel drain
    if effects.fuelDrain then
        CreateThread(function()
            while ActiveEmergency and ActiveEmergency.id == emergencyId do
                -- Visual/audio cues for fuel draining
                if math.random() < 0.3 then
                    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
                end
                Wait(10000)
            end
        end)
    end

    -- Electrical flicker
    if effects.flickerHUD then
        CreateThread(function()
            while ActiveEmergency and ActiveEmergency.id == emergencyId do
                -- Random HUD flicker
                if math.random() < 0.3 then
                    DisplayRadar(false)
                    Wait(math.random(100, 500))
                    DisplayRadar(true)
                end
                Wait(2000)
            end
            DisplayRadar(true)
        end)
    end

    -- Reduced control (hydraulic failure)
    if effects.reducedControl then
        CreateThread(function()
            while ActiveEmergency and ActiveEmergency.id == emergencyId do
                if CurrentPlane and DoesEntityExist(CurrentPlane) then
                    -- Apply random slight rotation to simulate control issues
                    if math.random() < 0.1 then
                        local roll = GetEntityRoll(CurrentPlane)
                        ApplyForceToEntity(CurrentPlane, 1,
                            math.random(-1, 1) * 0.5,
                            0.0,
                            math.random(-1, 1) * 0.3,
                            0.0, 0.0, 0.0,
                            0, false, true, true, false, true
                        )
                    end
                end
                Wait(500)
            end
        end)
    end

    -- Cracked windshield effect
    if effects.crackedWindshield then
        -- Apply damage overlay
        SetTimecycleModifier('prologue_ending_fog')
    end
end

-- =====================================
-- MONITOR EMERGENCY
-- =====================================

function MonitorEmergency(emergencyId, emergency)
    CreateThread(function()
        local warningShown = false

        while ActiveEmergency and ActiveEmergency.id == emergencyId do
            Wait(1000)

            if not CurrentPlane or not DoesEntityExist(CurrentPlane) then
                -- Plane destroyed or despawned
                FailEmergency('Aircraft lost')
                return
            end

            local heightAboveGround = GetEntityHeightAboveGround(CurrentPlane)
            local speed = GetEntitySpeed(CurrentPlane)
            local health = GetEntityHealth(CurrentPlane)

            -- Check for crash
            if health < 100 or IsEntityDead(CurrentPlane) then
                FailEmergency('Aircraft crashed')
                return
            end

            -- Check time limit
            if emergency.timeLimit > 0 then
                local elapsed = GetGameTimer() - EmergencyStartTime
                local remaining = emergency.timeLimit - elapsed

                if remaining <= 0 then
                    FailEmergency('Time limit exceeded')
                    return
                end

                -- Warning at 30 seconds
                if remaining < 30000 and not warningShown then
                    warningShown = true
                    lib.notify({
                        title = 'CRITICAL',
                        description = '30 seconds remaining!',
                        type = 'error',
                        duration = 5000
                    })
                    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                end
            end

            -- Check if landed safely
            if heightAboveGround < 5 and speed < 15 then
                -- Check if at an airport
                local playerPos = GetEntityCoords(CurrentPlane)
                local nearAirport = false

                for _, airport in pairs(Locations.Airports) do
                    local dist = #(playerPos - vector3(airport.coords.x, airport.coords.y, airport.coords.z))
                    if dist < 500 then
                        nearAirport = true
                        break
                    end
                end

                if nearAirport then
                    SuccessEmergency()
                    return
                else
                    -- Landed but not at airport - partial success
                    SuccessEmergency(true)
                    return
                end
            end
        end
    end)
end

-- =====================================
-- EMERGENCY RESOLUTION
-- =====================================

function SuccessEmergency(offAirport)
    if not ActiveEmergency then return end

    local emergency = ActiveEmergency.data
    local repGain = offAirport and math.floor(emergency.successRep * 0.5) or emergency.successRep

    -- Clear effects
    ClearTimecycleModifier()
    DisplayRadar(true)

    if CurrentPlane and DoesEntityExist(CurrentPlane) then
        SetEntityMaxSpeed(CurrentPlane, 100.0)
    end

    -- Notify player
    lib.notify({
        title = 'EMERGENCY HANDLED',
        description = offAirport
            and 'Emergency landing successful (off-airport)'
            or 'Emergency handled successfully!',
        type = 'success',
        duration = 8000
    })

    -- Notify server
    TriggerServerEvent('dps-airlines:server:emergencyResolved', ActiveEmergency.id, true, repGain)

    -- Log to black box
    if exports['dps-airlines'].RecordBlackBoxEvent then
        exports['dps-airlines']:RecordBlackBoxEvent('EMERGENCY_RESOLVED', {
            type = ActiveEmergency.id,
            success = true,
            offAirport = offAirport
        })
    end

    ActiveEmergency = nil
    EmergencyHandled = true
end

function FailEmergency(reason)
    if not ActiveEmergency then return end

    local emergency = ActiveEmergency.data

    -- Clear effects
    ClearTimecycleModifier()
    DisplayRadar(true)

    if CurrentPlane and DoesEntityExist(CurrentPlane) then
        SetEntityMaxSpeed(CurrentPlane, 100.0)
    end

    -- Notify player
    lib.notify({
        title = 'EMERGENCY FAILED',
        description = reason or 'Failed to handle emergency',
        type = 'error',
        duration = 8000
    })

    -- Notify server (reputation loss)
    TriggerServerEvent('dps-airlines:server:emergencyResolved', ActiveEmergency.id, false, emergency.failRep)

    -- Record crash if applicable
    if reason == 'Aircraft crashed' then
        TriggerServerEvent('dps-airlines:server:planeCrashed')
    end

    ActiveEmergency = nil
    EmergencyHandled = false
end

-- =====================================
-- MANUAL EMERGENCY TRIGGER (For Testing)
-- =====================================

RegisterCommand('testemergecy', function(source, args)
    if not Config.Debug then return end

    local emergencyId = args[1] or 'engine_fire'
    if EmergencyTypes[emergencyId] then
        TriggerEmergency(emergencyId)
    else
        print('Available emergencies: engine_fire, gear_failure, fuel_leak, electrical_failure, hydraulic_failure, bird_strike')
    end
end, false)

-- =====================================
-- CLEANUP
-- =====================================

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ClearTimecycleModifier()
        DisplayRadar(true)
        ActiveEmergency = nil
    end
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('GetActiveEmergency', function() return ActiveEmergency end)
exports('TriggerEmergency', TriggerEmergency)
exports('IsEmergencyActive', function() return ActiveEmergency ~= nil end)

print('^2[dps-airlines]^7 Emergency Scenarios module loaded')
