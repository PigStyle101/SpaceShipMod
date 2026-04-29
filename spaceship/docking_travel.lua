return function(SpaceShip)

    function SpaceShip.dock_ship(ship)
        local player = ship.player
        local dest_surface

        local player_body = player.character
        local body_on_ship_surface = player_body and player_body.valid and ship.surface and ship.surface.valid and
            player_body.surface == ship.surface
        local body_in_ship_cockpit = false

        if body_on_ship_surface then
            local nearby_cars = ship.surface.find_entities_filtered({
                position = player_body.position,
                radius = 2,
                name = "spaceship-control-hub-car"
            })
            for _, car in pairs(nearby_cars) do
                if car and car.valid then
                    local driver = car.get_driver()
                    if driver and driver.valid and driver.unit_number == player_body.unit_number then
                        body_in_ship_cockpit = true
                        break
                    end
                end
            end
        end

        ship.transfer_player_on_confirm = body_in_ship_cockpit

        for id, plat in pairs(player.force.platforms) do
            if plat.space_location then
                if plat.space_location.name == ship.planet_orbiting then
                    if plat.name ~= ship.name .. "-ship" then
                        dest_surface = player.force.platforms[id]
                    end
                end
            end
        end

        if not dest_surface then
            game.print("Error: No stations found, or not orbiting planet!")
            return
        end

        if not ship.scanned and not storage.scan_state then
            game.print("Error: need to scan ship, starting scan now.")
            SpaceShip.start_scan_ship(ship)
            return
        elseif storage.scan_state then
            game.print("Error: Scan is in progress, please wait.")
            return
        end

        ship.docking = true -- Flag to indicate docking process has started

        storage.player_body = player.character

        local player_pos = player.position
        local dest_center = { x = 0, y = 0 }
        player.set_controller({ type = defines.controllers.ghost }) -- Set the player to ghost contro
        player.teleport(dest_center, dest_surface.surface)

        storage.player_position_on_render = { x = math.floor(player.position.x), y = math.floor(player.position.y) }
        storage.highlight_data = storage.highlight_data or {}
        storage.highlight_data = SpaceShip.create_combined_renders(ship, ship.floor, false, { x = 0, y = -5 })
        game.print("rends count: " .. #storage.highlight_data)
        storage.highlight_data_player_index = player.index

        storage.docking_player = player.index
        storage.docking_ship = ship.id

        local gui = player.gui.screen.add {
            type = "frame",
            name = "dock-confirmation-gui",
            caption = "Confirm Docking",
            direction = "vertical",
            tags = { ship = ship.id }
        }
        gui.location = { x = 10, y = 10 }

        gui.add {
            type = "button",
            name = "confirm-dock",
            caption = "Confirm",
            tags = { ship = ship.id }
        }
        gui.add {
            type = "button",
            name = "cancel-dock",
            caption = "Cancel",
            tags = { ship = ship.id }
        }
    end

    function SpaceShip.finalize_dock(ship)
        if not ship.scanned then
            game.print("Error: No scanned ship data found.")
            return
        end

        local should_transfer_player = ship.transfer_player_on_confirm == true
        ship.transfer_player_on_confirm = nil

        local src_surface = ship.surface -- Retrieve the source surface
        local player = ship.player
        local dest_surface = ship.player.surface

        if should_transfer_player and storage.player_body and storage.player_body.valid then
            if not (src_surface and src_surface.valid and storage.player_body.surface == src_surface) then
                should_transfer_player = false
            end
        end

        -- Calculate spawn position using the same logic as render offset
        local reference_tile = ship.reference_tile
        if not reference_tile then
            game.print("Error: Reference tile is missing from ship data.")
            return
        end

        local dest_center = {
            x = math.floor(player.position.x - reference_tile.position.x + 0) - 1,
            y = math.floor(player.position.y - reference_tile.position.y + (-5)) - 1
        }

        local excluded_types = {
            ["logistic-robot"] = true,
            ["contruction-robot"] = true,
        }
        SpaceShip.clone_ship_area_instant(ship, dest_surface, dest_center, excluded_types)

        local control_hub_car
        local search_area = {
            { x = dest_center.x - 50, y = dest_center.y - 50 }, -- Define a reasonable search area around the cloned ship
            { x = dest_center.x + 50, y = dest_center.y + 50 }
        }

        local entities_in_area = dest_surface.find_entities_filtered({
            area = search_area,
            name = "spaceship-control-hub-car"
        })

        if #entities_in_area > 0 then
            control_hub_car = entities_in_area[1] -- Assume the first found entity is the control hub car
        end

        if storage.player_body and storage.player_body.valid then
            local body_surface = storage.player_body.surface
            local body_position = storage.player_body.position
            player.teleport(body_position, body_surface)

            player.set_controller({ type = defines.controllers.character, character = storage.player_body })
            storage.player_body = nil
        else
            -- Fallback: if no stored body, try to ensure character controller anyway.
            if player.character and player.character.valid and player.controller_type ~= defines.controllers.character then
                player.set_controller({ type = defines.controllers.character, character = player.character })
            end
            game.print("Warning: Unable to restore the player's stored body; using controller fallback.")
        end

        if should_transfer_player then
            if control_hub_car and control_hub_car.valid then
                player.teleport(control_hub_car.position, control_hub_car.surface)
                control_hub_car.set_driver(player)
                game.print("You have entered the spaceship control hub car at the destination.")
            else
                game.print("Error: Unable to find the spaceship control hub car at the destination.")
            end
        end

        if player.gui.screen["dock-confirmation-gui"] then
            player.gui.screen["dock-confirmation-gui"].destroy()
        end

        if storage.highlight_data then
            for _, rendering in pairs(storage.highlight_data) do
                if rendering.valid then
                    rendering.destroy()
                end
            end
            storage.highlight_data[player.index] = nil
        end

        game.print("Takeoff confirmed! Ship cloned to orbit.")
        local hubs_in_area = dest_surface.find_entities_filtered({
            area = search_area,
            name = "spaceship-control-hub"
        })
        ship.hub = hubs_in_area[1]

        if not should_transfer_player then
            local focus_entity = nil
            if ship.hub and ship.hub.valid then
                focus_entity = ship.hub
            elseif control_hub_car and control_hub_car.valid then
                focus_entity = control_hub_car
            end

            if focus_entity then
                pcall(function()
                    player.centered_on = focus_entity
                end)
            end
        end

        ship.taking_off = false -- Reset the taking off flag
        ship.docking = false
        ship.traveling = false
        ship.docked = true
        ship.own_surface = false
        ship.surface = dest_surface
        if SpaceShip.clear_waiting_states then
            SpaceShip.clear_waiting_states(ship)
        end
        storage.docking_ship = nil
        storage.docking_player = nil
        src_surface.platform.destroy(1)
    end

    -- Function to cancel spaceship takeoff
    function SpaceShip.cancel_dock(ship)
        local src_surface = game.surfaces["nauvis"] -- change this at some point
        local player_index = storage.takeoff_player
        local player = game.get_player(player_index)

        if player then
            if storage.player_body and storage.player_body.valid then
                local body_surface = storage.player_body.surface
                local body_position = storage.player_body.position
                player.teleport(body_position, body_surface)
                player.set_controller({ type = defines.controllers.character, character = storage.player_body })
                storage.player_body = nil -- Clear the reference to the player's body
            else
                game.print("Error: Unable to restore the player's body.")
            end
        end

        for _, id in ipairs(storage.takeoff_highlights or {}) do
            local ok, obj = pcall(function()
                return rendering.get_object_by_id(id)
            end)
            if ok and obj and obj.valid then
                obj.destroy()
            end
        end
        storage.takeoff_highlights = nil
        if player and player.gui.screen["dock-confirmation-gui"] then
            player.gui.screen["dock-confirmation-gui"].destroy()
        end

        game.print("Takeoff canceled. Returning to the ship.")
        ship.taking_off = false -- Reset the taking off flag
        ship.docking = false
        storage.docking_ship = nil
        storage.docking_player = nil
    end

    function SpaceShip.on_platform_state_change(event)
        local platform = event.platform
        if not platform or not platform.valid then
            game.print("Error: Invalid platform in state change event.")
            return
        end
        local hub = platform.surface.find_entities_filtered({
            name = "spaceship-control-hub",
            area = {
                { x = -20, y = -20 },
                { x = 20,  y = 20 }
            }
        })[1]
        local ship
        for key, value in pairs(storage.spaceships) do
            if value.hub.unit_number == hub.unit_number then
                ship = storage.spaceships[key]
            end
        end
        if not ship or not ship.docking_port then
            game.print("Error: No ship or docking port associated with the platform.")
            return
        end

        -- Check if the platform's state changed to 6 (waiting_at_station)
        if event.platform.state == 6 then
            local old_platform = platform
            platform.paused = true

            local success = SpaceShip.attempt_docking(ship)

            -- Delete the old platform surface only if docking was successful
            if success and old_platform and old_platform.valid then
                old_platform.destroy(1)
            end
        end
    end

    function SpaceShip.handle_cloned_storage_update(event)
        if not event or not event.source or not event.destination then
            return
        end

        if storage.spaceships then
            for key, value in pairs(storage.spaceships) do
                if value.hub and value.hub.unit_number == event.source.unit_number then
                    storage.spaceships[key].hub = event.destination
                    if event.destination and event.destination.valid and event.destination.name == "spaceship-control-hub" then
                        local tags = event.destination.tags or {}
                        tags.id = storage.spaceships[key].id
                        event.destination.tags = tags
                    end
                end
                if value.docking_port and value.docking_port.unit_number == event.source.unit_number then
                    storage.spaceships[key].docking_port = event.destination
                end
            end
        end

        if storage.docking_ports and storage.docking_ports[event.source.unit_number] then
            local old_data = storage.docking_ports[event.source.unit_number]
            storage.docking_ports[event.source.unit_number] = nil
            storage.docking_ports[event.destination.unit_number] = {
                entity = event.destination,
                position = event.destination.position,
                surface = event.destination.surface,
                name = old_data.name or "",
                ship_limit = old_data.ship_limit or 1
            }
        end
    end

    function SpaceShip.update_all_ship_docking_status()
        if not storage.spaceships then return end

        for ship_id, ship in pairs(storage.spaceships) do
            if ship and ship.surface then
                -- Check if ship is on its own surface (traveling in space)
                if ship.own_surface then
                    ship.docked = false
                    ship.traveling = true
                else
                    -- Ship is on a station surface
                    ship.docked = true
                    ship.traveling = false
                end
            end
        end

        game.print("Updated docking status for " .. table_size(storage.spaceships) .. " ships")
    end
end
