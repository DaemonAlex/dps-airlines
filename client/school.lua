-- Flight School System
local QBCore = exports['qb-core']:GetCoreObject()

local InLesson = false
local CurrentLesson = nil
local LessonPlane = nil

-- =====================================
-- FLIGHT SCHOOL MENU
-- =====================================

function OpenFlightSchoolMenu()
    local stats = lib.callback.await('dps-airlines:server:getPilotStats', false)
    local completedLessons = json.decode(stats.lessons_completed or '[]')
    local hasLicense = stats.license_obtained ~= nil

    local options = {}

    if hasLicense then
        table.insert(options, {
            title = 'Licensed Pilot',
            description = 'You already have your pilot license!',
            icon = 'fas fa-certificate',
            disabled = true
        })
    else
        -- Show lessons
        table.insert(options, {
            title = 'Training Lessons',
            description = string.format('%d/%d completed', #completedLessons, Config.FlightSchool.requiredLessons),
            icon = 'fas fa-book',
            onSelect = function()
                OpenLessonsMenu(completedLessons)
            end
        })

        -- Purchase license
        local canPurchase = #completedLessons >= Config.FlightSchool.requiredLessons
        table.insert(options, {
            title = 'Purchase License',
            description = canPurchase
                and string.format('Cost: $%d', Config.FlightSchool.licenseCost)
                or 'Complete all lessons first',
            icon = 'fas fa-id-card',
            disabled = not canPurchase,
            onSelect = function()
                PurchaseLicense()
            end
        })
    end

    -- View progress
    table.insert(options, {
        title = 'View Progress',
        description = 'Check your training progress',
        icon = 'fas fa-chart-line',
        onSelect = function()
            ViewProgress(stats)
        end
    })

    lib.registerContext({
        id = 'airlines_school_menu',
        title = 'Flight School',
        options = options
    })

    lib.showContext('airlines_school_menu')
end

function OpenLessonsMenu(completedLessons)
    local options = {}

    for _, lesson in ipairs(Config.FlightSchool.lessons) do
        local isCompleted = false
        for _, completed in ipairs(completedLessons) do
            if completed == lesson.name then
                isCompleted = true
                break
            end
        end

        table.insert(options, {
            title = lesson.label,
            description = isCompleted
                and 'COMPLETED'
                or string.format('%s | Reward: $%d', lesson.description, lesson.reward),
            icon = isCompleted and 'fas fa-check-circle' or 'fas fa-plane',
            disabled = isCompleted or InLesson,
            onSelect = function()
                StartLesson(lesson)
            end
        })
    end

    lib.registerContext({
        id = 'airlines_lessons_menu',
        title = 'Training Lessons',
        menu = 'airlines_school_menu',
        options = options
    })

    lib.showContext('airlines_lessons_menu')
end

-- =====================================
-- LESSON SYSTEM
-- =====================================

function StartLesson(lesson)
    local confirm = lib.alertDialog({
        header = lesson.label,
        content = string.format([[
**%s**

This lesson will test your flying skills.
You will be provided a training aircraft.

**Reward:** $%d on completion

Ready to begin?
        ]], lesson.description, lesson.reward),
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then return end

    InLesson = true
    CurrentLesson = lesson

    -- Spawn training plane
    local spawnPoint = Locations.Hub.planeSpawns[1]
    local hash = GetHashKey('luxor')
    lib.requestModel(hash)

    LessonPlane = CreateVehicle(hash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
    SetVehicleOnGroundProperly(LessonPlane)
    SetEntityAsMissionEntity(LessonPlane, true, true)

    -- Put player in plane
    SetPedIntoVehicle(PlayerPedId(), LessonPlane, -1)

    lib.notify({
        title = 'Flight School',
        description = string.format('%s started', lesson.label),
        type = 'inform'
    })

    -- Start lesson based on type
    if lesson.name == 'takeoff_landing' then
        TakeoffLandingLesson()
    elseif lesson.name == 'navigation' then
        NavigationLesson()
    elseif lesson.name == 'emergency' then
        EmergencyLesson()
    end
end

-- =====================================
-- LESSON: TAKEOFF & LANDING
-- =====================================

function TakeoffLandingLesson()
    lib.notify({
        title = 'Lesson',
        description = 'Take off from the runway, reach 500ft altitude, then land safely',
        type = 'inform',
        duration = 10000
    })

    CreateThread(function()
        local phase = 'ground'
        local reachedAltitude = false
        local startTime = GetGameTimer()
        local timeout = 300000 -- 5 minutes

        while InLesson and CurrentLesson.name == 'takeoff_landing' do
            Wait(500)

            if GetGameTimer() - startTime > timeout then
                FailLesson('Time ran out')
                break
            end

            if not DoesEntityExist(LessonPlane) then
                FailLesson('Aircraft destroyed')
                break
            end

            local altitude = GetEntityCoords(LessonPlane).z
            local speed = GetEntitySpeed(LessonPlane)
            local heightAboveGround = GetEntityHeightAboveGround(LessonPlane)

            -- Check takeoff
            if phase == 'ground' and heightAboveGround > 10 then
                phase = 'flying'
                lib.notify({ title = 'Lesson', description = 'Good takeoff! Now reach 500ft altitude', type = 'success' })
            end

            -- Check altitude
            if phase == 'flying' and altitude > 500 then
                reachedAltitude = true
                lib.notify({ title = 'Lesson', description = 'Altitude reached! Now land safely at the airport', type = 'success' })
                phase = 'landing'
            end

            -- Check landing
            if phase == 'landing' and reachedAltitude then
                -- Check if near airport and on ground
                local pos = GetEntityCoords(LessonPlane)
                local dist = #(pos - vector3(Locations.Hub.coords.x, Locations.Hub.coords.y, Locations.Hub.coords.z))

                if dist < 500 and heightAboveGround < 2 and speed < 5 then
                    CompleteLesson()
                    break
                end
            end
        end
    end)
end

-- =====================================
-- LESSON: NAVIGATION
-- =====================================

function NavigationLesson()
    local destination = Locations.Airports['sandy']

    lib.notify({
        title = 'Lesson',
        description = 'Navigate to Sandy Shores Airfield and land there',
        type = 'inform',
        duration = 10000
    })

    SetNewWaypoint(destination.coords.x, destination.coords.y)

    CreateThread(function()
        local startTime = GetGameTimer()
        local timeout = 600000 -- 10 minutes

        while InLesson and CurrentLesson.name == 'navigation' do
            Wait(1000)

            if GetGameTimer() - startTime > timeout then
                FailLesson('Time ran out')
                break
            end

            if not DoesEntityExist(LessonPlane) then
                FailLesson('Aircraft destroyed')
                break
            end

            local pos = GetEntityCoords(LessonPlane)
            local dist = #(pos - vector3(destination.coords.x, destination.coords.y, destination.coords.z))
            local heightAboveGround = GetEntityHeightAboveGround(LessonPlane)
            local speed = GetEntitySpeed(LessonPlane)

            if dist < 100 and heightAboveGround < 5 and speed < 10 then
                CompleteLesson()
                break
            end
        end
    end)
end

-- =====================================
-- LESSON: EMERGENCY PROCEDURES
-- =====================================

function EmergencyLesson()
    lib.notify({
        title = 'Lesson',
        description = 'Take off normally. An emergency will occur that you must handle.',
        type = 'warning',
        duration = 10000
    })

    CreateThread(function()
        -- Wait for takeoff
        while InLesson and CurrentLesson.name == 'emergency' do
            Wait(500)
            if GetEntityHeightAboveGround(LessonPlane) > 100 then
                break
            end
        end

        if not InLesson then return end

        -- Simulate engine failure
        Wait(math.random(5000, 15000))

        if not InLesson or not DoesEntityExist(LessonPlane) then return end

        lib.notify({
            title = 'EMERGENCY',
            description = 'Engine failure! Land immediately!',
            type = 'error',
            duration = 10000
        })

        -- Reduce engine power
        SetVehicleEngineHealth(LessonPlane, 100.0)

        -- Monitor for safe landing
        local startTime = GetGameTimer()
        local timeout = 120000 -- 2 minutes to land

        while InLesson and CurrentLesson.name == 'emergency' do
            Wait(500)

            if GetGameTimer() - startTime > timeout then
                FailLesson('Failed to land in time')
                break
            end

            if not DoesEntityExist(LessonPlane) then
                FailLesson('Aircraft destroyed')
                break
            end

            local heightAboveGround = GetEntityHeightAboveGround(LessonPlane)
            local speed = GetEntitySpeed(LessonPlane)

            -- Check for safe landing
            if heightAboveGround < 2 and speed < 15 then
                local health = GetEntityHealth(LessonPlane)
                if health > 200 then
                    CompleteLesson()
                else
                    FailLesson('Landing too hard')
                end
                break
            end
        end
    end)
end

-- =====================================
-- LESSON COMPLETION
-- =====================================

function CompleteLesson()
    if not InLesson or not CurrentLesson then return end

    lib.notify({
        title = 'Lesson Complete!',
        description = string.format('%s passed!', CurrentLesson.label),
        type = 'success',
        duration = 5000
    })

    TriggerServerEvent('dps-airlines:server:completeLesson', CurrentLesson.name)

    CleanupLesson()
end

function FailLesson(reason)
    if not InLesson then return end

    lib.notify({
        title = 'Lesson Failed',
        description = reason or 'Try again',
        type = 'error',
        duration = 5000
    })

    CleanupLesson()
end

function CleanupLesson()
    InLesson = false
    CurrentLesson = nil

    if LessonPlane and DoesEntityExist(LessonPlane) then
        local ped = PlayerPedId()
        if IsPedInVehicle(ped, LessonPlane, false) then
            TaskLeaveVehicle(ped, LessonPlane, 0)
            Wait(2000)
        end
        DeleteEntity(LessonPlane)
        LessonPlane = nil
    end
end

-- =====================================
-- LICENSE PURCHASE
-- =====================================

function PurchaseLicense()
    local confirm = lib.alertDialog({
        header = 'Purchase Pilot License',
        content = string.format([[
**Cost:** $%d

This will grant you an official pilot license, allowing you to work as a commercial pilot.

Proceed with purchase?
        ]], Config.FlightSchool.licenseCost),
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        TriggerServerEvent('dps-airlines:server:purchaseLicense')
    end
end

-- =====================================
-- VIEW PROGRESS
-- =====================================

function ViewProgress(stats)
    local completedLessons = json.decode(stats.lessons_completed or '[]')

    local lessonList = ''
    for _, lesson in ipairs(Config.FlightSchool.lessons) do
        local completed = false
        for _, c in ipairs(completedLessons) do
            if c == lesson.name then
                completed = true
                break
            end
        end
        lessonList = lessonList .. string.format('\n- %s: %s', lesson.label, completed and 'Completed' or 'Incomplete')
    end

    lib.alertDialog({
        header = 'Training Progress',
        content = string.format([[
**Lessons Completed:** %d/%d
%s

**License Status:** %s
        ]],
            #completedLessons,
            Config.FlightSchool.requiredLessons,
            lessonList,
            stats.license_obtained and 'Licensed' or 'Not Licensed'
        ),
        centered = true,
        cancel = false
    })
end

-- =====================================
-- EVENT HANDLERS
-- =====================================

RegisterNetEvent('dps-airlines:client:startLesson', function(lesson)
    StartLesson(lesson)
end)

RegisterNetEvent('dps-airlines:client:canGetLicense', function()
    lib.notify({
        title = 'Flight School',
        description = 'All lessons completed! You can now purchase your license.',
        type = 'success',
        duration = 7000
    })
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupLesson()
    end
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('IsInLesson', function() return InLesson end)
exports('GetCurrentLesson', function() return CurrentLesson end)
