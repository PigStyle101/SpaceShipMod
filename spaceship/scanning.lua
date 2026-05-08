return function(SpaceShip)
    local function is_player_attending_scan(player, ship, state)
        if not (player and player.valid and state and state.surface and state.surface.valid) then
            return false
        end

        if player.gui and player.gui.relative and player.gui.relative["schedule-container"] then
            return true
        end

        if ship and ship.player_in_cockpit and ship.player_in_cockpit.valid and ship.player_in_cockpit.index == player.index then
            return true
        end

        local vehicle = player.vehicle
        if vehicle and vehicle.valid and vehicle.name == "spaceship-control-hub-car" and vehicle.surface == state.surface then
            return true
        end

        if player.surface ~= state.surface then
            return false
        end

        local player_tile = state.surface.get_tile(player.position)
        if player_tile and player_tile.valid and player_tile.name == "spaceship-flooring" then
            return true
        end

        local bounds = state.bounds
        local p = player.position
        if bounds then
            local margin = 20
            if p.x >= (bounds.left_top.x - margin) and p.x <= (bounds.right_bottom.x + margin) and
                p.y >= (bounds.left_top.y - margin) and p.y <= (bounds.right_bottom.y + margin) then
                return true
            end
        elseif ship and ship.hub and ship.hub.valid then
            local dx = p.x - ship.hub.position.x
            local dy = p.y - ship.hub.position.y
            if (dx * dx + dy * dy) <= (80 * 80) then
                return true
            end
        end

        return false
    end

    local function get_scan_runtime_profile(state, ship)
        local base_budget = tonumber(state and state.scan_per_tick) or 30
        if base_budget < 1 then base_budget = 1 end

        local attending = is_player_attending_scan(state and state.player, ship, state)
        if attending then
            return 1, math.max(base_budget, math.floor(base_budget * 2))
        end

        local waiting_priority = (state and state.priority_waiting_condition) or
            (ship and (ship.waiting_for_open_dock or ship.waiting_for_clear_dock_area or ship.leave_immediately))
        if waiting_priority then
            -- Roughly half the attentive throughput.
            return 1, math.max(base_budget, math.floor(base_budget))
        end

        -- Background profile: target ~10/tick for base_budget=60.
        return 1, math.max(10, math.floor(base_budget / 6))
    end

    local function ensure_scan_queue()
        storage.scan_queue = storage.scan_queue or {}
    end

    local function remove_scan_request(ship_id)
        ensure_scan_queue()
        for i = #storage.scan_queue, 1, -1 do
            if storage.scan_queue[i].ship_id == ship_id then
                table.remove(storage.scan_queue, i)
            end
        end
    end

    local function enqueue_scan_request(ship, scan_per_tick, tick_amount, priority_waiting_condition)
        ensure_scan_queue()
        for _, request in ipairs(storage.scan_queue) do
            if request.ship_id == ship.id then
                if priority_waiting_condition then
                    request.priority_waiting_condition = true
                end
                return false
            end
        end
        table.insert(storage.scan_queue, {
            ship_id = ship.id,
            scan_per_tick = scan_per_tick,
            tick_amount = tick_amount,
            priority_waiting_condition = priority_waiting_condition == true,
        })
        return true
    end

    local function start_next_queued_scan()
        if storage.scan_state then return end
        ensure_scan_queue()

        while #storage.scan_queue > 0 do
            local request = table.remove(storage.scan_queue, 1)
            local next_ship = storage.spaceships and storage.spaceships[request.ship_id]

            if next_ship and next_ship.hub and next_ship.hub.valid then
                SpaceShip.start_scan_ship(next_ship, request.scan_per_tick, request.tick_amount,
                    request.priority_waiting_condition)
                return
            end
        end
    end

    function SpaceShip.start_scan_ship(ship, scan_per_tick, tick_amount, priority_waiting_condition)
        if not ship or not ship.hub or not ship.hub.valid then
            game.print("Error: Cannot start scan; ship or hub is invalid.")
            return
        end

        local player = ship.player
        local preexisting_waiting_state = (ship.waiting_for_open_dock == true) or
            (ship.waiting_for_clear_dock_area == true) or
            (ship.leave_immediately == true)
        local waiting_priority = (priority_waiting_condition == true) or preexisting_waiting_state
        if storage.scan_state then
            if storage.scan_state.ship_id == ship.id then
                if waiting_priority then
                    storage.scan_state.priority_waiting_condition = true
                    storage.scan_state.next_run_tick = game.tick
                end
                return
            end

            local queued = enqueue_scan_request(ship, scan_per_tick, tick_amount, waiting_priority)
            ship.waiting_for_scan = true
            return
        end

        remove_scan_request(ship.id)

        local surface = ship.hub.surface
        local start_pos = ship.hub.position
        local tiles_to_check = { start_pos }
        local scanned_tiles = {}
        local flooring_tiles = {}
        local flooring_lookup = {}
        local entities_on_flooring = {}
        local reference_tile = nil -- Initialize reference_tile
        local scan_radius = 200    -- Limit to prevent excessive scans

        local count = table_size(storage.spaceships) + 1
        if not ship then
            ship = SpaceShip.new("Explorer" .. count, count, player)
        end

        -- Preserve important ship data during scan
        local preserved_port_records = ship.port_records

        ship.floor = nil
        ship.floor_positions = nil
        ship.bounds = nil
        ship.entities = nil
        ship.reference_tile = nil
        ship.surface = nil
        ship.scanned = false
        ship.waiting_for_scan = true

        storage.scan_state = {
            player = player,
            ship_id = ship.id,
            surface = surface,
            tiles_to_check = tiles_to_check,
            scanned_tiles = scanned_tiles,
            flooring_tiles = flooring_tiles,
            flooring_lookup = flooring_lookup,
            entities_on_flooring = entities_on_flooring,
            reference_tile = reference_tile,
            docking_port = nil,
            phase = "tiles",
            total_floor_tiles = nil,
            total_entities = nil,
            bounds = nil,
            pending_entities = nil,
            pending_entities_index = 1,
            scan_radius = scan_radius,
            start_pos = start_pos,
            scan_per_tick = scan_per_tick or 30,            -- how many tiles to scan per tick
            tick_counter = 0,                               -- Counter to track ticks for progress updates
            tick_amount = tick_amount or 1,                 --how ofter to keep scanning, higher=slower
            next_run_tick = game.tick,
            priority_waiting_condition = waiting_priority,
            preserved_port_records = preserved_port_records -- Preserve port_records during scan
        }
    end

    function SpaceShip.continue_scan_ship()
        local state = storage.scan_state
        if not state then return end

        local ship = storage.spaceships and storage.spaceships[state.ship_id]
        if not ship then
            storage.scan_state = nil
            start_next_queued_scan()
            return
        end

        if (ship.waiting_for_open_dock or ship.waiting_for_clear_dock_area or ship.leave_immediately) and
            not state.priority_waiting_condition then
            state.priority_waiting_condition = true
            state.next_run_tick = game.tick
        end

        local interval_ticks, run_budget = get_scan_runtime_profile(state, ship)
        state.next_run_tick = state.next_run_tick or game.tick
        if game.tick < state.next_run_tick then
            return
        end
        state.next_run_tick = game.tick + interval_ticks

        local function finalize_scan()
            ship.floor = state.flooring_tiles

            local floor_positions = {}
            local min_x, max_x = math.huge, -math.huge
            local min_y, max_y = math.huge, -math.huge
            local floor_count = 0
            for _, tile in pairs(state.flooring_tiles) do
                floor_count = floor_count + 1
                floor_positions[floor_count] = tile
                local x = tile.position.x
                local y = tile.position.y
                if x < min_x then min_x = x end
                if x > max_x then max_x = x end
                if y < min_y then min_y = y end
                if y > max_y then max_y = y end
            end

            ship.floor_positions = floor_positions
            ship.bounds = floor_count > 0 and {
                left_top = { x = min_x, y = min_y },
                right_bottom = { x = max_x, y = max_y }
            } or nil
            ship.entities = state.entities_on_flooring
            ship.reference_tile = state.reference_tile
            ship.surface = state.surface
            ship.scanned = floor_count > 0
            ship.waiting_for_scan = false

            if state.preserved_port_records then
                ship.port_records = state.preserved_port_records
            end

            if state.surface and state.surface.valid and state.surface.platform and state.surface.platform.space_location then
                ship.planet_orbiting = state.surface.platform.space_location.name
            else
                ship.planet_orbiting = "none"
            end

            storage.scan_highlight_expire_tick = game.tick + 60

            if state.docking_port then
                ship.docking_port = state.docking_port
            else
                game.print("No docking port found on the ship.")
            end

            storage.scan_state = nil
            start_next_queued_scan()
        end

        if state.phase == "tiles" then
            local processed_tiles = 0
            while processed_tiles < run_budget and #state.tiles_to_check > 0 do
                local current_pos = table.remove(state.tiles_to_check)
                local tile_key = current_pos.x .. "," .. current_pos.y

                if not state.scanned_tiles[tile_key] then
                    state.scanned_tiles[tile_key] = true

                    local tile = state.surface.get_tile(current_pos.x, current_pos.y)
                    if tile and tile.valid and tile.name == "spaceship-flooring" then
                        state.flooring_tiles[tile_key] = {
                            name = tile.name,
                            position = { x = current_pos.x, y = current_pos.y }
                        }

                        local row = state.flooring_lookup[current_pos.x]
                        if not row then
                            row = {}
                            state.flooring_lookup[current_pos.x] = row
                        end
                        row[current_pos.y] = true

                        if not state.reference_tile then
                            state.reference_tile = state.flooring_tiles[tile_key]
                        end

                        if not state.bounds then
                            state.bounds = {
                                left_top = { x = current_pos.x, y = current_pos.y },
                                right_bottom = { x = current_pos.x, y = current_pos.y }
                            }
                        else
                            if current_pos.x < state.bounds.left_top.x then state.bounds.left_top.x = current_pos.x end
                            if current_pos.x > state.bounds.right_bottom.x then state.bounds.right_bottom.x = current_pos.x end
                            if current_pos.y < state.bounds.left_top.y then state.bounds.left_top.y = current_pos.y end
                            if current_pos.y > state.bounds.right_bottom.y then state.bounds.right_bottom.y = current_pos.y end
                        end

                        if #state.tiles_to_check == 0 then
                            state.tiles_to_check = state.surface.get_connected_tiles(
                                { x = current_pos.x, y = current_pos.y },
                                { "spaceship-flooring" }
                            )
                            state.total_floor_tiles = #state.tiles_to_check
                        end
                    end
                end

                processed_tiles = processed_tiles + 1
            end

            if #state.tiles_to_check == 0 then
                if not state.bounds then
                    ship.floor = {}
                    ship.floor_positions = {}
                    ship.bounds = nil
                    ship.entities = {}
                    ship.reference_tile = nil
                    ship.surface = state.surface
                    ship.scanned = false
                    ship.waiting_for_scan = false
                    if state.preserved_port_records then
                        ship.port_records = state.preserved_port_records
                    end
                    storage.scan_state = nil
                    start_next_queued_scan()
                    return
                end

                state.pending_entities = state.surface.find_entities_filtered {
                    area = {
                        { x = state.bounds.left_top.x - 0.5, y = state.bounds.left_top.y - 0.5 },
                        { x = state.bounds.right_bottom.x + 0.5, y = state.bounds.right_bottom.y + 0.5 }
                    }
                }
                state.total_entities = #state.pending_entities
                state.pending_entities_index = 1
                state.phase = "entities"
            end
        end

        if state.phase == "entities" then
            local processed_entities = 0
            while processed_entities < run_budget and
                state.pending_entities and
                state.pending_entities_index <= #state.pending_entities do
                local entity = state.pending_entities[state.pending_entities_index]
                state.pending_entities_index = state.pending_entities_index + 1
                processed_entities = processed_entities + 1

                if entity and entity.valid and entity.name ~= "spaceship-flooring" and
                    entity.type ~= "resource" and entity.type ~= "character" then
                    local tx = math.floor(entity.position.x)
                    local ty = math.floor(entity.position.y)
                    local row = state.flooring_lookup[tx]
                    if row and row[ty] then
                        state.entities_on_flooring[#state.entities_on_flooring + 1] = entity
                        if entity.name == "spaceship-docking-port" then
                            state.docking_port = entity
                        end
                    end
                end
            end

            if not state.pending_entities or state.pending_entities_index > #state.pending_entities then
                finalize_scan()
                return
            end
        end

        state.tick_counter = state.tick_counter + 1
    end
end
