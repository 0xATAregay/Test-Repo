-- ============================================================================
-- ProfileService.lua (Stub / Interface)
--
-- In production, replace this file with the REAL ProfileService by
-- madstudioroblox: https://madstudioroblox.github.io/ProfileService/
--
-- Installation in Roblox Studio:
--   1. Download from: https://github.com/MadStudioRoblox/ProfileService
--   2. Insert the ModuleScript into ServerScriptService/Lib
--   3. Delete this stub file
--
-- This stub provides the same API surface so the rest of the codebase
-- can require() it without errors during development.
-- ============================================================================

local ProfileService = {}

-- ============================================================================
-- MOCK PROFILE
-- ============================================================================

local MockProfile = {}
MockProfile.__index = MockProfile

function MockProfile:Reconcile()
    -- In real ProfileService this merges missing keys from the template
    -- into the loaded data. Our stub uses the template directly as Data.
end

function MockProfile:ListenToRelease(callback)
    self._releaseCallback = callback
end

function MockProfile:Release()
    if self._releaseCallback then
        task.spawn(self._releaseCallback)
    end
    self._released = true
end

function MockProfile:Save()
    -- No-op in stub. Real ProfileService writes to DataStore here.
end

function MockProfile:IsActive()
    return not self._released
end

-- ============================================================================
-- MOCK PROFILE STORE
-- ============================================================================

local MockProfileStore = {}
MockProfileStore.__index = MockProfileStore

function MockProfileStore:LoadProfileAsync(profileKey, notReleasedHandler)
    -- In the real library this loads from DataStore with session locking.
    -- Our stub just returns a fresh profile with the template data.
    local profile = setmetatable({}, MockProfile)
    profile.Data = {}

    -- Deep copy the template so each player gets their own table
    local function deepCopy(original)
        if type(original) ~= "table" then return original end
        local copy = {}
        for k, v in pairs(original) do
            copy[deepCopy(k)] = deepCopy(v)
        end
        return copy
    end

    profile.Data = deepCopy(self._template)
    profile._released = false
    profile._releaseCallback = nil

    return profile
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function ProfileService.GetProfileStore(storeName, template)
    local store = setmetatable({}, MockProfileStore)
    store._storeName = storeName
    store._template = template
    return store
end

return ProfileService
