local WAITING_DOCK_ALERT_ICON = { type = "virtual", name = "signal-red" }

-- Function to find a cloned entity near a given position within a specified radius
local function find_cloned_entity_near(surface, name, expected_position, radius)
    -- Implementation of the function
end

-- Function to clear the waiting open dock alert for a ship
local function clear_waiting_open_dock_alert(ship)
    -- Implementation of the function
end

-- Function to clear the waiting blocked dock area alert for a ship
local function clear_waiting_blocked_dock_area_alert(ship)
    -- Implementation of the function
end

-- Function to clear the missing docking port alert for a ship
local function clear_missing_docking_port_alert(ship)
    -- Implementation of the function
end

-- Initialize the docking ports storage if it doesn't exist
SpaceShip.init_docking_ports = function()
    storage.docking_ports = storage.docking_ports or {}
end

-- Function to connect adjacent docking ports
function SpaceShip.connect_adjacent_ports()
    if not storage.docking_ports then return end

    local function are_adjacent(port1, port2)
        -- Implementation of the function
    end

    -- Implementation of the function
end

-- Function to attempt docking for a ship
function SpaceShip.attempt_docking(ship)
    -- Implementation of the function
end
