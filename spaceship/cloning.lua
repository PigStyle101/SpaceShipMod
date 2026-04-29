return function(SpaceShip)
    local UNATTENDED_CLONE_CLEANUP_TILE_BUDGET = 120
    local UNATTENDED_CLONE_CLEANUP_ENTITY_BUDGET = 60
    local UNATTENDED_CLONE_BRUSH_CHUNK_SIZE = 10
    local ENABLE_WIRE_SNAPSHOT_DEBUG = true
    local CONDITION_ENTITY_TYPES = { "inserter", "transport-belt", "underground-belt", "splitter", "assembling-machine", "furnace" }

    local function is_player_attending_ship(ship)
        if not ship then return false end
        local player = ship.player
        if not (player and player.valid) then return false end

        if player.gui and player.gui.relative and player.gui.relative["schedule-container"] then
            return true
        end

        if ship.player_in_cockpit and ship.player_in_cockpit.valid and ship.player_in_cockpit.index == player.index then
            return true
        end

        if not (ship.surface and ship.surface.valid and player.surface == ship.surface) then
            return false
        end

        local player_tile = ship.surface.get_tile(player.position)
        if player_tile and player_tile.valid and player_tile.name == "spaceship-flooring" then
            return true
        end

        if ship.hub and ship.hub.valid then
            local dx = player.position.x - ship.hub.position.x
            local dy = player.position.y - ship.hub.position.y
            return (dx * dx + dy * dy) <= (80 * 80)
        end

        return false
    end

    SpaceShip.is_player_attending_ship = is_player_attending_ship

    local function enqueue_clone_cleanup(src_surface, floor_positions, entities)
        storage.clone_cleanup_queue = storage.clone_cleanup_queue or {}
        table.insert(storage.clone_cleanup_queue, {
            src_surface = src_surface,
            floor_positions = floor_positions,
            tile_index = 1,
            entities = entities,
            entity_index = 1,
        })
    end

    local function find_cloned_entity_near(surface, name, expected_position, radius)
        if not (surface and surface.valid and expected_position) then return nil end
        local direct = surface.find_entity(name, expected_position)
        if direct and direct.valid then
            return direct
        end

        local r = radius or 2
        local candidates = surface.find_entities_filtered({
            name = name,
            area = {
                { x = expected_position.x - r, y = expected_position.y - r },
                { x = expected_position.x + r, y = expected_position.y + r }
            }
        })

        local best = nil
        local best_d = math.huge
        for _, e in pairs(candidates) do
            if e and e.valid then
                local dx = e.position.x - expected_position.x
                local dy = e.position.y - expected_position.y
                local d = dx * dx + dy * dy
                if d < best_d then
                    best_d = d
                    best = e
                end
            end
        end
        return best
    end

    function SpaceShip.process_clone_cleanup_queue()
        local queue = storage.clone_cleanup_queue
        if not queue or #queue == 0 then return end

        local task = queue[1]
        if not task or not task.src_surface or not task.src_surface.valid then
            table.remove(queue, 1)
            return
        end

        local tile_budget = UNATTENDED_CLONE_CLEANUP_TILE_BUDGET
        local entity_budget = UNATTENDED_CLONE_CLEANUP_ENTITY_BUDGET

        if task.tile_index <= #task.floor_positions then
            local set_tiles_batch = {}
            local processed = 0
            while processed < tile_budget and task.tile_index <= #task.floor_positions do
                local tile = task.floor_positions[task.tile_index]
                task.tile_index = task.tile_index + 1
                processed = processed + 1

                if tile and tile.position then
                    local hidden_tile = task.src_surface.get_hidden_tile(tile.position)
                    if not hidden_tile then
                        hidden_tile = "space-platform-foundation"
                    end
                    set_tiles_batch[#set_tiles_batch + 1] = {
                        name = hidden_tile,
                        position = tile.position
                    }
                    task.src_surface.set_hidden_tile(tile.position, nil)
                end
            end

            if #set_tiles_batch > 0 then
                task.src_surface.set_tiles(set_tiles_batch, true, false)
            end
            return
        end

        if task.entity_index <= #task.entities then
            local processed = 0
            while processed < entity_budget and task.entity_index <= #task.entities do
                local entity = task.entities[task.entity_index]
                task.entity_index = task.entity_index + 1
                processed = processed + 1
                if entity and entity.valid then
                    local same_surface = task.src_surface and task.src_surface.valid and
                        entity.surface and entity.surface.valid and entity.surface.index == task.src_surface.index
                    if same_surface then
                        entity.destroy()
                    end
                end
            end
            return
        end

        table.remove(queue, 1)
    end

    local function free_previous_dock_port(ship)
        if ship.docked_port_unit_number and storage.docking_ports and storage.docking_ports[ship.docked_port_unit_number] then
            storage.docking_ports[ship.docked_port_unit_number].ship_docked = false
            game.print("Port freed: " ..
                ((storage.docking_ports[ship.docked_port_unit_number] and storage.docking_ports[ship.docked_port_unit_number].name) or
                    "unnamed") .. " is now available")
            ship.docked_port_unit_number = nil
        end
    end

    local function enqueue_clone_job(job)
        storage.clone_job_queue = storage.clone_job_queue or {}
        storage.clone_job_queue[#storage.clone_job_queue + 1] = job
    end

    local function queue_entities_for_restore_and_pause(entities, tick)
        if not entities or #entities == 0 then return end

        storage.entities_to_restore = storage.entities_to_restore or {}
        storage.entities_to_restore_lookup = storage.entities_to_restore_lookup or {}
        local restore_tick = (tick or game.tick) + 60
        storage.entities_to_restore_tick = math.max(storage.entities_to_restore_tick or 0, restore_tick)

        for _, entity in pairs(entities) do
            if entity and entity.valid then
                local unit_number = entity.unit_number
                if not unit_number or not storage.entities_to_restore_lookup[unit_number] then
                    storage.entities_to_restore[#storage.entities_to_restore + 1] = {
                        entity = entity,
                        active = entity.active
                    }
                    if unit_number then
                        storage.entities_to_restore_lookup[unit_number] = true
                    end
                end
                entity.active = false
            end
        end
    end

    local function restore_cockpit_occupants(character_data, dest_surface, offset)
        if not (character_data and dest_surface and dest_surface.valid and offset) then return end

        for _, data in pairs(character_data) do
            if data and data.character and data.character.valid and data.cockpit_vehicle_name and data.cockpit_vehicle_position then
                local cockpit = dest_surface.find_entity(data.cockpit_vehicle_name, {
                    x = data.cockpit_vehicle_position.x + offset.x,
                    y = data.cockpit_vehicle_position.y + offset.y
                })
                if cockpit and cockpit.valid then
                    local current_driver = cockpit.get_driver()
                    if not (current_driver and current_driver.valid) then
                        local ok, err = pcall(function()
                            cockpit.set_driver(data.character)
                        end)
                        if not ok and err then
                            -- ignore reseat errors during transitions
                        end
                    end
                end
            end
        end
    end

    local function eject_cockpit_occupants(character_data, src_surface)
        if not (character_data and src_surface and src_surface.valid) then return end

        for _, data in pairs(character_data) do
            if data and data.character and data.character.valid and data.cockpit_vehicle_name and data.cockpit_vehicle_position then
                local cockpit = src_surface.find_entity(data.cockpit_vehicle_name, data.cockpit_vehicle_position)
                local seated_in_this_cockpit = cockpit and cockpit.valid and
                    data.character.vehicle and data.character.vehicle.valid and data.character.vehicle == cockpit

                if seated_in_this_cockpit then
                    cockpit.set_driver(nil)
                end
            end
        end
    end

    local function pause_newly_cloned_condition_entities(dest_surface, source_positions, offset, tick)
        if not (dest_surface and dest_surface.valid and source_positions and offset) then return end

        local to_pause = {}
        for i = 1, #source_positions do
            local src_pos = source_positions[i]
            if src_pos then
                local x = src_pos.x + offset.x
                local y = src_pos.y + offset.y
                local found = dest_surface.find_entities_filtered {
                    type = CONDITION_ENTITY_TYPES,
                    area = {
                        { x = x - 0.51, y = y - 0.51 },
                        { x = x + 0.51, y = y + 0.51 }
                    }
                }
                for _, entity in pairs(found) do
                    to_pause[#to_pause + 1] = entity
                end
            end
        end

        queue_entities_for_restore_and_pause(to_pause, tick)
    end

    local function are_area_chunks_generated(surface, area)
        if not (surface and surface.valid and area and area.left_top and area.right_bottom) then
            return false
        end

        local min_chunk_x = math.floor(area.left_top.x / 32)
        local max_chunk_x = math.floor(area.right_bottom.x / 32)
        local min_chunk_y = math.floor(area.left_top.y / 32)
        local max_chunk_y = math.floor(area.right_bottom.y / 32)

        for cx = min_chunk_x, max_chunk_x do
            for cy = min_chunk_y, max_chunk_y do
                if not surface.is_chunk_generated({ x = cx, y = cy }) then
                    return false
                end
            end
        end

        return true
    end

    local function capture_ship_wire_snapshot(entities)
        local snapshot = {
            entities_by_unit = {},
            connector_edges = {},
        }

        local entity_set = {}
        for _, entity in pairs(entities or {}) do
            if entity and entity.valid and entity.unit_number then
                entity_set[entity.unit_number] = true
                snapshot.entities_by_unit[entity.unit_number] = {
                    name = entity.name,
                    position = { x = entity.position.x, y = entity.position.y }
                }
            end
        end

        local seen_connector_edge = {}

        for _, entity in pairs(entities or {}) do
            if entity and entity.valid and entity.unit_number then
                local from_unit = entity.unit_number

                local ok_connectors, connectors = pcall(function()
                    return entity.get_wire_connectors(false)
                end)
                if ok_connectors and connectors then
                    pcall(function()
                        for _, connector in pairs(connectors) do
                            if connector and connector.valid then
                                local from_connector_id = connector.wire_connector_id
                                local from_wire_type = connector.wire_type
                                for _, conn in pairs(connector.real_connections or {}) do
                                    local target = conn.target
                                    if target and target.valid and target.owner and target.owner.valid and target.owner.unit_number and entity_set[target.owner.unit_number] then
                                        local to_unit = target.owner.unit_number
                                        local to_connector_id = target.wire_connector_id
                                        local to_wire_type = target.wire_type
                                        local origin = conn.origin

                                        local left_key = tostring(from_unit) .. ":" .. tostring(from_connector_id) .. ":" .. tostring(from_wire_type)
                                        local right_key = tostring(to_unit) .. ":" .. tostring(to_connector_id) .. ":" .. tostring(to_wire_type)
                                        local edge_key
                                        local edge

                                        if left_key <= right_key then
                                            edge_key = left_key .. "|" .. right_key .. "|" .. tostring(origin)
                                            edge = {
                                                from_unit = from_unit,
                                                from_connector_id = from_connector_id,
                                                to_unit = to_unit,
                                                to_connector_id = to_connector_id,
                                                origin = origin,
                                            }
                                        else
                                            edge_key = right_key .. "|" .. left_key .. "|" .. tostring(origin)
                                            edge = {
                                                from_unit = to_unit,
                                                from_connector_id = to_connector_id,
                                                to_unit = from_unit,
                                                to_connector_id = from_connector_id,
                                                origin = origin,
                                            }
                                        end

                                        if not seen_connector_edge[edge_key] then
                                            seen_connector_edge[edge_key] = true
                                            snapshot.connector_edges[#snapshot.connector_edges + 1] = edge
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end

        return snapshot
    end

    local function wire_snapshot_debug_print(ship_name, mode, stats)
        if not ENABLE_WIRE_SNAPSHOT_DEBUG then return end
        if not stats then return end

        game.print(
            "Wire snapshot [" .. (mode or "unknown") .. "] " .. (ship_name or "?") ..
            " captured(circuits=" .. tostring(stats.captured_circuits or 0) .. ")" ..
            " mapped=" .. tostring(stats.mapped_entities or 0) .. "/" .. tostring(stats.total_entities or 0) ..
            " circuit(applied=" .. tostring(stats.applied_circuits or 0) .. ", missing=" .. tostring(stats.missing_circuits or 0) .. ", failed=" .. tostring(stats.failed_circuits or 0) .. ")"
        )

        if stats.sample_errors and #stats.sample_errors > 0 then
            for i = 1, #stats.sample_errors do
                game.print("Wire snapshot error sample [" .. (mode or "unknown") .. "] " .. tostring(stats.sample_errors[i]))
            end
        end
    end

    local function apply_ship_wire_snapshot(snapshot, dest_surface, offset)
        if not (snapshot and dest_surface and dest_surface.valid and offset) then return nil end

        local stats = {
            total_entities = 0,
            mapped_entities = 0,
            captured_circuits = #(snapshot.connector_edges or {}),
            applied_circuits = 0,
            missing_circuits = 0,
            failed_circuits = 0,
            sample_errors = {},
        }

        local mapped = {}
        local mapped_connectors = {}
        for unit_number, meta in pairs(snapshot.entities_by_unit or {}) do
            stats.total_entities = stats.total_entities + 1
            local expected = {
                x = meta.position.x + offset.x,
                y = meta.position.y + offset.y,
            }
            local ent = find_cloned_entity_near(dest_surface, meta.name, expected, 1.0)
            mapped[unit_number] = ent
            if ent and ent.valid then
                stats.mapped_entities = stats.mapped_entities + 1
                local ok_connectors, connectors = pcall(function()
                    return ent.get_wire_connectors(true)
                end)
                if ok_connectors and connectors then
                    mapped_connectors[unit_number] = connectors
                end
            end
        end

        local function try_connect_connectors(from_connector, to_connector, origin)
            local ok, result = pcall(function()
                return from_connector.connect_to(to_connector, false, origin)
            end)
            if ok and result then
                return true
            end

            ok, result = pcall(function()
                return from_connector.connect_to(to_connector, false)
            end)
            if ok and result then
                return true
            end

            ok, result = pcall(function()
                return from_connector.connect_to(to_connector)
            end)
            if ok and result then
                return true
            end

            return false, (ok and "connect_to returned false" or tostring(result))
        end

        for _, edge in pairs(snapshot.connector_edges or {}) do
            local from_entity = mapped[edge.from_unit]
            local to_entity = mapped[edge.to_unit]
            local from_connector = mapped_connectors[edge.from_unit] and mapped_connectors[edge.from_unit][edge.from_connector_id] or nil
            local to_connector = mapped_connectors[edge.to_unit] and mapped_connectors[edge.to_unit][edge.to_connector_id] or nil

            if from_entity and from_entity.valid and to_entity and to_entity.valid and
                from_connector and from_connector.valid and to_connector and to_connector.valid then
                local connected, err = try_connect_connectors(from_connector, to_connector, edge.origin)
                if connected then
                    stats.applied_circuits = stats.applied_circuits + 1
                else
                    stats.failed_circuits = stats.failed_circuits + 1
                    if #stats.sample_errors < 3 then
                        stats.sample_errors[#stats.sample_errors + 1] = err
                    end
                end
            else
                stats.missing_circuits = stats.missing_circuits + 1
            end
        end

        return stats
    end

    function SpaceShip.process_clone_job_queue()
        local queue = storage.clone_job_queue
        if not queue or #queue == 0 then return end

        local job = queue[1]
        if not job then
            table.remove(queue, 1)
            return
        end

        local ship = storage.spaceships and storage.spaceships[job.ship_id]
        if not ship then
            table.remove(queue, 1)
            return
        end

        if not (job.src_surface and job.src_surface.valid and job.dest_surface and job.dest_surface.valid) then
            ship.is_cloning = false
            ship.clone_job_active = nil
            table.remove(queue, 1)
            return
        end

        if job.phase == "wait_chunks" then
            if not are_area_chunks_generated(job.dest_surface, job.dest_area) then
                return
            end

            if job.change_tiles_dest and #job.change_tiles_dest > 0 then
                job.tile_index = job.tile_index or 1
                job.phase = "apply_tiles"
                return
            end

            job.phase = "clone_chunks"
            return
        end

        if job.phase == "apply_tiles" then
            if not job.change_tiles_dest or #job.change_tiles_dest == 0 then
                job.phase = "clone_chunks"
                return
            end

            local start_i = job.tile_index or 1
            if start_i > #job.change_tiles_dest then
                job.change_tiles_dest = nil
                job.tile_index = nil
                job.phase = "clone_chunks"
                return
            end

            local end_i = math.min(#job.change_tiles_dest, start_i + UNATTENDED_CLONE_BRUSH_CHUNK_SIZE - 1)
            local tiles_batch = {}
            for i = start_i, end_i do
                tiles_batch[#tiles_batch + 1] = job.change_tiles_dest[i]
            end

            if #tiles_batch > 0 then
                job.dest_surface.set_tiles(tiles_batch, true)
            end

            job.tile_index = end_i + 1
            if job.tile_index > #job.change_tiles_dest then
                job.change_tiles_dest = nil
                job.tile_index = nil
                job.phase = "clone_chunks"
            end
            return
        end

        if job.phase == "clone_chunks" then
            local start_i = job.clone_index
            local end_i = math.min(#job.entity_clone_positions, start_i + UNATTENDED_CLONE_BRUSH_CHUNK_SIZE - 1)
            if start_i > #job.entity_clone_positions then
                job.phase = "finalize"
            else
                local source_positions = {}
                for i = start_i, end_i do
                    local pos = job.entity_clone_positions[i]
                    if pos then
                        local hub_at_pos = job.src_surface.find_entities_filtered({
                            name = "spaceship-control-hub",
                            position = pos
                        })
                        if not (hub_at_pos and hub_at_pos[1] and hub_at_pos[1].valid) then
                            source_positions[#source_positions + 1] = pos
                        end
                    end
                end

                if #source_positions > 0 then
                    job.src_surface.clone_brush {
                        source_offset = { 0, 0 },
                        destination_offset = { job.offset.x, job.offset.y },
                        destination_surface = job.dest_surface,
                        clone_tiles = false,
                        clone_entities = true,
                        clone_decoratives = false,
                        clear_destination_entities = false,
                        clear_destination_decoratives = false,
                        expand_map = true,
                        source_positions = source_positions
                    }

                    pause_newly_cloned_condition_entities(job.dest_surface, source_positions, job.offset, game.tick)
                end

                job.clone_index = end_i + 1
                if job.clone_index > #job.entity_clone_positions then
                    job.phase = "finalize"
                end
            end
            return
        end

        if job.phase == "finalize" then
            eject_cockpit_occupants(job.character_data, job.src_surface)

            for _, vehicle in pairs(job.vehicles or {}) do
                if vehicle and vehicle.valid and not (job.excluded_types and job.excluded_types[vehicle.type]) then
                    local vehicle_tile = job.src_surface.get_tile(vehicle.position)
                    local vehicle_on_ship_floor = vehicle_tile and vehicle_tile.valid and
                        job.ship_floor_lookup[vehicle_tile.position.x] and
                        job.ship_floor_lookup[vehicle_tile.position.x][vehicle_tile.position.y]
                    if vehicle_on_ship_floor then
                        vehicle.teleport({ x = vehicle.position.x + job.offset.x, y = vehicle.position.y + job.offset.y },
                            job.dest_surface)
                    end
                end
            end

            for _, data in pairs(job.character_data or {}) do
                if data.character and data.character.valid then
                    data.character.teleport(
                        { x = data.original_position.x + job.offset.x, y = data.original_position.y + job.offset.y },
                        job.dest_surface)
                end
            end
            restore_cockpit_occupants(job.character_data, job.dest_surface, job.offset)

            local condition_entities = job.dest_surface.find_entities_filtered {
                type = CONDITION_ENTITY_TYPES,
                area = job.dest_area
            }
            queue_entities_for_restore_and_pause(condition_entities, game.tick)

            local cleanup_entities = {}
            for _, entity in pairs(ship.entities or {}) do
                cleanup_entities[#cleanup_entities + 1] = entity
            end
            enqueue_clone_cleanup(job.src_surface, job.floor_positions, cleanup_entities)

            for _, driver_data in pairs(job.rail_vehicle_drivers or {}) do
                local vehicle = job.dest_surface.find_entity(driver_data.vehicle_name,
                    { x = driver_data.vehicle_position.x + job.offset.x, y = driver_data.vehicle_position.y + job.offset.y })
                local driver = job.dest_surface.find_entity(driver_data.driver_name,
                    { x = driver_data.driver_position.x + job.offset.x, y = driver_data.driver_position.y + job.offset.y })
                if vehicle and driver then
                    vehicle.set_driver(driver)
                end
            end

            for _, locomotive_data in pairs(job.train_settings or {}) do
                local locomotive = job.dest_surface.find_entity(locomotive_data.name,
                    { x = locomotive_data.position.x + job.offset.x, y = locomotive_data.position.y + job.offset.y })
                if locomotive and locomotive.train then
                    locomotive.train.schedule = locomotive_data.schedule
                    locomotive.train.manual_mode = locomotive_data.manual_mode
                end
            end

            if ship.hub and ship.hub.valid then
                local expected_hub_pos = { x = ship.hub.position.x + job.offset.x, y = ship.hub.position.y + job.offset.y }
                local new_hub = find_cloned_entity_near(job.dest_surface, "spaceship-control-hub", expected_hub_pos, 3)
                if not new_hub then
                    local hubs = job.dest_surface.find_entities_filtered({ name = "spaceship-control-hub", area = job.dest_area })
                    if hubs and hubs[1] and hubs[1].valid then
                        new_hub = hubs[1]
                    end
                end
                if not new_hub then
                    local hubs_anywhere = job.dest_surface.find_entities_filtered({ name = "spaceship-control-hub" })
                    if hubs_anywhere and hubs_anywhere[1] and hubs_anywhere[1].valid then
                        new_hub = hubs_anywhere[1]
                    end
                end
                if not new_hub then
                    game.print("Warning: Deferred clone finalization waiting for destination hub on ship " .. ship.name)
                    return
                end
                ship.hub = new_hub
                local tags = ship.hub.tags or {}
                tags.id = ship.id
                ship.hub.tags = tags
            end

            local wire_stats = apply_ship_wire_snapshot(job.wire_snapshot, job.dest_surface, job.offset)
            wire_snapshot_debug_print(ship.name, "deferred", wire_stats)

            ship.is_cloning = false
            ship.clone_job_active = nil
            ship.surface_lock_timeout = game.tick + 60

            ship.own_surface = true
            ship.planet_orbiting = job.OG_surface
            ship.surface = job.dest_surface
            ship.traveling = true
            ship.docked = false
            free_previous_dock_port(ship)

            local platform = ship.hub and ship.hub.valid and ship.hub.surface and ship.hub.surface.platform or nil
            if platform then
                platform.schedule = ship.schedule
                platform.paused = false
                local schedule = ship.schedule
                local current_station = schedule and schedule.records and schedule.records[schedule.current] or nil
                if current_station then
                    game.print("Ship " .. ship.name .. " departing to " .. current_station.station)
                end
            end

            SpaceShip.start_scan_ship(ship)
            SpaceShip.connect_adjacent_ports()

            table.remove(queue, 1)
        end
    end

    local function start_staged_departure_clone_job(ship, dest_surface, dest_center, excluded_types, OG_surface)
        local tick = game.tick
        local queue_len_before = #(storage.clone_job_queue or {})
        local src_surface
        if ship.surface and ship.surface.platform and ship.surface.platform.surface then
            src_surface = ship.surface.platform.surface
        else
            src_surface = ship.surface
        end

        if not src_surface or not src_surface.valid then
            game.print("Error: Source surface is invalid for cloning.")
            return false
        end

        local reference_tile = ship.reference_tile
        if not reference_tile then
            game.print("Error: Reference tile is missing from ship data. Ship may need to be rescanned.")
            return false
        end

        local floor_positions = ship.floor_positions
        if not floor_positions or #floor_positions == 0 then
            floor_positions = {}
            local idx = 0
            for _, tile in pairs(ship.floor or {}) do
                idx = idx + 1
                floor_positions[idx] = tile
            end
            ship.floor_positions = floor_positions
        end
        if #floor_positions == 0 then
            game.print("Error: Ship floor data is missing. Ship may need to be rescanned.")
            return false
        end

        local wire_snapshot = capture_ship_wire_snapshot(ship.entities or {})

        local bounds = ship.bounds
        if not bounds then
            local min_x, max_x = math.huge, -math.huge
            local min_y, max_y = math.huge, -math.huge
            for i = 1, #floor_positions do
                local p = floor_positions[i].position
                if p.x < min_x then min_x = p.x end
                if p.x > max_x then max_x = p.x end
                if p.y < min_y then min_y = p.y end
                if p.y > max_y then max_y = p.y end
            end
            bounds = { left_top = { x = min_x, y = min_y }, right_bottom = { x = max_x, y = max_y } }
            ship.bounds = bounds
        end

        local offset = {
            x = math.ceil(dest_center.x - reference_tile.position.x),
            y = math.ceil(dest_center.y - reference_tile.position.y)
        }

        local ship_area = {
            left_top = { x = bounds.left_top.x, y = bounds.left_top.y },
            right_bottom = { x = bounds.right_bottom.x, y = bounds.right_bottom.y }
        }
        local dest_area = {
            left_top = { x = bounds.left_top.x + offset.x, y = bounds.left_top.y + offset.y },
            right_bottom = { x = bounds.right_bottom.x + offset.x, y = bounds.right_bottom.y + offset.y }
        }

        ship.is_cloning = true
        ship.clone_job_active = true

        dest_surface.request_to_generate_chunks(dest_center,
            math.ceil(math.max(bounds.right_bottom.x - bounds.left_top.x, bounds.right_bottom.y - bounds.left_top.y) / 32) + 2)

        local change_tiles_dest = {}
        local ship_floor_lookup = {}

        for i = 1, #floor_positions do
            local tile = floor_positions[i]
            change_tiles_dest[i] = {
                name = "spaceship-flooring",
                position = { x = tile.position.x + offset.x, y = tile.position.y + offset.y }
            }
            local row = ship_floor_lookup[tile.position.x]
            if not row then
                row = {}
                ship_floor_lookup[tile.position.x] = row
            end
            row[tile.position.y] = true
        end

        local vehicles = src_surface.find_entities_filtered {
            type = { "car", "spider-vehicle" },
            area = ship_area
        }
        local rail_vehicles = src_surface.find_entities_filtered {
            type = { "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" },
            area = ship_area
        }
        local rail_vehicle_drivers = {}
        local train_settings = {}

        for _, locomotive in pairs(src_surface.find_entities_filtered { type = "locomotive", area = ship_area }) do
            local train = locomotive.train
            if train and not train_settings[train.id] then
                train_settings[train.id] = {
                    schedule = train.schedule,
                    manual_mode = train.manual_mode,
                    name = locomotive.name,
                    position = locomotive.position
                }
            end
        end

        for _, vehicle in pairs(rail_vehicles) do
            local driver = vehicle.get_driver()
            vehicle.set_driver(nil)
            if driver and driver.is_player() then
                driver = driver.character
            end
            if driver and driver.valid then
                rail_vehicle_drivers[#rail_vehicle_drivers + 1] = {
                    vehicle_name = vehicle.name,
                    vehicle_position = vehicle.position,
                    driver_name = driver.name,
                    driver_position = driver.position
                }
            end
        end

        local character_data = {}
        local cockpit_cars = src_surface.find_entities_filtered {
            name = "spaceship-control-hub-car",
            area = ship_area
        }
        for _, vehicle in pairs(cockpit_cars) do
            if vehicle and vehicle.valid then
                local car_tile = src_surface.get_tile(vehicle.position)
                local cockpit_on_ship_floor = car_tile and car_tile.valid and
                    ship_floor_lookup[car_tile.position.x] and
                    ship_floor_lookup[car_tile.position.x][car_tile.position.y]
                if cockpit_on_ship_floor then
                    local character = vehicle.get_driver()
                    if character and character.valid and character.is_player and character.is_player() then
                        character = character.character
                    end
                    if character and character.valid then
                    character_data[#character_data + 1] = {
                        character = character,
                        ship_name = ship.name,
                        original_position = { x = character.position.x, y = character.position.y },
                        cockpit_vehicle_name = vehicle.name,
                        cockpit_vehicle_position = { x = vehicle.position.x, y = vehicle.position.y }
                    }
                    end
                end
            end
        end

        local entity_clone_positions = {}
        local entity_clone_position_seen = {}
        for _, entity in pairs(ship.entities or {}) do
            if entity and entity.valid then
                local excluded = excluded_types and (excluded_types[entity.type] or excluded_types[entity.name])
                if not excluded then
                    local key = entity.position.x .. "," .. entity.position.y
                    if not entity_clone_position_seen[key] then
                        entity_clone_position_seen[key] = true
                        entity_clone_positions[#entity_clone_positions + 1] = {
                            x = entity.position.x,
                            y = entity.position.y
                        }
                    end
                end
            end
        end

        enqueue_clone_job({
            ship_id = ship.id,
            src_surface = src_surface,
            dest_surface = dest_surface,
            offset = offset,
            entity_clone_positions = entity_clone_positions,
            clone_index = 1,
            floor_positions = floor_positions,
            ship_floor_lookup = ship_floor_lookup,
            vehicles = vehicles,
            rail_vehicle_drivers = rail_vehicle_drivers,
            train_settings = train_settings,
            character_data = character_data,
            excluded_types = excluded_types,
            dest_area = dest_area,
            change_tiles_dest = change_tiles_dest,
            wire_snapshot = wire_snapshot,
            phase = "wait_chunks",
            created_tick = tick,
            OG_surface = OG_surface,
        })

        return true
    end

    function SpaceShip.clone_ship_area_instant(ship, dest_surface, dest_center, excluded_types)
        local tick = game.tick
        local attended = SpaceShip.is_player_attending_ship(ship)
        local src_surface
        if ship.surface and ship.surface.platform and ship.surface.platform.surface then
            src_surface = ship.surface.platform.surface
        else
            src_surface = ship.surface
        end
        if not src_surface or not src_surface.valid then
            game.print("Error: Source surface is invalid for cloning.")
            return false
        end
        local reference_tile = ship.reference_tile
        if not reference_tile then
            game.print("Error: Reference tile is missing from ship data. Ship may need to be rescanned.")
            return false
        end

        if not ship.floor or table_size(ship.floor) == 0 then
            game.print("Error: Ship floor data is missing. Ship may need to be rescanned.")
            return false
        end

        local wire_snapshot = capture_ship_wire_snapshot(ship.entities or {})

        local floor_positions = ship.floor_positions
        if not floor_positions or #floor_positions == 0 then
            floor_positions = {}
            local floor_index = 0
            for _, tile in pairs(ship.floor) do
                floor_index = floor_index + 1
                floor_positions[floor_index] = tile
            end
            ship.floor_positions = floor_positions
        end

        local bounds = ship.bounds
        if not bounds then
            local min_x, max_x = math.huge, -math.huge
            local min_y, max_y = math.huge, -math.huge
            for i = 1, #floor_positions do
                local tile = floor_positions[i]
                local x = tile.position.x
                local y = tile.position.y
                if x < min_x then min_x = x end
                if x > max_x then max_x = x end
                if y < min_y then min_y = y end
                if y > max_y then max_y = y end
            end
            bounds = {
                left_top = { x = min_x, y = min_y },
                right_bottom = { x = max_x, y = max_y }
            }
            ship.bounds = bounds
        end

        local offset = {
            x = math.ceil(dest_center.x - reference_tile.position.x),
            y = math.ceil(dest_center.y - reference_tile.position.y)
        }

        local min_x = bounds.left_top.x
        local max_x = bounds.right_bottom.x
        local min_y = bounds.left_top.y
        local max_y = bounds.right_bottom.y

        local ship_area = {
            left_top = { x = min_x, y = min_y },
            right_bottom = { x = max_x, y = max_y }
        }

        local dest_area = {
            left_top = { x = min_x + offset.x, y = min_y + offset.y },
            right_bottom = { x = max_x + offset.x, y = max_y + offset.y }
        }

        ship.is_cloning = true

        dest_surface.request_to_generate_chunks(dest_center, math.ceil(math.max(max_x - min_x, max_y - min_y) / 32) + 2)
        dest_surface.force_generate_chunk_requests()

        local change_tiles_dest = {}
        local ship_floor_lookup = {}
        local tile_count = #floor_positions
        for i = 1, tile_count do
            local tile = floor_positions[i]
            change_tiles_dest[i] = {
                name = "spaceship-flooring",
                position = { x = tile.position.x + offset.x, y = tile.position.y + offset.y }
            }

            local row = ship_floor_lookup[tile.position.x]
            if not row then
                row = {}
                ship_floor_lookup[tile.position.x] = row
            end
            row[tile.position.y] = true
        end
        dest_surface.set_tiles(change_tiles_dest, true)

        local clone_positions = {}
        local clone_position_seen = {}
        local function add_clone_position(x, y)
            local key = x .. "," .. y
            if clone_position_seen[key] then return end
            clone_position_seen[key] = true
            clone_positions[#clone_positions + 1] = { x = x, y = y }
        end

        for _, entity in pairs(ship.entities or {}) do
            if entity and entity.valid then
                add_clone_position(entity.position.x, entity.position.y)
            end
        end

        if ship.hub and ship.hub.valid then
            add_clone_position(ship.hub.position.x, ship.hub.position.y)
        end
        if ship.docking_port and ship.docking_port.valid then
            add_clone_position(ship.docking_port.position.x, ship.docking_port.position.y)
        end

        local vehicles = src_surface.find_entities_filtered {
            type = { "car", "spider-vehicle" },
            area = ship_area
        }
        local rail_vehicles = src_surface.find_entities_filtered {
            type = { "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" },
            area = ship_area
        }
        local rail_vehicle_drivers = {}
        local train_settings = {}

        for _, locomotive in pairs(src_surface.find_entities_filtered { type = "locomotive", area = ship_area }) do
            local train = locomotive.train
            if train and not train_settings[train.id] then
                train_settings[train.id] = {
                    schedule = train.schedule,
                    manual_mode = train.manual_mode,
                    name = locomotive.name,
                    position = locomotive.position
                }
            end
        end

        for _, vehicle in pairs(rail_vehicles) do
            local driver = vehicle.get_driver()
            vehicle.set_driver(nil)
            if driver and driver.is_player() then
                driver = driver.character
            end
            if driver and driver.valid then
                table.insert(rail_vehicle_drivers, {
                    vehicle_name = vehicle.name,
                    vehicle_position = vehicle.position,
                    driver_name = driver.name,
                    driver_position = driver.position
                })
            end
        end

        local character_data = {}
        local cockpit_cars = src_surface.find_entities_filtered {
            name = "spaceship-control-hub-car",
            area = ship_area
        }
        for _, vehicle in pairs(cockpit_cars) do
            if vehicle and vehicle.valid then
                local car_tile = src_surface.get_tile(vehicle.position)
                local cockpit_on_ship_floor = car_tile and car_tile.valid and
                    ship_floor_lookup[car_tile.position.x] and
                    ship_floor_lookup[car_tile.position.x][car_tile.position.y]
                if cockpit_on_ship_floor then
                    local character = vehicle.get_driver()
                    if character and character.valid and character.is_player and character.is_player() then
                        character = character.character
                    end
                    if character and character.valid then
                    table.insert(character_data, {
                        character = character,
                        ship_name = ship.name,
                        original_position = { x = character.position.x, y = character.position.y },
                        cockpit_vehicle_name = vehicle.name,
                        cockpit_vehicle_position = { x = vehicle.position.x, y = vehicle.position.y }
                    })
                    end
                end
            end
        end

        src_surface.clone_brush {
            source_offset = { 0, 0 },
            destination_offset = { offset.x, offset.y },
            destination_surface = dest_surface,
            clone_tiles = false,
            clone_entities = true,
            clone_decoratives = false,
            clear_destination_entities = false,
            clear_destination_decoratives = false,
            expand_map = true,
            source_positions = clone_positions
        }

        eject_cockpit_occupants(character_data, src_surface)

        for _, vehicle in pairs(vehicles) do
            if vehicle.valid and not excluded_types[vehicle.type] then
                local vehicle_tile = src_surface.get_tile(vehicle.position)
                local vehicle_on_ship_floor = vehicle_tile and vehicle_tile.valid and
                    ship_floor_lookup[vehicle_tile.position.x] and
                    ship_floor_lookup[vehicle_tile.position.x][vehicle_tile.position.y]
                if vehicle_on_ship_floor then
                    local new_pos = { x = vehicle.position.x + offset.x, y = vehicle.position.y + offset.y }
                    vehicle.teleport(new_pos, dest_surface)
                end
            end
        end

        for _, data in pairs(character_data) do
            if data.character.valid then
                local new_pos = { x = data.original_position.x + offset.x, y = data.original_position.y + offset.y }
                data.character.teleport(new_pos, dest_surface)
            end
        end
        restore_cockpit_occupants(character_data, dest_surface, offset)

        local condition_entities = dest_surface.find_entities_filtered {
            type = CONDITION_ENTITY_TYPES,
            area = dest_area
        }
        queue_entities_for_restore_and_pause(condition_entities, tick)

        local cleanup_entities = {}
        for _, entity in pairs(ship.entities or {}) do
            cleanup_entities[#cleanup_entities + 1] = entity
        end
        enqueue_clone_cleanup(src_surface, floor_positions, cleanup_entities)

        for _, driver_data in pairs(rail_vehicle_drivers) do
            local vehicle = dest_surface.find_entity(driver_data.vehicle_name,
                { x = driver_data.vehicle_position.x + offset.x, y = driver_data.vehicle_position.y + offset.y })
            local driver = dest_surface.find_entity(driver_data.driver_name,
                { x = driver_data.driver_position.x + offset.x, y = driver_data.driver_position.y + offset.y })
            if vehicle and driver then
                vehicle.set_driver(driver)
            end
        end

        for _, locomotive_data in pairs(train_settings) do
            local locomotive = dest_surface.find_entity(locomotive_data.name,
                { x = locomotive_data.position.x + offset.x, y = locomotive_data.position.y + offset.y })
            if locomotive and locomotive.train then
                locomotive.train.schedule = locomotive_data.schedule
                locomotive.train.manual_mode = locomotive_data.manual_mode
            end
        end

        if ship.hub then
            local expected_hub_pos = { x = ship.hub.position.x + offset.x, y = ship.hub.position.y + offset.y }
            local new_hub = find_cloned_entity_near(dest_surface, "spaceship-control-hub", expected_hub_pos, 3)
            if new_hub then
                ship.hub = new_hub
                local tags = ship.hub.tags or {}
                tags.id = ship.id
                ship.hub.tags = tags
            end
        end

        local wire_stats = apply_ship_wire_snapshot(wire_snapshot, dest_surface, offset)
        wire_snapshot_debug_print(ship.name, "immediate", wire_stats)

        ship.is_cloning = false
        ship.surface_lock_timeout = tick + 60

        if attended and ship.player and ship.player.valid then
            ship.player.force.chart(dest_surface, {
                left_top = { x = dest_area.left_top.x - 32, y = dest_area.left_top.y - 32 },
                right_bottom = { x = dest_area.right_bottom.x + 32, y = dest_area.right_bottom.y + 32 }
            })
        end

        SpaceShip.start_scan_ship(ship)
        SpaceShip.connect_adjacent_ports()
        return true
    end

    function SpaceShip.clone_ship_area_staged(ship, dest_surface, dest_center, excluded_types, OG_surface)
        return start_staged_departure_clone_job(ship, dest_surface, dest_center, excluded_types, OG_surface)
    end

    function SpaceShip.clone_ship_to_space_platform(ship)
        if not ship or not ship.player or not ship.player.valid then
            ship.game.print("Error: Invalid player.")
            return
        end

        if ship.clone_job_active or ship.is_cloning then
            return "deferred"
        end

        if storage.scan_state then
            game.print("Error: Scan is in progress, please wait.")
            return
        end

        if not ship.scanned or not ship.reference_tile or not ship.floor or table_size(ship.floor) == 0 then
            game.print("Error: No scanned ship data found. Running a rescan now.")
            SpaceShip.start_scan_ship(ship, 60, 1)
            return
        end

        local space_platform_temp
        for _, surface in pairs(ship.player.force.platforms) do
            space_platform_temp = surface
            break
        end

        local space_platform = ship.player.force.create_space_platform({
            name = ship.name .. "-ship",
            map_gen_settings = space_platform_temp.surface.map_gen_settings,
            planet = ship.planet_orbiting,
            starter_pack = "space-ship-starter-pack",
        })
        space_platform.apply_starter_pack()

        local dest_center = { x = 0, y = 0 }

        local excluded_types = {
            ["logistic-robot"] = true,
            ["construction-robot"] = true,
            ["spaceship-control-hub"] = true,
        }
        local OG_surface
        if ship.surface.platform then
            OG_surface = ship.surface.platform.space_location.name
        else
            OG_surface = ship.surface.name
        end

        local started = SpaceShip.clone_ship_area_staged(
            ship,
            space_platform.surface,
            dest_center,
            excluded_types,
            OG_surface)
        if started then
            return "deferred"
        end

        game.print("Error: Failed to start deferred clone job.")
        if space_platform and space_platform.valid then
            space_platform.destroy(1)
        end
    end
end
