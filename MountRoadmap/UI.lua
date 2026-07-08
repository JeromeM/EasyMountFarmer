-- UI.lua — the "one step at a time" window: current target only, with
-- breadcrumb, boss/mount rows, Prev/Next, Guide and Difficulty buttons, plus a
-- congrats popup on loot.

local ADDON, ns = ...
ns.UI = ns.UI or {}
local UI = ns.UI
local L = ns.L

local MAX_ROWS = 4          -- max bosses shown at once (AQ drops 4 crystals)
local EPIC = "|cffa335ee"
local RARE = "|cff0070dd"
local GREY = "|cff808080"

local BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- Format a duration in seconds as "Xd Yh" / "Xh Ym" / "Xm".
function UI.Dur(s)
  s = math.max(0, math.floor(s or 0))
  local d = math.floor(s / 86400); s = s % 86400
  local h = math.floor(s / 3600); s = s % 3600
  local m = math.floor(s / 60)
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  return m .. "m"
end

-- --- position persistence -------------------------------------------------
function UI.SavePosition()
  local p, _, rp, x, y = UI.frame:GetPoint()
  ns.db.pos = { p = p, rp = rp, x = x, y = y }
end

function UI.RestorePosition()
  UI.frame:ClearAllPoints()
  local pos = ns.db and ns.db.pos
  if pos and pos.p then
    UI.frame:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    UI.frame:SetPoint("CENTER")
  end
end

-- --- build the window -----------------------------------------------------
function UI.Init()
  if UI.frame then return end

  local f = CreateFrame("Frame", "MountRoadmapFrame", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
  UI.frame = f
  f:SetSize(384, 372)
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:SetBackdrop(BACKDROP)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); UI.SavePosition() end)
  f:SetClampedToScreen(true)
  f:Hide()

  -- title
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText(L["Mount Roadmap"])

  -- close button
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- header (progress + counts)
  f.header = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  f.header:SetPoint("TOPLEFT", 18, -44)
  f.header:SetPoint("RIGHT", -18, 0)
  f.header:SetJustifyH("LEFT")

  -- reset timers
  f.reset = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  f.reset:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -5)
  f.reset:SetPoint("RIGHT", -18, 0)
  f.reset:SetJustifyH("LEFT")

  -- breadcrumb
  f.trail = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  f.trail:SetPoint("TOPLEFT", f.reset, "BOTTOMLEFT", 0, -8)
  f.trail:SetWidth(348)
  f.trail:SetHeight(42)
  f.trail:SetJustifyH("LEFT")
  f.trail:SetJustifyV("TOP")
  f.trail:SetWordWrap(true)

  -- target (instance/run) title
  f.target = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  f.target:SetPoint("TOPLEFT", f.trail, "BOTTOMLEFT", 0, -6)
  f.target:SetPoint("RIGHT", -18, 0)
  f.target:SetJustifyH("LEFT")

  -- boss rows
  UI.rows = {}
  local anchor = f.target
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(348, 32)
    if i == 1 then
      row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      row:SetPoint("TOPLEFT", UI.rows[i - 1], "BOTTOMLEFT", 0, -2)
    end
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("TOPLEFT", 0, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetPoint("RIGHT", 0, 0)
    row.name:SetJustifyH("LEFT")
    row.note = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.note:SetPoint("RIGHT", 0, 0)
    row.note:SetJustifyH("LEFT")
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      if not self.boss then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local b = self.boss
      if b.spellId and GameTooltip.SetMountBySpellID then
        GameTooltip:SetMountBySpellID(b.spellId)
      elseif b.itemId and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(b.itemId)
      else
        GameTooltip:SetText(b.mount or "")
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    UI.rows[i] = row
  end

  -- difficulty button (conditional)
  f.diff = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.diff:SetSize(180, 22)
  f.diff:SetPoint("BOTTOM", 0, 44)
  f.diff:SetScript("OnClick", function()
    ns.Difficulty.SwitchTo(ns.Progress.Current())
  end)
  f.diff:Hide()

  -- bottom buttons
  f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.prev:SetSize(92, 22)
  f.prev:SetPoint("BOTTOMLEFT", 16, 14)
  f.prev:SetText(L["< Prev"])
  f.prev:SetScript("OnClick", function() ns.Progress.Prev() end)

  f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.next:SetSize(92, 22)
  f.next:SetPoint("LEFT", f.prev, "RIGHT", 6, 0)
  f.next:SetText(L["Next >"])
  f.next:SetScript("OnClick", function() ns.Progress.Next() end)

  f.guide = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.guide:SetSize(110, 22)
  f.guide:SetPoint("BOTTOMRIGHT", -16, 14)
  f.guide:SetText(L["Guide me"])
  f.guide:SetScript("OnClick", function() ns.Waypoint.GuideTo(ns.Progress.Current()) end)

  UI.RestorePosition()
end

-- --- refresh the display --------------------------------------------------
function UI.Refresh()
  local f = UI.frame
  if not f then return end

  f.reset:SetText(string.format(L["Daily reset: %s"], UI.Dur(ns.Progress.SecondsUntilDaily()))
    .. "   " .. GREY .. "•|r   " .. string.format(L["Weekly: %s"], UI.Dur(ns.Progress.SecondsUntilWeekly())))

  local active = ns.Progress.Active()
  local n = #active
  local total = ns.Route.CountRemainingMounts(ns.allTargets or {})
  local idx = ns.Progress.Index()
  local cur = ns.Progress.Current()

  if not cur then
    if total == 0 then
      f.header:SetText("|cff40ff40" .. L["Grats! All farmable mounts collected."] .. "|r")
    else
      f.header:SetText(L["Nothing to farm this reset — come back after reset."])
    end
    f.trail:SetText("")
    f.target:SetText("")
    for _, row in ipairs(UI.rows) do row:Hide() end
    f.prev:Disable(); f.next:Disable(); f.guide:Disable(); f.diff:Hide()
    return
  end

  f.header:SetText(string.format(L["Step %d / %d"], idx, n)
    .. "   " .. GREY .. "•|r   " .. string.format(L["%d mounts left"], total))

  -- breadcrumb
  local parts = {}
  for _, e in ipairs(cur.breadcrumb or {}) do parts[#parts + 1] = e.label end
  if #parts > 0 then
    f.trail:SetText(L["Route:"] .. "  " .. table.concat(parts, "  " .. GREY .. ">|r  "))
  else
    f.trail:SetText("")
  end

  f.target:SetText(cur.title or "")

  -- boss rows
  local shown = 0
  for i, boss in ipairs(cur.bosses) do
    local row = UI.rows[i]
    if not row then break end
    row.boss = boss
    row.icon:SetTexture("Interface\\Icons\\" .. (boss.icon or "INV_Misc_QuestionMark"))
    local color = boss.epic and EPIC or RARE
    local bossName = (boss.name and boss.name ~= "") and ("  " .. GREY .. "— " .. boss.name .. "|r") or ""
    row.name:SetText(color .. (boss.mount or "?") .. "|r" .. bossName)
    row.note:SetText(boss.note or "")
    row:Show()
    shown = i
  end
  for i = shown + 1, #UI.rows do UI.rows[i]:Hide() end
  if #cur.bosses > MAX_ROWS then
    UI.rows[MAX_ROWS].note:SetText(string.format(L["(+%d more mounts here)"], #cur.bosses - MAX_ROWS))
  end

  -- buttons
  if idx > 1 then f.prev:Enable() else f.prev:Disable() end
  if idx < n then f.next:Enable() else f.next:Disable() end
  f.guide:Enable()

  if ns.Difficulty.NeedsSwitch(cur) then
    f.diff:SetText(ns.Difficulty.SwitchLabel(cur))
    f.diff:Show()
  else
    f.diff:Hide()
  end
end

-- --- show/hide ------------------------------------------------------------
function UI.Show()
  if not UI.frame then UI.Init() end
  UI.frame:Show()
  UI.Refresh()
end

function UI.Hide()
  if UI.frame then UI.frame:Hide() end
end

function UI.Toggle()
  if not UI.frame then UI.Init() end
  if UI.frame:IsShown() then UI.frame:Hide() else UI.Show() end
end

-- --- loot popup -----------------------------------------------------------
function UI.ShowLootPopup(name, icon)
  local p = UI.popup
  if not p then
    p = CreateFrame("Frame", "MountRoadmapPopup", UIParent,
      BackdropTemplateMixin and "BackdropTemplate" or nil)
    p:SetSize(320, 72)
    p:SetPoint("TOP", 0, -200)
    p:SetFrameStrata("DIALOG")
    p:SetBackdrop(BACKDROP)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetSize(44, 44)
    p.icon:SetPoint("LEFT", 16, 0)
    p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    p.text = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    p.text:SetPoint("LEFT", p.icon, "RIGHT", 12, 0)
    p.text:SetPoint("RIGHT", -12, 0)
    p.text:SetJustifyH("LEFT")
    UI.popup = p
  end
  p.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  p.text:SetText("|cff40ff40" .. L["Mount obtained!"] .. "|r\n" .. (name or ""))
  p:Show()
  if p.timer then p.timer:Cancel() end
  p.timer = C_Timer.NewTimer(7, function() p:Hide() end)
  if PlaySound and SOUNDKIT then
    pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST)
  end
end
