if CLIENT then return end

local CurTime = CurTime
local math_min = math.min
local IsValid = IsValid

local CONFIG = {
    -- HEAL SETTINGS
    THINK_INTERVAL = 2,  -- How often to process health updates (in seconds)
    MAX_RESTORE_PERCENT = 75,  -- Maximum percentage of health to restore to (0-100)
    HEAL_DELAY = 60,  -- Time before healing starts after taking damage (in seconds)
    HEAL_INTERVAL = 1,  -- Time between each healing tick (should be less than THINK_INTERVAL)
    HEAL_AMOUNT = 1, -- Amount of health restored per think interval (THINK_INTERVAL)
    BATCH_INTERVAL = 1, -- How often to process batched health updates (in seconds)
    CLEANUP_INTERVAL = 300, -- How often to clean up player states (in seconds)

    -- SOUND SETTINGS
    ENABLE_SOUNDS = true,
    HEAL_START_SOUND = "items/medshot4.wav",
    HEAL_STOP_SOUND = "items/medshotno1.wav",
}

local playerStates = {}
local pendingHealthUpdates = {}

local healingQueue = {}

local function IsPlayerValid(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Health() > 0
end

local function CalculateMaxRestore(maxHealth)
    local maxRestore = math_min(maxHealth * (CONFIG.MAX_RESTORE_PERCENT / 100), maxHealth)
    return hook.Run("HealthRestore_ModifyMaxRestore", maxHealth, maxRestore) or maxRestore
end

local function PlayHealSound(ply, soundName)
    if CONFIG.ENABLE_SOUNDS and hook.Run("HealthRestore_PlaySound", ply, soundName) then
        ply:EmitSound(soundName, 60, 100, 0.4)
    end
end

local function AddToHealingQueue(ply)
    if not healingQueue[ply] and IsPlayerValid(ply) then
        healingQueue[ply] = true
    end
end

local function RemoveFromHealingQueue(ply)
    healingQueue[ply] = nil
end

hook.Add("PlayerInitialSpawn", "HealthRestore_InitPlayer", function(ply)
    playerStates[ply] = {
        lastDamage = 0,
        healTime = nil,
        maxHealth = ply:GetMaxHealth(),
        maxRestoreAmount = CalculateMaxRestore(ply:GetMaxHealth())
    }
    AddToHealingQueue(ply)
end)

hook.Add("EntityTakeDamage", "HealthRestore_DamageTrack", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    
    playerStates[target] = playerStates[target] or {}
    playerStates[target].lastDamage = CurTime()
    playerStates[target].healTime = nil
    AddToHealingQueue(target)
end)

hook.Add("PlayerDeath", "HealthRestore_Death", function(ply)
    if not playerStates[ply] then return end
    playerStates[ply].lastDamage = CurTime()
    playerStates[ply].healTime = nil
end)

hook.Add("PlayerSpawn", "HealthRestore_Spawn", function(ply)
    if not playerStates[ply] then return end
    playerStates[ply].lastDamage = CurTime()
    playerStates[ply].healTime = nil
end)

hook.Add("PlayerDisconnected", "HealthRestore_Cleanup", function(ply)
    playerStates[ply] = nil
    RemoveFromHealingQueue(ply)
end)

hook.Add("PlayerMaxHealthChanged", "HealthRestore_MaxHealthUpdate", function(ply, newMaxHealth)
    if not playerStates[ply] or not IsValid(ply) then return end
    
    playerStates[ply].maxHealth = newMaxHealth
    playerStates[ply].maxRestoreAmount = CalculateMaxRestore(newMaxHealth)
end)

local function ValidateHealth(health, maxHealth)
    if not isnumber(health) then return false end
    if health < 0 or health > maxHealth * 2 then return false end
    return true
end

local function ProcessHealing(ply, currentHealth, state)
    if hook.Run("HealthRestore_CanHeal", ply) == false then return end
    
    local healAmount = CONFIG.HEAL_AMOUNT

    healAmount = hook.Run("HealthRestore_ModifyHealAmount", ply, healAmount) or healAmount

    local newHealth = math_min(currentHealth + healAmount, state.maxRestoreAmount)
    newHealth = hook.Run("HealthRestore_ModifyFinalHealth", ply, newHealth, currentHealth) or newHealth
    
    return newHealth
end

local function ProcessHealthUpdates()
    local curTime = CurTime()
    
    for ply, newHealth in pairs(pendingHealthUpdates) do
        if not IsValid(ply) then continue end
        
        local state = playerStates[ply]
        if not state then continue end
        
        -- Double-check that enough time has passed since last damage
        if (curTime - state.lastDamage) < CONFIG.HEAL_DELAY then
            print("[HealthRestore] Cancelling heal - recent damage for:", ply:Nick())
            pendingHealthUpdates[ply] = nil
            continue
        end
        
        local maxHealth = ply:GetMaxHealth()
        
        -- Validate health value
        if not ValidateHealth(newHealth, maxHealth) then
            print("[HealthRestore] Invalid health value detected for player:", ply:Nick())
            pendingHealthUpdates[ply] = nil
            continue
        end
        
        -- Apply health with safety checks
        if newHealth > maxHealth * 2 then
            newHealth = maxHealth
        end
        
        -- Final check to ensure player is still valid and alive
        if IsPlayerValid(ply) then
            ply:SetHealth(newHealth)
            print("[HealthRestore] Applied healing to:", ply:Nick(), "New Health:", newHealth)
        end
    end
    table.Empty(pendingHealthUpdates)
end

local function HealthRestore_Think()
    local curTime = CurTime()

    for ply, state in pairs(playerStates) do
        if IsPlayerValid(ply) then
            local currentHealth = ply:Health()
            -- Add to queue if they need healing and aren't already queued
            if currentHealth < state.maxRestoreAmount and not healingQueue[ply] then
                print("[HealthRestore] Adding player to queue:", ply:Nick(), "Health:", currentHealth)
                AddToHealingQueue(ply)
            end
        end
    end

    for ply in pairs(healingQueue) do
        if not IsPlayerValid(ply) then
            print("[HealthRestore] Player not valid:", ply)
            RemoveFromHealingQueue(ply)
            continue
        end

        local state = playerStates[ply]
        if not state then 
            print("[HealthRestore] No state for player:", ply:Nick())
            continue 
        end

        local currentHealth = ply:Health()
        local currentMaxHealth = ply:GetMaxHealth()

        -- Update max health if changed
        if currentMaxHealth != state.maxHealth then
            state.maxHealth = currentMaxHealth
            state.maxRestoreAmount = CalculateMaxRestore(currentMaxHealth)
        end

        -- Only remove from queue if they're at max health
        if currentHealth >= state.maxRestoreAmount then
            print("[HealthRestore] Player reached max health:", ply:Nick())
            RemoveFromHealingQueue(ply)
            continue
        end

        local timeSinceLastDamage = curTime - state.lastDamage
        if timeSinceLastDamage >= CONFIG.HEAL_DELAY then
            print("[HealthRestore] Time since damage:", timeSinceLastDamage, "for player:", ply:Nick())
            
            if not state.healTime then
                -- Start healing
                if hook.Run("HealthRestore_ShouldStartHealing", ply) ~= false then
                    print("[HealthRestore] Starting healing for:", ply:Nick())
                    state.healTime = curTime
                    PlayHealSound(ply, CONFIG.HEAL_START_SOUND)
                else
                    print("[HealthRestore] Healing prevented by hook for:", ply:Nick())
                end
            elseif (curTime - state.healTime) >= CONFIG.HEAL_INTERVAL then
                -- Process healing
                local newHealth = ProcessHealing(ply, currentHealth, state)
                if newHealth then
                    print("[HealthRestore] Healing", ply:Nick(), "from", currentHealth, "to", newHealth)
                    pendingHealthUpdates[ply] = newHealth
                    state.healTime = curTime
                else
                    print("[HealthRestore] Healing prevented for:", ply:Nick())
                end
            end
        else
            if state.healTime then
                print("[HealthRestore] Stopping healing for:", ply:Nick())
                PlayHealSound(ply, CONFIG.HEAL_STOP_SOUND)
                state.healTime = nil
            end
        end
    end
end

local function CleanupPlayerStates()
    for ply, state in pairs(playerStates) do
        if hook.Run("HealthRestore_ShouldCleanupPlayer", ply, state) then
            playerStates[ply] = nil
            RemoveFromHealingQueue(ply)
            continue
        end
        
        if state.lastDamage and (CurTime() - state.lastDamage) > 3600 then
            if hook.Run("HealthRestore_ShouldResetState", ply, state) then
                state.lastDamage = CurTime()
                state.healTime = nil
            end
        end
    end
end

--[[

Hooks for modifying the healing system / adding custom logic from other addons

Example:

hook.Add("HealthRestore_ModifyMaxRestore", "Custom_MaxRestore", function(maxHealth, maxRestore)
    -- Allow VIPs to heal to full health
    if ply:GetUserGroup() == "vip" then
        return maxHealth
    end
    return maxRestore
end)

--]]

local function CreateHooks()
    hook.Add("HealthRestore_CanHeal", "HealthRestore_DefaultCanHeal", function(ply)
        return true
    end)

    hook.Add("HealthRestore_ModifyHealAmount", "HealthRestore_DefaultHealAmount", function(ply, amount)
        return amount
    end)

    hook.Add("HealthRestore_ShouldStartHealing", "HealthRestore_DefaultShouldStart", function(ply)
        return true
    end)

    hook.Add("HealthRestore_ModifyMaxRestore", "HealthRestore_DefaultMaxRestore", function(maxHealth, maxRestore)
        return maxRestore
    end)

    hook.Add("HealthRestore_PlaySound", "HealthRestore_DefaultSound", function(ply, soundName)
        return true -- Allow sound to play
    end)

    hook.Add("HealthRestore_ShouldCleanupPlayer", "HealthRestore_DefaultCleanup", function(ply, state)
        return not IsValid(ply) or not ply:IsPlayer()
    end)

    hook.Add("HealthRestore_ShouldResetState", "HealthRestore_DefaultResetState", function(ply, state)
        return not IsValid(ply) or not ply:IsPlayer()
    end)
end

CreateHooks()

timer.Create("HealthRestore_Think", CONFIG.THINK_INTERVAL, 0, HealthRestore_Think)
timer.Create("HealthRestore_BatchProcess", CONFIG.BATCH_INTERVAL, 0, ProcessHealthUpdates)
timer.Create("HealthRestore_Cleanup", CONFIG.CLEANUP_INTERVAL, 0, CleanupPlayerStates)