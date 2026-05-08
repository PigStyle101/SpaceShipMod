local SpaceShip = require("SpaceShip")
local SpaceShipGuis = {}
local gui_maker = require("shipGui/spaceship_gui")

local function build_docks_table()
    local docks_table = {}
    local seen_per_planet = {}
    storage.docking_ports = storage.docking_ports or {}

    for _, value in pairs(storage.docking_ports) do
        if value.name ~= "ship" and value.surface and value.surface.platform and value.surface.platform.space_location then
            local location_name = value.surface.platform.space_location.name
            docks_table[location_name] = docks_table[location_name] or { names = {} }
            seen_per_planet[location_name] = seen_per_planet[location_name] or {}
            if value.name and not seen_per_planet[location_name][value.name] then
                seen_per_planet[location_name][value.name] = true
                table.insert(docks_table[location_name].names, value.name)
            end
        end
    end

    return docks_table
end

local function get_ship_gui_anchor(player, fallback_position)
    return {
        gui = defines.relative_gui_type.container_gui,
        position = fallback_position or defines.relative_gui_position.left
    }
end

-- Define event handlers
function SpaceShipGuis.on_station_selected(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
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
            else
                game.print("Warning: No available ports found for station " .. event.selected_station)
            end

            local player = game.get_player(event.player_index)
            local updated = false
            if player and player.valid then
                updated = gui_maker.add_station_widget(player, ship, station_index, build_docks_table(), ship.port_records)
            end
            if not updated then
                SpaceShipGuis.gui_maker_handler(ship, event.player_index)
            end
        else
            SpaceShipGuis.gui_maker_handler(ship, event.player_index)
        end
    end
end

function SpaceShipGuis.on_station_move_up(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.station_move_up(ship, event.station_index)

    local player = game.get_player(event.player_index)
    local updated = false
    if player and player.valid and ship then
        updated = gui_maker.swap_station_widgets(player, ship, event.station_index, event.station_index - 1)
    end

    if not updated then SpaceShipGuis.gui_maker_handler(ship, event.player_index) end
end

function SpaceShipGuis.on_station_move_down(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.station_move_down(ship, event.station_index)

    local player = game.get_player(event.player_index)
    local updated = false
    if player and player.valid and ship then
        updated = gui_maker.swap_station_widgets(player, ship, event.station_index, event.station_index + 1)
    end

    if not updated then SpaceShipGuis.gui_maker_handler(ship, event.player_index) end
end

function SpaceShipGuis.on_station_dock_selected(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        -- Initialize port_records if needed
        if not ship.port_records then
            ship.port_records = {}
        end
        
        -- Store the port name for this station (e.g., "nauvis0", "nauvis1", etc.)
        ship.port_records[event.station_index] = event.selected_dock
    end
end

function SpaceShipGuis.on_station_unload_check_changed(event)
end

function SpaceShipGuis.on_station_condition_add(event)
    local ship = storage.spaceships[event.ship_id]
    local condition_type = event.selected_condition_type
    if not condition_type then
        condition_type = string.lower(string.gsub(event.selected_item or "", " condition", ""))
    end
    SpaceShip.add_wait_condition(ship, event.station_index, condition_type)
    local player = game.get_player(event.player_index)
    if not (player and player.valid and gui_maker.refresh_station_conditions(player, ship, event.station_index)) then
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_station_goto(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        SpaceShip.goto_station(ship, event.station_index)
    end
    local player = game.get_player(event.player_index)
    if not (player and player.valid and gui_maker.reindex_station_widgets(player, ship)) then
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_condition_move_up(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.condition_move_up(ship, event.station_index, event.condition_index)
    local player = game.get_player(event.player_index)
    if not (player and player.valid and gui_maker.refresh_station_conditions(player, ship, event.station_index)) then
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_condition_move_down(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.condition_move_down(ship, event.station_index, event.condition_index)
    local player = game.get_player(event.player_index)
    if not (player and player.valid and gui_maker.refresh_station_conditions(player, ship, event.station_index)) then
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_station_delete(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.delete_station(ship, event.station_index)
    local player = game.get_player(event.player_index)
    if not (player and player.valid and gui_maker.remove_station_widget(player, ship, event.station_index)) then
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_condition_delete(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.remove_wait_condition(ship, event.station_index, event.condition_index)
    local player = game.get_player(event.player_index)
    if not (player and player.valid and gui_maker.refresh_station_conditions(player, ship, event.station_index)) then
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end
end

function SpaceShipGuis.on_condition_constant_confirmed(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.constant_changed(ship, event.station_index, event.condition_index, event.amount)
end

function SpaceShipGuis.on_comparison_sign_changed(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.compare_changed(ship, event.station_index, event.condition_index, event.comparator)
end

function SpaceShipGuis.on_bool_changed(event)
    local ship = storage.spaceships[event.ship_id]
    if ship then
        local station = ship.schedule and ship.schedule.records and ship.schedule.records[event.station_index]
        local condition = station and station.wait_conditions and station.wait_conditions[event.condition_index]
        if condition then
            condition.compare_type = event.bool or event.to_bool or condition.compare_type
        end
    end
end

function SpaceShipGuis.on_first_signal_selected(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.signal_changed(ship, event.station_index, event.condition_index, event.selected_signal)
end

function SpaceShipGuis.on_ship_rename_confirmed(event)
    local ship = storage.spaceships[event.ship_id]
    if not ship then return end

    local old_name = ship.name or "Unnamed SpaceShip"
    local new_name = tostring(event.ship_name or "")
    new_name = string.gsub(new_name, "^%s+", "")
    new_name = string.gsub(new_name, "%s+$", "")

    if new_name == "" then
        game.print("Warning: Ship rename ignored (name cannot be empty).")
        return
    end

    ship.name = new_name
end

function SpaceShipGuis.on_ship_paused_unpaused(event)
    local ship = storage.spaceships[event.ship_id]
    SpaceShip.set_automatic_mode(ship, event.automatic == true)
end

-- Function to create the custom spaceship control GUI
function SpaceShipGuis.create_spaceship_gui(player, ship)
    if not (player and player.valid and ship and ship.name) then return end
    local relative_gui = player.gui.relative

    -- Prevent duplicate GUIs
    if relative_gui["spaceship-controller-extended-gui-" .. ship.name] then return end
    if relative_gui["spaceship-controller-schedule-gui-" .. ship.name] or relative_gui["spaceship-controller-schedual-gui-" .. ship.name] then return end

    local ship_tag_number = tonumber(ship.id)
    storage = storage or {}
    storage.spaceships = storage.spaceships or {}

    -- 1. Create the schedule GUI on the left
    local gui_anchor_left = get_ship_gui_anchor(player, defines.relative_gui_position.left)
    gui_maker.make_gui(
        player,
        ship.schedule,
        ship.automatic,
        ship.name,
        ship.id,
        build_docks_table(),
        ship.port_records or {},
        { mod = "pig-ex" },
        gui_anchor_left
    )

    -- 2. Create the spaceship actions GUI on the right (under circuit conditions)
    local gui_anchor_right = get_ship_gui_anchor(player, defines.relative_gui_position.right)
    local custom_gui = relative_gui.add {
        type = "frame",
        name = "spaceship-controller-extended-gui-" .. ship.name,
        caption = "Spaceship Actions",
        direction = "vertical",
        anchor = gui_anchor_right,
        tags = { ship = ship_tag_number }
    }

    -- Add a dropdown with researched planets (even if not yet visited)
    local planet_names = {}
    local force = ship.hub.force
    table.insert(planet_names, "nauvis")
    local planet_research_map = {
        ["vulcanus"] = "planet-discovery-vulcanus",
        ["fulgora"] = "planet-discovery-fulgora",
        ["gleba"] = "planet-discovery-gleba",
        ["aquilo"] = "planet-discovery-aquilo"
    }
    for planet_name, research_tech in pairs(planet_research_map) do
        local tech = force.technologies[research_tech]
        if tech and tech.researched then
            table.insert(planet_names, planet_name)
        end
    end
    for tech_name, technology in pairs(force.technologies) do
        if string.match(tech_name, "^planet%-discovery%-(.+)$") and technology.researched then
            local planet_name = string.match(tech_name, "^planet%-discovery%-(.+)$")
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
    for surface_name, surface in pairs(game.surfaces) do
        if not string.find(surface_name, "platform") and not string.find(surface_name, "space%-") and not string.find(surface_name, "orbit") and surface_name ~= "nauvis" then
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

    if ship.own_surface then
        custom_gui.add { type = "button", name = "drop-player-to-planet", caption = "Drop player to Planet", tags = { ship = ship_tag_number } }

        local drop_slots_flow = custom_gui.add {
            type = "flow",
            name = "drop-slot-limit-flow",
            direction = "horizontal"
        }
        drop_slots_flow.add {
            type = "label",
            caption = "Drop slots:"
        }
        drop_slots_flow.add {
            type = "textfield",
            name = "drop-slot-limit-input",
            text = tostring(ship.drop_slot_limit or 10),
            numeric = true,
            allow_decimal = false,
            allow_negative = false,
            tooltip = "Only the first N hub inventory slots will be dropped"
        }

        custom_gui.add { type = "button", name = "drop-items-to-planet", caption = "Drop items to Planet", tags = { ship = ship_tag_number } }
    end
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
    if not player or not player.valid then return end
    if not ship then return end
    if event.entity and event.entity.name == "spaceship-control-hub" then
        -- Destroy the custom GUI when the main GUI for "spaceship-control-hub" is closed.
        local custom_gui = player.gui.relative["spaceship-controller-extended-gui-" .. ship.name]
        if custom_gui then
            custom_gui.destroy()
        end
        local custom_gui = player.gui.relative["spaceship-controller-schedule-gui-" .. ship.name] or
            player.gui.relative["spaceship-controller-schedual-gui-" .. ship.name]
        if custom_gui then
            custom_gui.destroy()
            ship.schedule_gui = nil
        end
    end
end

-- Function to handle button clicks
function SpaceShipGuis.handle_button_click(event)
    local button_name = event.element.name
    local player = game.get_player(event.player_index)
    if button_name == "ship-takeoff" then -- Call the shipTakeoff function
        local ship = storage.spaceships[event.element.tags.ship]
        local dropdown = event.element.parent["surface-dropdown"]
        SpaceShip.ship_takeoff(ship, dropdown)
        SpaceShip.set_automatic_mode(ship, true)
    elseif button_name == "confirm-dock" then
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.finalize_dock(ship)
    elseif button_name == "cancel-dock" then
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.cancel_dock(ship)
    elseif button_name == "ship-dock" then
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.dock_ship(ship)
    elseif button_name == "drop-player-to-planet" then
        local ship = storage.spaceships[event.element.tags.ship]
        SpaceShip.drop_player_to_planet(ship)
    elseif button_name == "drop-items-to-planet" then
        local ship = storage.spaceships[event.element.tags.ship]
        local slot_limit
        local invalid_slot_input = false
        local parent = event.element.parent
        if parent and parent.valid and parent["drop-slot-limit-flow"] and parent["drop-slot-limit-flow"].valid then
            local input = parent["drop-slot-limit-flow"]["drop-slot-limit-input"]
            if input and input.valid then
                local value = tonumber(input.text)
                if value and value > 0 then
                    slot_limit = math.floor(value)
                elseif input.text ~= "" then
                    invalid_slot_input = true
                end
            end
        end

        if ship then
            if invalid_slot_input then
                slot_limit = ship.drop_slot_limit or 10
                game.print("[color=yellow]Invalid drop slot limit. Using " .. tostring(slot_limit) .. " slot(s).[/color]")
            end
            ship.drop_slot_limit = slot_limit
        end

        SpaceShip.drop_items_to_planet(ship, slot_limit)
    elseif button_name == "close-dock-gui" then
        SpaceShipGuis.close_docking_port_gui(player)
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

    -- Register this as the player's opened GUI so Escape/E can close it naturally.
    player.opened = dock_gui

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
    if not (player and player.valid) then return end

    -- Close the docking port GUI
    local dock_gui = player.gui.screen["docking-port-gui"]
    if dock_gui and dock_gui.valid then
        if player.opened == dock_gui then
            player.opened = nil
        end
        if dock_gui.valid then
            dock_gui.destroy()
        end
    end
    
    -- Clear the selected docking port reference
    storage.selected_docking_port = nil
end

function SpaceShipGuis.handle_text_changed_docking_port(event)
    local text_field = event.element
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
    if not ship then return end
    local docks_table = {}
    local seen_per_planet = {}
    if not storage.docking_ports then
        storage.docking_ports = {}
    end
    for _, value in pairs(storage.docking_ports) do
        if value and value.name ~= "ship" then
            local port_surface = value.surface
            local platform = port_surface and port_surface.valid and port_surface.platform or nil
            local space_location = platform and platform.space_location or nil
            local planet_name = space_location and space_location.name or nil

            if planet_name and value.name then
                if not docks_table[planet_name] then
                    docks_table[planet_name] = {
                        names = {}
                    }
                end
                seen_per_planet[planet_name] = seen_per_planet[planet_name] or {}
                if not seen_per_planet[planet_name][value.name] then
                    seen_per_planet[planet_name][value.name] = true
                    table.insert(docks_table[planet_name].names, value.name)
                end
            end
        end
    end
    local player = game.get_player(player_id)
    if not player or not player.valid then return end
    local schedule = ship.schedule
    local automatic = ship.automatic == true
    local ship_name = ship.name
    local ship_id = ship.id

    -- Ensure port_records exists, initialize if nil
    if not ship.port_records then
        ship.port_records = {}
    end
    local stations_docks = ship.port_records

    local gui_anchor_left = get_ship_gui_anchor(player, defines.relative_gui_position.left)

    -- Only set platform schedule if it's properly structured
    if ship.own_surface and ship.surface and ship.surface.valid and ship.surface.platform and schedule and type(schedule) == "table" then
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
        automatic,
        ship_name,
        ship_id,
        docks_table,
        stations_docks,
        { mod = "pig-ex", },
        gui_anchor_left
    )
end

return SpaceShipGuis
