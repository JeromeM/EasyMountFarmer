-- Travel.lua — on-screen, movable, CLICKABLE action button for the current
-- travel step (use hearthstone / cast a teleport / use a toy). It is a secure
-- macro button parented to UIParent (NOT inside our movable window — that is
-- what triggers "Cannot anchor protected frames to regions"). Names/icons are
-- resolved from IDs at runtime, so everything is localized.

local ADDON, ns = ...
ns.Travel = ns.Travel or {}
local Travel = ns.Travel
local L = ns.L

local btn
local pending          -- action to apply once out of combat: { kind, id, label }

-- --- localized name / icon resolution -------------------------------------
local function itemName(id)
  return C_Item and C_Item.GetItemInfo and (C_Item.GetItemInfo(id))
end
local function spellName(id)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
  return info and info.name
end
local function itemIcon(id)
  return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
end
local function spellIcon(id)
  return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
end

-- macrotext for an action (localized where needed; items go by id, so no locale issue)
local function macrotext(kind, id)
  if kind == "item" or kind == "toy" then return "/use item:" .. id end
  if kind == "spell" then
    local n = spellName(id)
    return n and ("/cast " .. n) or nil
  end
  return nil
end

-- --- the secure button ----------------------------------------------------
local function ensureButton()
  if btn then return btn end
  btn = CreateFrame("Button", "SAMountsActionButton", UIParent,
    "SecureActionButtonTemplate,UIPanelButtonTemplate")
  btn:SetSize(210, 30)
  btn:SetFrameStrata("HIGH")
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForDrag("LeftButton")
  btn:RegisterForClicks("AnyUp")

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(22, 22)
  btn.icon:SetPoint("LEFT", 5, 0)
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  -- dragging moves a protected frame -> only allowed out of combat
  btn:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then self:StartMoving() end
  end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.actionPos = { p = p, rp = rp, x = x, y = y }
  end)

  local pos = ns.db and ns.db.actionPos
  btn:ClearAllPoints()
  if pos and pos.p then
    btn:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    btn:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
  end
  btn:Hide()
  return btn
end

-- Show a clickable action. kind = "item" | "toy" | "spell". label optional.
function Travel.ShowAction(kind, id, label)
  ensureButton()
  if InCombatLockdown() then
    pending = { kind = kind, id = id, label = label }  -- apply after combat
    return
  end
  pending = nil
  local mt = macrotext(kind, id)
  if not mt then btn:Hide(); return end
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", mt)
  local name = label or (kind == "spell" and spellName(id)) or itemName(id) or ("#" .. tostring(id))
  btn:SetText(name)
  local ic = (kind == "spell") and spellIcon(id) or itemIcon(id)
  if ic then btn.icon:SetTexture(ic); btn.icon:Show() else btn.icon:Hide() end
  btn:Show()
end

function Travel.Hide()
  pending = nil
  if btn and not InCombatLockdown() then btn:Hide() end
end

-- Apply a deferred action once we leave combat.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function()
  if pending then
    local p = pending
    Travel.ShowAction(p.kind, p.id, p.label)
  end
end)
