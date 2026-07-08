-- Locale.lua — localization scaffolding. Loads before everything else.
-- ns.L[key] returns the localized string, falling back to the key itself
-- (the English source) when a locale is missing an entry.

local ADDON, ns = ...

ns.L = setmetatable({}, { __index = function(_, k) return k end })

-- Chat message helper with the addon tag.
function ns.Print(msg)
  print("|cffffd200SAMounts|r: " .. tostring(msg))
end
