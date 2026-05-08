local gui_maker = require("shipGui/spaceship_gui")
local SpaceShipGuis = require("shipGui/SpaceShipGuisScript")

local callbacks = {
    on_state_changed = {},
    on_click = {},
    on_elem_changed = {},
    on_check = {},
    on_switch = {},
    on_gui_confirmed = {},
    on_gui_text_changed = {}
}

local ShipGuiControl = {}

local function emit(handler_name, payload)
    local handler = SpaceShipGuis[handler_name]
    if handler then
        handler(payload)
    end
end

local function element_belongs_to_ship_gui(element)
    if element
    and element.tags
    and element.tags.filter then
        if element.tags.filter.owner == "ship-gui" then return true end
    end

    return false
end

callbacks.on_state_changed["station-menu"] = function (event)
    local element = event.element
    
    if element.name ~= "station-menu" then return end
    
    local selected_index = element.selected_index
    local selected_station = element.tags.stations[selected_index]
    element.parent.parent.visible = false

    emit("on_station_selected", {
        selected_station = selected_station,
        ship_id = element.tags.ship_id,
        player_index = event.player_index
    })
end

callbacks.on_state_changed["comparison-dropdown"] = function (event)
    local element = event.element
    
    local selected_index = element.selected_index
    local sign = element.items[selected_index]



    emit("on_comparison_sign_changed", {
        station_index = element.tags.station_index,
        condition_index = element.tags.condition_index,
        comparator = sign,
        ship_id = element.tags.ship_id,
        player_index = event.player_index
    })


end

callbacks.on_state_changed["dock-menu"] = function(event)
    local element = event.element
    local selected_index = element.selected_index
    local selected_dock = element.items[selected_index]
    local tags = element.tags

    emit("on_station_dock_selected", {
        station_index = tags.station_index,
        ship_id = tags.ship_id,
        dock_index = selected_index,
        selected_dock = selected_dock,
        player_index = event.player_index
    })
end

callbacks.on_elem_changed["select-first-signal"] = function(event)
    local element = event.element
    local tags = element.tags

    emit("on_first_signal_selected", {
        station_index = tags.station_index,
        condition_index = tags.condition_index,
        ship_id = tags.ship_id,
        selected_signal = element.elem_value,
        selected_type = element.elem_type,
        player_index = event.player_index
    })


end






callbacks.on_click["add-station-button"] = function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local parent = player.gui.relative["schedule-container"]
    if not parent then return end
    if parent["station-menu-container"] then parent["station-menu-container"].visible = not parent["station-menu-container"].visible return end
    gui_maker.station_menu(parent)

end

callbacks.on_click["moveup"] = function(event)
    local element = event.element
    local target_type = element.tags.type

    local event_map = {
        condition = "on_condition_move_up",
        station = "on_station_move_up"
    }

    local event_to_dispatch = event_map[target_type]
    
    if event_to_dispatch then
        emit(event_to_dispatch, {
            ship_id = element.tags.ship_id,
            station_index = element.tags.station_index,
            condition_index = element.tags.condition_index,
            player_index = event.player_index
        })
    end
end

callbacks.on_click["movedown"] = function(event)
    local element = event.element
    local target_type = element.tags.type

    local event_map = {
        condition = "on_condition_move_down",
        station = "on_station_move_down"
    }

    local event_to_dispatch = event_map[target_type]
    
    if event_to_dispatch then
        emit(event_to_dispatch, {
            ship_id = element.tags.ship_id,
            station_index = element.tags.station_index,
            condition_index = element.tags.condition_index,
            player_index = event.player_index
        })
    end
end

callbacks.on_click["bool-switch"] = function(event)
    local element = event.element
    local tags = element.tags
    local current_bool = string.lower(tostring(element.caption or "and"))
    local next_bool = (current_bool == "and") and "or" or "and"

    -- Update clicked button immediately so we don't need a full GUI rebuild.
    element.caption = string.upper(next_bool)

    emit("on_bool_changed", {
        ship_id = tags.ship_id,
        station_index = tags.station_index,
        condition_index = tags.condition_index,
        from_bool = current_bool,
        to_bool = next_bool,
        bool = next_bool,
        player_index = event.player_index
    })

end

callbacks.on_click["remove-condition"] = function(event)
    local element = event.element
    local tags = element.tags

    emit("on_condition_delete", {
        ship_id = tags.ship_id,
        station_index = tags.station_index,
        condition_index = tags.condition_index,
        player_index = event.player_index
    })


end

callbacks.on_click["add-condition"] = function(event)
    gui_maker.on_add_condition(event)
end

callbacks.on_state_changed["condition-list"] = function (event)
    local element = event.element
    local tags = element.tags
    local selected_index = element.selected_index
    local selected = element.items[selected_index]

    
    emit("on_station_condition_add", {
        ship_id = tags.ship_id,
        station_index = tags.station_index,
        selected_index = selected_index,
        selected_item = selected,
        selected_condition_type = tags.conditions_map and tags.conditions_map[selected_index] or nil,
        player_index = event.player_index
    })
    if element.valid then element.parent.destroy() end
end


callbacks.on_click["remove-station"] = function(event)
    local element = event.element
    local tags = element.tags

    emit("on_station_delete", {
        ship_id = tags.ship_id,
        station_index = tags.station_index,
        station_name = tags.station_static_name,
        condition_index = tags.condition_index,
        player_index = event.player_index
    })
end

callbacks.on_click["start-stop-button"] = function(event)
    local element = event.element
    local tags = element.tags

    emit("on_station_goto", {
        station_index = tags.station_index,
        ship_id = tags.ship_id,
        station_name = tags.station_name,
        player_index = event.player_index
    })
end


callbacks.on_check["unload"] = function(event)
    local element = event.element
    local state = element.state
    local tags = element.tags
    emit("on_station_unload_check_changed", {
        ship_id = tags.ship_id,
        station_index = tags.station_index,
        condition_index = tags.condition_index,
        from_state = not state,
        state = state,
        player_index = event.player_index
    })


end


callbacks.on_switch["paused"] = function(event)
    local element = event.element
    local state = element.switch_state
    local tags = element.tags
    local is_automatic = state == "left"
    emit("on_ship_paused_unpaused", {
        ship_id = tags.ship_id,
        state = state,
        switch_state = state,
        automatic = is_automatic,
        player_index = event.player_index
    })


end

callbacks.on_gui_confirmed["name-textfield"] = function (event)
    local textfield = event.element
    local flow = textfield.parent
    local label = flow["label"]

    label.caption = textfield.text
    label.visible = true
    textfield.visible = false

    emit("on_ship_rename_confirmed", {
        ship_id = event.element.tags.ship_id,
        ship_name = textfield.text,
        player_index = event.player_index
    })

end

callbacks.on_gui_text_changed["constant-amount"] = function(event)
    local element = event.element
    local amount = element.text
    local tags = element.tags

    emit("on_condition_constant_confirmed", {
        condition_index = tags.condition_index,
        station_index = tags.station_index,
        ship_id = tags.ship_id,
        amount = amount,
        player_index = event.player_index
    })
end

callbacks.on_click["edit-name"] = function(event)
    local flow = event.element.parent
    local label = flow["label"]
    local textfield = flow["name-textfield"]

    if textfield.visible then
        -- Leaving edit mode: save
        local new_text = textfield.text
        label.caption = new_text
        label.visible = true
        textfield.visible = false
    else
        -- Entering edit mode
        label.visible = false
        textfield.visible = true
        textfield.focus()
    end

end


callbacks.on_click["edit-ship-name"] = function(event)
    local flow = event.element.parent
    local label = flow["ship-name-label"] or flow["label"]
    local textfield = flow["ship-name-textfield"]
    if not label or not textfield then
        return
    end

    if textfield.visible then
        -- Leaving edit mode: save
        local new_text = textfield.text
        label.caption = new_text
        label.visible = true
        textfield.visible = false
    else
        -- Entering edit mode
        label.visible = false
        textfield.visible = true
        textfield.focus()
    end

end

callbacks.on_gui_confirmed["ship-name-textfield"] = function(event)
    local textfield = event.element
    local flow = textfield.parent
    local label = flow["ship-name-label"] or flow["label"]
    if not label then
        return
    end
    local tags = event.element.tags

    label.caption = textfield.text
    label.visible = true
    textfield.visible = false

    emit("on_ship_rename_confirmed", {
        ship_id = tags.ship_id,
        ship_name = textfield.text,
        player_index = event.player_index
    })
end

function ShipGuiControl.on_gui_click(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end


    local func = callbacks.on_click[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_click, function(event)
    ShipGuiControl.on_gui_click(event)

end)

function ShipGuiControl.on_gui_checked_state_changed(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end

    local func = callbacks.on_check[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    ShipGuiControl.on_gui_checked_state_changed(event)
end)

function ShipGuiControl.on_gui_switch_state_changed(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end

    local func = callbacks.on_switch[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_switch_state_changed, function(event)
    ShipGuiControl.on_gui_switch_state_changed(event)
end)

function ShipGuiControl.on_gui_confirmed(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end

    local func = callbacks.on_gui_confirmed[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_confirmed, function(event)
    ShipGuiControl.on_gui_confirmed(event)
end)

function ShipGuiControl.on_gui_elem_changed(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end

    local func = callbacks.on_elem_changed[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_elem_changed, function(event)
    ShipGuiControl.on_gui_elem_changed(event)
end)


function ShipGuiControl.on_gui_selection_state_changed(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end

    local func = callbacks.on_state_changed[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    ShipGuiControl.on_gui_selection_state_changed(event)
end)

function ShipGuiControl.on_gui_text_changed(event)
    local element = event.element

    if not element_belongs_to_ship_gui(element) then return end

    local func = callbacks.on_gui_text_changed[event.element.name]

    if not func then return end

    func(event)

    return true
end

script.on_event(defines.events.on_gui_text_changed, function(event)
    ShipGuiControl.on_gui_text_changed(event)
end)

return ShipGuiControl