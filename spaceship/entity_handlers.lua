return function(SpaceShip)
    local function deep_copy(value, seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}
        if seen[value] then return seen[value] end

        local copy = {}
        seen[value] = copy
        for k, v in pairs(value) do
            copy[deep_copy(k, seen)] = deep_copy(v, seen)
        end
        return setmetatable(copy, getmetatable(value))
    end

    local function get_next_ship_id()
        storage.spaceships = storage.spaceships or {}
        storage.next_ship_id = storage.next_ship_id or 0

        local max_id = storage.next_ship_id
        for id, _ in pairs(storage.spaceships) do
            local numeric_id = tonumber(id)
            if numeric_id and numeric_id > max_id then
                max_id = numeric_id
            end
        end

        storage.next_ship_id = max_id + 1
        return storage.next_ship_id
    end

    local function get_ship_by_hub_entity(hub_entity)
        if not (hub_entity and hub_entity.valid and hub_entity.name == "spaceship-control-hub") then
            return nil
        end

        for _, ship in pairs(storage.spaceships or {}) do
            if ship.hub and ship.hub.valid and ship.hub.unit_number == hub_entity.unit_number then
                return ship
            end
        end

        return nil
    end

    function SpaceShip.handle_built_entity(entity, player)
        if not (entity and entity.valid) then return end

        local surface = entity.surface

        -- Check thruster placement restrictions
        if entity.name == "thruster" then
            -- Get the thruster's bounding box to check all tiles underneath
            local bounding_box = entity.bounding_box
            local left_top = { x = math.floor(bounding_box.left_top.x), y = math.floor(bounding_box.left_top.y) }
            local right_bottom = {
                x = math.ceil(bounding_box.right_bottom.x) - 1,
                y = math.ceil(bounding_box.right_bottom.y) -
                    1
            }

            -- Check all tiles under the thruster
            local invalid_tiles = {}
            for x = left_top.x, right_bottom.x do
                for y = left_top.y, right_bottom.y do
                    local tile = surface.get_tile({ x = x, y = y })
                    if tile.name ~= "spaceship-flooring" then
                        table.insert(invalid_tiles, { x = x, y = y, name = tile.name })
                    end
                end
            end

            -- If any tiles are not spaceship flooring, prevent placement
            if #invalid_tiles > 0 then
                local item_stack = { name = "thruster", count = 1 }

                -- Return the thruster to player inventory or spill on ground
                if player and player.valid then
                    local inserted = player.insert(item_stack)
                    if inserted == 0 then
                        -- If player inventory is full, spill on ground
                        surface.spill_item_stack(entity.position, item_stack, true, player.force, false)
                    end

                    -- Show error message to player
                    player.print("[color=red]Thrusters can only be placed on Spaceship Flooring![/color]")
                else
                    -- No player (robot built), spill on ground
                    surface.spill_item_stack(entity.position, item_stack, true, entity.force, false)
                end

                -- Remove the incorrectly placed thruster
                entity.destroy()
                return
            end
        end

        -- Spawn the car on the spaceship controller:
        if entity.name == "spaceship-control-hub" then
            storage.spaceships = storage.spaceships or {}
            local next_id = get_next_ship_id()
            local my_ship = SpaceShip.new("Explorer" .. next_id, next_id, player)
            entity.tags = { id = my_ship.id }
            my_ship.hub = entity
            storage.spaceships[my_ship.id] = my_ship
            local car_position = { x = entity.position.x + 2, y = entity.position.y + 3.5 } -- Car spawns slightly lower so player can enter it
            local car = surface.create_entity {
                name = "spaceship-control-hub-car",
                position = car_position,
                force = entity.force
            }
            if car then
                car.orientation = 0.0 -- Align the car with the controller orientation, if needed.
            else
                game.print("Unable to spawn spaceship control hub car!")
            end
        end
        if entity.name == "spaceship-docking-port" then
            SpaceShip.register_docking_port(entity)
            SpaceShip.connect_adjacent_ports()
        end

        -- If built on a spaceship tile, mark scanned as false
        for _, ship in pairs(storage.spaceships or {}) do
            if ship.hub and ship.hub.valid and entity.surface == ship.hub.surface then
                -- Check if any tile under the entity is spaceship-flooring
                local bb = entity.bounding_box or { left_top = entity.position, right_bottom = entity.position }
                local found = false
                for x = math.floor(bb.left_top.x), math.ceil(bb.right_bottom.x) do
                    for y = math.floor(bb.left_top.y), math.ceil(bb.right_bottom.y) do
                        local tile = entity.surface.get_tile(x, y)
                        if tile and tile.name == "spaceship-flooring" then
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
                if found then
                    ship.scanned = false
                end
            end
        end
    end

    function SpaceShip.handle_mined_entity(entity)
        if not (entity and entity.valid) then return end
        -- Remove the car associated with the mined hub
        if entity.name == "spaceship-control-hub" then
            local area = {
                { entity.position.x - 5, entity.position.y },
                { entity.position.x + 5, entity.position.y + 6 }
            }
            local cars = entity.surface.find_entities_filtered {
                area = area,
                name = "spaceship-control-hub-car"
            }
            for _, car in pairs(cars) do
                car.destroy()
            end
            for key, value in pairs(storage.spaceships) do
                if value.hub.unit_number == entity.unit_number then
                    storage.spaceships[key] = nil
                end
            end
        end
        if entity.name == "spaceship-docking-port" then
            if storage.docking_ports and storage.docking_ports[entity.unit_number] then
                storage.docking_ports[entity.unit_number] = nil
            end
            SpaceShip.connect_adjacent_ports()
        end
        -- If built on a spaceship tile, mark scanned as false
        for _, ship in pairs(storage.spaceships or {}) do
            if ship.hub and ship.hub.valid and entity.surface == ship.hub.surface then
                -- Check if any tile under the entity is spaceship-flooring
                local bb = entity.bounding_box or { left_top = entity.position, right_bottom = entity.position }
                local found = false
                for x = math.floor(bb.left_top.x), math.ceil(bb.right_bottom.x) do
                    for y = math.floor(bb.left_top.y), math.ceil(bb.right_bottom.y) do
                        local tile = entity.surface.get_tile(x, y)
                        if tile and tile.name == "spaceship-flooring" then
                            found = true
                            break
                        end
                    end
                    if found then break end
                end
                if found then
                    ship.scanned = false
                end
            end
        end
    end

    function SpaceShip.handle_ghost_entity(ghost, player)
        if not (ghost and ghost.valid) then return end

        -- Check thruster ghost placement restrictions
        if ghost.ghost_name == "thruster" then
            local surface = ghost.surface

            -- Get the thruster's bounding box to check all tiles underneath
            local bounding_box = ghost.bounding_box
            local left_top = { x = math.floor(bounding_box.left_top.x), y = math.floor(bounding_box.left_top.y) }
            local right_bottom = {
                x = math.ceil(bounding_box.right_bottom.x) - 1,
                y = math.ceil(bounding_box.right_bottom.y) -
                    1
            }

            -- Check all tiles under the thruster ghost
            local invalid_tiles = {}
            for x = left_top.x, right_bottom.x do
                for y = left_top.y, right_bottom.y do
                    local position = { x = x, y = y }
                    local tile = surface.get_tile(position)
                    local valid_tile = false

                    -- Check if current tile is spaceship flooring
                    if tile.name == "spaceship-flooring" then
                        valid_tile = true
                    else
                        -- Check for spaceship flooring ghost tiles at this position
                        local ghost_tiles = surface.find_entities_filtered({
                            position = position,
                            type = "tile-ghost",
                            name = "tile-ghost"
                        })

                        for _, ghost_tile in pairs(ghost_tiles) do
                            if ghost_tile.ghost_name == "spaceship-flooring" then
                                valid_tile = true
                                break
                            end
                        end
                    end

                    if not valid_tile then
                        table.insert(invalid_tiles, { x = x, y = y, name = tile.name })
                    end
                end
            end

            -- If any tiles are not spaceship flooring (actual or ghost), prevent ghost placement
            if #invalid_tiles > 0 then
                -- Show error message to player
                if player and player.valid then
                    player.print("[color=red]Thrusters can only be placed on Spaceship Flooring![/color]")
                end

                -- Remove the incorrectly placed ghost
                ghost.destroy()
                return
            end
        end
    end

    function SpaceShip.handle_entity_settings_pasted(event)
        local source = event and event.source
        local destination = event and event.destination

        if not (source and source.valid and destination and destination.valid) then return end
        if source.unit_number == destination.unit_number then return end

        if source.name == "spaceship-control-hub" and destination.name == "spaceship-control-hub" then
            local source_ship = get_ship_by_hub_entity(source)
            local destination_ship = get_ship_by_hub_entity(destination)
            if not source_ship or not destination_ship then return end

            if source_ship.schedule then
                destination_ship.schedule = deep_copy(source_ship.schedule)
                if destination_ship.platform and destination_ship.platform.valid then
                    destination_ship.platform.schedule = deep_copy(source_ship.schedule)
                end
            else
                destination_ship.schedule = {}
                if destination_ship.platform and destination_ship.platform.valid then
                    destination_ship.platform.schedule = nil
                end
            end
            return
        end

        if source.name == "spaceship-docking-port" and destination.name == "spaceship-docking-port" then
            if not storage.docking_ports then return end

            local source_port = storage.docking_ports[source.unit_number]
            local destination_port = storage.docking_ports[destination.unit_number]
            if not source_port or not destination_port then return end

            -- Copy configurable settings while preserving destination runtime references.
            for key, value in pairs(source_port) do
                if key ~= "entity" and key ~= "position" and key ~= "surface" and key ~= "ship_docked" then
                    destination_port[key] = deep_copy(value)
                end
            end

            local player = event.player_index and game.get_player(event.player_index) or nil
            local message = "Copied docking port settings from '" .. (source_port.name or "") .. "' to destination port"
            if player and player.valid then
                player.print(message)
            else
                game.print(message)
            end
            return
        end
    end
end
