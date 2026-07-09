-- Travel.lua — on-screen, movable, CLICKABLE action button for the current
-- travel step (use hearthstone / cast a teleport / use a toy). Icon-only.
-- It is a secure button parented to UIParent (NOT inside our movable window —
-- that is what triggers "Cannot anchor protected frames to regions"). Names and
-- icons are resolved from IDs at runtime, so everything is localized.

local ADDON, ns = ...
ns.Travel = ns.Travel or {}
local Travel = ns.Travel
local L = ns.L

local btn
local pending          -- action to apply once out of combat: { kind, id }

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

-- --- the secure icon button -----------------------------------------------
local function ensureButton()
  if btn then return btn end
  btn = CreateFrame("Button", "SAMountsActionButton", UIParent,
    "SecureActionButtonTemplate,BackdropTemplate")
  btn:SetSize(44, 44)
  btn:SetFrameStrata("HIGH")
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForDrag("LeftButton")
  btn:RegisterForClicks("AnyUp", "AnyDown")

  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  btn:SetBackdropColor(0, 0, 0, 0.6)

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("TOPLEFT", 4, -4)
  btn.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  btn:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then self:StartMoving() end
  end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.actionPos = { p = p, rp = rp, x = x, y = y }
  end)

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.actionKind == "spell" and self.actionId then
      GameTooltip:SetSpellByID(self.actionId)
    elseif self.actionId then
      GameTooltip:SetItemByID(self.actionId)
    end
    GameTooltip:AddLine(L["Click to use, drag to move"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)

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

-- Show a clickable action. kind = "item" | "toy" | "spell".
function Travel.ShowAction(kind, id)
  ensureButton()
  if InCombatLockdown() then
    pending = { kind = kind, id = id }   -- attributes can't change in combat
    return
  end
  pending = nil
  if kind == "spell" then
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", spellName(id) or id)
  else -- item or toy
    btn:SetAttribute("type", "item")
    btn:SetAttribute("item", "item:" .. id)
  end
  btn.actionKind, btn.actionId = kind, id
  local ic = (kind == "spell") and spellIcon(id) or itemIcon(id)
  btn.icon:SetTexture(ic or "Interface\\Icons\\INV_Misc_QuestionMark")
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
  if pending then Travel.ShowAction(pending.kind, pending.id) end
end)
