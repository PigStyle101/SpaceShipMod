local Stations = {}

-- Function to check if a platform name indicates it's a station
local function is_station_platform(platform_name)
    return string.find(platform_name, "-station") ~= nil
end

-- Function to check if a platform name indicates it's a ship
local function is_ship_platform(platform_name)
    return string.find(platform_name, "-ship") ~= nil
end

-- Function to get the planet name from a station platform name
local function get_planet_from_station_name(station_name)
    local planet_name = string.match(station_name, "(.+)-station")
    return planet_name
end

-- Function to count existing stations orbiting a planet
local function count_stations_for_planet(force, planet_name)
    local station_count = 0
    local station_platforms = {}
    
    for _, platform in pairs(force.platforms) do
        if platform.space_location and platform.space_location.name == planet_name then
            if is_station_platform(platform.name) then
                station_count = station_count + 1
                table.insert(station_platforms, platform)
            end
        end
    end
    
    return station_count, station_platforms
end

-- Main function to handle new platform creation and station management
function Stations.handle_platform_state_change(event)
    local platform = event.platform
    local old_state = event.old_state
    local new_state = platform.state
    
    -- Check for state change from 1 (waiting for starter pack) to 7 (ready)
    if old_state == 1 and new_state == 7 then
        -- Skip if this is a ship platform (should have been renamed by SpaceShip.lua)
        if is_ship_platform(platform.name) then
            return -- Ships are handled separately
        end
        
        -- Check if this is a new platform that needs to be processed as a station
        local space_location = platform.space_location
        if not space_location then
            return -- No location, can't process
        end
        
        local planet_name = space_location.name
        local force = platform.force
        
        -- Count existing stations for this planet
        local station_count, existing_stations = count_stations_for_planet(force, planet_name)
        
        if station_count == 0 then
            -- This is the first station for this planet, rename it appropriately
            local new_station_name = planet_name .. "-station"
            platform.name = new_station_name
            game.print("[color=green]Created first station for " .. planet_name .. ": " .. new_station_name .. "[/color]")
        else
            -- There's already a station for this planet, delete the new one
            game.print("[color=yellow]A station already exists for " .. planet_name .. ". Removing duplicate station platform.[/color]")
            
            -- Give feedback about the existing station
            if existing_stations[1] then
                game.print("[color=cyan]Existing station: " .. existing_stations[1].name .. "[/color]")
            end
            
            -- Destroy the duplicate platform
            platform.destroy()
            return
        end
    end
end

-- Check if player has required armor to get off planet
function Stations.has_spaceship_armor(player)
    if not player or not player.valid then return false end
    
    -- Get player armor inventory
    local armor_inventory = player.get_inventory(defines.inventory.character_armor)
    if not armor_inventory or armor_inventory.is_empty() then return false end
    
    -- Check if player is wearing spaceship armor
    local armor = armor_inventory[1]
    if not armor or not armor.valid_for_read then return false end
    
    -- Check if armor is the required type (spaceship-armor)
    return armor.name == "spaceship-armor" or armor.name == "space-armor"
end

-- Function to initialize station management (call this from control.lua)
function Stations.init()
    -- Any initialization logic can go here
    if not storage.stations then
        storage.stations = {}
    end
    storage.station_control_state = storage.station_control_state or {}
end

-- Prevent station platforms from being manually scheduled or set to automatic travel.
-- This only targets "-station" platforms and does not touch "-ship" logic.
function Stations.enforce_station_hub_controls()
    storage.station_control_state = storage.station_control_state or {}

    for _, force in pairs(game.forces) do
        for _, platform in pairs(force.platforms) do
            if platform and platform.valid and is_station_platform(platform.name) then
                local key = force.name .. "/" .. platform.name
                local state = storage.station_control_state[key] or {
                    warned_schedule = false,
                    warned_auto = false
                }

                local has_schedule_records = false
                local current_schedule = platform.schedule
                if type(current_schedule) == "table" then
                    local records = rawget(current_schedule, "records")
                    if type(records) == "table" and #records > 0 then
                        has_schedule_records = true
                    end
                end

                if has_schedule_records then
                    platform.schedule = nil
                    if not state.warned_schedule then
                        game.print("[color=red]Station platform schedules are disabled. Use spaceship schedules only.[/color]")
                        state.warned_schedule = true
                    end
                else
                    state.warned_schedule = false
                end

                if not platform.paused then
                    platform.paused = true
                    if not state.warned_auto then
                        game.print("[color=red]Station platforms cannot be set to automatic travel.[/color]")
                        state.warned_auto = true
                    end
                else
                    state.warned_auto = false
                end

                storage.station_control_state[key] = state
            end
        end
    end
end

return Stations
