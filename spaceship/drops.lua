return function(SpaceShip, DROP_COST)
    function SpaceShip.drop_player_to_planet(ship)
        -- Testing: material/cost gate is disabled for spaceship player drop.
        -- local can_drop, cost_message = check_drop_cost(ship)
        -- if not can_drop then
        --     game.print(cost_message or "[color=red]Insufficient resources for drop![/color]")
        --     return
        -- end

        if not ship.planet_orbiting then
            game.print("[color=red]Error: Ship is not orbiting any planet![/color]")
            return
        end

        local player = ship.player_in_cockpit
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
            game.print("[color=green]Launching base-game landing sequence to " .. ship.planet_orbiting .. "![/color]")
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
        -- Helper: Check if the ship has the required drop cost
        local function check_drop_cost(ship)
            if not ship.hub or not ship.hub.valid then return false, "No hub" end
            local inventory = ship.hub.get_inventory(defines.inventory.chest)
            if not inventory then return false, "No inventory" end
            for item, count in pairs(DROP_COST) do
                if inventory.get_item_count(item) < count then
                    return false, "[color=red]Not enough " .. item .. " (" .. count .. " required)[/color]"
                end
            end
            return true
        end

        -- Helper: Consume the drop cost from the ship's hub inventory
        local function consume_drop_cost(ship)
            if not ship.hub or not ship.hub.valid then return false end
            local inventory = ship.hub.get_inventory(defines.inventory.chest)
            if not inventory then return false end
            for item, count in pairs(DROP_COST) do
                local removed = inventory.remove { name = item, count = count }
                if removed < count then
                    return false
                end
            end
            return true
        end

        -- Testing: material/cost gate is disabled for spaceship cargo drop.
        -- local can_drop, cost_message = check_drop_cost(ship)
        -- if not can_drop then
        --     game.print(cost_message or "[color=red]Insufficient resources for drop![/color]")
        --     return
        -- end
        if not ship.planet_orbiting then
            game.print("[color=red]Error: Ship is not orbiting any planet![/color]")
            return
        end
        local target_surface_name = ship.planet_orbiting
        local target_surface = game.surfaces[target_surface_name]
        if not target_surface then
            target_surface = game.create_surface(target_surface_name)
        end
        local cargo_items = {}
        local has_cargo = false
        if ship.hub and ship.hub.valid then
            local inventory = ship.hub.get_inventory(defines.inventory.chest)
            if inventory and not inventory.is_empty() then
                -- Blacklist drop cost items: do not allow them to be dropped as cargo
                for i = 1, #inventory do
                    local stack = inventory[i]
                    if stack.valid_for_read then
                        local item_name = stack.name
                        -- Explicitly skip cost items (blacklist)
                        if not DROP_COST[item_name] then
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
                end
                -- Remove only the dropped items from inventory
                for _, item in ipairs(cargo_items) do
                    inventory.remove({ name = item.name, count = item.count })
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
        local drop_pod_position = { x = ship.hub.position.x, y = ship.hub.position.y - 5 }
        drop_pod_position.x = math.floor(drop_pod_position.x)
        drop_pod_position.y = math.floor(drop_pod_position.y)
        if not ship.hub.surface or not ship.hub.surface.valid then
            game.print("[color=red]Error: Invalid surface for drop pod launch![/color]")
            return
        end
        local pod_entity_types = {
            "cargo-pod-container",
            "steel-chest",
            "rocket-silo-rocket",
            "rocket-silo",
            "space-platform-hub",
            "assembling-machine-1"
        }
        local drop_force = ship.hub.force
        local drop_pod = nil
        for _, entity_type in ipairs(pod_entity_types) do
            local success, result = pcall(function()
                return ship.hub.surface.create_entity {
                    name = entity_type,
                    position = drop_pod_position,
                    force = drop_force,
                    create_build_effect_smoke = false
                }
            end)
            if success and result then
                drop_pod = result
                break
            end
        end
        if not drop_pod then
            game.print("[color=red]Error: Failed to create drop pod![/color]")
            return
        end
        -- Only consume cost if all checks pass and drop will happen
        -- Testing: cost consumption disabled for spaceship cargo drop.
        -- if not consume_drop_cost(ship) then
        --     game.print("[color=red]Failed to consume drop cost![/color]")
        --     return
        -- end
        local drop_data = {
            player = nil,
            target_surface = target_surface,
            drop_pod = drop_pod,
            tick_to_execute = game.tick + 180, -- 3 second delay
            ship = ship,
            cargo_items = cargo_items,
            has_cargo = has_cargo
        }
        storage.pending_drops = storage.pending_drops or {}
        table.insert(storage.pending_drops, drop_data)
        if drop_pod then
            local effect_force = ship.hub.force
            pcall(function()
                ship.hub.surface.create_entity {
                    name = "explosion",
                    position = drop_pod.position,
                    force = effect_force
                }
            end)
            for i = 1, 5 do
                pcall(function()
                    ship.hub.surface.create_entity {
                        name = "explosion-gunshot",
                        position = {
                            x = drop_pod.position.x + math.random(-2, 2),
                            y = drop_pod.position.y + math.random(-2, 2)
                        },
                        force = effect_force
                    }
                end)
            end
        end
        game.print("[color=green]Launching cargo drop pod to " .. target_surface_name .. "![/color]")
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
