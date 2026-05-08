return function(SpaceShip)
    local WAITING_DOCK_ALERT_ICON = { type = "virtual", name = "signal-red" }
    local WAITING_DOCK_ALERT_DELAY_TICKS = 60 * 30
    local WAITING_DOCK_ALERT_REFRESH_TICKS = 60 * 5
    local WAITING_BLOCKED_DOCK_AREA_ALERT_ICON = { type = "virtual", name = "signal-yellow" }
    local WAITING_BLOCKED_DOCK_AREA_ALERT_REFRESH_TICKS = 60 * 5

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

    local function clear_waiting_open_dock_alert(ship)
        if not ship then return end
        if ship.player and ship.player.valid and ship.waiting_for_open_dock_alert_message then
            pcall(function()
                ship.player.remove_alert({
                    icon = WAITING_DOCK_ALERT_ICON,
                    message = ship.waiting_for_open_dock_alert_message
                })
            end)
        end
        ship.waiting_for_open_dock_alerted = false
        ship.waiting_for_open_dock_alert_message = nil
        ship.waiting_for_open_dock_since_tick = nil
        ship.waiting_for_open_dock_alert_last_tick = nil
    end

    local function clear_waiting_blocked_dock_area_alert(ship)
        if not ship then return end
        if ship.player and ship.player.valid and ship.waiting_for_clear_dock_area_alert_message then
            pcall(function()
                ship.player.remove_alert({
                    icon = WAITING_BLOCKED_DOCK_AREA_ALERT_ICON,
                    message = ship.waiting_for_clear_dock_area_alert_message
                })
            end)
        end
        ship.waiting_for_clear_dock_area_alerted = false
        ship.waiting_for_clear_dock_area_alert_message = nil
        ship.waiting_for_clear_dock_area_alert_last_tick = nil
        ship.waiting_for_clear_dock_area = false
    end

    SpaceShip.clear_waiting_states = function(ship)
        if not ship then return end
        ship.waiting_for_open_dock = false
        clear_waiting_open_dock_alert(ship)
        clear_waiting_blocked_dock_area_alert(ship)
    end

    SpaceShip.init_docking_ports = function()
        storage.docking_ports = storage.docking_ports or {}
    end

    SpaceShip.register_docking_port = function(entity)
        if not storage.docking_ports then SpaceShip.init_docking_ports() end
        local name
        if entity.surface.get_tile(entity.position.x, entity.position.y).name ~= "spaceship-flooring" then
            name = entity.surface.platform.space_location.name .. table_size(storage.docking_ports)
        else
            name = "ship"
        end
        storage.docking_ports[entity.unit_number] = {
            entity = entity,
            position = entity.position,
            surface = entity.surface,
            name = name,
            ship_limit = 1,
            ship_docked = nil
        }
    end

    function SpaceShip.check_waiting_ships_for_dock_availability()
        if not storage.spaceships or not storage.docking_ports then return end

        for _, ship in pairs(storage.spaceships) do
            if (ship.waiting_for_open_dock or ship.waiting_for_clear_dock_area) and ship.own_surface then
                local schedule = ship.schedule
                if schedule and schedule.records and schedule.records[schedule.current] then
                    local docked = SpaceShip.attempt_docking(ship)
                    if not docked then
                        if ship.waiting_for_open_dock then
                            ship.waiting_for_open_dock = true
                        end
                        if ship.waiting_for_clear_dock_area then
                            ship.waiting_for_clear_dock_area = true
                        end
                    end
                end
            elseif ship.automatic and ship.own_surface and ship.scanned and not storage.scan_state then
                local platform = ship.surface and ship.surface.platform
                if platform and platform.valid and
                    platform.paused and
                    platform.state ~= defines.space_platform_state.on_the_path then
                    SpaceShip.attempt_docking(ship)
                end
            end
        end
    end

    function SpaceShip.connect_adjacent_ports()
        if not storage.docking_ports then return end

        local function are_adjacent(port1, port2)
            local dx = math.abs(port1.position.x - port2.position.x)
            local dy = math.abs(port1.position.y - port2.position.y)
            return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
        end

        for id1, port1 in pairs(storage.docking_ports) do
            for id2, port2 in pairs(storage.docking_ports) do
                if id1 ~= id2 and are_adjacent(port1, port2) then
                    if port1.entity.valid and port2.entity.valid then
                        local red_connector1 = port1.entity.get_wire_connector(defines.wire_connector_id.circuit_red)
                        local green_connector1 = port1.entity.get_wire_connector(defines.wire_connector_id.circuit_green)
                        local red_connector2 = port2.entity.get_wire_connector(defines.wire_connector_id.circuit_red)
                        local green_connector2 = port2.entity.get_wire_connector(defines.wire_connector_id.circuit_green)

                        if red_connector1 and red_connector2 then
                            red_connector1.connect_to(red_connector2)
                        end

                        if green_connector1 and green_connector2 then
                            green_connector1.connect_to(green_connector2)
                        end
                    end
                end
            end
        end
    end

    function SpaceShip.attempt_docking(ship)
        local schedule = ship.schedule
        if not schedule or not schedule.records or not schedule.records[schedule.current] then
            game.print("Error: Invalid schedule for ship " .. ship.name)
            return false
        end

        local target_docking_port
        local target_docking_port_unit_number

        local selected_port_name = ship.port_records[schedule.current]
        if selected_port_name == "none" then
            if ship.automatic then
                if SpaceShip.set_automatic_mode then
                    SpaceShip.set_automatic_mode(ship, false)
                else
                    ship.automatic = false
                end
                game.print("Ship " .. ship.name .. " reached " .. (schedule.records[schedule.current].station or "station") ..
                    " with dock anchor 'none'; automatic mode disabled.")
            end
            return false
        end

        if selected_port_name then
            local target_planet = schedule.records[schedule.current].station
            local found_named_port = false

            for unit_number, port_data in pairs(storage.docking_ports) do
                if port_data.name == selected_port_name and port_data.entity and port_data.entity.valid and
                    port_data.surface and port_data.surface.valid and
                    port_data.surface.platform and port_data.surface.platform.space_location and
                    port_data.surface.platform.space_location.name == target_planet then
                    local port_tile = port_data.surface.get_tile(port_data.position.x, port_data.position.y)
                    if port_tile.name ~= "spaceship-flooring" then
                        found_named_port = true

                        if not target_docking_port then
                            target_docking_port_unit_number = unit_number
                            target_docking_port = port_data.entity
                        end

                        if not port_data.ship_docked then
                            target_docking_port_unit_number = unit_number
                            target_docking_port = port_data.entity
                            break
                        end
                    end
                end
            end

            if not found_named_port or not target_docking_port_unit_number or not target_docking_port or not target_docking_port.valid then
                game.print("Error: Could not find docking port named '" ..
                    selected_port_name .. "' for station " .. schedule.records[schedule.current].station)
                return false
            end
        else
            local target_planet = schedule.records[schedule.current].station
            for unit_number, port_data in pairs(storage.docking_ports) do
                if port_data.entity.valid and port_data.surface.platform and
                    port_data.surface.platform.space_location and
                    port_data.surface.platform.space_location.name == target_planet and
                    not port_data.ship_docked then
                    local port_tile = port_data.surface.get_tile(port_data.position.x, port_data.position.y)
                    if port_tile.name ~= "spaceship-flooring" then
                        target_docking_port = port_data.entity
                        target_docking_port_unit_number = unit_number
                        break
                    end
                end
            end

            if not target_docking_port then
                return false
            end
        end

        if storage.docking_ports[target_docking_port_unit_number].ship_docked or not ship.scanned or
            not ship.reference_tile or not ship.floor or not ship.docking_port or not ship.docking_port.valid then
            if not ship.scanned or not ship.reference_tile or not ship.floor or not ship.docking_port or not ship.docking_port.valid then
                if not storage.scan_state then
                    game.print("Warning: Ship " .. ship.name .. " data incomplete, triggering rescan...")
                    ship.waiting_for_scan = true
                    SpaceShip.start_scan_ship(ship, 60, 1)
                end
            elseif storage.docking_ports[target_docking_port_unit_number].ship_docked then
                ship.waiting_for_open_dock = true
                if not ship.waiting_for_open_dock_since_tick then
                    ship.waiting_for_open_dock_since_tick = game.tick
                end

                local waited_long_enough = (game.tick - ship.waiting_for_open_dock_since_tick) >=
                    WAITING_DOCK_ALERT_DELAY_TICKS

                local should_refresh_alert = ship.waiting_for_open_dock_alerted and
                    ship.waiting_for_open_dock_alert_last_tick and
                    (game.tick - ship.waiting_for_open_dock_alert_last_tick) >= WAITING_DOCK_ALERT_REFRESH_TICKS

                if waited_long_enough and (not ship.waiting_for_open_dock_alerted or should_refresh_alert) and
                    ship.player and ship.player.valid then
                    local alert_entity = nil
                    if target_docking_port and target_docking_port.valid then
                        alert_entity = target_docking_port
                    elseif ship.hub and ship.hub.valid then
                        alert_entity = ship.hub
                    end

                    if alert_entity then
                        ship.waiting_for_open_dock_alert_message =
                            "Selected docking port is occupied. Ship " .. ship.name .. " waiting for availability."
                        if not ship.waiting_for_open_dock_alerted then
                            game.print("Warning: " .. ship.waiting_for_open_dock_alert_message)
                        end
                        pcall(function()
                            ship.player.add_custom_alert(
                                alert_entity,
                                WAITING_DOCK_ALERT_ICON,
                                ship.waiting_for_open_dock_alert_message,
                                true)
                        end)
                        ship.waiting_for_open_dock_alerted = true
                        ship.waiting_for_open_dock_alert_last_tick = game.tick
                    end
                end
            end
            return false
        end

        if ship.waiting_for_open_dock then
            ship.waiting_for_open_dock = false
            clear_waiting_open_dock_alert(ship)
        end

        local offset = {
            x = target_docking_port.position.x - ship.docking_port.position.x + 1,
            y = target_docking_port.position.y - ship.docking_port.position.y
        }

        local dest_center = {
            x = ship.reference_tile.position.x + offset.x,
            y = ship.reference_tile.position.y + offset.y
        }

        local area_has_blockers = false
        local blocker_entity = nil
        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge

        for _, tile in pairs(ship.floor) do
            local tx = tile.position.x + offset.x
            local ty = tile.position.y + offset.y
            local target_tile = target_docking_port.surface.get_tile({ x = tx, y = ty })
            if target_tile and target_tile.valid and
                target_tile.name ~= "empty-space" then
                area_has_blockers = true
                break
            end
            min_x = math.min(min_x, tx)
            max_x = math.max(max_x, tx)
            min_y = math.min(min_y, ty)
            max_y = math.max(max_y, ty)
        end

        if not area_has_blockers then
            local blockers = target_docking_port.surface.find_entities_filtered({
                area = {
                    { x = min_x - 0.49, y = min_y - 0.49 },
                    { x = max_x + 0.49, y = max_y + 0.49 }
                }
            })

            if blockers and #blockers > 0 then
                for _, entity in pairs(blockers) do
                    if entity and entity.valid then
                        local is_target_dock = target_docking_port and target_docking_port.valid and
                            entity.unit_number and target_docking_port.unit_number and
                            entity.unit_number == target_docking_port.unit_number

                        local is_non_blocking =
                            is_target_dock or
                            entity.type == "character" or
                            entity.name == "entity-ghost" or
                            entity.name == "tile-ghost"

                        if not is_non_blocking then
                            area_has_blockers = true
                            blocker_entity = entity
                            break
                        end
                    end
                end
            end
        end

        if area_has_blockers then
            ship.waiting_for_clear_dock_area = true

            local should_refresh_blocked_area_alert = ship.waiting_for_clear_dock_area_alerted and
                ship.waiting_for_clear_dock_area_alert_last_tick and
                (game.tick - ship.waiting_for_clear_dock_area_alert_last_tick) >=
                WAITING_BLOCKED_DOCK_AREA_ALERT_REFRESH_TICKS

            if (not ship.waiting_for_clear_dock_area_alerted or should_refresh_blocked_area_alert) and
                ship.player and ship.player.valid then
                local alert_entity = nil
                if blocker_entity and blocker_entity.valid then
                    alert_entity = blocker_entity
                elseif target_docking_port and target_docking_port.valid then
                    alert_entity = target_docking_port
                elseif ship.hub and ship.hub.valid then
                    alert_entity = ship.hub
                end

                if alert_entity then
                    ship.waiting_for_clear_dock_area_alert_message =
                        "Docking area is blocked for ship " .. ship.name .. ". Waiting for clear space."
                    if not ship.waiting_for_clear_dock_area_alerted then
                        game.print("Warning: " .. ship.waiting_for_clear_dock_area_alert_message)
                    end
                    pcall(function()
                        ship.player.add_custom_alert(
                            alert_entity,
                            WAITING_BLOCKED_DOCK_AREA_ALERT_ICON,
                            ship.waiting_for_clear_dock_area_alert_message,
                            true)
                    end)
                    ship.waiting_for_clear_dock_area_alerted = true
                    ship.waiting_for_clear_dock_area_alert_last_tick = game.tick
                end
            end
            return false
        end

        if ship.waiting_for_clear_dock_area then
            clear_waiting_blocked_dock_area_alert(ship)
        end

        local old_platform = nil
        if ship.own_surface and ship.surface and ship.surface.platform and ship.surface.platform.valid then
            old_platform = ship.surface.platform
        end

        local clone_success = SpaceShip.clone_ship_area_instant(
            ship,
            target_docking_port.surface,
            dest_center,
            {})
        if not clone_success then
            game.print("Error: Failed to clone ship for docking.")
            return false
        end

        local expected_ship_dock_pos = {
            x = ship.docking_port.position.x + offset.x,
            y = ship.docking_port.position.y + offset.y
        }
        local new_ship_dock = find_cloned_entity_near(target_docking_port.surface, "spaceship-docking-port",
            expected_ship_dock_pos, 3)
        if new_ship_dock and new_ship_dock.valid then
            ship.docking_port = new_ship_dock
        end

        ship.surface = target_docking_port.surface
        ship.own_surface = false
        ship.traveling = false
        ship.docked = true
        ship.waiting_for_open_dock = false
        clear_waiting_open_dock_alert(ship)
        ship.waiting_for_scan = false
        ship.docked_port_unit_number = target_docking_port_unit_number
        storage.docking_ports[target_docking_port_unit_number].ship_docked = true

        if old_platform and old_platform.valid then
            old_platform.destroy(1)
        end

        game.print("Ship " ..
            ship.name .. " successfully docked at port on " .. target_docking_port.surface.platform.space_location.name)

        return true
    end
end