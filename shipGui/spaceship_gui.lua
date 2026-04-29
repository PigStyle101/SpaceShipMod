local helpers = require("shipGui/helpers")

local schedule_gui = {}

local ship_captions = {
    automatic = "Automatic",
    paused = "Paused",
    add_station = "+ Add station",
    dock_anchor = "Dock anchor",
    add_condition = "+Add wait condition",
    circuit_condition = "Circuit condition",
    passenger_not_present_condition = "Passenger not present",
    unload = "Unload",
    no_dock = ": (Station has no dock)"
}
--- Fetches the names of space stations and constructs a table mapping each station's name
--- to a localized display format.
---
--- This function iterates over the `prototypes.space_location` table, which is expected to
--- contain information about space stations. For each station, it creates an entry in the
--- response table where the key is the station's name, and the value is a table containing:
--- 1. An empty string (used for localization purposes).
--- 2. A formatted string with the station's name in the form `[space-location=<station_name>]`.
--- 3. The localized name of the station.
---
--- @return table<string, table> A table where keys are station names and values are tables
--- containing localized display information for each station.
local function fetch_station_names()
    local stations = prototypes.space_location

    local response = {}
    for _, station in pairs(stations) do
        response[station.name] = { { "", "[space-location=" .. station.name .. "] ", station.localised_name } }
    end

    return response
end


function schedule_gui.station_menu(parent)
    local main_frame = parent.add {
        type = "frame",
        direction = "vertical",
        style = "frame",
        name = "station-menu-container",
    }

    local titlebar = main_frame.add {
        type = "flow",
        direction = "horizontal"
    }

    titlebar.add {
        type = "label",
        caption = "Add station",
        style = "frame_title"
    }
    local spacer = titlebar.add {
        type = "empty-widget",
        style = "draggable_space_header",
        ignored_by_interaction = true
    }
    spacer.style.horizontally_stretchable = true

    titlebar.add {
        type = "sprite-button",
        name = "close-station-selector",
        style = "frame_action_button",
        sprite = "utility/close",
    }

    ---

    local content_frame = main_frame.add {
        type = "frame",
        name = "station-list",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    --local locations = get_space_locations()
    --local location_display_names, location_names = get_space_location_names(locations)
    local stations = fetch_station_names()
    local location_display_names = {}
    local location_names = {}

    for name, display_name in pairs(stations) do
        table.insert(location_display_names, display_name[1])
        table.insert(location_names, name)
    end

    content_frame.add {
        type = "list-box",
        name = "station-menu",
        items = location_display_names,
        tags = { stations = location_names, filter = parent.tags.filter, ship_id = parent.tags.ship_id }
    }
end

local function create_editable_label(parent, ship_name, identifier, callbacks_filter)
    -- Container flow
    local flow = parent.add {
        type = "flow",
        name = "container",
        direction = "horizontal",
        style_mods = { vertical_align = "center" }
    }
    --Visible
    flow.add {
        type = "label",
        name = "ship-name-label",
        caption = ship_name or "Newship",
        style = "heading_2_label",
        tags = { ship_id = identifier, filter = callbacks_filter }
    }
    flow.style.vertical_align = "center"

    -- Only visible in edit mode
    flow.add {
        type = "textfield",
        name = "ship-name-textfield",
        text = ship_name or "Newship",
        visible = false,
        style_mods = { width = 150 },
        tags = { ship_id = identifier, filter = callbacks_filter }

    }

    -- Edit button
    local edit_button = flow.add {
        type = "sprite-button",
        name = "edit-ship-name",
        style = "mini_button_aligned_to_text_vertically_when_centered",
        sprite = "utility/rename_icon",
        tooltip = "Edit",
        mouse_button_filter = { "left" },
        tags = { ship_id = identifier, filter = callbacks_filter }
    }
    edit_button.style.width = 16
    edit_button.style.height = 16
end

local function create(player, ship_name, ship_id, callbacks_filter, gui_anchor, paused)
    --local anchor = {gui=defines.relative_gui_type.space_platform_hub_gui, position = defines.relative_gui_position.right}

    local is_paused = paused == true
    if type(paused) == "string" then
        is_paused = paused == "right" or paused == "paused"
    end

    local frame = player.gui.relative.add {
        type = "frame",
        name = "schedule-container",
        anchor = gui_anchor,
        direction = "vertical",
        tags = { filter = callbacks_filter, ship_id = ship_id }
    }
    create_editable_label(frame, ship_name, ship_id, callbacks_filter)
    local switch = frame.add {
        type = "switch",
        name = "paused",
        switch_state = is_paused and "right" or "left",
        left_label_caption = ship_captions.automatic,
        right_label_caption = ship_captions.paused,
        tags = { ship_id = ship_id, filter = callbacks_filter }
    }

    local inner_frame = frame.add {
        type = "flow",
        name = "schedule-inner-frame",
        direction = "vertical",
        { filter = callbacks_filter }
    }

    local root_flow = inner_frame.add {
        type = "scroll-pane",
        direction = "vertical",
        name = "schedule-scroll-pane",
        style = "train_schedule_scroll_pane",
        { filter = callbacks_filter }
    }
    root_flow.style.vertically_stretchable = true
    root_flow.style.vertically_squashable = true

    local stations_button = inner_frame.add {
        type = "button",
        caption = ship_captions.add_station,
        name = "add-station-button",
        tags = { ship_id = ship_id, filter = callbacks_filter }
    }
    stations_button.style.horizontally_stretchable = true
    return root_flow
end


local function add_condition_button(parent, station_index, ship_id, callbacks_filter)
    local condition_flow = parent.add {
        type = "flow",
        direction = "horizontal",
        name = "condition-button-container",
        tags = { station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
    }

    local condition_spacer = condition_flow.add {
        type = "empty-widget",
        tags = { station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
    }

    condition_spacer.style.horizontally_stretchable = true

    local condition_button = condition_flow.add {
        type = "button",
        caption = ship_captions.add_condition,
        name = "add-condition",
        tags = { station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
    }
    condition_button.style.horizontal_align = "right"
end

local function add_dock_selector(parent, docks, selected_dock, station_index, ship_id, callbacks_filter)
    -- Not all stations have docks

    local clamp_flow = parent.add {
        type = "flow",
        direction = "horizontal"
    }


    local clamp_frame = clamp_flow.add {
        type = "frame",
        direction = "horizontal"
    }
    clamp_frame.style.horizontally_stretchable = true
    clamp_frame.style.maximal_height = 40
    clamp_frame.style.minimal_width = 392
    clamp_frame.add {
        type = "label",
        caption = ship_captions.dock_anchor
    }
    clamp_flow.style.maximal_width = 292
    if not docks then
        local warning = clamp_frame.add {
            type = "label",
            caption = ship_captions.no_dock
        }
        return
    end
    for key, value in pairs(docks.names) do
        if value == selected_dock then
            selected_dock = key
        end
    end
    local select_dock = clamp_frame.add {
        type = "drop-down",
        name = "dock-menu",
        items = docks.names or nil,
        caption = "Select clamp",
        selected_index = selected_dock or 1,
        tags = { station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
    }
end

local function add_move_up_down_buttons(parent, station_index, type, condition_index, ship_id, callbacks_filter)
    local up_down_flow = parent.add {
        type = "flow",
        direction = "vertical"
    }
    local moveup = up_down_flow.add {
        type = "sprite-button",
        name = "moveup",
        sprite = "virtual-signal/up-arrow",
        tooltip = "Move up",
        style = "train_schedule_action_button",
        tags = {
            station_index = station_index, condition_index = condition_index or nil, type = type, ship_id = ship_id, filter = callbacks_filter
        }
    }
    moveup.style.size = { 20, 12 }

    local movedown = up_down_flow.add {
        type = "sprite-button",
        name = "movedown",
        sprite = "virtual-signal/down-arrow",
        tooltip = "Move down",
        style = "train_schedule_action_button",
        tags = {
            station_index = station_index, condition_index = condition_index or nil, type = type, ship_id = ship_id, filter = callbacks_filter
        }
    }
    movedown.style.size = { 20, 12 }
end


local function unpack_station_args(args)
    return args.main_frame, args.ship_id, args.station_locale_name, args.station_static_name, args.station_index,
        args.current_destination, args.callbacks_filter, args.docks, args.selected_dock_index
end



local function add_station(args)
    local main_frame, ship_id, station_locale_name, station_static_name, station_index, current_destination, callbacks_filter, docks, selected_dock =
    unpack_station_args(args)
    local element_position = #main_frame.children + 1

    local root_flow = main_frame.add {
        type = "flow",
        direction = "vertical",
        tags = { station_name = station_static_name, type = "root", station_index = station_index, ship_id = ship_id }
    }


    local location_frame = root_flow.add {
        type = "frame",
        direction = "horizontal",
        style = "train_schedule_station_frame",
        name = "location-frame"
    }
    location_frame.style.horizontally_stretchable = true
    location_frame.style.vertically_stretchable = false

    local location_flow = location_frame.add {
        type = "flow",
        direction = "horizontal",
    }
    location_flow.style.vertical_align = "center"

    location_flow.add {
        type = "sprite-button",
        sprite = station_index == current_destination and "utility/stop" or "utility/play",
        style = "train_schedule_action_button",
        name = "start-stop-button",
        tags = { station_name = station_static_name, station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
    }

    local spacer = location_flow.add {
        type = "empty-widget",
        style = "draggable_space_header",
        ignored_by_interaction = true
    }
    local planet_label = location_flow.add {
        type = "label",
        caption = station_locale_name,
        style = "clickable_squashable_label"
    }

    local middle_spacer = location_flow.add {
        type = "empty-widget",
    }
    middle_spacer.style.horizontally_stretchable = true


    local unload_check = location_flow.add {
        type = "checkbox",
        name = "unload",
        caption = ship_captions.unload,
        state = false,
        tags = { station = station_static_name, station_index = station_index, ship_id = ship_id, filter = callbacks_filter }

    }

    local dragger = location_flow.add {
        type = "empty-widget",
        style = "draggable_space_header"
    }
    dragger.style.height = 24
    dragger.style.horizontally_stretchable = true
    dragger.style.vertically_stretchable = true
    dragger.style.natural_width = 60
    --dragger.drag_target = location_frame

    add_dock_selector(root_flow, docks, selected_dock, station_index, ship_id, callbacks_filter)
    add_move_up_down_buttons(location_flow, station_index, "station", nil, ship_id, callbacks_filter)


    local close_button = location_flow.add {
        type = "sprite-button",
        style = "train_schedule_delete_button",
        sprite = "utility/close",
        name = "remove-station",
        tags = {
            station = station_static_name, station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
        --caption = "x"
    }

    local empty_conditions_flow = root_flow.add {
        type = "flow",
        direction = "horizontal",
        name = "conditions-flow",
        tags = { station = station_static_name, station_index = station_index, index = element_position }
    }

    add_condition_button(root_flow, element_position, ship_id, callbacks_filter)

    return root_flow
end




function schedule_gui.on_add_condition(event)
    --[[     local available_conditions = {
      "All requests satisfied",
        "Any request not satisfied",
        "Any request zero",
        "Circuit condition",
        "Item condition"
    } ]]

    local conditions_display_name = {
        ship_captions.circuit_condition,
        ship_captions.passenger_not_present_condition
    }

    local conditions_map = { "circuit", "passenger_not_present" }

    local element = event.element

    if element.parent.parent["condition-list-container"] then
        element.parent.parent["condition-list-container"].destroy()
        return
    end

    local parent_container = element.parent.parent
    --local parent_position = parent_container.tags.position

    local container = parent_container.add {
        type = "frame",
        style = "frame_with_even_paddings",
        name = "condition-list-container"
    }

    local list = container.add {
        type = "list-box",
        name = "condition-list",
        items = conditions_display_name,
        tags = {
            station = event.element.tags.station,
            station_index = element.tags.station_index,
            conditions_map = conditions_map,
            filter = element.tags.filter,
            ship_id = element.tags.ship_id
        }
    }
end

local function create_passenger_absent_condition(condition, condition_index, frame, override_right, ship_id, callbacks_filter)
    if not frame then return end

    local station_index = frame.tags.station_index
    local main_container = frame
    local compare_type = condition.compare_type

    local bool_container = main_container["bool-column"] or
    main_container.add { type = "flow", direction = "vertical", name = "bool-column" }

    if #bool_container.children == 0 then
        local spacer = bool_container.add { type = "empty-widget" }
        spacer.style.minimal_height = 18
        spacer.style.natural_height = 18
    end

    if main_container["conditions-column"] then
        local bool_flow = bool_container.add { type = "flow", direction = "horizontal" }
        bool_flow.style.minimal_width = 100

        local bool_frame = bool_flow.add { type = "frame" }
        bool_frame.style.maximal_height = 40
        bool_frame.style.vertical_align = "center"
        bool_frame.style.top_padding = 2
        bool_frame.style.bottom_padding = 2
        bool_frame.style.left_padding = 2
        bool_frame.style.right_padding = 2

        local bool_button = bool_frame.add {
            type = "button",
            name = "bool-switch",
            caption = condition.compare_type == "and" and "AND" or condition.compare_type == "or" and "OR" or "AND",
            tags = {
                station_index = station_index,
                condition_index = condition_index,
                ship_id = ship_id,
                callbacks_filter = callbacks_filter
            }
        }
        bool_button.style.maximal_width = 56

        bool_flow.style.minimal_height = 40
        bool_flow.style.natural_height = 40
        bool_flow.style.maximal_height = 40
        bool_flow.style.vertical_align = "center"

        if override_right then bool_flow.style.horizontal_align = "right" elseif compare_type == "or" then bool_flow.style.horizontal_align =
            "left" else bool_flow.style.horizontal_align = "right" end
    end

    local condition_flow = main_container["conditions-column"] or
    main_container.add { type = "flow", direction = "vertical", name = "conditions-column" }

    local condition_frame = condition_flow.add {
        type = "frame",
        style = "train_schedule_station_frame",
        tags = {
            type = "condition", condition_index = condition_index, station_index = station_index, ship_id = ship_id, callbacks_filter = callbacks_filter
        }
    }
    condition_frame.style.horizontally_stretchable = true

    local progress = condition_frame.add {
        type = "progressbar",
        name = "condition-progress",
        value = 0,
        embed_text_in_bar = true,
        tags = {
            condition_index = condition_index, station_index = station_index, ship_id = ship_id, callbacks_filter = callbacks_filter
        },
    }
    progress.style.horizontally_stretchable = true
    progress.style.bar_width = 32
    progress.style.height = 32
    progress.style.color = { r = 0, g = 1, b = 0, a = 0.4 }
    progress.style.font_color = { r = 0, g = 0, b = 0 }
    progress.style.font = "default-bold"
    progress.style.horizontal_align = "center"
    progress.style.vertical_align = "center"

    local row = condition_frame.add {
        type = "flow",
        direction = "horizontal",
        name = "input-flow"
    }
    row.style.horizontal_align = "center"
    row.style.vertical_align = "center"

    row.add {
        type = "label",
        caption = ship_captions.passenger_not_present_condition,
        style = "bold_label"
    }

    add_move_up_down_buttons(row, station_index, "condition", condition_index, ship_id, callbacks_filter)

    row.add {
        type = "sprite-button",
        name = "remove-condition",
        sprite = "virtual-signal/signal-X",
        style = "train_schedule_delete_button",
        tags = { station_index = station_index, condition_index = condition_index, ship_id = ship_id, filter = callbacks_filter }
    }
end

local function create_constant_condition(condition, condition_index, frame, override_right, ship_id, callbacks_filter)
    if not frame then return end

    local station_index = frame.tags.station_index
    local main_container = frame
    local compare_type = condition.compare_type

    local bool_container = main_container["bool-column"] or
    main_container.add { type = "flow", direction = "vertical", name = "bool-column" }

    if #bool_container.children == 0 then
        local spacer = bool_container.add { type = "empty-widget" }
        spacer.style.minimal_height = 18
        spacer.style.natural_height = 18
    end

    if main_container["conditions-column"] then
        local bool_flow = bool_container.add { type = "flow", direction = "horizontal" }
        bool_flow.style.minimal_width = 100

        local bool_frame = bool_flow.add { type = "frame" }
        bool_frame.style.maximal_height = 40
        bool_frame.style.vertical_align = "center"
        --bool_frame.style.top_margin = 4
        --bool_frame.style.bottom_margin = 4
        bool_frame.style.top_padding = 2
        bool_frame.style.bottom_padding = 2
        bool_frame.style.left_padding = 2
        bool_frame.style.right_padding = 2

        local bool_button = bool_frame.add {
            type = "button",
            name = "bool-switch",
            caption = condition.compare_type == "and" and "AND" or condition.compare_type == "or" and "OR" or "AND",
            --style = "train_schedule_comparison_type_button",
            tags = {
                station_index = station_index,
                condition_index = condition_index,
                ship_id = ship_id,
                callbacks_filter = callbacks_filter
            }
        }
        bool_button.style.maximal_width = 56


        bool_flow.style.minimal_height = 40
        bool_flow.style.natural_height = 40
        bool_flow.style.maximal_height = 40
        bool_flow.style.vertical_align = "center"

        if override_right then bool_flow.style.horizontal_align = "right" elseif compare_type == "or" then bool_flow.style.horizontal_align =
            "left" else bool_flow.style.horizontal_align = "right" end
    end


    local condition_flow = main_container["conditions-column"] or
    main_container.add { type = "flow", direction = "vertical", name = "conditions-column" }

    -- Create condition frame with progress bar
    local condition_frame = condition_flow.add {
        type = "frame",
        style = "train_schedule_station_frame",
        tags = {
            type = "condition", condition_index = condition_index, station_index = station_index, ship_id = ship_id, callbacks_filter = callbacks_filter
        }
    }
    condition_frame.style.horizontally_stretchable = true

    local progress = condition_frame.add {
        type = "progressbar",
        name = "condition-progress",
        value = 0,
        embed_text_in_bar = true,
        tags = {
            condition_index = condition_index, station_index = station_index, ship_id = ship_id, callbacks_filter = callbacks_filter
        },
        --caption = "number"
    }
    progress.style.horizontally_stretchable = true
    progress.style.bar_width = 32
    progress.style.height = 32
    progress.style.color = { r = 0, g = 1, b = 0, a = 0.4 }
    progress.style.font_color = { r = 0, g = 0, b = 0 }
    progress.style.font = "default-bold"
    progress.style.horizontal_align = "center"
    progress.style.vertical_align = "center"

    local row = condition_frame.add {
        type = "flow",
        direction = "horizontal",
        name = "input-flow"
    }
    row.style.horizontal_align = "center"
    row.style.vertical_align = "center"

    local selected_elem_name = condition.condition and condition.condition.first_signal and
    condition.condition.first_signal.name or nil

    local chose_elem = row.add {
        type = "choose-elem-button",
        name = "select-first-signal",
        elem_type = "signal",
        style = "train_schedule_item_select_button",
        tags = { condition_index = condition_index, station_index = station_index, ship_id = ship_id, filter = callbacks_filter }
    }
    if selected_elem_name then
        chose_elem.elem_value = { type = condition.condition.first_signal.type, name = selected_elem_name }
    end


    local operators_array = { "<", "<=", "=", ">=", ">" }
    local operator_index = (function(comparator)
        for index, value in ipairs(operators_array) do
            if value == comparator then
                return index
            end
        end
        return nil -- not found
    end)(condition.condition and condition.condition.comparator)

    row.add {
        type = "drop-down",
        name = "comparison-dropdown",
        items = operators_array,
        selected_index = operator_index or 1,
        style = "train_schedule_circuit_condition_comparator_dropdown",
        tags = {
            condition_index = condition_index, station_index = station_index, ship_id = ship_id, filter = callbacks_filter
        }
    }

    local value_field = row.add {
        type = "textfield",
        name = "constant-amount",
        text = condition.condition and condition.condition.constant or "0",
        numeric = true,
        allow_negative = true,
        style = "console_input_textfield",
        tags = {
            condition_index = condition_index, station_index = station_index, ship_id = ship_id, filter = callbacks_filter
        }
    }
    value_field.style.horizontal_align = "left"
    value_field.style.minimal_width = 50
    value_field.style.maximal_width = 100

    add_move_up_down_buttons(row, station_index, "condition", condition_index, ship_id, callbacks_filter)

    row.add {
        type = "sprite-button",
        name = "remove-condition",
        sprite = "virtual-signal/signal-X",
        style = "train_schedule_delete_button",
        tags = { station_index = station_index, condition_index = condition_index, ship_id = ship_id, filter = callbacks_filter }
    }
end



local function add_conditions(args)
    local wait_conditions, container, ship_id, callbacks_filter = args.wait_conditions, args.container, args.ship_id,
        args.callbacks_filter

    local override_right = true

    if not (wait_conditions and wait_conditions[1]) then return end

    local first_compare_type = wait_conditions[1].compare_type
    for _, condition in pairs(wait_conditions) do
        if first_compare_type ~= condition.compare_type then
            override_right = false
        end
    end


    for i, condition in pairs(wait_conditions) do
        local condition_type = condition and condition.type and
            string.gsub(string.lower(tostring(condition.type)), "[%s%-]+", "_") or ""
        if condition_type == "passenger_not_present" then
            create_passenger_absent_condition(
                condition,
                i,
                container,
                override_right,
                ship_id,
                callbacks_filter
            )
        else
            create_constant_condition(
                condition,
                i,
                container,
                override_right,
                ship_id,
                callbacks_filter
            )
        end
    end
end



local function create_item_condition()
    assert(false, "ERROR: NOT IMPLEMENTED")
end


function schedule_gui.close_station_selector(event)
    local element = helpers.find_element_up(event.element, "station-selector-main")
    if not element then return end
    element.destroy()
end

--- Creates a GUI for scheduling a spaceship.
--- @param player LuaPlayer The player for whom the GUI is being created.
--- @param schedule table The schedule table containing the spaceship's schedule data.
--- @param paused boolean Whether the spaceship is currently paused.
--- @param ship_name string The name of the spaceship.
--- @param ship_id any A unique identifier for the ship
--- @param docks_table table<string, table<string, any>> A table where the key is a space location name,
--- and the value is a table with keys "names" (string) and "optional" (any).
--- @param stations_docks table<int, int> A table where the key is an integer and the value is an integer.
--- @param callbacks_filter table contains arbitraty strings to help you filter callbacks
--- @param gui_anchor table A table specifying GUI anchor position with keys {gui=defines.relative_gui_type, position=defines.relative_gui_position}
function schedule_gui.make_gui(player, schedule, paused, ship_name, ship_id, docks_table, stations_docks,
                               callbacks_filter, gui_anchor)
    local debug_func_name = "schedule_gui.make_gui"
    assert(player, "ERROR: arg player missing for " .. debug_func_name)

    if not callbacks_filter then
        callbacks_filter = { owner = "ship-gui" }
    else
        callbacks_filter.owner = "ship-gui"
    end

    if player.gui.relative["schedule-container"] then player.gui.relative["schedule-container"].destroy() end

    local schedule_container = create(player, ship_name, ship_id, callbacks_filter, gui_anchor, paused)

    local station_names = fetch_station_names()

    if not schedule or not schedule.records then return end

    local current_destination = schedule.current

    for _, record in pairs(schedule.records) do
        local destination_docks = docks_table and docks_table[record.station]
        local selected_dock = stations_docks and stations_docks[_]

        local station_widget = add_station {
            main_frame = schedule_container,
            ship_id = ship_id,
            station_locale_name = station_names[record.station][1],
            station_static_name = record.station,
            station_index = _,
            current_destination = current_destination,
            player = player,
            callbacks_filter = callbacks_filter,
            docks = destination_docks,
            selected_dock_index = selected_dock,
        }

        if record.wait_conditions then
            add_conditions {
                wait_conditions = record.wait_conditions,
                container = station_widget["conditions-flow"],
                ship_id = ship_id,
                callbacks_filter = callbacks_filter
            }
        end
    end
end

local function apply_progress_to_station_widget(station_widget, conditions_ratio)
    if not (station_widget and station_widget.valid) then return end
    local conditions_flow = station_widget["conditions-flow"]
    if not (conditions_flow and conditions_flow.valid) then return end
    local conditions_column = conditions_flow["conditions-column"]
    if not (conditions_column and conditions_column.valid) then return end

    for condition_index, condition in pairs(conditions_column.children) do
        local progress_bar = condition and condition.valid and condition["condition-progress"] or nil
        if progress_bar and progress_bar.valid then
            local ratio = tonumber(conditions_ratio and conditions_ratio[condition_index]) or 0
            if ratio < 0 then ratio = 0 end
            if ratio > 1 then ratio = 1 end

            if progress_bar.value ~= ratio then
                progress_bar.value = ratio
            end

            local is_complete = ratio >= 1
            local tags = progress_bar.tags or {}
            if tags.progress_complete ~= is_complete then
                if is_complete then
                    progress_bar.style.color = { r = 0.2, g = 0.9, b = 0.2, a = 0.7 }
                else
                    progress_bar.style.color = { r = 0.9, g = 0.7, b = 0.1, a = 0.6 }
                end
                tags.progress_complete = is_complete
                progress_bar.tags = tags
            end
        end
    end
end

function schedule_gui.update_station_progress(station_index, conditions_ratio, player)
    if not (player and player.valid and player.gui and player.gui.relative) then return end
    local schedule_root = player.gui.relative["schedule-container"]
    if not (schedule_root and schedule_root.valid) then return end
    local inner = schedule_root["schedule-inner-frame"]
    if not (inner and inner.valid) then return end
    local schedule_container = inner["schedule-scroll-pane"]
    if not (schedule_container and schedule_container.valid and schedule_container.children) then return end

    local station_widget = schedule_container.children[station_index]
    apply_progress_to_station_widget(station_widget, conditions_ratio)
end

function schedule_gui.update_all_station_progress(progress_by_station, player)
    if not (player and player.valid and player.gui and player.gui.relative) then return end
    local schedule_root = player.gui.relative["schedule-container"]
    if not (schedule_root and schedule_root.valid) then return end
    local inner = schedule_root["schedule-inner-frame"]
    if not (inner and inner.valid) then return end
    local schedule_container = inner["schedule-scroll-pane"]
    if not (schedule_container and schedule_container.valid and schedule_container.children) then return end

    for station_index, station_widget in pairs(schedule_container.children) do
        apply_progress_to_station_widget(station_widget, progress_by_station and progress_by_station[station_index])
    end
end

local function get_schedule_scroll_pane(player)
    if not player or not player.valid then return nil end
    local container = player.gui.relative["schedule-container"]
    if not container then return nil end
    local inner = container["schedule-inner-frame"]
    if not inner then return nil end
    return inner["schedule-scroll-pane"]
end

local function get_callbacks_filter_from_gui(player)
    if not player or not player.valid then
        return { mod = "pig-ex", owner = "ship-gui" }
    end

    local container = player.gui.relative["schedule-container"]
    if container and container.tags and container.tags.filter then
        return container.tags.filter
    end

    return { mod = "pig-ex", owner = "ship-gui" }
end

local function update_station_index_tags_recursive(element, new_station_index)
    if not (element and element.valid) then return end

    local tags = element.tags
    if tags and tags.station_index then
        tags.station_index = new_station_index
        element.tags = tags
    end

    for _, child in pairs(element.children or {}) do
        update_station_index_tags_recursive(child, new_station_index)
    end
end

function schedule_gui.reindex_station_widgets(player, ship)
    local scroll_pane = get_schedule_scroll_pane(player)
    if not scroll_pane then return false end

    local current_station = ship and ship.schedule and ship.schedule.current

    for index, station_root in ipairs(scroll_pane.children) do
        update_station_index_tags_recursive(station_root, index)

        local start_stop_button = helpers.find_element_down(station_root, "start-stop-button")
        if start_stop_button and start_stop_button.valid then
            start_stop_button.sprite = (current_station == index) and "utility/stop" or "utility/play"
        end
    end

    return true
end

function schedule_gui.swap_station_widgets(player, ship, index_a, index_b)
    local scroll_pane = get_schedule_scroll_pane(player)
    if not scroll_pane then return false end

    local child_count = #scroll_pane.children
    if child_count < 2 then return false end
    if not index_a or not index_b then return false end
    if index_a < 1 or index_a > child_count or index_b < 1 or index_b > child_count then return false end
    if index_a == index_b then return true end

    scroll_pane.swap_children(index_a, index_b)
    return schedule_gui.reindex_station_widgets(player, ship)
end

function schedule_gui.add_station_widget(player, ship, station_index, docks_table, stations_docks)
    local scroll_pane = get_schedule_scroll_pane(player)
    if not scroll_pane then return false end
    if not ship or not ship.schedule or not ship.schedule.records then return false end

    local record = ship.schedule.records[station_index]
    if not record then return false end

    local station_names = fetch_station_names()
    local station_locale_name = station_names[record.station] and station_names[record.station][1] or record.station
    local callbacks_filter = get_callbacks_filter_from_gui(player)

    local station_widget = add_station {
        main_frame = scroll_pane,
        ship_id = ship.id,
        station_locale_name = station_locale_name,
        station_static_name = record.station,
        station_index = station_index,
        current_destination = ship.schedule.current,
        player = player,
        callbacks_filter = callbacks_filter,
        docks = docks_table and docks_table[record.station],
        selected_dock_index = stations_docks and stations_docks[station_index],
    }

    if record.wait_conditions then
        add_conditions {
            wait_conditions = record.wait_conditions,
            container = station_widget["conditions-flow"],
            ship_id = ship.id,
            callbacks_filter = callbacks_filter
        }
    end

    return schedule_gui.reindex_station_widgets(player, ship)
end

function schedule_gui.remove_station_widget(player, ship, station_index)
    local scroll_pane = get_schedule_scroll_pane(player)
    if not scroll_pane then return false end

    local station_root = scroll_pane.children[station_index]
    if not station_root or not station_root.valid then return false end

    station_root.destroy()
    return schedule_gui.reindex_station_widgets(player, ship)
end

function schedule_gui.refresh_station_conditions(player, ship, station_index)
    local scroll_pane = get_schedule_scroll_pane(player)
    if not scroll_pane then return false end
    if not ship or not ship.schedule or not ship.schedule.records then return false end

    local station_root = scroll_pane.children[station_index]
    if not station_root or not station_root.valid then return false end

    local old_conditions_flow = station_root["conditions-flow"]
    if old_conditions_flow and old_conditions_flow.valid then
        old_conditions_flow.destroy()
    end

    local existing_condition_button = station_root["condition-button-container"]
    if existing_condition_button and existing_condition_button.valid then
        existing_condition_button.destroy()
    end

    local station_name = ""
    if station_root.tags then
        station_name = station_root.tags.station_name or station_root.tags.station or ""
    end

    local conditions_flow = station_root.add {
        type = "flow",
        direction = "horizontal",
        name = "conditions-flow",
        tags = { station = station_name, station_index = station_index, index = station_index }
    }

    local callbacks_filter = get_callbacks_filter_from_gui(player)
    add_condition_button(station_root, station_index, ship.id, callbacks_filter)

    local record = ship.schedule.records[station_index]
    if record and record.wait_conditions then
        add_conditions {
            wait_conditions = record.wait_conditions,
            container = conditions_flow,
            ship_id = ship.id,
            callbacks_filter = callbacks_filter
        }
    end

    return true
end

return schedule_gui
