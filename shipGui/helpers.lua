local helpers = {}

--- Recursively searches for a GUI element by name.
-- @param parent LuaGuiElement - The GUI element to start searching from.
-- @param target_name string - The name of the element we are trying to find
-- @return LuaGuiElement or nil - The element if found, or nil if not.
function helpers.find_element_down(parent, target_name)
    if not (parent and parent.valid and parent.children) then return nil end

    for _, child in pairs(parent.children) do
        if child.name == target_name then
            return child
        end

        local found = helpers.find_element_down(child, target_name)
        if found then return found end
    end

    return nil
end

function helpers.find_element_up(element, target_name)
    if not (element and element.valid) then return nil end

    if element.name == target_name then return element end
    local found = helpers.find_element_up(element.parent, target_name)
        if found then return found end
    return nil
end

function helpers.find_element_up_with_tag(element, key, value)
    if not (element and element.valid) then return nil end

    if element.tags and element.tags[key] and element.tags[key] == value then return element end
    local found = helpers.find_element_up_with_tag(element.parent, key, value)
        if found then return found end
    return nil
end

--- Retrieves essential information from a GUI event.
--- 
--- @param event table The event table containing details about the GUI interaction.
--- @return LuaPlayer? player The player who triggered the event.
--- @return LuaGuiElement element The GUI element involved in the event.
--- @return uint selected_index The selected index of the GUI element, if applicable.
function helpers.get_essential_events_info(event)
    local player = game.get_player(event.player_index)
    local element = event.element
    local selected_index = element.selected_index

    return player, element, selected_index

end


return helpers