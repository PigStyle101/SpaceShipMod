-- File: spaceship/docking_ports.lua

local WAITING_DOCK_ALERT_ICON = { type = "virtual", name = "signal-red" }

-- Function to find cloned entity near a given position and radius
local function find_cloned_entity_near(surface, name, expected_position, radius)
    -- Implementation details...
end

-- Function to clear waiting open dock alert for a ship
local function clear_waiting_open_dock_alert(ship)
    -- Implementation details...
end

-- Function to clear waiting blocked dock area alert for a ship
local function clear_waiting_blocked_dock_area_alert(ship)
    -- Implementation details...
end

-- Function to clear missing docking port alert for a ship
local function clear_missing_docking_port_alert(ship)
    -- Implementation details...
end

-- Function to clear all waiting states for a ship
SpaceShip.clear_waiting_states = function(ship)
    if not ship then return end
    ship.waiting_for_open_dock = false
    clear_waiting_open_dock_alert(ship)
    clear_waiting_blocked_dock_area_alert(ship)
    clear_missing_docking_port_alert(ship)
end

-- Function to initialize docking ports storage
SpaceShip.init_docking_ports = function()
    storage.docking_ports = storage.docking_ports or {}
end

-- Function to register a docking port entity
SpaceShip.register_docking_port = function(entity)
    if not storage.docking_ports then SpaceShip.init_docking_ports() end
    local name
    if entity.surface.get_tile(entity.position.x, entity.position.y).name ~= "spaceship-flooring" then
        name = entity.surface.platform.space_location.name .. table_size(storage.docking_ports)
    else
        name = "ship"
    end
    storage.docking_ports[entity.unit_number] = {
        entity = entity,
        -- Additional properties...
    }
end

-- Function to connect adjacent docking ports
SpaceShip.connect_adjacent_ports = function()
    if not storage.docking_ports then return end

    local function are_adjacent(port1, port2)
        -- Implementation details...
    end

    for _, port in pairs(storage.docking_ports) do
        for _, other_port in pairs(storage.docking_ports) do
            if port ~= other_port and are_adjacent(port, other_port) then
                -- Connect ports logic...
            end
        end
    end
end

-- Function to attempt docking of a ship
SpaceShip.attempt_docking = function(ship)
    -- Implementation details...
end
