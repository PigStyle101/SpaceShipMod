local SpaceShipFunctions = require("SpaceShipFunctionsScript")
local SpaceShip = require("SpaceShip")
local SpaceShipGuis = {}
local gui_maker = require("__ship-gui__.spaceship_gui.spaceship_gui")

-- Define event handlers
function SpaceShipGuis.on_station_selected(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Station " .. event.selected_station .. " selected for ship " .. ship.name)
        SpaceShip.add_or_change_station(ship, event.selected_station)
        
        -- Initialize port_records if needed
        if not ship.port_records then
            ship.port_records = {}
        end
        
        -- Find the station index for the newly added station
        local station_index = nil
        if ship.schedule and ship.schedule.records then
            for i, record in pairs(ship.schedule.records) do
                if record.station == event.selected_station then
                    station_index = i
                    break
                end
            end
        end
        
        -- Auto-assign the first available port for this planet
        if station_index then
            local first_port = nil
            for unit_number, port_data in pairs(storage.docking_ports or {}) do
                if port_data.surface and port_data.surface.platform and 
                   port_data.surface.platform.space_location and
                   port_data.surface.platform.space_location.name == event.selected_station and
                   port_data.name ~= "ship" then
                    first_port = port_data.name
                    break
                end
            end
            
            if first_port then
                ship.port_records[station_index] = first_port
                game.print("Auto-assigned port '" .. first_port .. "' for station " .. event.selected_station)
            else
                game.print("Warning: No available ports found for station " .. event.selected_station)
            end
        end
        
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_station_move_up(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " moving station up")
    end
    SpaceShip.station_move_up(ship, event.station_index)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_station_move_down(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " moving station down")
    end
    SpaceShip.station_move_down(ship, event.station_index)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_station_dock_selected(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling dock selection")
        -- Initialize port_records if needed
        if not ship.port_records then
            ship.port_records = {}
        end
        
        -- Store the port name for this station (e.g., "nauvis0", "nauvis1", etc.)
        ship.port_records[event.station_index] = event.selected_dock
        game.print("Selected port '" .. event.selected_dock .. "' for station " .. event.station_index)
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_station_unload_check_changed(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling unload")
    end
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_station_condition_add(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling add condition")
    end
    local condition_type = string.lower(string.gsub(event.selected_item, " condition", ""))
    SpaceShip.add_wait_condition(ship, event.station_index, condition_type)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_station_goto(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling goto")
        SpaceShip.goto_station(ship, event.station_index)
    end
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_condition_move_up(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling move condition up")
    end
    SpaceShip.condition_move_up(ship, event.station_index, event.condition_index)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_condition_move_down(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling move condition down")
    end
    SpaceShip.condition_move_down(ship, event.station_index, event.condition_index)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_station_delete(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling delete station")
    end
    SpaceShip.delete_station(ship, event.station_index)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_condition_delete(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling delete condition")
    end
    SpaceShip.remove_wait_condition(ship, event.station_index, event.condition_index)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_condition_constant_confirmed(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling constant changed")
    end
    SpaceShip.constant_changed(ship, event.station_index, event.condition_index, event.amount)
end

function SpaceShipGuis.on_comparison_sign_changed(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling compair changed")
    end
    SpaceShip.compair_changed(ship, event.station_index, event.condition_index, event.comparator)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_bool_changed(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling bool changed")
    end
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_first_signal_selected(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling signal check")
    end
    SpaceShip.signal_changed(ship, event.station_index, event.condition_index, event.selected_signal)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_ship_rename_confirmed(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling rename")
    end
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

function SpaceShipGuis.on_ship_paused_unpaused(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        game.print("Ship " .. ship.name .. " handling paused")
    end
    SpaceShip.auto_manual_changed(ship)
    SpaceShipGuis.gui_maker_handler(ship, event.player_index)
end

-- Function to create the custom spaceship control GUI
function SpaceShipGuis.create_spaceship_gui(player, ship)
    local relative_gui = player.gui.relative

    if relative_gui["spaceship-controller-extended-gui-" .. ship.name] then
        return
    end
    if relative_gui["spaceship-controller-schedual-gui-" .. ship.name] then
        return
    end
    local ship_tag_number = tonumber(ship.id)
    -- Initialize storage if needed
    storage = storage or {}
    storage.spaceships = storage.spaceships or {}

    local custom_gui = relative_gui.add {
        type = "frame",
        name = "spaceship-controller-extended-gui-" .. ship.name,
        caption = "Spaceship Actions",
        direction = "vertical",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            position = defines.relative_gui_position.left
        },
        tags = { ship = ship_tag_number }
    }

    -- Add a dropdown with researched planets (even if not yet visited)
    local planet_names = {}
    local force = ship.hub.force

    -- Always include Nauvis (starting planet)
    table.insert(planet_names, "nauvis")

    -- Check for researched Space Age planets
    local planet_research_map = {
        ["vulcanus"] = "planet-discovery-vulcanus",
        ["fulgora"] = "planet-discovery-fulgora",
        ["gleba"] = "planet-discovery-gleba",
        ["aquilo"] = "planet-discovery-aquilo"
    }

    -- Add planets that have been researched
    for planet_name, research_tech in pairs(planet_research_map) do
        local tech = force.technologies[research_tech]
        if tech and tech.researched then
            table.insert(planet_names, planet_name)
        end
    end

    -- Check for modded planets with discovery technologies
    -- Look through all technologies for ones that follow the planet-discovery pattern
    for tech_name, technology in pairs(force.technologies) do
        if string.match(tech_name, "^planet%-discovery%-(.+)$") and technology.researched then
            local planet_name = string.match(tech_name, "^planet%-discovery%-(.+)$")
            -- Don't add duplicates from the standard planets above
            local already_added = false
            for _, existing_planet in pairs(planet_names) do
                if existing_planet == planet_name then
                    already_added = true
                    break
                end
            end
            if not already_added then
                table.insert(planet_names, planet_name)
            end
        end
    end

    -- Also add any existing surfaces that are clearly planets (visited planets)
    -- This catches any edge cases or planets that don't follow the research pattern
    for surface_name, surface in pairs(game.surfaces) do
        if not string.find(surface_name, "platform") and
            not string.find(surface_name, "space%-") and
            not string.find(surface_name, "orbit") and
            surface_name ~= "nauvis" then -- Don't duplicate nauvis
            -- Check if it's not already in our list
            local already_added = false
            for _, existing_planet in pairs(planet_names) do
                if existing_planet == surface_name then
                    already_added = true
                    break
                end
            end
            if not already_added then
                table.insert(planet_names, surface_name)
            end
        end
    end

    custom_gui.add {
        type = "drop-down",
        name = "surface-dropdown",
        items = planet_names,
        selected_index = 1,
        tags = { ship = ship_tag_number }
    }
    custom_gui.add { type = "button", name = "ship-dock", caption = "Dock", tags = { ship = ship_tag_number } }
    custom_gui.add { type = "button", name = "ship-takeoff", caption = "Takeoff", tags = { ship = ship_tag_number } }
    custom_gui.add { type = "button", name = "drop-player-to-planet", caption = "Drop player to Planet", tags = { ship = ship_tag_number } }
    custom_gui.add { type = "button", name = "drop-items-to-planet", caption = "Drop items to Planet", tags = { ship = ship_tag_number } }
end

-- Function to close the spaceship control GUI
function SpaceShipGuis.close_spaceship_gui(event)
    if not event.entity then return end
    if event.entity.name ~= "spaceship-control-hub" then return end
    if not event.player_index then return end
    local ship
    for _, value in pairs(storage.spaceships) do
        if value.hub.unit_number == event.entity.unit_number then
            ship = storage.spaceships[value.id]
        end
    end
    local player = game.get_player(event.player_index)
    if event.entity and event.entity.name == "spaceship-control-hub" then
        -- Destroy the custom GUI when the main GUI for "spaceship-control-hub" is closed.
        local custom_gui = player.gui.relative["spaceship-controller-extended-gui-" .. ship.name]
        if custom_gui then
            custom_gui.destroy()
            game.print("extended GUI closed with the main GUI.")
        end
        local custom_gui = player.gui.relative["spaceship-controller-schedual-gui-" .. ship.name]
        if custom_gui then
            custom_gui.destroy()
            ship.schedule_gui = nil
            game.print("schedual GUI closed with the main GUI.")
        end
    end
end

-- Function to handle button clicks
function SpaceShipGuis.handle_button_click(event)
    local button_name = event.element.name
    local player = game.get_player(event.player_index)
    if button_name == "ship-takeoff" then -- Call the shipTakeoff function
        local ship = storage.spaceships[event.element.tags.ship]
        game.print("Spaceship takeoff initiated!")
        local dropdown = event.element.parent["surface-dropdown"]
        SpaceShip.ship_takeoff(ship, dropdown)
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
        SpaceShip.auto_manual_changed(ship)
    elseif button_name == "confirm-dock" then
        local ship = storage.spaceships[event.element.tags.ship]
        game.print("Docking confirmed!")
        SpaceShip.finalize_dock(ship)
    elseif button_name == "cancel-dock" then
        local ship = storage.spaceships[event.element.tags.ship]
        game.print("Docking canceled!")
        SpaceShip.cancel_dock(ship)
    elseif button_name == "ship-dock" then
        game.print("Docking the spaceship...")
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.dock_ship(ship)
    elseif button_name == "drop-player-to-planet" then
        game.print("dropping player to planet")
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.drop_player_to_planet(ship)
    elseif button_name == "drop-items-to-planet" then
        game.print("dropping items to planet")
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.drop_items_to_planet(ship)
    elseif button_name == "close-dock-gui" then
        SpaceShipGuis.close_docking_port_gui(player)
    else
        game.print("Unknown button clicked: " .. button_name)
    end
end

function SpaceShipGuis.create_docking_port_gui(player, docking_port)
    local tile = docking_port.surface.get_tile(docking_port.position)
    if tile.name ~= "space-platform-foundation" then
        game.print("Space ship docking ports cannot be modified")
        if player.gui.screen["docking-port-gui"] then
            player.gui.screen["docking-port-gui"].destroy()
        end
        return
    end
    -- Store the selected docking port for reference
    storage.selected_docking_port = docking_port

    -- First close any existing GUI
    if player.gui.screen["docking-port-gui"] then
        player.gui.screen["docking-port-gui"].destroy()
    end

    -- Create new custom GUI in screen instead of relative
    local dock_gui = player.gui.screen.add {
        type = "frame",
        name = "docking-port-gui",
        caption = "Docking Port Settings",
        direction = "vertical"
    }

    -- Center the GUI on screen
    dock_gui.force_auto_center()

    -- Add name label and textbox
    local name_flow = dock_gui.add {
        type = "flow",
        direction = "horizontal"
    }
    name_flow.add {
        type = "label",
        caption = "Name:"
    }
    name_flow.add {
        type = "textfield",
        name = "dock-name-input",
        text = ""
    }

    -- Add ship limit label and textbox
    local limit_flow = dock_gui.add {
        type = "flow",
        direction = "horizontal"
    }
    limit_flow.add {
        type = "label",
        caption = "Ship Limit:"
    }
    limit_flow.add {
        type = "textfield",
        name = "dock-limit-input",
        text = "1",
        numeric = true,
        allow_decimal = false,
        allow_negative = false
    }

    -- Load existing values if they exist
    if storage.docking_ports[docking_port.unit_number] then
        local port_data = storage.docking_ports[docking_port.unit_number]
        name_flow["dock-name-input"].text = port_data.name or ""
        limit_flow["dock-limit-input"].text = tostring(port_data.ship_limit or 1)
    end

    -- Add close button at the bottom
    dock_gui.add {
        type = "button",
        name = "close-dock-gui",
        caption = "Close",
        style = "back_button" -- Using a built-in button style
    }
end

function SpaceShipGuis.close_docking_port_gui(player)
    -- Close the docking port GUI
    if player.gui.screen["docking-port-gui"] then
        player.gui.screen["docking-port-gui"].destroy()
    end
    
    -- Clear the selected docking port reference
    storage.selected_docking_port = nil
end

function SpaceShipGuis.handle_text_changed_docking_port(event)
    local text_field = event.element
    local player = game.get_player(event.player_index)
    local docking_port = storage.selected_docking_port

    if not docking_port then return end

    -- Handle dock name changes
    if text_field.name == "dock-name-input" then
        storage.docking_ports[docking_port.unit_number].name = text_field.text

        -- Handle ship limit changes
    elseif text_field.name == "dock-limit-input" then
        local limit = tonumber(text_field.text)
        if limit then
            storage.docking_ports[docking_port.unit_number].ship_limit = limit
        end
    end
end

function SpaceShipGuis.gui_maker_handler(ship, player_id)
    local docks_table = {}
    if not storage.docking_ports then
        storage.docking_ports = {}
    end
    for key, value in pairs(storage.docking_ports) do
        if value.name ~= "ship" then
            if not docks_table[value.surface.platform.space_location.name] then
                docks_table[value.surface.platform.space_location.name] =
                {
                    names = {}
                }
                table.insert(docks_table[value.surface.platform.space_location.name].names, value.name)
            else
                table.insert(docks_table[value.surface.platform.space_location.name].names, value.name)
            end
        end
    end
    local player = game.get_player(player_id)
    local schedule = ship.schedule
    local paused = ship.autom
    local ship_name = ship.name
    local ship_id = ship.id

    -- Ensure port_records exists, initialize if nil
    if not ship.port_records then
        ship.port_records = {}
    end
    local stations_docks = ship.port_records

    local gui_anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position
            .right
    }

    -- Only set platform schedule if it's properly structured
    if ship.own_surface and schedule and type(schedule) == "table" then
        -- Check if schedule has the required structure
        local valid_schedule = false
        if schedule.records and type(schedule.records) == "table" and #schedule.records > 0 then
            -- Check if at least one record has the required fields
            for _, record in pairs(schedule.records) do
                if record.station and type(record.station) == "string" and record.station ~= "" then
                    valid_schedule = true
                    break
                end
            end
        end

        if valid_schedule then
            ship.surface.platform.schedule = schedule
        end
    end

    gui_maker.make_gui(
        player,
        schedule,
        paused,
        ship_name,
        ship_id,
        docks_table,
        stations_docks,
        { mod = "pig-ex", },
        gui_anchor
    )
end

return SpaceShipGuis
