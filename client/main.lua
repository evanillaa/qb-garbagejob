local QBCore = exports['qb-core']:GetCoreObject()
local isLoggedIn = LocalPlayer.state['isLoggedIn']
local playerJob = nil

local garbageVehicle = nil
local hasBag = false
local currentStop = 0
local deliveryBlip = nil
local isWorking = false
local amountOfBags = 0
local garbageObject = nil
local endBlip = nil
local garbageBlip = nil
local canTakeBag = true
local currentStopNum = 0

local payCoords = vector3(Config.Locations["paycheck"].coords.x, Config.Locations["paycheck"].coords.y, Config.Locations["paycheck"].coords.z)
local vehCoords = vector3(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = LocalPlayer.state['isLoggedIn']
    playerJob = QBCore.Functions.GetPlayerData().job

    setupClient()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    isLoggedIn = LocalPlayer.state['isLoggedIn']
    playerJob = JobInfo

    if playerJob.name == "garbage" then
        if garbageBlip ~= nil then
            RemoveBlip(garbageBlip)
        end
    end

    setupClient()
end)

RegisterNetEvent('garbagejob:client:SetWaypointHome')
AddEventHandler('garbagejob:client:SetWaypointHome', function()
    SetNewWaypoint(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y)
end)

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function DrawText3D2(coords, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(coords.x,coords.y,coords.z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function LoadModel(hash)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Citizen.Wait(10) end
end

function LoadAnimation(dict)
    RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do Citizen.Wait(10) end
end

function BringBackCar()
    local veh = GetVehiclePedIsIn(PlayerPedId())
    DeleteVehicle(veh)
    if endBlip ~= nil then
        RemoveBlip(endBlip)
    end
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
    end

    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    isWorking = false
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0
end

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        if isLoggedIn and playerJob ~= nil and playerJob.name == "garbage" then
            sleep = 1
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local InVehicle = IsPedInAnyVehicle(ped, false)
            local distance = #(pos - vehCoords)
            local payDistance = #(pos - payCoords)

            if distance < 10.0 then
                DrawMarker(2, vehCoords.x, vehCoords.y, vehCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 233, 55, 22, 222, false, false, false, true, false, false, false)
                if distance < 1.5 then
                    if InVehicle then
                        DrawText3D(vehCoords.x, vehCoords.y, vehCoords.z, "~g~E~w~ - Store Garbage Truck")
                        if IsControlJustReleased(0, 38) then
                            QBCore.Functions.TriggerCallback('garbagejob:server:EndShift', function(endShift)
                                if endShift then
                                    BringBackCar()
                                    QBCore.Functions.Notify("Truck returned, collect your payslip to recieve your pay and deposit back!")
                                else
                                    QBCore.Functions.Notify("You have no deposit paid on this vehicle..")
                                    currentStopNum = 0
                                    currentStop = 0
                                end
                            end, pos)
                        end
                    else
                        DrawText3D(vehCoords.x, vehCoords.y, vehCoords.z, "~g~E~w~ - Garbage Truck")
                        if IsControlJustReleased(0, 38) then
                            QBCore.Functions.TriggerCallback('garbagejob:server:NewShift', function(shouldContinue, firstStop, totalBags)
                                if shouldContinue then

                                    local coords = Config.Locations["vehicle"].coords
                                    QBCore.Functions.SpawnVehicle("trash2", function(veh)
                                        TaskWarpPedIntoVehicle(ped, veh, -1) -- hopefully this fixes an issue if something is delayed they'll get crushed
                                        SetVehicleEngineOn(veh, true, true)

                                        garbageVehicle = veh
                                        SetVehicleNumberPlateText(veh, "GARB"..tostring(math.random(1000, 9999)))
                                        SetEntityHeading(veh, coords.w)
                                        exports['LegacyFuel']:SetFuel(veh, 100.0)
                                        SetEntityAsMissionEntity(veh, true, true)
                                        TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(veh))
                                        currentStop = firstStop
                                        currentStopNum = 1
                                        amountOfBags = totalBags
                                        isWorking = true
                                        SetGarbageRoute()
                                        QBCore.Functions.Notify("You have $"..Config.TruckPrice..", deposit paid!")
                                        QBCore.Functions.Notify("You have started working, location marked on GPS!")
                                    end, coords, true)

                                else
                                    QBCore.Functions.Notify("You have not enough money for the deposit.. Deposit costs are $"..Config.TruckPrice)
                                end
                            end)
                        end
                    end
                end
            end

            if payDistance < 20 then
                DrawMarker(2, payCoords.x, payCoords.y, payCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 233, 55, 22, 222, false, false, false, true, false, false, false)
                if payDistance < 1.5 then
                    DrawText3D(payCoords.x, payCoords.y, payCoords.z, "~g~E~w~ - Payslip")
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('garbagejob:server:PayShift', location)
                    end
                elseif payDistance < 5 then
                    DrawText3D(payCoords.x, payCoords.y, payCoords.z, "Payslip")
                end
            end

        end

        Citizen.Wait(sleep)
    end
end)

function SetGarbageRoute()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local CurrentLocation = Config.Locations["trashcan"][currentStop]
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
    end
    deliveryBlip = AddBlipForCoord(CurrentLocation.coords.x, CurrentLocation.coords.y, CurrentLocation.coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipDisplay(deliveryBlip, 2)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipColour(deliveryBlip, 27)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations["trashcan"][currentStop].name)
    EndTextCommandSetBlipName(deliveryBlip)
    SetBlipRoute(deliveryBlip, true)


    -- Run the Work Loop to check for Garbo Bags.
    RunWorkLoop()
end

function RunWorkLoop()
    Citizen.CreateThread(function()
        while isWorking and isLoggedIn do

            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)

            if playerJob ~= nil and playerJob.name == "garbage" and currentStop ~= 0 and deliveryBlip ~= nil then

                local DeliveryData = Config.Locations["trashcan"][currentStop]
                local Distance = #(pos - vector3(DeliveryData.coords.x, DeliveryData.coords.y, DeliveryData.coords.z))

                if Distance < 20 or hasBag then
                    LoadAnimation('missfbi4prepp1')
                    DrawMarker(2, DeliveryData.coords.x, DeliveryData.coords.y, DeliveryData.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 55, 22, 255, false, false, false, false, false, false, false)

                    if not hasBag and canTakeBag then
                        if Distance < 1.5 then
                            DrawText3D2(DeliveryData.coords, "~g~E~w~ - Grab a garbage bag")
                            if IsControlJustPressed(0, 51) then

                                hasBag = true
                                TakeAnim()
                            end
                        elseif Distance < 10 then
                            DrawText3D2(DeliveryData.coords, "Stand here to grab a garbage bag.")
                        end
                    else
                        if DoesEntityExist(garbageVehicle) then
                            local Coords = GetOffsetFromEntityInWorldCoords(garbageVehicle, 0.0, -4.5, 0.0)
                            local TruckDist = #(pos - Coords)

                            if Distance < 10 then
                                DrawText3D2(DeliveryData.coords, "Put the bag in your truck..")
                            end

                            if TruckDist < 2 then
                                DrawText3D(Coords.x, Coords.y, Coords.z, "~g~E~w~ - Dispose of Garbage Bag")
                                if IsControlJustPressed(0, 51) then
                                    QBCore.Functions.Progressbar("deliverbag", "Putting bag in trashmaster ..", 2000, false, true, {
                                        disableMovement = true,
                                        disableCarMovement = true,
                                        disableMouse = false,
                                        disableCombat = true,
                                    }, {}, {}, {}, function() -- Done
                                        hasBag = false
                                        -- Looks if you have delivered all bags
                                        if (amountOfBags - 1) == 0 then
                                            QBCore.Functions.TriggerCallback('garbagejob:server:NextStop', function(hasMoreStops, nextStop, newBagAmount)
                                                if hasMoreStops and nextStop ~= 0 then
                                                    -- Here he puts your next location and you are not finished working yet.
                                                    currentStop = nextStop
                                                    currentStopNum = currentStopNum + 1
                                                    amountOfBags = newBagAmount
                                                    SetGarbageRoute()
                                                    QBCore.Functions.Notify("All garbage bags are done, proceed to the next location!")
                                                else
                                                    if hasMoreStops and nextStop == currentStop then
                                                        QBCore.Functions.Notify("There was an issue at the depot, please return immediately!")
                                                        amountOfBags = 0
                                                    else
                                                        -- You are done with work here.
                                                        QBCore.Functions.Notify("You are done working! Go back to the depot.")
                                                        isWorking = false
                                                        RemoveBlip(deliveryBlip)
                                                        SetRouteBack()
                                                        amountOfBags = 0
                                                    end
                                                end
                                            end, currentStop, currentStopNum, pos)
                                            hasBag = false
                                        else
                                            -- You haven't delivered all bags here
                                            amountOfBags = amountOfBags - 1
                                            if amountOfBags > 1 then
                                                QBCore.Functions.Notify("There are still "..amountOfBags.." bags left!")
                                            else
                                                QBCore.Functions.Notify("There is still "..amountOfBags.." bags over there!")
                                            end
                                            hasBag = false
                                        end

                                        DeliverAnim()
                                    end, function() -- Cancel
                                        QBCore.Functions.Notify("Canceled", "error")
                                    end)

                                end
                            elseif TruckDist < 10 then
                                DrawText3D(Coords.x, Coords.y, Coords.z, "Stand here..")
                            end
                        else
                            QBCore.Functions.Notify("You have no truck", "error")
                            print("You no longer have a truck, contact an admin!")
                            DeliverAnim()
                            hasBag = false
                        end
                    end
                end


            end

            Citizen.Wait(1)
        end
    end)
end


function SetRouteBack()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local inleverpunt = Config.Locations["vehicle"]

    endBlip = AddBlipForCoord(inleverpunt.coords.x, inleverpunt.coords.y, inleverpunt.coords.z)
    SetBlipSprite(endBlip, 1)
    SetBlipDisplay(endBlip, 2)
    SetBlipScale(endBlip, 1.0)
    SetBlipAsShortRange(endBlip, false)
    SetBlipColour(endBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations["vehicle"].name)
    EndTextCommandSetBlipName(endBlip)
    SetBlipRoute(endBlip, true)
end

function TakeAnim()
    local ped = PlayerPedId()

    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
    garbageObject = CreateObject(GetHashKey("prop_cs_rub_binbag_01"), 0, 0, 0, true, true, true)
    AttachEntityToEntity(garbageObject, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)

    AnimCheck()
end

function AnimCheck()
    Citizen.CreateThread(function()
        while true do
            local ped = PlayerPedId()

            if hasBag then
                if not IsEntityPlayingAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 3) then
                    ClearPedTasksImmediately(ped)
                    LoadAnimation('missfbi4prepp1')
                    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
                end
            else
                break
            end

            Citizen.Wait(200)
        end
    end)
end

function DeliverAnim()
    local ped = PlayerPedId()

    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, GetEntityHeading(garbageVehicle))
    canTakeBag = false

    SetTimeout(1250, function()
        DetachEntity(garbageObject, 1, false)
        DeleteObject(garbageObject)
        TaskPlayAnim(ped, 'missfbi4prepp1', 'exit', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
        FreezeEntityPosition(ped, false)
        garbageObject = nil
        canTakeBag = true
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() == resource then
        if garbageObject ~= nil then
            DeleteEntity(garbageObject)
            garbageObject = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        isLoggedIn = LocalPlayer.state['isLoggedIn']
        playerJob = QBCore.Functions.GetPlayerData().job
        setupClient()
    end
end)

function setupClient()
    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    isWorking = false
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0

    if playerJob.name == "garbage" then
        garbageBlip = AddBlipForCoord(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y, Config.Locations["main"].coords.z)
        SetBlipSprite(garbageBlip, 318)
        SetBlipDisplay(garbageBlip, 4)
        SetBlipScale(garbageBlip, 1.0)
        SetBlipAsShortRange(garbageBlip, true)
        SetBlipColour(garbageBlip, 39)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.Locations["main"].label)
        EndTextCommandSetBlipName(garbageBlip)
    end
end