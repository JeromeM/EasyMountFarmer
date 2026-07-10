-- MinimapButton.lua — self-contained minimap button (no external libs).
-- Left-click: toggle window. Right-click: reset per-reset completions.

local ADDON, ns = ...
ns.Minimap = ns.Minimap or {}
local Minimap = ns.Minimap
local L = ns.L

local RADIUS = 80

local function updatePosition(btn)
  local angle = math.rad((ns.db.minimap and ns.db.minimap.angle) or 200)
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", _G.Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

function Minimap.Init()
  if Minimap.button then return end
  ns.db.minimap = ns.db.minimap or {}

  local btn = CreateFrame("Button", "EasyMountFarmerMinimapButton", _G.Minimap)
  Minimap.button = btn
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\Icons\\Ability_Mount_Drake_Blue")
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  btn:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      ns.Progress.ResetAllDone()
      ns.Print(L["Re-synced to the first step to do."])
    else
      ns.UI.Toggle()
    end
  end)

  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = _G.Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = _G.Minimap:GetEffectiveScale()
      px, py = px / scale, py / scale
      ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx))
      updatePosition(self)
    end)
  end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L["EasyMountFarmer"])
    GameTooltip:AddLine(L["Left-click: open/close"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: jump to the next step to do"], 1, 1, 1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)

  updatePosition(btn)
  if ns.db.minimap.hide then btn:Hide() end
end
