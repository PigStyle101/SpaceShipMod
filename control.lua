local SpaceShipGuis = require("SpaceShipGuisScript")
local SpaceShipFunctions = require("SpaceShipFunctionsScript")
local SpaceShip = require("SpaceShip")
local Stations = require("Stations")
local schedule_gui = require("__ship-gui__.spaceship_gui.spaceship_gui")


-- Initialize storage tables
storage.highlight_data = storage.highlight_data or {} -- Stores highlight data for each player

-- Initialize mod when first loaded
script.on_init(function()
    storage.highlight_data = storage.highlight_data or {}
    Stations.init()
    SpaceShip.update_all_ship_docking_status()
end)

-- Handle configuration changes (mod updates)
script.on_configuration_changed(function()
    storage.highlight_data = storage.highlight_data or {}
    Stations.init()
    SpaceShip.update_all_ship_docking_status()
end)

-- Get the event IDs from gui mod
local ship_gui_events

-- Register events and their handlers
local function register_events()
    -- Get events when needed
    if not ship_gui_events then
        ship_gui_events = remote.call("ship-gui", "get_event_ids")
    end

    -- Register handlers for each event type
    if ship_gui_events then
        if ship_gui_events.on_station_selected then
            script.on_event(ship_gui_events.on_station_selected, SpaceShipGuis.on_station_selected)
        end
        if ship_gui_events.on_station_move_up then
            script.on_event(ship_gui_events.on_station_move_up, SpaceShipGuis.on_station_move_up)
        end
        if ship_gui_events.on_station_move_down then
            script.on_event(ship_gui_events.on_station_move_down, SpaceShipGuis.on_station_move_down)
        end
        if ship_gui_events.on_station_dock_selected then
            script.on_event(ship_gui_events.on_station_dock_selected, SpaceShipGuis.on_station_dock_selected)
        end
        if ship_gui_events.on_station_delete then
            script.on_event(ship_gui_events.on_station_delete, SpaceShipGuis.on_station_delete)
        end
        if ship_gui_events.on_station_unload_check_changed then
            script.on_event(ship_gui_events.on_station_unload_check_changed,
                SpaceShipGuis.on_station_unload_check_changed)
        end
        if ship_gui_events.on_station_condition_add then
            script.on_event(ship_gui_events.on_station_condition_add, SpaceShipGuis.on_station_condition_add)
        end
        if ship_gui_events.on_station_goto then
            script.on_event(ship_gui_events.on_station_goto, SpaceShipGuis.on_station_goto)
        end
        if ship_gui_events.on_condition_move_up then
            script.on_event(ship_gui_events.on_condition_move_up, SpaceShipGuis.on_condition_move_up)
        end
        if ship_gui_events.on_condition_move_down then
            script.on_event(ship_gui_events.on_condition_move_down, SpaceShipGuis.on_condition_move_down)
        end
        if ship_gui_events.on_condition_delete then
            script.on_event(ship_gui_events.on_condition_delete, SpaceShipGuis.on_condition_delete)
        end
        if ship_gui_events.on_condition_constant_confirmed then
            script.on_event(ship_gui_events.on_condition_constant_confirmed,
                SpaceShipGuis.on_condition_constant_confirmed)
        end
        if ship_gui_events.on_comparison_sign_changed then
            script.on_event(ship_gui_events.on_comparison_sign_changed, SpaceShipGuis.on_comparison_sign_changed)
        end
        if ship_gui_events.on_bool_changed then
            script.on_event(ship_gui_events.on_bool_changed, SpaceShipGuis.on_bool_changed)
        end
        if ship_gui_events.on_first_signal_selected then
            script.on_event(ship_gui_events.on_first_signal_selected, SpaceShipGuis.on_first_signal_selected)
        end
        if ship_gui_events.on_ship_rename_confirmed then
            script.on_event(ship_gui_events.on_ship_rename_confirmed, SpaceShipGuis.on_ship_rename_confirmed)
        end
        if ship_gui_events.on_ship_paused_unpaused then
            script.on_event(ship_gui_events.on_ship_paused_unpaused, SpaceShipGuis.on_ship_paused_unpaused)
        end
    end
end

script.on_init(register_events)
script.on_load(register_events)
script.on_configuration_changed(register_events)

script.on_event(defines.events.on_gui_click, function(event)
    SpaceShipGuis.handle_button_click(event)
end)

script.on_event(defines.events.on_built_entity, function(event)
    local player = game.get_player(event.player_index)
    -- Handle both regular entities and ghosts
    if event.entity.type == "entity-ghost" then
        SpaceShip.handle_ghost_entity(event.entity, player)
    else
        SpaceShip.handle_built_entity(event.entity, player)
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    local player = game.get_player(event.robot.force.players[1].index)
    SpaceShip.handle_built_entity(event.entity, player)
end)

script.on_event(defines.events.on_space_platform_built_entity, function(event)
    local player = game.get_player(event.platform.force.players[1].index)
    SpaceShip.handle_built_entity(event.entity, player)
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    SpaceShip.handle_mined_entity(event.entity)
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    SpaceShip.handle_mined_entity(event.entity)
end)

script.on_event(defines.events.on_space_platform_mined_entity, function(event)
    SpaceShip.handle_mined_entity(event.entity)
end)

script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    local opened_entity = event.entity
    local ship

    if opened_entity and opened_entity.valid and opened_entity.name == "spaceship-control-hub" then
        for _, value in pairs(storage.spaceships) do
            if value.hub.unit_number == opened_entity.unit_number then
                ship = storage.spaceships[value.id]
            end
        end
        SpaceShipGuis.create_spaceship_gui(player, ship)
        SpaceShipGuis.gui_maker_handler(ship, event.player_index)
    end

    if event.entity and event.entity.name == "spaceship-docking-port" then
        -- Close default GUI
        if player.opened then
            player.opened = nil
        end
        -- Open our custom GUI
        SpaceShipGuis.create_docking_port_gui(player, event.entity)
    end
end)

script.on_event(defines.events.on_tick, function(event)
    storage.highlight_data = storage.highlight_data or {}

    -- Handle clearing hights after the timer expires
    if storage.scan_highlight_expire_tick and game.tick >= storage.scan_highlight_expire_tick then
        if storage.scan_highlights then
            for _, render_object in pairs(storage.scan_highlights) do
                if render_object.valid then
                    render_object.destroy() -- Destroy the highlight object
                end
            end
        end
        --rendering.clear()                        -- Remove all rendering highlights
        storage.scan_highlight_expire_tick = nil -- Reset the timer
        storage.scan_highlights = nil            -- Clear the highlights
    end

    if storage.SpaceShip and storage.SpaceShip[storage.docking_ship].scanned then
        goto continue
    end
    if not storage.spaceships or not storage.spaceships[storage.docking_ship] then goto continue end
    if game.tick % 10 == 0 and
        storage.spaceships and
        storage.docking_ship and
        storage.spaceships[storage.docking_ship].docking then -- Update every 10 ticks
        local player = storage.spaceships[storage.docking_ship].player
        if not player or not player.valid then
            storage.highlight_data = nil
        end

        for _, rendering in pairs(storage.highlight_data) do
            if player and player.valid and rendering.valid then
                -- Calculate the offset between the stored position and the player's current position
                local offset_for_player = {
                    x = player.position.x - storage.player_position_on_render.x,
                    y = player.position.y - storage.player_position_on_render.y
                }

                -- Snap the offset to the grid
                local snapped_offset = {
                    x = math.floor(offset_for_player.x),
                    y = math.floor(offset_for_player.y)
                }

                -- Update the render position to follow the player and snap to grid
                -- Since left_top and right_bottom are ScriptRenderTargetTable with position data
                local current_left_top = rendering.left_top
                local current_right_bottom = rendering.right_bottom

                -- Extract position from the target table (position.x and position.y)
                if current_left_top and current_right_bottom and current_left_top.position and current_right_bottom.position then
                    rendering.left_top = {
                        position = {
                            x = math.floor(current_left_top.position.x + snapped_offset.x),
                            y = math.floor(current_left_top.position.y + snapped_offset.y)
                        }
                    }
                    rendering.right_bottom = {
                        position = {
                            x = math.floor(current_right_bottom.position.x + snapped_offset.x),
                            y = math.floor(current_right_bottom.position.y + snapped_offset.y)
                        }
                    }
                end
            end
        end
        -- Update the stored player position
        storage.player_position_on_render = {
            x = math.floor(player.position.x),
            y = math.floor(player.position.y)
        }
    end
    ::continue::
    if storage.scan_state and game.tick % 10 == storage.scan_state.tick_amount then
        SpaceShip.continue_scan_ship()
    end

    if game.tick % 60 == 0 then
        for _, ship in pairs(storage.spaceships or {}) do
            local player = ship.player
            if player.gui.relative["schedule-container"] then
                signals = SpaceShip.read_circuit_signals(ship.hub)
                values = SpaceShip.get_progress_values(ship, signals)
                for key, value in pairs(values) do
                    schedule_gui.update_station_progress(key, value, player)
                end
            end
        end
        SpaceShip.check_automatic_behavior()
        SpaceShip.check_waiting_ships_for_dock_availability()
    end

    -- Process pending planet drops
    SpaceShip.process_pending_drops()

    -- Restore entities that were temporarily disabled during cloning
    if storage.entities_to_restore and storage.entities_to_restore_tick and game.tick >= storage.entities_to_restore_tick then
        for _, entity_data in pairs(storage.entities_to_restore) do
            if entity_data.entity and entity_data.entity.valid then
                entity_data.entity.active = entity_data.active
            end
        end
        storage.entities_to_restore = nil
        storage.entities_to_restore_tick = nil
    end
end)

script.on_event(defines.events.on_player_driving_changed_state, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local vehicle = event.entity
    if not vehicle or not vehicle.valid then return end

    local entered = player.vehicle ~= nil
    local riding_state = player.riding_state

    if vehicle.name == "spaceship-control-hub-car" then
        local search_area = {
            { x = vehicle.position.x - 50, y = vehicle.position.y - 50 }, -- Define a reasonable search area around the cloned ship
            { x = vehicle.position.x + 50, y = vehicle.position.y + 50 }
        }
        hub = event.entity.surface.find_entities_filtered { area = search_area, name = "spaceship-control-hub" }
        if not hub or #hub == 0 then return end

        local ship
        for _, value in pairs(storage.spaceships) do
            if value.hub.unit_number == hub[1].unit_number then
                ship = storage.spaceships[value.id]
            end
        end

        -- Player entered/exited the cockpit
        if player.vehicle then

            ship.player_in_cockpit = player
            -- Player entered the cockpit
            --SpaceShipGuis.create_spaceship_gui(player)
        else
            ship.player_in_cockpit = nil
        end
    elseif vehicle.name == "space-platform-hub" then
        player.leave_space_platform()
        player.set_controller ({ type = defines.controllers.character,character = player.character })
    elseif vehicle.name == "cargo-pod" then
        if not Stations.has_spaceship_armor(player) then
            player.driving = false
            game.print("[color=red]You need Spaceship Armor to go to space![/color]")
        end
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    if event.element.name == "dock-name-input" or event.element.name == "dock-limit-input" then
        SpaceShipGuis.handle_text_changed_docking_port(event)
    end
end)

script.on_event(defines.events.on_selected_entity_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local selected_entity = player.selected -- The entity the player is currently hovering over
    -- Check if the player is hovering over the spaceship-control-hub
    if selected_entity and selected_entity.valid and selected_entity.name == "spaceship-control-hub" then
        storage.spaceships = storage.spaceships or {}
        local ship
        for _, value in pairs(storage.spaceships) do
            if value.hub.unit_number == selected_entity.unit_number then
                ship = storage.spaceships[value.id]
            end
        end
        -- Create a GUI if it doesn't already exist
        if not player.gui.screen["hovering_gui"] then
            local hovering_gui = player.gui.screen.add
                { type = "frame", name = "hovering_gui", caption = "Spaceship Info", direction = "vertical" }
            for key, value in pairs(ship) do
                if type(value) == "table" then
                    hovering_gui.add { type = "label", name = key .. table_size(value), caption = key .. ":" .. table_size(value) }
                elseif type(value) ~= "userdata" and type(value) ~= "boolean" then
                    hovering_gui.add { type = "label", name = key .. tostring(value), caption = key .. ":" .. tostring(value) }
                elseif type(value) == "boolean" then
                    if value then
                        value = "true"
                    else
                        value = "false"
                    end
                    hovering_gui.add { type = "label", name = key .. tostring(value), caption = key .. ":" .. tostring(value) }
                elseif key == "surface" then
                    hovering_gui.add { type = "label", name = key .. tostring(value), caption = key .. ":" .. tostring(value.name) }
                end
            end
            hovering_gui.location = { x = 100, y = 100 } -- Position the GUI on the screen
        end
    else
        -- Destroy the GUI if the player is no longer hovering over the entity
        if player.gui.screen["hovering_gui"] then
            player.gui.screen["hovering_gui"].destroy()
        end
    end
end)

script.on_event(defines.events.on_space_platform_changed_state, function(event)
    -- Handle station management for all platform state changes
    Stations.handle_platform_state_change(event)

    local plat = event.platform
    game.print(plat.name .. " has been changed state from:" .. event.old_state .. ",to:" .. plat.state)
    if string.find(plat.name, "-ship") and event.platform.state == defines.space_platform_state.waiting_at_station then
        if event.old_state == defines.space_platform_state.on_the_path then
            hub = plat.surface.find_entities_filtered { name = "spaceship-control-hub" }
            local ship
            for _, value in pairs(storage.spaceships) do
                if value.hub.unit_number == hub[1].unit_number then
                    ship = storage.spaceships[value.id]
                end
            end
            ship.planet_orbiting = plat.space_location.name
            SpaceShip.on_platform_state_change(event)
        end
    elseif string.find(plat.name, "-ship") and event.platform.state == defines.space_platform_state.on_the_path then
        hub = plat.surface.find_entities_filtered { name = "spaceship-control-hub" }
        local ship
        for _, value in pairs(storage.spaceships) do
            if value.hub.unit_number == hub[1].unit_number then
                ship = storage.spaceships[value.id]
            end
        end
        ship.planet_orbiting = "none"
    end
end)

script.on_event(defines.events.on_entity_cloned, function(event)
    if event.source.name == "spaceship-control-hub" then
        game.print("Spaceship control hub cloned!")
    end
    SpaceShip.handle_cloned_storage_update(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local closed_entity = event.entity

    -- If a spaceship control hub GUI was closed, close all related GUIs
    if closed_entity and closed_entity.valid and closed_entity.name == "spaceship-control-hub" then
        -- Find the ship associated with this hub
        local ship
        for _, value in pairs(storage.spaceships or {}) do
            if value.hub.unit_number == closed_entity.unit_number then
                ship = storage.spaceships[value.id]
                break
            end
        end

        if ship then
            -- Close the extended GUI
            local extended_gui = player.gui.relative["spaceship-controller-extended-gui-" .. ship.name]
            if extended_gui and extended_gui.valid then
                extended_gui.destroy()
            end

            -- Close the schedule GUI
            local schedule_gui = player.gui.relative["spaceship-controller-schedual-gui-" .. ship.name]
            if schedule_gui and schedule_gui.valid then
                schedule_gui.destroy()
                ship.schedule_gui = nil
            end
        end
    end

    -- Close any hovering GUI when any relative GUI is closed
    if player.gui.screen["hovering_gui"] then
        player.gui.screen["hovering_gui"].destroy()
    end

    -- Close schedule container GUI if it exists (from ship-gui mod)
    if player.gui.relative["schedule-container"] then
        player.gui.relative["schedule-container"].destroy()
    end

    -- Close docking port GUI if a docking port was closed
    if closed_entity and closed_entity.valid and closed_entity.name == "spaceship-docking-port" then
        if player.gui.screen["docking-port-gui"] then
            player.gui.screen["docking-port-gui"].destroy()
        end
    end

    -- Close dock confirmation GUI when any GUI is closed (it's a modal dialog)
    if player.gui.screen["dock-confirmation-gui"] then
        player.gui.screen["dock-confirmation-gui"].destroy()
    end
end)
