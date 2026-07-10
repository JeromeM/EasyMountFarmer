-- UI.lua — the "one step at a time" window, flat/modern look.
-- Shows only the current target: header, per-reset counters, a ROUTE box (the
-- travel steps as a bullet list), the localized headline ("Do the dungeon X"),
-- one row per still-needed mount, and Prev / Mark-done / Next.
-- Everything user-facing is localized: UI chrome via ns.L, and mount / boss /
-- instance / difficulty names resolved from IDs and the game's own source text.

local ADDON, ns = ...
ns.UI = ns.UI or {}
local UI = ns.UI
local L = ns.L

local MAX_ROWS = 4          -- max bosses shown at once (AQ drops 4 crystals)
local W, PAD = 340, 14
local INNER = W - PAD * 2

-- text colors (escape codes)
local AMBER = "|cfff0a94a"
local GREY  = "|cff8a8a8a"
local WHITE = "|cffe9e9ec"

-- rgb accents
local C_BG        = { 0.086, 0.090, 0.106 }
local C_BORDER    = { 0.22, 0.22, 0.27 }
local C_SEP       = { 0.19, 0.19, 0.23 }
local C_PANEL_BG  = { 0.15, 0.15, 0.18 }    -- same family as the nav buttons
local C_PANEL_BRD = { 0.30, 0.30, 0.36 }
local C_GOLD_BRD  = { 0.55, 0.40, 0.14 }
local C_AMBER_TX  = { 0.96, 0.72, 0.32 }
local C_EPIC      = { 0.64, 0.21, 0.93 }
local C_RARE      = { 0.12, 0.55, 0.90 }
local NORMAL_DIFFS = { [1] = true, [14] = true }   -- not worth a badge
local MYTHIC_DIFFS = { [23] = true, [16] = true, [8] = true }
local HEARTHSTONE_ID = 6948   -- the standard Hearthstone item

-- 1px flat backdrop, fully colorable
local BD1 = {
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
}

-- ---------------------------------------------------------------------------
-- localization helpers (resolve names from IDs / the game's source text)
-- ---------------------------------------------------------------------------

--- Resolve the localized mount name from its journal id; falls back to the stored name.
---@param boss table  a mount/boss entry (has .mountID journal id and .mount fallback name)
---@return string  the localized mount name, or "?" if unknown
local function mountName(boss)
  if boss.mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
    local ok, name = pcall(C_MountJournal.GetMountInfoByID, boss.mountID)
    if ok and name and name ~= "" then return name end
  end
  return boss.mount or "?"
end

--- Resolve a mount's icon texture from its journal id (the 3rd GetMountInfoByID return).
---@param boss table  a mount/boss entry (has .mountID)
---@return number|string  the icon fileID/path, or a question-mark fallback
local function iconFor(boss)
  if boss.mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
    local ok, _, _, icon = pcall(C_MountJournal.GetMountInfoByID, boss.mountID)
    if ok and icon then return icon end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- Split a mount's localized source text into its individual lines. The source is
--- a few lines separated by "|n" (WoW's newline token) or real newlines, e.g.
--- "Drop: <boss>|n<instance>|n<expansion>"; color codes and inline textures are stripped.
---@param mountID number  the mount journal id
---@return string[]? lines  trimmed, non-empty source lines, or nil if unavailable
local function sourceLines(mountID)
  if not (mountID and C_MountJournal and C_MountJournal.GetMountInfoExtraByID) then return end
  local ok, _, _, source = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
  if not ok or type(source) ~= "string" or source == "" then return end
  source = source:gsub("|n", "\n")
  local lines = {}
  for line in source:gmatch("[^\r\n]+") do
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")   -- strip color codes
    line = line:gsub("|T.-|t", "")                              -- strip inline textures
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then lines[#lines + 1] = line end
  end
  return lines
end

--- Strip a leading localized label ("Drop:", "Butin :", "Région :", ...) and a
--- trailing "(difficulty)" parenthetical, keeping the meaningful name.
---@param s string?  a raw source line
---@return string?  the cleaned name, or nil if empty/nil
local function stripLabel(s)
  if not s then return nil end
  s = s:gsub("%s*%b()%s*$", "")           -- trailing "(mythic)" etc.
  local after = s:match("[:：]%s*(.+)$")   -- text after "Label :"
  if after then s = after end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return (s ~= "" and s) or nil
end

--- Uppercase the first letter (only when it is an ASCII a-z, to stay UTF-8 safe).
---@param s string?  the input string
---@return string?  the string with its first letter capitalized (unchanged if non-ASCII/empty/nil)
local function capitalize(s)
  if not s or s == "" then return s end
  local b = s:byte(1)
  if b and b >= 97 and b <= 122 then
    return string.char(b - 32) .. s:sub(2)
  end
  return s
end

--- Resolve the localized boss name for a mount from its first source line,
--- falling back to the stored boss name.
---@param boss table  a mount/boss entry (has .mountID journal id and .name fallback)
---@return string?  the localized boss name, or nil if unknown
local function bossName(boss)
  local lines = sourceLines(boss.mountID)
  local b = lines and lines[1] and stripLabel(lines[1])
  if b then return b end
  return (boss.name and boss.name ~= "" and boss.name) or nil
end

--- Resolve the localized instance name for a target. Generated data already stores
--- a localized name; hand-authored trash instances carry an English one, so for those
--- we prefer the mount's localized source "location" line, then a locale override.
---@param target table  a farm target (has .instance, .category, .title and .bosses)
---@return string  the localized instance name
local function instanceName(target)
  local first = target.bosses and target.bosses[1]
  if target.category == "trash" then
    if first then
      local lines = sourceLines(first.mountID)
      local s = lines and lines[2] and stripLabel(lines[2])
      if s and s ~= "" then return s end
    end
    local inst = target.instance
    local tr = inst and L[inst]
    if tr and tr ~= inst then return tr end
    return inst or "?"
  end
  if target.instance and target.instance ~= "" then return target.instance end
  if first then
    local lines = sourceLines(first.mountID)
    if lines and lines[2] then
      local inst = stripLabel(lines[2])
      if inst then return inst end
    end
  end
  return target.title or "?"
end

--- Build the localized headline for a target, split into an action line and a name line.
--- Handles world bosses / rares (name the mount's boss), dungeons and raids.
---@param target table  a farm target (has .category, .bosses, .instance)
---@return string? action  the localized action line (e.g. "Do the dungeon"), or nil
---@return string name  the localized, capitalized target name
local function targetParts(target)
  local cat = target.category
  if cat == "worldboss" then
    -- world boss: the name is the BOSS (source line 1), not its zone
    local first = target.bosses and target.bosses[1]
    local bn = (first and bossName(first)) or instanceName(target)
    return L["Kill the world boss"], capitalize(bn)
  end
  if cat == "rare" or cat == "treasure" or cat == "vendor" or cat == "event" then
    local first = target.bosses and target.bosses[1]
    local label = (cat == "rare" and L["Rare enemy"]) or (cat == "treasure" and L["Treasure"])
      or (cat == "vendor" and L["Vendor"]) or L["Seasonal event"]
    if cat == "vendor" and target.vendor then label = label .. " · " .. target.vendor end
    if target.zoneName and target.zoneName ~= "" then label = label .. " · " .. target.zoneName end
    -- rare/treasure: name the source (NPC / treasure); vendor/event: name the mount
    local name
    if cat == "rare" or cat == "treasure" then
      name = (first and bossName(first)) or (first and mountName(first)) or instanceName(target)
    else
      name = (first and mountName(first)) or instanceName(target)
    end
    return label, capitalize(name)
  end
  local inst = capitalize(instanceName(target))
  if cat == "dungeon" then return L["Do the dungeon"], inst end
  if cat == "raid" or cat == "trash" then return L["Do the raid"], inst end
  return nil, inst
end

--- Resolve the localized required-difficulty label for a target via the game. The
--- required difficulty is derived and stored on the target (target.reqDiff).
---@param target table  a farm target (has .reqDiff)
---@return string? name  the localized difficulty name, or nil if not worth a badge
---@return boolean? isMythic  true when the required difficulty is a Mythic tier
local function diffBadge(target)
  local req = target and target.reqDiff
  if not req or NORMAL_DIFFS[req] then return nil end
  if GetDifficultyInfo then
    local ok, name = pcall(GetDifficultyInfo, req)
    if ok and name and name ~= "" then return name, MYTHIC_DIFFS[req] end
  end
  return nil
end

--- Format a duration in seconds as "Xd Yh" / "Xh Ym" / "Xm".
---@param s number?  a duration in seconds (clamped to >= 0)
---@return string  the human-readable duration
function UI.Dur(s)
  s = math.max(0, math.floor(s or 0))
  local d = math.floor(s / 86400); s = s % 86400
  local h = math.floor(s / 3600); s = s % 3600
  local m = math.floor(s / 60)
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  return m .. "m"
end

-- ---------------------------------------------------------------------------
-- flat widget builders
-- ---------------------------------------------------------------------------
local BTN_COLORS = {
  primary = { bg = {0.24,0.17,0.05}, hov = {0.34,0.25,0.08}, brd = {0.85,0.65,0.25}, tx = {1.0,0.82,0.40} },
  warn    = { bg = {0.20,0.14,0.04}, hov = {0.28,0.20,0.06}, brd = {0.80,0.55,0.15}, tx = {1.0,0.78,0.35} },
  nav     = { bg = {0.15,0.15,0.18}, hov = {0.22,0.22,0.27}, brd = {0.30,0.30,0.36}, tx = {0.86,0.86,0.90} },
}

--- Repaint a flat button to reflect its kind and enabled/hover state.
---@param b Frame  a button created by makeButton (has ._kind and .label)
---@param hover boolean  true to use the hover colors
local function paint(b, hover)
  local c = BTN_COLORS[b._kind] or BTN_COLORS.nav
  local on = b:IsEnabled()
  local a = on and 1 or 0.4
  local bg = (hover and on) and c.hov or c.bg
  b:SetBackdropColor(bg[1], bg[2], bg[3], on and 0.95 or 0.5)
  b:SetBackdropBorderColor(c.brd[1], c.brd[2], c.brd[3], a)
  b.label:SetTextColor(c.tx[1], c.tx[2], c.tx[3], a)
end

--- Enable or disable a flat button and repaint it accordingly.
---@param b Frame  a button created by makeButton
---@param enabled boolean  true to enable the button, false to disable it
function UI.SetBtn(b, enabled)
  if enabled then b:Enable() else b:Disable() end
  paint(b, false)
end

--- Create a flat, colorable button with a centered label and hover repainting.
---@param parent Frame  the parent frame
---@param kind string  a BTN_COLORS key ("primary" | "warn" | "nav")
---@param font string?  a font object name for the label (default "GameFontNormalSmall")
---@return Frame  the created button (with .label and ._kind fields)
local function makeButton(parent, kind, font)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetBackdrop(BD1)
  b.label = b:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
  b.label:SetPoint("CENTER")
  b.label:SetJustifyH("CENTER")
  b._kind = kind
  --- Repaint the button in its hover state.
  ---@param s Frame  the hovered button
  b:SetScript("OnEnter", function(s) paint(s, true) end)
  --- Repaint the button in its normal state.
  ---@param s Frame  the button that lost hover
  b:SetScript("OnLeave", function(s) paint(s, false) end)
  paint(b, false)
  return b
end

--- Create a flat, colorable panel frame using the 1px backdrop.
---@param parent Frame  the parent frame
---@return Frame  the created panel
local function makePanel(parent)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  p:SetBackdrop(BD1)
  return p
end

-- flat check row (checkbox + label), matching the window's look
local C_CHK_ON = { 0.24, 0.17, 0.05 }   -- amber fill when ticked
local C_CHK_OFF = { 0.12, 0.12, 0.15 }

--- Repaint a check row to reflect its ticked state.
---@param row Frame  a row from makeCheckRow
---@param checked boolean  whether the row is ticked
local function paintCheck(row, checked)
  local bg = checked and C_CHK_ON or C_CHK_OFF
  row.box:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
  local brd = checked and C_GOLD_BRD or C_PANEL_BRD
  row.box:SetBackdropBorderColor(brd[1], brd[2], brd[3], 1)
  row.check:SetShown(checked)
  if checked then
    row.text:SetTextColor(C_AMBER_TX[1], C_AMBER_TX[2], C_AMBER_TX[3])
  else
    row.text:SetTextColor(0.55, 0.55, 0.60)
  end
end

--- Create a flat check row (clickable checkbox + label) in a parent.
---@param parent Frame  the parent frame
---@param label string  the row label
---@param width number  the row width
---@return Frame  the row (with .box, .check, .text; use paintCheck to set its state)
local function makeCheckRow(parent, label, width)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, 20)
  row.box = makePanel(row)
  row.box:SetSize(15, 15)
  row.box:SetPoint("LEFT", 4, 0)
  row.check = row.box:CreateTexture(nil, "OVERLAY")
  row.check:SetPoint("CENTER")
  row.check:SetSize(16, 16)
  row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.text:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
  row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  row.text:SetJustifyH("LEFT")
  row.text:SetText(label)
  return row
end

-- ---------------------------------------------------------------------------
-- position persistence
-- ---------------------------------------------------------------------------
--- Persist the window's current anchor point to the saved variables.
function UI.SavePosition()
  local p, _, rp, x, y = UI.frame:GetPoint()
  ns.db.pos = { p = p, rp = rp, x = x, y = y }
end

--- Restore the window's saved anchor point, or center it if none is stored.
function UI.RestorePosition()
  UI.frame:ClearAllPoints()
  local pos = ns.db and ns.db.pos
  if pos and pos.p then
    UI.frame:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    UI.frame:SetPoint("CENTER")
  end
end

-- ---------------------------------------------------------------------------
-- filter panel (in-window category / expansion checklist)
-- ---------------------------------------------------------------------------
--- Build the filter popup: a checklist of categories + expansions anchored to the
--- right of the main window. Idempotent (no-op once built).
function UI.BuildFilterPanel()
  if UI.filterPanel then return end
  local FW = 190
  local p = CreateFrame("Frame", "EasyMountFarmerFilter", UI.frame, "BackdropTemplate")
  UI.filterPanel = p
  p:SetFrameStrata("DIALOG")
  p:SetWidth(FW)
  -- anchored on open by UI.PositionFilterPanel (left or right of the window)
  p:SetBackdrop(BD1)
  p:SetBackdropColor(C_BG[1], C_BG[2], C_BG[3], 0.98)
  p:SetBackdropBorderColor(C_BORDER[1], C_BORDER[2], C_BORDER[3], 1)
  p:EnableMouse(true)
  p:Hide()

  UI.filterRows = {}
  local y = -10

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 10, y)
  title:SetText(WHITE .. L["Filters"] .. "|r")
  y = y - 24

  --- Add a dim section header at the running offset.
  ---@param text string  the header label
  local function sectionHeader(text)
    local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", 10, y)
    h:SetText(text)
    h:SetTextColor(0.55, 0.55, 0.62)
    y = y - 18
  end

  --- Add a check row bound to a getter/setter; rebuilds the route on toggle.
  ---@param label string  the row label
  ---@param get function  returns the current boolean value
  ---@param set function  receives the new boolean value
  local function addRow(label, get, set)
    local row = makeCheckRow(p, label, FW - 16)
    row:SetPoint("TOPLEFT", 8, y)
    paintCheck(row, get())
    row:SetScript("OnClick", function()
      local v = not get()
      set(v)
      paintCheck(row, v)
      if ns.Progress and ns.Progress.Rebuild then ns.Progress.Rebuild(true) end
    end)
    UI.filterRows[#UI.filterRows + 1] = { row = row, get = get }
    y = y - 20
  end

  sectionHeader(L["Show these categories"])
  local CATS = {
    { "dungeon", L["Dungeons"] }, { "raid", L["Raids"] }, { "worldboss", L["World bosses"] },
    { "trash", L["Trash drops"] },
    { "rare", L["Rare enemies"] }, { "event", L["Seasonal events"] },
    { "vendor", L["Vendors"] }, { "treasure", L["Treasures"] }, { "achievement", L["Achievements"] },
  }
  for _, c in ipairs(CATS) do
    local cat = c[1]
    addRow(c[2],
      function() return ns.db.filter and ns.db.filter.categories[cat] == true end,
      function(v) ns.db.filter.categories[cat] = v end)
  end

  y = y - 8
  sectionHeader(L["Show these expansions"])
  for _, e in ipairs(ns.EXPANSION_ORDER or {}) do
    local exp = e
    addRow(L[exp],
      function() return not ns.db.filter or ns.db.filter.expansions[exp] ~= false end,
      function(v) ns.db.filter.expansions[exp] = v end)
  end

  p:SetHeight(-y + 10)
end

--- Repaint every filter check row from the current saved state.
function UI.RefreshFilterRows()
  for _, r in ipairs(UI.filterRows or {}) do paintCheck(r.row, r.get()) end
end

--- Anchor the filter popup to whichever side of the window has room, so it stays on
--- screen even when the main window is pushed against the right edge.
function UI.PositionFilterPanel()
  local p, f = UI.filterPanel, UI.frame
  if not p or not f then return end
  p:ClearAllPoints()
  local right = f:GetRight()
  local screenW = UIParent:GetWidth()
  local panelW = p:GetWidth() or 190
  if right and screenW and (screenW - right) >= (panelW + 10) then
    p:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)      -- room on the right
  else
    p:SetPoint("TOPRIGHT", f, "TOPLEFT", -6, 0)     -- flip to the left
  end
end

--- Toggle the filter popup open/closed (building it on first use).
function UI.ToggleFilter()
  UI.BuildFilterPanel()
  if UI.filterPanel:IsShown() then
    UI.filterPanel:Hide()
  else
    UI.PositionFilterPanel()
    UI.RefreshFilterRows()
    UI.filterPanel:Show()
  end
end

-- ---------------------------------------------------------------------------
-- build the window
-- ---------------------------------------------------------------------------
--- Build the main window and all its child widgets (idempotent: no-op if already built).
function UI.Init()
  if UI.frame then return end

  local f = CreateFrame("Frame", "EasyMountFarmerFrame", UIParent, "BackdropTemplate")
  UI.frame = f
  f:SetSize(W, 360)
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:SetBackdrop(BD1)
  f:SetBackdropColor(C_BG[1], C_BG[2], C_BG[3], 0.97)
  f:SetBackdropBorderColor(C_BORDER[1], C_BORDER[2], C_BORDER[3], 1)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  --- Begin dragging the window, unless it is locked.
  ---@param self Frame  the window frame
  f:SetScript("OnDragStart", function(self)
    if not (ns.db and ns.db.locked) then self:StartMoving() end
  end)
  --- Stop dragging the window and persist its new position.
  ---@param self Frame  the window frame
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); UI.SavePosition() end)
  f:SetClampedToScreen(true)
  f:Hide()

  -- header: icon (left) + centered title + close (right)
  f.icon = makePanel(f)
  f.icon:SetSize(22, 22)
  f.icon:SetPoint("TOPLEFT", PAD, -12)
  f.icon:SetBackdropColor(0.10, 0.08, 0.14, 1)
  f.icon:SetBackdropBorderColor(C_EPIC[1], C_EPIC[2], C_EPIC[3], 0.9)
  f.iconTex = f.icon:CreateTexture(nil, "ARTWORK")
  f.iconTex:SetPoint("TOPLEFT", 2, -2)
  f.iconTex:SetPoint("BOTTOMRIGHT", -2, 2)
  f.iconTex:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
  f.iconTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  f.icon:EnableMouse(true)
  f.icon:SetScript("OnMouseUp", function()
    if not InCombatLockdown() and ToggleCollectionsJournal then
      pcall(ToggleCollectionsJournal, 1)   -- open Collections -> Mounts tab
    end
  end)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOP", f, "TOP", 0, -15)
  f.title:SetText(WHITE .. L["EasyMountFarmer"] .. "|r")

  f.close = makeButton(f, "nav", "GameFontNormalLarge")
  f.close:SetSize(22, 22)
  f.close:SetPoint("TOPRIGHT", -10, -11)
  f.close.label:SetText("×")
  f.close:SetScript("OnClick", function() UI.Hide() end)

  -- options (gear) button, just left of the close button
  f.gear = makeButton(f, "nav")
  f.gear:SetSize(22, 22)
  f.gear:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  f.gear.label:Hide()
  f.gearTex = f.gear:CreateTexture(nil, "OVERLAY")
  f.gearTex:SetSize(14, 14)
  f.gearTex:SetPoint("CENTER")
  f.gearTex:SetTexture("Interface\\ICONS\\INV_Misc_Gear_01")
  f.gearTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  f.gear:SetScript("OnClick", function() UI.OpenSettings() end)

  -- header separator
  f.sep = f:CreateTexture(nil, "ARTWORK")
  f.sep:SetColorTexture(C_SEP[1], C_SEP[2], C_SEP[3], 1)
  f.sep:SetHeight(1)
  f.sep:SetPoint("TOPLEFT", PAD, -44)
  f.sep:SetPoint("TOPRIGHT", -PAD, -44)

  -- step / count row
  f.step = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.step:SetJustifyH("LEFT")
  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.count:SetJustifyH("CENTER")

  -- "Filters" button, right-aligned on the count line (positioned in Refresh)
  f.filter = makeButton(f, "nav")
  f.filter:SetSize(58, 20)
  f.filter.label:SetText(L["Filters"])
  f.filter:SetScript("OnClick", function() UI.ToggleFilter() end)

  -- target headline: small dim action line + big amber name line (both centered)
  f.targetAction = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.targetAction:SetJustifyH("CENTER")
  f.targetAction:SetTextColor(0.62, 0.62, 0.68)

  f.target = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.target:SetJustifyH("CENTER")
  f.target:SetWordWrap(true)
  f.target:SetSpacing(2)

  -- "done this reset" marker (shown when the current step is already completed)
  f.doneMark = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.doneMark:SetJustifyH("CENTER")
  f.doneMark:Hide()

  -- "wait for reset" info: guidance + countdown, shown on the all-done step
  f.waitInfo = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.waitInfo:SetJustifyH("CENTER")
  f.waitInfo:SetSpacing(5)
  f.waitInfo:Hide()

  -- docked action panel: the clickable travel action (hearthstone / teleport /
  -- item) with the secure button anchored inside it (see Travel.lua).
  f.actionPanel = makePanel(f)
  f.actionPanel:SetBackdropColor(0.17, 0.13, 0.05, 0.9)
  f.actionPanel:SetBackdropBorderColor(C_GOLD_BRD[1], C_GOLD_BRD[2], C_GOLD_BRD[3], 1)
  f.actionLabel = f.actionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.actionLabel:SetPoint("LEFT", f.actionPanel, "LEFT", 46, 0)
  f.actionLabel:SetPoint("RIGHT", f.actionPanel, "RIGHT", -8, 0)
  f.actionLabel:SetJustifyH("LEFT")
  f.actionLabel:SetWordWrap(false)
  f.actionLabel:SetTextColor(C_AMBER_TX[1], C_AMBER_TX[2], C_AMBER_TX[3])
  ns.Travel.Ensure(f.actionPanel)   -- builds + docks the secure button in the panel
  f.actionPanel:Hide()

  -- boss rows
  UI.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(INNER, 38)

    row.iconFrame = makePanel(row)
    row.iconFrame:SetSize(36, 36)
    row.iconFrame:SetPoint("TOPLEFT", 0, 0)
    row.iconFrame:SetBackdropColor(0, 0, 0, 0.5)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 10, -1)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(C_AMBER_TX[1], C_AMBER_TX[2], C_AMBER_TX[3])

    row.boss = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.boss:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.boss:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.boss:SetJustifyH("LEFT")
    row.boss:SetWordWrap(false)

    -- difficulty badge (pill)
    row.badge = makePanel(row)
    row.badge:SetHeight(18)
    row.badge:SetPoint("TOPRIGHT", 0, -1)
    row.badgeText = row.badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.badgeText:SetPoint("CENTER")

    row:EnableMouse(true)
    --- Show a tooltip for the row's mount (by spell/item id, else plain name) plus any note.
    ---@param self Frame  the hovered row (has .data mount entry and .noteText)
    row:SetScript("OnEnter", function(self)
      if not self.data then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local b = self.data
      if b.spellID and GameTooltip.SetMountBySpellID then
        GameTooltip:SetMountBySpellID(b.spellID)
      elseif b.itemID and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(b.itemID)
      else
        GameTooltip:SetText(mountName(b))
      end
      if self.noteText and self.noteText ~= "" then
        GameTooltip:AddLine(self.noteText, 0.7, 0.7, 0.7, true)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    UI.rows[i] = row
  end

  -- difficulty switch button (conditional)
  f.diff = makeButton(f, "warn")
  f.diff:SetHeight(24)
  f.diff:SetScript("OnClick", function()
    ns.Difficulty.SwitchTo(ns.Progress.Current())
  end)
  f.diff:Hide()

  -- bottom nav row
  f.prev = makeButton(f, "nav", "GameFontNormalLarge")
  f.prev:SetSize(34, 28)
  f.prev.label:SetText("‹")

  f.next = makeButton(f, "nav", "GameFontNormalLarge")
  f.next:SetSize(34, 28)
  f.next.label:SetText("›")

  f.done = makeButton(f, "primary", "GameFontNormalSmall")
  f.done:SetHeight(28)
  f.done.label:SetText(L["Mark step as done"])

  -- left-click: step by one; right-click: jump back to the first step still to do
  f.prev:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  --- Go to the previous step (left-click), or jump back to the first undone step (right-click).
  ---@param _ Frame  the button frame (unused)
  ---@param mb string  the mouse button that was clicked
  f.prev:SetScript("OnClick", function(_, mb)
    if mb == "RightButton" then ns.Progress.ResetPointer() else ns.Progress.Prev() end
  end)
  f.next:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  --- Go to the next step (left-click), or jump back to the first undone step (right-click).
  ---@param _ Frame  the button frame (unused)
  ---@param mb string  the mouse button that was clicked
  f.next:SetScript("OnClick", function(_, mb)
    if mb == "RightButton" then ns.Progress.ResetPointer() else ns.Progress.Next() end
  end)
  f.done:SetScript("OnClick", function()
    local cur = ns.Progress.Current()
    if cur then ns.Progress.MarkDone(cur.key, cur.type, "manual") end
  end)

  -- reset-all popup (triggered by slash / minimap right-click; no visible button)
  StaticPopupDialogs["EASYMOUNTFARMER_RESET_ALL"] = {
    text = L["Reset all completed steps for this reset?"],
    button1 = YES, button2 = NO,
    OnAccept = function() ns.Progress.ResetAllDone() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }

  UI.RestorePosition()
end

--- Determine which reset cadences have completed (locked) content this reset. Used by
--- the "wait for reset" step to show only the relevant countdown(s).
---@return boolean daily  true if a daily-reset target is done this reset
---@return boolean weekly  true if a weekly-reset target is done (defaults true when none)
local function pendingResets()
  local daily, weekly = false, false
  for _, t in ipairs(ns.Progress.Active()) do
    if ns.Progress.IsDone(t.key) then
      if ns.Progress.ResetTypeFor(t.key, t.type) == "Dungeon" then daily = true else weekly = true end
    end
  end
  if not daily and not weekly then weekly = true end   -- sane default
  return daily, weekly
end

-- ---------------------------------------------------------------------------
-- refresh the display
-- ---------------------------------------------------------------------------
--- Rebuild the window contents for the current step: counters, route, headline,
--- boss rows, travel action, and nav buttons; also drives auto-guide/waypoints.
function UI.Refresh()
  local f = UI.frame
  if not f or not f.target then return end
  f.waitInfo:Hide()

  local y = -56

  -- step (left) / count (centered) / Filters button (right-aligned), same line
  f.step:ClearAllPoints(); f.step:SetPoint("TOPLEFT", PAD, y)
  f.count:ClearAllPoints(); f.count:SetPoint("TOP", f, "TOP", 0, y - 2)
  f.filter:ClearAllPoints(); f.filter:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
  y = y - 30

  local n = #ns.Progress.Active()
  local total = ns.Route.CountRemainingMounts(ns.allTargets or {})
  local idx = ns.Progress.Index()
  local cur = ns.Progress.Current()

  -- empty states: keep the centered count + Filters line at the top (so the filter
  -- stays reachable even when everything is filtered out), and show the message below.
  if not cur then
    f.step:SetWidth(0); f.step:SetWordWrap(false); f.step:SetText("")
    f.count:SetText(GREY .. string.format(L["%d mounts to find"], total) .. "|r")
    f.doneMark:Hide()
    f.actionPanel:Hide()
    f.targetAction:Hide()
    for _, row in ipairs(UI.rows) do row:Hide() end
    f.diff:Hide()
    ns.Travel.Hide()

    f.target:ClearAllPoints()
    f.target:SetPoint("TOP", f, "TOP", 0, y)
    f.target:SetWidth(INNER)
    f.target:SetText((total == 0)
      and ("|cff62d06e" .. L["Grats! All farmable mounts collected."] .. "|r")
      or (WHITE .. L["Nothing to farm this reset — come back after reset."] .. "|r"))
    local my = y - math.max(22, f.target:GetStringHeight()) - 16

    UI.SetBtn(f.prev, false); UI.SetBtn(f.next, false); UI.SetBtn(f.done, false)
    f.prev:ClearAllPoints(); f.prev:SetPoint("TOPLEFT", PAD, my)
    f.next:ClearAllPoints(); f.next:SetPoint("TOPRIGHT", -PAD, my)
    f.done:ClearAllPoints()
    f.done:SetPoint("LEFT", f.prev, "RIGHT", 8, 0)
    f.done:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    f:SetHeight(-(my - 28) + 12)
    return
  end

  f.step:SetWidth(0); f.step:SetWordWrap(false)
  f.step:SetText(WHITE .. string.format(L["Step %d / %d"], idx, n) .. "|r")
  f.count:SetText(GREY .. string.format(L["%d mounts to find"], total) .. "|r")

  local curDone = ns.Progress.IsDone(cur.key)

  -- "wait for reset" step: everything is done this reset but mounts remain.
  -- Shown only while auto-following (manual nav still browses the done steps),
  -- so the natural end of the run lands on a clear "come back later" screen.
  if ns.Progress.AutoFollowing() and not ns.Progress.AnyUndone() then
    ns.Travel.Hide()
    ns.Waypoint.Clear()
    UI.lastGuidedKey = nil

    f.step:SetWidth(0); f.step:SetWordWrap(false)
    f.step:SetText(WHITE .. string.format(L["Step %d / %d"], n, n) .. "|r")
    f.count:SetText(GREY .. string.format(L["%d mounts to find"], total) .. "|r")

    f.doneMark:Hide()
    f.actionPanel:Hide()
    f.targetAction:Hide()
    f.diff:Hide()
    for _, row in ipairs(UI.rows) do row:Hide() end

    y = y - 8
    f.target:ClearAllPoints()
    f.target:SetPoint("TOPLEFT", PAD, y)
    f.target:SetWidth(INNER)
    f.target:SetText("|cff62d06e" .. L["All done for this reset"] .. "|r")
    y = y - math.max(22, f.target:GetStringHeight()) - 12

    -- guidance + the relevant reset countdown(s)
    local info = { L["Come back after the reset to continue."] }
    local daily, weekly = pendingResets()
    if daily then info[#info + 1] = string.format(L["Daily reset in %s"], UI.Dur(ns.Progress.SecondsUntilDaily())) end
    if weekly then info[#info + 1] = string.format(L["Weekly reset in %s"], UI.Dur(ns.Progress.SecondsUntilWeekly())) end
    f.waitInfo:ClearAllPoints()
    f.waitInfo:SetPoint("TOPLEFT", PAD, y)
    f.waitInfo:SetWidth(INNER)
    f.waitInfo:SetText(GREY .. table.concat(info, "\n") .. "|r")
    f.waitInfo:Show()
    y = y - f.waitInfo:GetStringHeight() - 16

    -- nav row: let the player step back to review done steps; nothing forward
    f.prev:ClearAllPoints(); f.prev:SetPoint("TOPLEFT", PAD, y)
    f.next:ClearAllPoints(); f.next:SetPoint("TOPRIGHT", -PAD, y)
    f.done:ClearAllPoints()
    f.done:SetPoint("LEFT", f.prev, "RIGHT", 8, 0)
    f.done:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    UI.SetBtn(f.prev, n > 1)
    UI.SetBtn(f.next, false)
    UI.SetBtn(f.done, false)
    y = y - 28

    f:SetHeight(-y + 12)
    return
  end

  -- navigation decision up front (sets ns.Travel.active + the waypoint), so the
  -- docked action panel can be laid out below; skipped when the step is done.
  if f:IsShown() and ns.db and ns.db.autoGuide then
    local inInstance = IsInInstance()
    if not inInstance then ns.leaveInstanceHint = nil end   -- reset once outside

    if inInstance and ns.leaveInstanceHint then
      -- boss objective reached in this instance -> guide the player out
      -- (no FarstriderLib needed: it's just a hearthstone)
      ns.Travel.ShowAction("item", HEARTHSTONE_ID, L["Leave the instance / Hearthstone"])
      ns.Waypoint.Clear()
    elseif inInstance then
      -- still working on this instance's objective: no prompt, no arrow
      ns.Travel.Hide()
      ns.Waypoint.Clear()
    elseif curDone then
      ns.Travel.Hide()
      ns.Waypoint.Clear()
    elseif ns.Nav.Available() then
      -- FarstriderLib turn-by-turn; if it can't route (returns false/empty), fall
      -- back to a plain waypoint to the entrance.
      if not ns.Nav.Update(cur) then
        ns.Travel.Hide()
        if cur.key ~= UI.lastGuidedKey then
          UI.lastGuidedKey = cur.key
          ns.Waypoint.GuideTo(cur, true)
        end
      end
    else
      -- no FarstriderLib: just a waypoint arrow to the entrance
      ns.Travel.Hide()
      if cur.key ~= UI.lastGuidedKey then
        UI.lastGuidedKey = cur.key
        ns.Waypoint.GuideTo(cur, true)  -- silent
      end
    end
  else
    ns.Travel.Hide()
    if curDone then ns.Waypoint.Clear() end
  end

  -- "done this reset" marker
  if curDone then
    f.doneMark:ClearAllPoints()
    f.doneMark:SetPoint("TOPLEFT", PAD, y)
    f.doneMark:SetWidth(INNER)
    f.doneMark:SetText("|cff62d06e" .. (ns.Progress.AnyUndone() and L["Done this reset"] or L["All done for this reset"]) .. "|r")
    f.doneMark:Show()
    y = y - 22
  else
    f.doneMark:Hide()
  end

  -- docked action panel: secure button + "Use X", when a travel action is suggested
  if ns.Travel.active then
    f.actionLabel:SetText(ns.Travel.label or "")
    f.actionPanel:ClearAllPoints()
    f.actionPanel:SetPoint("TOPLEFT", PAD, y)
    f.actionPanel:SetSize(INNER, 42)
    f.actionPanel:Show()
    y = y - 42 - 14
  else
    f.actionPanel:Hide()
  end

  -- target headline: dim action line, then big amber name line (wraps if long)
  local action, name = targetParts(cur)
  if action then
    f.targetAction:ClearAllPoints()
    f.targetAction:SetPoint("TOPLEFT", PAD, y)
    f.targetAction:SetWidth(INNER)
    f.targetAction:SetText(action)
    f.targetAction:Show()
    y = y - 16
  else
    f.targetAction:Hide()
  end
  f.target:ClearAllPoints()
  f.target:SetPoint("TOPLEFT", PAD, y)
  f.target:SetWidth(INNER)
  f.target:SetText(AMBER .. name .. "|r")
  y = y - math.max(22, f.target:GetStringHeight()) - 14

  -- boss rows (dimmed when the step is done)
  local rowAlpha = curDone and 0.4 or 1
  local badgeLabel, isMythic = diffBadge(cur)
  local shown = 0
  for i, boss in ipairs(cur.bosses) do
    local row = UI.rows[i]
    if not row then break end
    row:SetAlpha(rowAlpha)
    row.data = boss
    row.noteText = boss.note or ""
    row.icon:SetTexture(iconFor(boss))
    local rc = boss.epic and C_EPIC or C_RARE
    row.iconFrame:SetBackdropBorderColor(rc[1], rc[2], rc[3], 0.9)
    row.name:SetText(mountName(boss))
    row.boss:SetText(GREY .. (bossName(boss) or "-") .. "|r")

    -- difficulty badge only on the first row
    if i == 1 and badgeLabel then
      local col = isMythic and { 1.0, 0.5, 0.0 } or { 0.90, 0.30, 0.30 }
      row.badgeText:SetText(badgeLabel)
      row.badgeText:SetTextColor(col[1] + 0.05, col[2] + 0.3, col[3] + 0.3)
      row.badge:SetWidth(row.badgeText:GetStringWidth() + 16)
      row.badge:SetBackdropColor(col[1] * 0.45, col[2] * 0.30, col[3] * 0.30, 0.85)
      row.badge:SetBackdropBorderColor(col[1], col[2], col[3], 0.9)
      row.badge:Show()
      row.name:ClearAllPoints()
      row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 10, -1)
      row.name:SetPoint("RIGHT", row.badge, "LEFT", -8, 0)
    else
      row.badge:Hide()
      row.name:ClearAllPoints()
      row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 10, -1)
      row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD, y)
    row:Show()
    y = y - 44
    shown = i
  end
  for i = shown + 1, #UI.rows do UI.rows[i]:Hide() end
  if #cur.bosses > MAX_ROWS then
    UI.rows[MAX_ROWS].boss:SetText(GREY .. string.format(L["(+%d more mounts here)"], #cur.bosses - MAX_ROWS) .. "|r")
  end

  -- difficulty switch button (only when needed and the step isn't done)
  if not curDone and ns.Difficulty.NeedsSwitch(cur) then
    f.diff.label:SetText(ns.Difficulty.SwitchLabel(cur))
    f.diff:ClearAllPoints()
    f.diff:SetPoint("TOPLEFT", PAD, y - 2)
    f.diff:SetWidth(INNER)
    f.diff:Show()
    y = y - 34
  else
    f.diff:Hide()
  end

  -- bottom nav row
  y = y - 10
  f.prev:ClearAllPoints(); f.prev:SetPoint("TOPLEFT", PAD, y)
  f.next:ClearAllPoints(); f.next:SetPoint("TOPRIGHT", -PAD, y)
  f.done:ClearAllPoints()
  f.done:SetPoint("LEFT", f.prev, "RIGHT", 8, 0)
  f.done:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
  UI.SetBtn(f.prev, idx > 1)
  UI.SetBtn(f.next, idx < n)
  UI.SetBtn(f.done, not curDone)
  y = y - 28

  f:SetHeight(-y + 12)
end

-- ---------------------------------------------------------------------------
-- show / hide
-- ---------------------------------------------------------------------------
--- Build the window if needed, mark it shown in saved variables, and refresh it.
function UI.Show()
  if not UI.frame then UI.Init() end
  if ns.db then ns.db.shown = true end
  UI.frame:Show()
  -- start the tour near the player each time the window is opened
  if ns.Route and ns.Route.ComputeStart and ns.Progress and ns.Progress.Rebuild then
    ns.Route.ComputeStart()
    ns.Progress.Rebuild(true)
  end
  UI.Refresh()
end

--- Hide the window (marking it hidden in saved variables) and any travel prompt.
function UI.Hide()
  if ns.db then ns.db.shown = false end
  if UI.frame then UI.frame:Hide() end
  if UI.filterPanel then UI.filterPanel:Hide() end
  if ns.Travel then ns.Travel.Hide() end
end

--- Toggle the window's visibility, building it first if needed.
function UI.Toggle()
  if not UI.frame then UI.Init() end
  if UI.frame:IsShown() then UI.Hide() else UI.Show() end
end

-- ---------------------------------------------------------------------------
-- options: registered in the game's Settings panel (AddOns category)
-- ---------------------------------------------------------------------------
--- Register the addon's options in the game's Settings panel (idempotent).
function UI.BuildSettings()
  if UI.settingsCategory then return end
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then return end

  local category, layout = Settings.RegisterVerticalLayoutCategory(L["EasyMountFarmer"])
  UI.settingsCategory = category

  --- Register a boolean proxy setting and add a checkbox for it to the category.
  ---@param variable string  the setting's storage key suffix (prefixed with "EasyMountFarmer_")
  ---@param name string  the localized label shown next to the checkbox
  ---@param getter function  returns the current boolean value
  ---@param setter function  receives the new boolean value
  local function boolean(variable, name, getter, setter)
    local setting = Settings.RegisterProxySetting(category, "EasyMountFarmer_" .. variable,
      Settings.VarType.Boolean, name, true, getter, setter)
    Settings.CreateCheckbox(category, setting)
  end

  boolean("autoAdvance", L["Auto-advance to the next step"],
    function() return ns.db.autoAdvance ~= false end,
    function(v) ns.db.autoAdvance = v; if ns.UI.Refresh then ns.UI.Refresh() end end)

  -- TomTom checkbox only when TomTom is installed
  if TomTom and TomTom.AddWaypoint then
    boolean("useTomTom", L["Use TomTom"],
      function() return ns.db.useTomTom ~= false end,
      function(v) ns.db.useTomTom = v; UI.lastGuidedKey = nil; if ns.UI.Refresh then ns.UI.Refresh() end end)
  end

  boolean("lootPopup", L["Show the loot notification"],
    function() return ns.db.lootPopup ~= false end,
    function(v) ns.db.lootPopup = v end)

  boolean("autoGuide", L["Auto-guide (waypoint / action)"],
    function() return ns.db.autoGuide ~= false end,
    function(v) ns.db.autoGuide = v; UI.lastGuidedKey = nil; if ns.UI.Refresh then ns.UI.Refresh() end end)

  boolean("showMinimap", L["Show the minimap button"],
    function() return not (ns.db.minimap and ns.db.minimap.hide) end,
    function(v)
      ns.db.minimap = ns.db.minimap or {}
      ns.db.minimap.hide = not v
      if ns.Minimap then
        if not ns.Minimap.button and ns.Minimap.Init then ns.Minimap.Init() end
        if ns.Minimap.button then ns.Minimap.button:SetShown(v) end
      end
    end)

  boolean("locked", L["Lock the window position"],
    function() return ns.db.locked == true end,
    function(v) ns.db.locked = v end)

  -- loot announce channel (dropdown)
  if Settings.CreateDropdown and Settings.CreateControlTextContainer then
    local chan = Settings.RegisterProxySetting(category, "EasyMountFarmer_lootChannel",
      Settings.VarType.String, L["Announce loot in channel"], "NONE",
      function() return ns.db.lootChannel or "NONE" end,
      function(v) ns.db.lootChannel = v end)
    --- Build the dropdown options for the loot announce channel.
    ---@return table  the dropdown control data
    local function options()
      local c = Settings.CreateControlTextContainer()
      c:Add("NONE", L["Do not announce"])
      c:Add("PARTY", L["Party"])
      c:Add("RAID", L["Raid"])
      c:Add("GUILD", L["Guild"])
      return c:GetData()
    end
    Settings.CreateDropdown(category, chan, options)
  end

  Settings.RegisterAddOnCategory(category)
end

--- Build the settings if needed and open the game's Settings panel to this category.
function UI.OpenSettings()
  UI.BuildSettings()
  if UI.settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(UI.settingsCategory:GetID())
  end
end

-- ---------------------------------------------------------------------------
-- loot popup
-- ---------------------------------------------------------------------------
--- Show a transient "mount obtained" popup with the mount's icon and name (auto-hides).
---@param name string?  the obtained mount's name
---@param icon string?  the icon texture path (defaults to a question mark)
function UI.ShowLootPopup(name, icon)
  local p = UI.popup
  if not p then
    p = CreateFrame("Frame", "EasyMountFarmerPopup", UIParent, "BackdropTemplate")
    p:SetSize(320, 74)
    p:SetPoint("TOP", 0, -200)
    p:SetFrameStrata("DIALOG")
    p:SetBackdrop(BD1)
    p:SetBackdropColor(C_BG[1], C_BG[2], C_BG[3], 0.98)
    p:SetBackdropBorderColor(C_GOLD_BRD[1], C_GOLD_BRD[2], C_GOLD_BRD[3], 1)
    p.iconFrame = makePanel(p)
    p.iconFrame:SetSize(46, 46)
    p.iconFrame:SetPoint("LEFT", 14, 0)
    p.iconFrame:SetBackdropColor(0, 0, 0, 0.5)
    p.iconFrame:SetBackdropBorderColor(C_EPIC[1], C_EPIC[2], C_EPIC[3], 0.9)
    p.icon = p.iconFrame:CreateTexture(nil, "ARTWORK")
    p.icon:SetPoint("TOPLEFT", 2, -2)
    p.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.text = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.text:SetPoint("LEFT", p.iconFrame, "RIGHT", 12, 0)
    p.text:SetPoint("RIGHT", -12, 0)
    p.text:SetJustifyH("LEFT")
    UI.popup = p
  end
  p.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  p.text:SetText("|cff62d06e" .. L["Mount obtained!"] .. "|r\n" .. WHITE .. (name or "") .. "|r")
  p:Show()
  if p.timer then p.timer:Cancel() end
  p.timer = C_Timer.NewTimer(7, function() p:Hide() end)
  if PlaySound and SOUNDKIT then
    pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST)
  end
end
