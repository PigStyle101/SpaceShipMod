local SpaceShip                 = {}
SpaceShip.__index               = SpaceShip
local SpaceShipFunctions        = require("SpaceShipFunctionsScript")

local DROP_COST                 = {
    ["rocket-fuel"] = 20,
    ["processing-unit"] = 20,
    ["low-density-structure"] = 20
}

SpaceShip.hub                   = nil
SpaceShip.floor                 = {}                         -- Table to store floor tiles
SpaceShip.walls                 = {}                         -- Table to store wall tiles
SpaceShip.entities              = {}                         -- Table to store entities
SpaceShip.name                  = nil or "Unnamed SpaceShip" -- Name of the spaceship
SpaceShip.id                    = nil or 0                   -- Unique ID for the spaceship
SpaceShip.player_owner          = nil                        -- Reference to the player prototype
SpaceShip.reference_tile        = nil
SpaceShip.referance_tile        = nil -- legacy typo alias kept for compatibility
SpaceShip.surface               = nil
SpaceShip.scanned               = false
SpaceShip.scanning              = false
SpaceShip.player_in_cockpit     = nil
SpaceShip.taking_off            = false
SpaceShip.own_surface           = false
SpaceShip.planet_orbiting       = nil
SpaceShip.schedule              = {}
SpaceShip.traveling             = false
SpaceShip.automatic             = false
SpaceShip.port_records          = {}
SpaceShip.docking_port          = nil
SpaceShip.docked_port_unit_number = nil
SpaceShip.docked                = true
SpaceShip.leave_immediately     = false
SpaceShip.waiting_for_open_dock = false
SpaceShip.waiting_for_open_dock_since_tick = nil
SpaceShip.waiting_for_open_dock_alerted = false
SpaceShip.waiting_for_open_dock_alert_message = nil
SpaceShip.waiting_for_open_dock_alert_last_tick = nil
SpaceShip.waiting_for_clear_dock_area = false
SpaceShip.waiting_for_clear_dock_area_alerted = false
SpaceShip.waiting_for_clear_dock_area_alert_message = nil
SpaceShip.waiting_for_clear_dock_area_alert_last_tick = nil
SpaceShip.waiting_for_scan      = false

-- Constructor for creating a new SpaceShip
function SpaceShip.new(name, id, player)
    local self                 = setmetatable({}, SpaceShip)

    -- Initialize spaceship parameters
    self.floor                 = {}                      -- Table to store floor tiles
    self.walls                 = {}                      -- Table to store wall tiles
    self.entities              = {}                      -- Table to store entities
    self.name                  = name or "Unnamed SpaceShip" -- Name of the spaceship
    self.id                    = id or 0                 -- Unique ID for the spaceship
    self.player                = player                  -- Reference to the player prototype
    self.hub                   = nil
    self.reference_tile        = nil
    self.referance_tile        = nil -- legacy typo alias kept for compatibility
    self.surface               = nil
    self.scanned               = false
    self.scanning              = false
    self.player_in_cockpit     = nil
    self.taking_off            = false
    self.own_surface           = false
    self.planet_orbiting       = nil
    self.schedule              = {}
    self.traveling             = false
    self.automatic             = false
    self.port_records          = {}
    self.docking_port          = nil
    self.docked_port_unit_number = nil
    self.docked                = true
    self.leave_immediately     = false
    self.waiting_for_open_dock = false
    self.waiting_for_open_dock_since_tick = nil
    self.waiting_for_open_dock_alerted = false
    self.waiting_for_open_dock_alert_message = nil
    self.waiting_for_open_dock_alert_last_tick = nil
    self.waiting_for_clear_dock_area = false
    self.waiting_for_clear_dock_area_alerted = false
    self.waiting_for_clear_dock_area_alert_message = nil
    self.waiting_for_clear_dock_area_alert_last_tick = nil
    self.waiting_for_scan      = false

    -- Store the spaceship in the global storage
    return self
end

require("spaceship/rendering")(SpaceShip)
require("spaceship/scanning")(SpaceShip)
require("spaceship/docking_ports")(SpaceShip)
require("spaceship/schedule")(SpaceShip)
require("spaceship/cloning")(SpaceShip)
require("spaceship/docking_travel")(SpaceShip)
require("spaceship/drops")(SpaceShip, DROP_COST)
require("spaceship/entity_handlers")(SpaceShip)

return SpaceShip
