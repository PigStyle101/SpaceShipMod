local SpaceShipGuis = require("shipGui/SpaceShipGuisScript")
local SpaceShip = require("SpaceShip")
local Stations = require("Stations")
local schedule_gui = require("shipGui/spaceship_gui")
local ship_gui_control = require("shipGui/gui_controller")

local function resolve_ship_by_hub_entity(hub_entity)
    if not (hub_entity and hub_entity.valid and hub_entity.name == "spaceship-control-hub") then
        return nil
    end

    storage.spaceships = storage.spaceships or {}

    for _, value in pairs(storage.spaceships) do
        if value and value.hub and value.hub.valid and value.hub.unit_number == hub_entity.unit_number then
            return value
        end
    end

    local tag_id = hub_entity.tags and tonumber(hub_entity.tags.id)
    if tag_id and storage.spaceships[tag_id] then
        local ship = storage.spaceships[tag_id]
        ship.hub = hub_entity
        return ship
    end

    for _, value in pairs(storage.spaceships) do
        if value and (not value.hub or not value.hub.valid) and value.surface and value.surface.valid and
            value.surface.index == hub_entity.surface.index then
            value.hub = hub_entity
            local tags = hub_entity.tags or {}
            tags.id = value.id
            hub_entity.tags = tags
            return value
        end
    end

    return nil
end

local function resolve_ship_by_car_entity(car_entity)
    if not (car_entity and car_entity.valid and car_entity.name == "spaceship-control-hub-car") then
        return nil
    end

    local best_ship = nil
    local best_distance_sq = math.huge

    for _, ship in pairs(storage.spaceships or {}) do
        if ship and ship.hub and ship.hub.valid and ship.hub.surface == car_entity.surface then
            local dx = ship.hub.position.x - car_entity.position.x
            local dy = ship.hub.position.y - car_entity.position.y
            local distance_sq = (dx * dx) + (dy * dy)

            if distance_sq < best_distance_sq then
                best_distance_sq = distance_sq
                best_ship = ship
            end
        end
    end

    if best_ship and best_distance_sq <= (100 * 100) then
        return best_ship
    end

    local nearby_hubs = car_entity.surface.find_entities_filtered({
        name = "spaceship-control-hub",
        area = {
            { x = car_entity.position.x - 100, y = car_entity.position.y - 100 },
            { x = car_entity.position.x + 100, y = car_entity.position.y + 100 }
        }
    })

    if nearby_hubs and nearby_hubs[1] and nearby_hubs[1].valid then
        return resolve_ship_by_hub_entity(nearby_hubs[1])
    end

    return nil
end


-- Initialize storage tables
storage.highlight_data = storage.highlight_data or {} -- Stores highlight data for each player

-- Initialize mod when first loaded
script.on_init(function()
    storage.highlight_data = storage.highlight_data or {}
    storage.recent_rocket_arrival_tick = storage.recent_rocket_arrival_tick or {}
    storage.platform_hub_action_tick = storage.platform_hub_action_tick or {}
    storage.temp_platform_hubs_cleanup = storage.temp_platform_hubs_cleanup or {}
    Stations.init()
    SpaceShip.update_all_ship_docking_status()
end)

-- Handle configuration changes (mod updates)
script.on_configuration_changed(function()
    storage.highlight_data = storage.highlight_data or {}
    storage.recent_rocket_arrival_tick = storage.recent_rocket_arrival_tick or {}
    storage.platform_hub_action_tick = storage.platform_hub_action_tick or {}
    storage.temp_platform_hubs_cleanup = storage.temp_platform_hubs_cleanup or {}
    Stations.init()
    SpaceShip.update_all_ship_docking_status()
end)

script.on_event(defines.events.on_cargo_pod_finished_descending, function(event)
    if not event then return end

    if not event.player_index then return end
    if not event.launched_by_rocket then return end

    storage.recent_rocket_arrival_tick = storage.recent_rocket_arrival_tick or {}
    storage.recent_rocket_arrival_tick[event.player_index] = game.tick
end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if element and element.valid and element.tags and element.tags.filter and element.tags.filter.owner == "ship-gui" then
        ship_gui_control.on_gui_click(event)
        return
    end

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

script.on_event(defines.events.on_entity_settings_pasted, function(event)
    SpaceShip.handle_entity_settings_pasted(event)
end)

script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local opened_entity = event.entity
    local ship

    if opened_entity and opened_entity.valid and opened_entity.name == "spaceship-control-hub-car" then
        ship = resolve_ship_by_car_entity(opened_entity)
        if ship and ship.hub and ship.hub.valid then
            player.opened = ship.hub
            return
        end
    end

    if opened_entity and opened_entity.valid and opened_entity.name == "spaceship-control-hub" then
        ship = resolve_ship_by_hub_entity(opened_entity)
        if ship then
            SpaceShipGuis.create_spaceship_gui(player, ship)
            SpaceShipGuis.gui_maker_handler(ship, event.player_index)
        end
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
    storage.temp_platform_hubs_cleanup = storage.temp_platform_hubs_cleanup or {}

    if #storage.temp_platform_hubs_cleanup > 0 then
        for i = #storage.temp_platform_hubs_cleanup, 1, -1 do
            local cleanup = storage.temp_platform_hubs_cleanup[i]
            if not cleanup.entity or not cleanup.entity.valid or game.tick >= cleanup.cleanup_tick then
                if cleanup.entity and cleanup.entity.valid then
                    cleanup.entity.destroy()
                end
                table.remove(storage.temp_platform_hubs_cleanup, i)
            end
        end
    end

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
    if storage.scan_state then
        SpaceShip.continue_scan_ship()
    end

    SpaceShip.process_clone_job_queue()
    SpaceShip.process_clone_cleanup_queue()

    if game.tick % 60 == 0 then
        for _, ship in pairs(storage.spaceships or {}) do
            local player = ship.player
            if player and player.valid and player.gui and player.gui.relative and player.gui.relative["schedule-container"] and ship.hub and ship.hub.valid then
                local signals = SpaceShip.read_circuit_signals(ship.hub)
                local values = SpaceShip.get_progress_values(ship, signals)
                schedule_gui.update_all_station_progress(values, player)
            end
        end
        Stations.enforce_station_hub_controls()
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
        storage.entities_to_restore_lookup = nil
        storage.entities_to_restore_tick = nil
    end
end)

script.on_event(defines.events.on_player_driving_changed_state, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local vehicle = event.entity
    if not vehicle or not vehicle.valid then return end

    if vehicle.name == "spaceship-control-hub-car" then
        local search_area = {
            { x = vehicle.position.x - 50, y = vehicle.position.y - 50 }, -- Define a reasonable search area around the cloned ship
            { x = vehicle.position.x + 50, y = vehicle.position.y + 50 }
        }
        local hubs = event.entity.surface.find_entities_filtered { area = search_area, name = "spaceship-control-hub" }
        if not hubs or #hubs == 0 or not (hubs[1] and hubs[1].valid) then return end

        local ship = resolve_ship_by_hub_entity(hubs[1])
        if not ship then
            for _, value in pairs(storage.spaceships or {}) do
                if value and value.player and value.player.valid and value.player.index == player.index and
                    (value.is_cloning or value.clone_job_active) then
                    ship = value
                    break
                end
            end
        end
        if not ship then return end

        if ship.is_cloning or ship.clone_job_active then
            return
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
        storage.recent_rocket_arrival_tick = storage.recent_rocket_arrival_tick or {}
        storage.platform_hub_action_tick = storage.platform_hub_action_tick or {}

        local last_action_tick = storage.platform_hub_action_tick[event.player_index]
        if last_action_tick and (game.tick - last_action_tick) <= 30 then
            return
        end

        local recent_rocket_tick = storage.recent_rocket_arrival_tick[event.player_index]
        local just_arrived_by_rocket = recent_rocket_tick and (game.tick - recent_rocket_tick) <= 600

        if just_arrived_by_rocket then
            player.leave_space_platform()
            player.set_controller({ type = defines.controllers.character, character = player.character })
            storage.recent_rocket_arrival_tick[event.player_index] = nil
            storage.platform_hub_action_tick[event.player_index] = game.tick
        else
            SpaceShip.drop_player_from_platform_hub(player, vehicle)
            storage.platform_hub_action_tick[event.player_index] = game.tick
        end
    elseif vehicle.name == "cargo-pod" then
        if not Stations.has_spaceship_armor(player) then
            player.driving = false
            game.print("[color=red]You need Spaceship Armor to go to space![/color]")
        end
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    local element = event.element
    if element and element.valid and element.tags and element.tags.filter and element.tags.filter.owner == "ship-gui" then
        ship_gui_control.on_gui_text_changed(event)
        return
    end

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
        local ship = resolve_ship_by_hub_entity(selected_entity)
        if not ship then
            if player.gui.screen["hovering_gui"] then
                player.gui.screen["hovering_gui"].destroy()
            end
            return
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
    if string.find(plat.name, "-ship") and event.platform.state == defines.space_platform_state.waiting_at_station then
        if event.old_state == defines.space_platform_state.on_the_path then
            local hub = plat.surface.find_entities_filtered { name = "spaceship-control-hub" }
            if not hub or not hub[1] or not hub[1].valid then
                return
            end
            local ship = resolve_ship_by_hub_entity(hub[1])
            if not ship then return end

            ship.planet_orbiting = plat.space_location.name
            SpaceShip.on_platform_state_change(event)
        end
    elseif string.find(plat.name, "-ship") and event.platform.state == defines.space_platform_state.on_the_path then
        local hub = plat.surface.find_entities_filtered { name = "spaceship-control-hub" }
        if not hub or not hub[1] or not hub[1].valid then
            return
        end
        local ship = resolve_ship_by_hub_entity(hub[1])
        if not ship then return end
        ship.planet_orbiting = "none"
    end
end)

script.on_event(defines.events.on_entity_cloned, function(event)
    SpaceShip.handle_cloned_storage_update(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local closed_entity = event.entity
    local closed_element = event.element

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
            local schedule_gui = player.gui.relative["spaceship-controller-schedule-gui-" .. ship.name] or
                player.gui.relative["spaceship-controller-schedual-gui-" .. ship.name]
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

    -- Close docking port GUI when custom GUI is closed via Escape/E.
    if closed_element and closed_element.valid and closed_element.name == "docking-port-gui" then
        if player.gui.screen["docking-port-gui"] and player.gui.screen["docking-port-gui"].valid then
            player.gui.screen["docking-port-gui"].destroy()
        end
        storage.selected_docking_port = nil
    end

    -- Close dock confirmation GUI when any GUI is closed (it's a modal dialog)
    if player.gui.screen["dock-confirmation-gui"] then
        player.gui.screen["dock-confirmation-gui"].destroy()
    end
end)
