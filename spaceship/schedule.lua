return function(SpaceShip)
    local function normalize_condition_type(condition_type)
        return string.gsub(string.lower(tostring(condition_type or "")), "[%s%-]+", "_")
    end

    local function normalize_wait_conditions_in_schedule(schedule)
        if not schedule or not schedule.records then return end
        if schedule._conditions_normalized then return end
        for _, record in pairs(schedule.records) do
            if record and record.wait_conditions then
                for _, condition in pairs(record.wait_conditions) do
                    if condition and condition.type then
                        condition.type = normalize_condition_type(condition.type)
                    end
                end
            end
        end
        schedule._conditions_normalized = true
    end

    local function mark_schedule_conditions_dirty(ship)
        if ship and ship.schedule then
            ship.schedule._conditions_normalized = nil
        end
    end

    local function get_next_schedule_index(schedule)
        if not (schedule and schedule.records and #schedule.records > 0) then
            return nil
        end

        local current = tonumber(schedule.current) or 1
        local next_index = current + 1
        if next_index > #schedule.records then
            next_index = 1
        end
        return next_index
    end

    local function is_player_in_ship_cockpit(ship)
        if not ship or not ship.surface or not ship.surface.valid then return false end

        local cockpit_player = ship.player_in_cockpit
        if cockpit_player and cockpit_player.valid and
            cockpit_player.vehicle and cockpit_player.vehicle.valid and
            cockpit_player.vehicle.name == "spaceship-control-hub-car" and
            cockpit_player.vehicle.surface == ship.surface then
            return true
        end

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
        else
            return false
        end

        local cockpit_cars = ship.surface.find_entities_filtered {
            name = "spaceship-control-hub-car",
            area = search_area
        }

        for _, car in pairs(cockpit_cars) do
            if car and car.valid then
                local driver = car.get_driver()
                if driver and driver.valid and driver.player and driver.player.valid then
                    return true
                end

                local passenger = car.get_passenger()
                if passenger and passenger.valid and passenger.player and passenger.player.valid then
                    return true
                end
            end
        end

        return false
    end

    local function is_player_on_ship(ship)
        if not ship or not ship.surface or not ship.surface.valid then return false end

        if is_player_in_ship_cockpit(ship) then
            return true
        end

        if not ship.floor or table_size(ship.floor) == 0 then
            return false
        end

        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge
        for _, tile in pairs(ship.floor) do
            min_x = math.min(min_x, tile.position.x)
            max_x = math.max(max_x, tile.position.x)
            min_y = math.min(min_y, tile.position.y)
            max_y = math.max(max_y, tile.position.y)
        end

        local characters = ship.surface.find_entities_filtered {
            type = "character",
            area = {
                { x = min_x - 0.5, y = min_y - 0.5 },
                { x = max_x + 0.5, y = max_y + 0.5 }
            }
        }

        for _, character in pairs(characters) do
            if character and character.valid and character.player and character.player.valid then
                local tile = ship.surface.get_tile(character.position)
                if tile and tile.valid and tile.name == "spaceship-flooring" then
                    return true
                end
            end
        end

        return false
    end

    local function evaluate_wait_condition(ship, condition, signals, passenger_on_ship)
        local condition_type = normalize_condition_type(condition and condition.type)
        if condition_type == "passenger_not_present" then
            if passenger_on_ship == nil then
                passenger_on_ship = is_player_on_ship(ship)
            end
            return not passenger_on_ship
        elseif condition_type == "passenger_present" then
            if passenger_on_ship == nil then
                passenger_on_ship = is_player_on_ship(ship)
            end
            return passenger_on_ship
        end

        if condition and condition.condition and condition.condition.first_signal then
            local signal_value = (signals and signals[condition.condition.first_signal.name]) or 0
            local comparison = condition.condition.comparator
            local value = tonumber(condition.condition.constant) or 0

            if comparison == "<" then
                return signal_value < value
            elseif comparison == "<=" then
                return signal_value <= value
            elseif comparison == "=" then
                return signal_value == value
            elseif comparison == ">=" then
                return signal_value >= value
            elseif comparison == ">" then
                return signal_value > value
            end
        end

        return true
    end

    function SpaceShip.ship_takeoff(ship, dropdown)
        local stationID = dropdown.selected_index
        local station   = dropdown.items[stationID]
        local schedule  = {
            current = 1,
            records = {
                {
                    station = station,
                    wait_conditions = { --[[
                    {
                        type = "circuit",
                        compare_type = "and",
                        condition =
                        {
                            first_signal =
                            {
                                type = "virtual",
                                name = "signal-A"
                            },
                            comparator = "<",
                            constant = 10
                        }
                    }]] --
                    },
                    temporary = true,
                    created_by_interrupt = true,
                    allows_unloading = false
                }
            }
        }
        ship.schedule   = schedule
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.add_or_change_station(ship, planet_name, index)
        ship.schedule = ship.schedule or {}
        if not ship.schedule.current then
            ship.schedule.current = 1 --default to 1 of not already set
        end
        if ship.schedule.records then
            record =
            {
                station = planet_name,
                wait_conditions = {
                    {
                        type = "circuit",
                        compare_type = "and",
                        condition =
                        {
                            first_signal =
                            {
                                type = "virtual",
                                name = "signal-A"
                            },
                            comparator = ">",
                            constant = 10
                        }
                    }
                },
                temporary = true,
                created_by_interrupt = false,
                allows_unloading = false
            }
            table.insert(ship.schedule.records, record)
        else
            ship.schedule.records = {
                {
                    station = planet_name,
                    wait_conditions = {
                        {
                            type = "circuit",
                            compare_type = "and",
                            condition =
                            {
                                first_signal =
                                {
                                    type = "virtual",
                                    name = "signal-A"
                                },
                                comparator = ">",
                                constant = 10
                            }
                        }
                    },
                    temporary = true,
                    created_by_interrupt = false,
                    allows_unloading = false
                }
            }
        end
        if ship.platform then
            ship.platform.schedule = ship.schedule
        end
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.delete_station(ship, station_index)
        if not ship or not ship.schedule or not ship.schedule.records then
            game.print("Error: Invalid ship or schedule.")
            return
        end

        if not ship.schedule.records[station_index] then
            game.print("Error: Station index " .. station_index .. " does not exist in the schedule.")
            return
        end

        table.remove(ship.schedule.records, station_index)

        local temp_schedule = {}
        for key, value in pairs(ship.schedule.records) do
            table.insert(temp_schedule, value)
        end

        ship.schedule.records = temp_schedule
        mark_schedule_conditions_dirty(ship)

    end

    function SpaceShip.read_circuit_signals(entity)
        -- Get the circuit network for red and green wires
        local red_network = entity.get_circuit_network(1)
        local green_network = entity.get_circuit_network(2)

        local signals = {}

        -- Read signals from red wire
        if red_network then
            local red_signals = red_network.signals
            if red_signals then
                for _, signal in pairs(red_signals) do
                    -- Signal structure: {signal = {type="item", name="iron-plate"}, count = 42}
                    signals[signal.signal.name] = signals[signal.signal.name] or 0
                    signals[signal.signal.name] = signals[signal.signal.name] + signal.count
                end
            end
        end

        -- Read signals from green wire
        if green_network then
            local green_signals = green_network.signals
            if green_signals then
                for _, signal in pairs(green_signals) do
                    signals[signal.signal.name] = signals[signal.signal.name] or 0
                    signals[signal.signal.name] = signals[signal.signal.name] + signal.count
                end
            end
        end

        return signals
    end

    function SpaceShip.get_progress_values(ship, signals)
        if not ship or not ship.schedule or not ship.schedule.records then
            return {}
        end

        local progress = {}
        local passenger_on_ship = nil

        for station_index, station in pairs(ship.schedule.records) do
            if station.wait_conditions then
                progress[station_index] = {}

                for condition_index, condition in pairs(station.wait_conditions) do
                    local progress_value = 0

                    local condition_type = normalize_condition_type(condition and condition.type)
                    if condition_type == "passenger_not_present" or condition_type == "passenger_present" then
                        if passenger_on_ship == nil then
                            passenger_on_ship = is_player_on_ship(ship)
                        end
                        if condition_type == "passenger_not_present" then
                            progress_value = (not passenger_on_ship) and 1 or 0
                        else
                            progress_value = passenger_on_ship and 1 or 0
                        end
                    elseif condition and condition.condition and condition.condition.first_signal then
                        local signal_value = tonumber(signals[condition.condition.first_signal.name]) or 0
                        local target_value = tonumber(condition.condition.constant) or 0
                        local comparator = condition.condition.comparator

                        if comparator == ">" or comparator == ">=" then
                            if target_value <= 0 then
                                progress_value = 1
                            else
                                progress_value = signal_value / target_value
                            end
                        elseif comparator == "<" or comparator == "<=" then
                            if signal_value <= 0 then
                                progress_value = target_value <= 0 and 1 or 0
                            else
                                progress_value = target_value / signal_value
                            end
                        elseif comparator == "=" then
                            if target_value == 0 then
                                progress_value = signal_value == 0 and 1 or 0
                            else
                                progress_value = 1 - (math.abs(signal_value - target_value) / target_value)
                            end
                        end
                    end

                    if progress_value < 0 then progress_value = 0 end
                    if progress_value > 1 then progress_value = 1 end

                    progress[station_index][condition_index] = progress_value
                end
            end
        end
        return progress
    end

    function SpaceShip.check_circuit_condition(entity, signal_name, comparison, value)
        local signals = SpaceShip.read_circuit_signals(entity)
        local signal_value = signals[signal_name] or 0

        if comparison == "<" then
            return signal_value < value
        elseif comparison == "<=" then
            return signal_value <= value
        elseif comparison == "=" then
            return signal_value == value
        elseif comparison == ">=" then
            return signal_value >= value
        elseif comparison == ">" then
            return signal_value > value
        end

        return false
    end

    function SpaceShip.check_schedule_conditions(ship)
        if not ship or not ship.schedule or not ship.schedule.records then
            return false
        end

        normalize_wait_conditions_in_schedule(ship.schedule)

        local current_station = ship.schedule.records[ship.schedule.current]
        if not current_station or not current_station.wait_conditions then
            return true -- No conditions means conditions are satisfied
        end

        -- If the station has no conditions (empty table), return true
        if #current_station.wait_conditions == 0 then
            return true
        end

        local result = true
        local temp_and_result = true
        local valid_conditions_found = false
        local signals = nil
        local passenger_on_ship = nil

        for i, condition in ipairs(current_station.wait_conditions) do
            if condition then
                valid_conditions_found = true
                local condition_type = normalize_condition_type(condition.type)
                if condition_type == "passenger_not_present" or condition_type == "passenger_present" then
                    if passenger_on_ship == nil then
                        passenger_on_ship = is_player_on_ship(ship)
                    end
                elseif not signals and ship.hub and ship.hub.valid then
                    signals = SpaceShip.read_circuit_signals(ship.hub)
                end

                local condition_met = evaluate_wait_condition(ship, condition, signals, passenger_on_ship)

                if condition.compare_type == "and" then
                    -- Combine with the temporary `and` result
                    temp_and_result = temp_and_result and condition_met
                elseif condition.compare_type == "or" then
                    -- Apply the grouped `and` result to the main result
                    result = result or temp_and_result
                    temp_and_result = condition_met -- Reset for the next group
                else
                    -- If no `and` or `or`, treat it as a standalone condition
                    temp_and_result = condition_met
                end

                -- If the result is already false for `and`, or true for `or`, we can short-circuit
                if (condition.compare_type == "and" and not temp_and_result) or (condition.compare_type == "or" and result) then
                    break
                end
            end
        end

        -- If no valid conditions were found, always return true
        if not valid_conditions_found then
            return true
        end

        -- Apply the final grouped `and` result to the main result
        if not result or not temp_and_result then
            result = false
        else
            result = result and temp_and_result
        end
        return result
    end

    function SpaceShip.check_automatic_behavior()
        for id, ship in pairs(storage.spaceships or {}) do
            if not ship.automatic then goto continue end
            if storage.scan_state then goto continue end

            local schedule = ship.schedule
            if not schedule or not schedule.records then goto continue end
            local current_station = schedule.records[schedule.current]
            if not current_station then goto continue end
            if not ship.scanned and not storage.scan_state then
                SpaceShip.start_scan_ship(ship, 60, 1)
            elseif not ship.scanned then
                goto continue
            end

            if ship.scanned and ship.docked and ship.reference_tile and ship.floor and table_size(ship.floor) > 0 then
                local all_conditions_met = SpaceShip.check_schedule_conditions(ship)
                if all_conditions_met or ship.leave_immediately then
                    local docked_planet = nil
                    if ship.surface and ship.surface.valid and ship.surface.platform and ship.surface.platform.space_location then
                        docked_planet = ship.surface.platform.space_location.name
                    end

                    if docked_planet and current_station and current_station.station == docked_planet then
                        local next_index = get_next_schedule_index(schedule)
                        if next_index and next_index ~= schedule.current then
                            schedule.current = next_index
                            current_station = schedule.records[schedule.current]
                        end
                    end

                    ship.leave_immediately = false -- Reset the flag
                    local clone_result = SpaceShip.clone_ship_to_space_platform(ship)
                    if clone_result == "deferred" then
                        goto continue
                    end

                    -- Set up platform to travel to the current station (don't advance yet)
                    local platform = ship.hub.surface.platform
                    if platform then
                        normalize_wait_conditions_in_schedule(schedule)
                        platform.schedule = schedule
                        platform.paused = false
                    end
                end
            end
            ::continue::
        end
    end

    function SpaceShip.add_wait_condition(ship, station_number, condition_type)
        if not ship.schedule.records[station_number].wait_conditions then
            ship.schedule.records[station_number].wait_conditions = {}
        end
        local normalized = normalize_condition_type(condition_type)
        local wait_condition = {
            type = normalized,
            compare_type = "and"
        }

        if normalized ~= "passenger_not_present" and normalized ~= "passenger_present" then
            wait_condition.condition = {
                first_signal = {
                    type = "virtual",
                    name = "signal-A"
                },
                comparator = ">",
                constant = 10
            }
        end
        table.insert(ship.schedule.records[station_number].wait_conditions, wait_condition)
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.remove_wait_condition(ship, station_index, condition_index)
        if not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index].wait_conditions then
            return
        end

        ship.schedule.records[station_index].wait_conditions[condition_index] = nil

        local temp_conditions = {}
        for _, condition in pairs(ship.schedule.records[station_index].wait_conditions) do
            if condition then
                table.insert(temp_conditions, condition)
            end
        end

        ship.schedule.records[station_index].wait_conditions = temp_conditions
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.station_move_up(ship, station_index)
        if not ship.schedule.records or
            not ship.schedule.records[station_index] or
            station_index <= 1 then
            return
        end

        local current_station = ship.schedule.records[station_index]
        local previous_station = ship.schedule.records[station_index - 1]

        ship.schedule.records[station_index] = previous_station
        ship.schedule.records[station_index - 1] = current_station
        mark_schedule_conditions_dirty(ship)

        if ship.schedule.current == station_index then
            ship.schedule.current = station_index - 1
        elseif ship.schedule.current == station_index - 1 then
            ship.schedule.current = station_index
        end
    end

    function SpaceShip.station_move_down(ship, station_index)
        if not ship.schedule.records or
            not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index + 1] then
            return
        end

        local current_station = ship.schedule.records[station_index]
        local next_station = ship.schedule.records[station_index + 1]

        ship.schedule.records[station_index] = next_station
        ship.schedule.records[station_index + 1] = current_station
        mark_schedule_conditions_dirty(ship)

        if ship.schedule.current == station_index then
            ship.schedule.current = station_index + 1
        elseif ship.schedule.current == station_index + 1 then
            ship.schedule.current = station_index
        end
    end

    function SpaceShip.goto_station(ship, station_index)
        if not ship or not ship.schedule or not ship.schedule.records then
            game.print("Error: Invalid ship or schedule.")
            return
        end

        if not ship.schedule.records[station_index] then
            game.print("Error: Station index " .. station_index .. " does not exist in the schedule.")
            return
        end

        ship.schedule.current = station_index
        if SpaceShip.clear_waiting_states then
            SpaceShip.clear_waiting_states(ship)
        else
            ship.waiting_for_open_dock = false
        end
        ship.automatic = true         -- Enable automatic mode
        if ship.docked then
            ship.leave_immediately = true -- Flag to leave as soon as possible
            if not ship.scanned and ship.hub and ship.hub.valid then
                SpaceShip.start_scan_ship(ship, 60, 1, true)
            end
        end

        -- If ship is already on its own moving platform, immediately resume travel
        -- to the newly selected destination.
        if ship.own_surface and ship.surface and ship.surface.platform then
            ship.surface.platform.schedule = ship.schedule
            ship.surface.platform.paused = false
        end
    end

    function SpaceShip.condition_move_up(ship, station_index, condition_index)
        if not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index].wait_conditions or
            not ship.schedule.records[station_index].wait_conditions[condition_index] or
            condition_index <= 1 then
            return
        end

        local current_condition = ship.schedule.records[station_index].wait_conditions[condition_index]
        local previous_condition = ship.schedule.records[station_index].wait_conditions[condition_index - 1]

        ship.schedule.records[station_index].wait_conditions[condition_index] = previous_condition
        ship.schedule.records[station_index].wait_conditions[condition_index - 1] = current_condition
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.condition_move_down(ship, station_index, condition_index)
        if not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index].wait_conditions or
            not ship.schedule.records[station_index].wait_conditions[condition_index] or
            not ship.schedule.records[station_index].wait_conditions[condition_index + 1] then
            return
        end

        local current_condition = ship.schedule.records[station_index].wait_conditions[condition_index]
        local next_condition = ship.schedule.records[station_index].wait_conditions[condition_index + 1]

        ship.schedule.records[station_index].wait_conditions[condition_index] = next_condition
        ship.schedule.records[station_index].wait_conditions[condition_index + 1] = current_condition
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.constant_changed(ship, station_index, condition_index, value)
        if not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index].wait_conditions or
            not ship.schedule.records[station_index].wait_conditions[condition_index] then
            return
        end

        ship.schedule.records[station_index].wait_conditions[condition_index].condition.constant = value
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.compare_changed(ship, station_index, condition_index, value)
        if not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index].wait_conditions or
            not ship.schedule.records[station_index].wait_conditions[condition_index] then
            return
        end

        ship.schedule.records[station_index].wait_conditions[condition_index].condition.comparator = value
        mark_schedule_conditions_dirty(ship)
    end

    -- Backward-compatible alias for older call sites.
    SpaceShip.compair_changed = SpaceShip.compare_changed

    function SpaceShip.signal_changed(ship, station_index, condition_index, signal)
        if not ship.schedule.records[station_index] or
            not ship.schedule.records[station_index].wait_conditions or
            not ship.schedule.records[station_index].wait_conditions[condition_index] then
            return
        end

        ship.schedule.records[station_index].wait_conditions[condition_index].condition.first_signal = {
            type = signal.type,
            name = signal.name
        }
        mark_schedule_conditions_dirty(ship)
    end

    function SpaceShip.set_automatic_mode(ship, automatic)
        if not ship then return end

        local desired_automatic = automatic == true
        ship.automatic = desired_automatic

        if not ship.automatic and SpaceShip.clear_waiting_states then
            SpaceShip.clear_waiting_states(ship)
        end

        if ship.own_surface == true and ship.surface and ship.surface.valid and ship.surface.platform and ship.surface.platform.valid then
            ship.surface.platform.paused = not ship.automatic
        end
    end

    function SpaceShip.auto_manual_changed(ship)
        if not ship then return end
        SpaceShip.set_automatic_mode(ship, not ship.automatic)
    end
end
