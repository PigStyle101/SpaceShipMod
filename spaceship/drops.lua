return function(SpaceShip)
    local function to_player(driver_or_passenger)
        if not (driver_or_passenger and driver_or_passenger.valid) then return nil end

        if driver_or_passenger.player and driver_or_passenger.player.valid then
            return driver_or_passenger.player
        end

        if driver_or_passenger.index and driver_or_passenger.controller_type then
            return driver_or_passenger
        end

        return nil
    end

    local function resolve_player_in_ship_cockpit(ship)
        if not ship then return nil end

        local cached = ship.player_in_cockpit
        if cached and cached.valid and cached.vehicle and cached.vehicle.valid and
            cached.vehicle.name == "spaceship-control-hub-car" then
            return cached
        end

        if not (ship.surface and ship.surface.valid) then return nil end

        local search_area = nil
        if ship.bounds then
            search_area = {
                { x = ship.bounds.left_top.x - 1, y = ship.bounds.left_top.y - 1 },
                { x = ship.bounds.right_bottom.x + 1, y = ship.bounds.right_bottom.y + 1 }
            }
        elseif ship.hub and ship.hub.valid and ship.hub.surface == ship.surface then
            search_area = {
                { x = ship.hub.position.x - 80, y = ship.hub.position.y - 80 },
                { x = ship.hub.position.x + 80, y = ship.hub.position.y + 80 }
            }
        end

        if not search_area then return nil end

        local cockpit_cars = ship.surface.find_entities_filtered {
            name = "spaceship-control-hub-car",
            area = search_area
        }

        for _, car in pairs(cockpit_cars) do
            if car and car.valid then
                local driver_player = to_player(car.get_driver())
                if driver_player then
                    ship.player_in_cockpit = driver_player
                    return driver_player
                end

                local passenger_player = to_player(car.get_passenger())
                if passenger_player then
                    ship.player_in_cockpit = passenger_player
                    return passenger_player
                end
            end
        end

        return nil
    end

    local function get_ship_orbit_planet(ship)
        if not ship then return nil end

        local hub = ship.hub
        local surface = hub and hub.valid and hub.surface or ship.surface
        if not (surface and surface.valid and surface.platform and surface.platform.valid) then
            return nil
        end

        local space_location = surface.platform.space_location
        if not (space_location and space_location.name and space_location.name ~= "none") then
            return nil
        end

        return space_location.name
    end

    function SpaceShip.drop_player_to_planet(ship)
        local orbit_planet = get_ship_orbit_planet(ship)
        if not orbit_planet then
            game.print("[color=red]Error: Ship is not orbiting any planet![/color]")
            return
        end

        local player = resolve_player_in_ship_cockpit(ship)
        if not player then
            game.print("[color=red]Error: No player in cockpit to drop![/color]")
            return
        end

        storage.base_landing_in_progress = storage.base_landing_in_progress or {}
        storage.platform_hub_action_tick = storage.platform_hub_action_tick or {}
        storage.base_landing_in_progress[player.index] = game.tick
        storage.platform_hub_action_tick[player.index] = game.tick

        if not ship.hub or not ship.hub.valid or not ship.hub.surface or not ship.hub.surface.valid then
            storage.base_landing_in_progress[player.index] = nil
            game.print("[color=red]Base-game landing sequence failed and ship hub is invalid.[/color]")
            return
        end

        local anchor_position = ship.hub.position
        if player.vehicle and player.vehicle.valid and player.vehicle.name == "spaceship-control-hub-car" then
            anchor_position = player.vehicle.position
        else
            local search_area = {
                { x = ship.hub.position.x - 8, y = ship.hub.position.y - 8 },
                { x = ship.hub.position.x + 8, y = ship.hub.position.y + 8 }
            }
            local cars = ship.hub.surface.find_entities_filtered({ area = search_area, name = "spaceship-control-hub-car" })
            if cars and cars[1] and cars[1].valid then
                anchor_position = cars[1].position
            end
        end

        local temp_hub_position = ship.hub.surface.find_non_colliding_position("space-platform-hub", anchor_position, 8, 0.5)
            or anchor_position

        local temp_platform_hub = nil
        local temp_hub_success, temp_hub_result = pcall(function()
            return ship.hub.surface.create_entity {
                name = "space-platform-hub",
                position = temp_hub_position,
                force = player.force,
                create_build_effect_smoke = false
            }
        end)
        if temp_hub_success then
            temp_platform_hub = temp_hub_result
        end

        if not temp_platform_hub or not temp_platform_hub.valid then
            storage.base_landing_in_progress[player.index] = nil
            game.print("[color=red]Base-game landing failed: temporary space-platform-hub could not be created.[/color]")
            return
        end

        -- Prevent the player from opening/mining the temporary hub while it's mid-sequence.
        pcall(function()
            temp_platform_hub.operable = false
            temp_platform_hub.minable = false
        end)

        pcall(function() player.driving = false end)
        if player.character and player.character.valid and player.controller_type ~= defines.controllers.character then
            pcall(function()
                player.set_controller({ type = defines.controllers.character, character = player.character })
            end)
        end
        pcall(function() player.teleport(temp_platform_hub.position, temp_platform_hub.surface) end)

        local temp_platform = temp_platform_hub.surface and temp_platform_hub.surface.platform
        local temp_enter_success, temp_enter_result = pcall(function()
            if not temp_platform or not temp_platform.valid then return false end
            return player.enter_space_platform(temp_platform)
        end)

        if not (temp_enter_success and temp_enter_result) then
            if temp_platform_hub.valid then
                temp_platform_hub.destroy()
            end
            storage.base_landing_in_progress[player.index] = nil
            game.print("[color=red]Base-game landing failed: could not enter platform via temporary space-platform-hub.[/color]")
            return
        end

        local temp_land_success, temp_land_result = pcall(function()
            return player.land_on_planet()
        end)

        if temp_land_success and temp_land_result then
            ship.player_in_cockpit = nil
            storage.temp_platform_hubs_cleanup = storage.temp_platform_hubs_cleanup or {}
            table.insert(storage.temp_platform_hubs_cleanup, {
                entity = temp_platform_hub,
                cleanup_tick = game.tick + 900
            })
            game.print("[color=green]Launching base-game landing sequence to " .. orbit_planet .. "![/color]")
            return
        end

        if temp_platform_hub.valid then
            temp_platform_hub.destroy()
        end

        storage.base_landing_in_progress[player.index] = nil

        game.print("[color=red]Base-game landing sequence failed.[/color]")
    end

    -- Drops a player from a space platform hub to the platform's current orbiting planet.
    function SpaceShip.drop_player_from_platform_hub(player, hub)
        if not player or not player.valid then return end

        storage.base_landing_in_progress = storage.base_landing_in_progress or {}
        local in_progress_tick = storage.base_landing_in_progress[player.index]
        if in_progress_tick and (game.tick - in_progress_tick) <= 600 then
            return
        end

        if not hub or not hub.valid or hub.name ~= "space-platform-hub" then
            player.print("[color=red]Error: Invalid space platform hub.[/color]")
            return
        end

        local platform = hub.surface and hub.surface.platform
        if not platform or not platform.valid or not platform.space_location then
            player.print("[color=red]Error: Platform is not orbiting a planet.[/color]")
            return
        end

        local target_surface_name = platform.space_location.name
        local target_surface = game.surfaces[target_surface_name]
        if not target_surface then
            target_surface = game.create_surface(target_surface_name)
        end

        -- First try the built-in Space Age landing flow.
        -- This is what triggers the native platform-to-planet procession visuals (cloud layers, audio, etc.).
        local land_success, land_result = pcall(function()
            return player.land_on_planet()
        end)
        if land_success and land_result then
            game.print("[color=green]Launching base-game landing sequence to " .. target_surface_name .. "![/color]")
            return
        end

        player.print("[color=red]Base-game landing sequence failed.[/color]")
    end

    -- Handles dropping items as cargo pods (no player drop)
    function SpaceShip.drop_items_to_planet(ship)
        local orbit_planet = get_ship_orbit_planet(ship)
        if not orbit_planet then
            game.print("[color=red]Error: Ship is not orbiting any planet![/color]")
            return
        end
        local target_surface_name = orbit_planet
        local target_surface = game.surfaces[target_surface_name]
        if not target_surface then
            target_surface = game.create_surface(target_surface_name)
        end
        local cargo_items = {}
        local has_cargo = false

        if ship.hub and ship.hub.valid then
            local inventory = ship.hub.get_inventory(defines.inventory.chest)
            if inventory and not inventory.is_empty() then
                local last_slot = #inventory

                for i = 1, last_slot do
                    local stack = inventory[i]
                    if stack.valid_for_read then
                        local item_data = {
                            name = stack.name,
                            count = stack.count
                        }
                        local success, value
                        success, value = pcall(function() return stack.quality end)
                        if success and value then item_data.quality = value end
                        success, value = pcall(function() return stack.health end)
                        if success and value and value < 1.0 then item_data.health = value end
                        success, value = pcall(function() return stack.durability end)
                        if success and value and value < 1.0 then item_data.durability = value end
                        success, value = pcall(function() return stack.ammo end)
                        if success and value then item_data.ammo = value end
                        success, value = pcall(function() return stack.custom_description end)
                        if success and value and value ~= "" then item_data.custom_description = value end
                        table.insert(cargo_items, item_data)
                        has_cargo = true
                    end
                end
                -- Remove only the dropped items from inventory. Quality must be specified here,
                -- otherwise remove() only matches normal-quality stacks and leaves the actual
                -- quality item behind while a copy was already queued for the cargo pod.
                for _, item in ipairs(cargo_items) do
                    inventory.remove({ name = item.name, count = item.count, quality = item.quality })
                end
                if has_cargo then
                    game.print("[color=yellow]Cargo extracted from spaceship control hub: " ..
                        #cargo_items .. " item stacks![/color]")
                end
            end
        end
        if not has_cargo then
            game.print("[color=red]Error: No cargo to drop![/color]")
            return
        end
        if not ship.hub.surface or not ship.hub.surface.valid then
            game.print("[color=red]Error: Invalid surface for drop pod launch![/color]")
            return
        end

        -- Use the same approach as the base-game player landing sequence: create a temporary
        -- space-platform-hub so we get a real cargo hatch, then create a genuine cargo pod from
        -- it and launch it toward the target planet. This gives us the actual in-game cargo pod
        -- ascend/descend animation instead of a faked explosion + delayed spawn.
        local anchor_position = ship.hub.position
        local temp_hub_position = ship.hub.surface.find_non_colliding_position("space-platform-hub", anchor_position,
            8, 0.5) or anchor_position

        local temp_platform_hub = nil
        local temp_hub_success, temp_hub_result = pcall(function()
            return ship.hub.surface.create_entity {
                name = "space-platform-hub",
                position = temp_hub_position,
                force = ship.hub.force,
                create_build_effect_smoke = false
            }
        end)
        if temp_hub_success then
            temp_platform_hub = temp_hub_result
        end

        if not temp_platform_hub or not temp_platform_hub.valid then
            game.print("[color=red]Error: Failed to create temporary space-platform-hub for cargo drop![/color]")
            return
        end

        -- Prevent the player from opening/mining the temporary hub while it's dispatching pods.
        pcall(function()
            temp_platform_hub.operable = false
            temp_platform_hub.minable = false
        end)

        -- Split the cargo into chunks so multiple real cargo pods get dispatched (e.g. 50 items
        -- selected results in 5 pods of 10 item stacks each), one hatch launch at a time.
        local ITEMS_PER_POD = 10
        local cargo_chunks = {}
        local current_chunk = {}
        for _, item_data in ipairs(cargo_items) do
            table.insert(current_chunk, item_data)
            if #current_chunk >= ITEMS_PER_POD then
                table.insert(cargo_chunks, current_chunk)
                current_chunk = {}
            end
        end
        if #current_chunk > 0 then
            table.insert(cargo_chunks, current_chunk)
        end

        storage.pending_cargo_pod_launches = storage.pending_cargo_pod_launches or {}
        storage.temp_hub_pending_chunks = storage.temp_hub_pending_chunks or {}
        storage.temp_hub_pending_chunks[temp_platform_hub.unit_number] = #cargo_chunks

        for _, chunk in ipairs(cargo_chunks) do
            table.insert(storage.pending_cargo_pod_launches, {
                hub = temp_platform_hub,
                items = chunk,
                target_surface_name = target_surface_name,
                force = ship.hub.force
            })
        end

        game.print("[color=green]Launching " .. #cargo_chunks .. " cargo drop pod" ..
            (#cargo_chunks == 1 and "" or "s") .. " to " .. target_surface_name .. "![/color]")
    end

    -- Processes queued cargo pod launches created by drop_items_to_planet. Each queued job
    -- represents one pod's worth of items; pods are launched one at a time per hub since a hub
    -- may only have a limited number of free cargo hatches at once. Should be called once per
    -- tick (e.g. from the on_tick handler in control.lua).
    function SpaceShip.process_pending_cargo_pod_launches()
        local queue = storage.pending_cargo_pod_launches
        if not queue or #queue == 0 then return end

        for i = #queue, 1, -1 do
            local job = queue[i]
            local hub = job.hub

            if not (hub and hub.valid) then
                table.remove(queue, i)
            else
                local pod_success, drop_pod = pcall(function() return hub.create_cargo_pod() end)
                if pod_success and drop_pod then
                    table.remove(queue, i)

                    local pod_inventory = drop_pod.get_inventory(defines.inventory.cargo_unit)
                    if pod_inventory then
                        for _, item_data in ipairs(job.items) do
                            local item_to_insert = { name = item_data.name, count = item_data.count }
                            if item_data.quality then item_to_insert.quality = item_data.quality end
                            if item_data.health then item_to_insert.health = item_data.health end
                            if item_data.durability then item_to_insert.durability = item_data.durability end
                            if item_data.ammo then item_to_insert.ammo = item_data.ammo end
                            if item_data.custom_description then
                                item_to_insert.custom_description = item_data.custom_description
                            end
                            pod_inventory.insert(item_to_insert)
                        end
                    end

                    local target_surface = game.surfaces[job.target_surface_name]
                    if target_surface and target_surface.valid then
                        local landing_pad = nil
                        local landing_pads = target_surface.find_entities_filtered {
                            type = "cargo-landing-pad",
                            force = job.force
                        }
                        for _, pad in pairs(landing_pads) do
                            if pad and pad.valid then
                                landing_pad = pad
                                break
                            end
                        end

                        if landing_pad then
                            drop_pod.cargo_pod_destination = {
                                type = defines.cargo_destination.station,
                                station = landing_pad
                            }
                        else
                            local landing_position = target_surface.find_non_colliding_position(
                                "cargo-pod-container", { 0, 0 }, 100, 1) or { 0, 0 }
                            drop_pod.cargo_pod_destination = {
                                type = defines.cargo_destination.surface,
                                surface = target_surface,
                                position = landing_position
                            }
                        end
                    end

                    -- Track remaining chunks for this hub so we know when it's safe to clean it up.
                    storage.temp_hub_pending_chunks = storage.temp_hub_pending_chunks or {}
                    local remaining = (storage.temp_hub_pending_chunks[hub.unit_number] or 1) - 1
                    if remaining <= 0 then
                        storage.temp_hub_pending_chunks[hub.unit_number] = nil
                        storage.temp_platform_hubs_cleanup = storage.temp_platform_hubs_cleanup or {}
                        table.insert(storage.temp_platform_hubs_cleanup, {
                            entity = hub,
                            cleanup_tick = game.tick + 900
                        })
                    else
                        storage.temp_hub_pending_chunks[hub.unit_number] = remaining
                    end
                end
                -- If pod creation failed (no free hatch yet), leave the job queued for a later tick.
            end
        end
    end

    function SpaceShip.process_pending_drops()
        if not storage.pending_drops then return end
        local current_tick = game.tick
        local completed_drops = {}
        for i, drop_data in ipairs(storage.pending_drops) do
            if current_tick >= drop_data.tick_to_execute then
                local player = drop_data.player
                local target_surface = drop_data.target_surface
                local drop_pod = drop_data.drop_pod
                -- Handle player drop
                if player and player.valid and target_surface and target_surface.valid then
                    local landing_position = target_surface.find_non_colliding_position("character", { 0, 0 }, 100, 1) or
                        { 0, 0 }
                    player.teleport(landing_position, target_surface)
                    game.print("[color=green]Player " ..
                        player.name .. " has landed on " .. target_surface.name .. "![/color]")
                end
                -- Handle cargo drop
                if drop_data.has_cargo and drop_data.cargo_items and #drop_data.cargo_items > 0 and target_surface and target_surface.valid then
                    local items_per_pod = 10
                    local cargo_chunks = {}
                    local current_chunk = {}
                    for i, item_data in ipairs(drop_data.cargo_items) do
                        table.insert(current_chunk, item_data)
                        if #current_chunk >= items_per_pod then
                            table.insert(cargo_chunks, current_chunk)
                            current_chunk = {}
                        end
                    end
                    if #current_chunk > 0 then
                        table.insert(cargo_chunks, current_chunk)
                    end
                    local total_pods = #cargo_chunks
                    local successful_pods = 0
                    for pod_index, item_chunk in ipairs(cargo_chunks) do
                        local pod_position = nil
                        for attempt = 1, 10 do
                            local test_pos = {
                                x = math.random(-50, 50) + (pod_index * 5),
                                y = math.random(-50, 50) + (pod_index * 5)
                            }
                            pod_position = target_surface.find_non_colliding_position("cargo-pod-container", test_pos, 20, 1)
                            if pod_position then break end
                        end
                        if not pod_position then
                            pod_position = { x = pod_index * 5, y = pod_index * 5 }
                        end
                        local pod_entity_types = { "cargo-pod-container", "steel-chest" }
                        local cargo_pod = nil
                        for _, entity_type in ipairs(pod_entity_types) do
                            local success, result = pcall(function()
                                return target_surface.create_entity {
                                    name = entity_type,
                                    position = pod_position,
                                    force = (player and player.force) or "player"
                                }
                            end)
                            if success and result then
                                cargo_pod = result
                                break
                            end
                        end
                        if cargo_pod then
                            successful_pods = successful_pods + 1
                            local pod_inventory = cargo_pod.get_inventory(defines.inventory.chest)
                            if pod_inventory then
                                for _, item_data in ipairs(item_chunk) do
                                    local item_to_insert = { name = item_data.name, count = item_data.count }
                                    if item_data.quality then item_to_insert.quality = item_data.quality end
                                    if item_data.health then item_to_insert.health = item_data.health end
                                    if item_data.durability then item_to_insert.durability = item_data.durability end
                                    if item_data.ammo then item_to_insert.ammo = item_data.ammo end
                                    if item_data.custom_description then
                                        item_to_insert.custom_description = item_data
                                            .custom_description
                                    end
                                    pod_inventory.insert(item_to_insert)
                                end
                            end
                            pcall(function()
                                target_surface.create_entity {
                                    name = "explosion",
                                    position = cargo_pod.position,
                                    force = cargo_pod.force
                                }
                            end)
                        end
                    end
                    if successful_pods > 0 then
                        game.print("[color=green]" ..
                            successful_pods ..
                            "/" .. total_pods .. " cargo pods have landed on " .. target_surface.name .. "![/color]")
                    else
                        game.print("[color=red]Failed to create cargo pods on " .. target_surface.name .. "![/color]")
                    end
                end
                -- Clean up the launch pod if it exists
                if drop_data.drop_pod and drop_data.drop_pod.valid then
                    drop_data.drop_pod.destroy()
                end
                table.insert(completed_drops, i)
            end
        end
        for i = #completed_drops, 1, -1 do
            table.remove(storage.pending_drops, completed_drops[i])
        end
    end
end
