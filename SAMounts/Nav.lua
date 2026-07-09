-- Nav.lua — turn-by-turn navigation using FarstriderLib as the routing engine
-- (its public API FarstriderLib_API.FindTrailTo). We render only the FIRST step
-- of the freshly-computed trail: FarstriderLib re-routes from the player's current
-- position on every call, so re-computing gives a live "next action / next hop".
--   * action step (item/spell) -> clickable secure button (Travel.lua)
--   * travel step (walk/fly/portal) -> waypoint arrow
-- Falls back cleanly (returns false) when FarstriderLib is absent.

local ADDON, ns = ...
ns.Nav = ns.Nav or {}
local Nav = ns.Nav

function Nav.Available()
  return (FarstriderLib_API and FarstriderLib_API.FindTrailTo) and true or false
end

-- Render navigation toward the target's entrance. Returns true if handled
-- (FarstriderLib present); false to let the caller fall back to a simple arrow.
function Nav.Update(target)
  if not Nav.Available() then return false end
  local l = (SAMountsLocations or {})[target.key]
  if not l or not l.map or not l.x or not l.y then return false end

  -- FarstriderLib wants UI coords in 0-1; our Locations store 0-100.
  local ok, op = pcall(FarstriderLib_API.FindTrailTo, l.map, l.x / 100, l.y / 100, 0)
  if not ok or type(op) ~= "table" or #op == 0 then
    -- present but no route (already there / off-map) -> just point at the entrance
    ns.Travel.Hide()
    ns.Waypoint.SetTo(l.map, l.x / 100, l.y / 100, target.title)
    Nav.currentLabel = nil
    return true
  end

  local step = op[1]

  -- action step? (use first usable item/spell option)
  local shown = false
  if step.actionOptions then
    for _, opt in ipairs(step.actionOptions) do
      if opt.type == "item" and opt.data then
        ns.Travel.ShowAction("item", opt.data); shown = true; break
      elseif opt.type == "spell" and opt.data then
        ns.Travel.ShowAction("spell", opt.data); shown = true; break
      end
    end
  end
  if not shown then ns.Travel.Hide() end

  -- arrow to where to go / stand to act
  if step.loc and step.loc.mapId and step.loc.pos then
    ns.Waypoint.SetTo(step.loc.mapId, step.loc.pos.x, step.loc.pos.y, step.loca or target.title)
  end
  Nav.currentLabel = step.loca      -- already-localized instruction for this step
  return true
end
