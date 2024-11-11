## Overview

A simple, single-script addon for Garry's Mod servers to automatically heal players that are low on health.

## Hooks Documentation

The script exposes several hooks that allow for external modification of its behavior.

**Example Usage:**
```lua
-- Allow VIPs to heal to full health
hook.Add("HealthRestore_ModifyMaxRestore", "Custom_MaxRestore", function(maxHealth, maxRestore)
    if ply:GetUserGroup() == "vip" then
        return maxHealth
    end
    return maxRestore
end)
```````

### 1. HealthRestore_CanHeal
**Determines if a player is allowed to receive healing.**

**Parameters:**
- `ply` (Player): The player to check.

**Returns:**
- `(boolean)`: 
  - `true`: Allow healing.
  - `false`: Prevent healing.

---

### 2. HealthRestore_ModifyHealAmount
**Allows modification of the healing amount per tick.**

**Parameters:**
- `ply` (Player): The player being healed.
- `amount` (number): Default heal amount.

**Returns:**
- `(number)`: Modified heal amount.

---

### 3. HealthRestore_ShouldStartHealing
**Determines if healing should begin for a player.**

**Parameters:**
- `ply` (Player): The player to check.

**Returns:**
- `(boolean)`: 
  - `true`: Start healing.
  - `false`: Prevent healing.

---

### 4. HealthRestore_ModifyMaxRestore
**Modifies the maximum amount of health a player can restore to.**

**Parameters:**
- `maxHealth` (number): Player's maximum health.
- `maxRestore` (number): Default maximum restore amount.

**Returns:**
- `(number)`: Modified maximum restore amount.

---

### 5. HealthRestore_PlaySound
**Controls whether healing sounds should play for a player.**

**Parameters:**
- `ply` (Player): The player to play sound for.
- `soundName` (string): Name of the sound to play.

**Returns:**
- `(boolean)`: 
  - `true`: Allow sound.
  - `false`: Prevent sound.

---

### 6. HealthRestore_ShouldCleanupPlayer
**Determines if a player's healing state should be cleaned up.**

**Parameters:**
- `ply` (Player): The player to check.
- `state` (table): Current healing state for the player.

**Returns:**
- `(boolean)`: 
  - `true`: Cleanup state.
  - `false`: Keep state.

---

### 7. HealthRestore_ShouldResetState
**Determines if a player's healing state should be reset.**

**Parameters:**
- `ply` (Player): The player to check.
- `state` (table): Current healing state for the player.

**Returns:**
- `(boolean)`: 
  - `true`: Reset state.
  - `false`: Keep state.
