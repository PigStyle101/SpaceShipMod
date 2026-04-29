-- =============================================================================
-- SPACESHIP MOD DATA DEFINITIONS
-- =============================================================================

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

local function make_tile_area(area, name)
    local result = {}
    local left_top = area[1]
    local right_bottom = area[2]
    for x = left_top[1], right_bottom[1] do
        for y = left_top[2], right_bottom[2] do
            table.insert(result, {
                position = { x, y },
                tile = name
            })
        end
    end
    return result
end

-- =============================================================================
-- PROTOTYPE COPIES (Base templates from existing game prototypes)
-- =============================================================================

-- Docking Port prototypes (based on constant-combinator and cargo-bay)
local dockingPortEntity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local dockingPortRecipe = table.deepcopy(data.raw["recipe"]["cargo-bay"])
local dockingPortItem = table.deepcopy(data.raw["item"]["cargo-bay"])

-- Floor prototypes (based on space-platform-foundation)
local floorItem = table.deepcopy(data.raw["item"]["space-platform-foundation"])
local floorRecipe = table.deepcopy(data.raw["recipe"]["space-platform-foundation"])

-- Wall prototypes (based on stone-wall)
local wallEntity = table.deepcopy(data.raw["wall"]["stone-wall"])
local wallItem = table.deepcopy(data.raw["item"]["stone-wall"])
local wallRecipe = table.deepcopy(data.raw["recipe"]["stone-wall"])

-- Control Hub prototypes (based on various prototypes)
local controlHubItem = table.deepcopy(data.raw["item"]["cargo-bay"])
local controlHubRecipe = table.deepcopy(data.raw["recipe"]["cargo-bay"])
local controlHubEntityHub = table.deepcopy(data.raw["space-platform-hub"]["space-platform-hub"])
local controlHubItemCar = table.deepcopy(data.raw["item-with-entity-data"]["car"])

-- =============================================================================
-- DOCKING PORT MODIFICATIONS
-- =============================================================================

dockingPortRecipe.name = "spaceship-docking-port"
dockingPortRecipe.localised_name = "Spaceship Docking Port"
dockingPortRecipe.localised_description = "Docking port for spaceship."
dockingPortRecipe.ingredients = { { type = "item", name = "iron-plate", amount = 1 } }
dockingPortRecipe.results = { { type = "item", name = "spaceship-docking-port", amount = 1 } }
dockingPortRecipe.enabled = false

dockingPortItem.name = "spaceship-docking-port"
dockingPortItem.localised_name = "Spaceship Docking Port"
dockingPortItem.place_result = "spaceship-docking-port"
-- Create tinted icon for docking port using icons property
dockingPortItem.icon = nil
dockingPortItem.icon_size = nil
dockingPortItem.icons = {
    {
        icon = data.raw["item"]["constant-combinator"].icon,
        icon_size = data.raw["item"]["constant-combinator"].icon_size,
        tint = { r = 0.8, g = 0.8, b = 0.8, a = 1.0 }
    }
}

dockingPortEntity.name = "spaceship-docking-port"
dockingPortEntity.localised_name = "Spaceship Docking Port"
dockingPortEntity.minable = { mining_time = 0.2, result = "spaceship-docking-port" }

-- =============================================================================
-- CONTROL HUB MODIFICATIONS
-- =============================================================================

controlHubItem.name = "spaceship-control-hub"
controlHubItem.localised_name = "Spaceship Control Hub"
controlHubItem.place_result = "spaceship-control-hub"
-- Create tinted icon for control hub using icons property
controlHubItem.icon = nil
controlHubItem.icon_size = nil
controlHubItem.icons = {
    {
        icon = data.raw["item"]["space-platform-hub"].icon,
        icon_size = data.raw["item"]["space-platform-hub"].icon_size,
        tint = { r = 0.8, g = 0.8, b = 0.8, a = 1.0 }
    }
}

controlHubRecipe.name = "spaceship-control-hub"
controlHubRecipe.localised_name = "Spaceship Control Hub"
controlHubRecipe.ingredients = { { type = "item", name = "iron-plate", amount = 1 } }
controlHubRecipe.results = { { type = "item", name = "spaceship-control-hub", amount = 1 } }
controlHubRecipe.main_product = "spaceship-control-hub"
controlHubRecipe.hidden = false
controlHubRecipe.enabled = false

controlHubItemCar.name = "spaceship-control-hub-car"

-- =============================================================================
-- WALL MODIFICATIONS
-- =============================================================================

wallEntity.name = "spaceship-wall"
wallEntity.localised_name = "Spaceship Wall"
wallEntity.minable = { mining_time = 0.2, result = "spaceship-wall" }
wallEntity.create_ghost_on_death = true
wallEntity.surface_conditions = nil

wallItem.name = "spaceship-wall"
wallItem.localised_name = "Spaceship Wall"
wallItem.place_result = "spaceship-wall"

wallRecipe.name = "spaceship-wall"
wallRecipe.localised_name = "Spaceship Wall"
wallRecipe.ingredients = { { type = "item", name = "iron-plate", amount = 1 } }
wallRecipe.results = { { type = "item", name = "spaceship-wall", amount = 1 } }
wallRecipe.enabled = false

-- =============================================================================
-- FLOOR MODIFICATIONS
-- =============================================================================

floorItem.name = "spaceship-flooring"
floorItem.localised_name = "Spaceship Flooring"
floorItem.place_as_tile = { result = "spaceship-flooring", condition_size = 0, condition = { layers = {} } }
-- Use refined concrete icon for spaceship flooring
floorItem.icon = data.raw["item"]["refined-concrete"].icon
floorItem.icon_size = data.raw["item"]["refined-concrete"].icon_size

floorRecipe.name = "spaceship-flooring"
floorRecipe.localised_name = "Spaceship Flooring"
floorRecipe.ingredients = { { type = "item", name = "iron-plate", amount = 1 } }
floorRecipe.results = { { type = "item", name = "spaceship-flooring", amount = 10 } }
floorRecipe.main_product = "spaceship-flooring"
floorRecipe.hidden = false
floorRecipe.enabled = false

-- =============================================================================
-- SPACESHIP FLOORING TILE (Custom tile with refined concrete graphics)
-- =============================================================================

local space_foundation = data.raw.tile["space-platform-foundation"]
local refined_concrete = data.raw.tile["refined-concrete"]

local spaceship_flooring_tile = nil
if space_foundation and refined_concrete then
    spaceship_flooring_tile = table.deepcopy(space_foundation)

    -- Keep all space platform foundation properties (space-compatible)
    spaceship_flooring_tile.name = "spaceship-flooring"
    spaceship_flooring_tile.localised_name = "Spaceship Flooring"
    spaceship_flooring_tile.order = "z[spaceship-flooring]"
    spaceship_flooring_tile.minable = { mining_time = 0.2, result = "spaceship-flooring" }
    spaceship_flooring_tile.map_color = { r = 200, g = 200, b = 200 }

    -- Use refined concrete graphics (clean grey appearance, no dirt transitions)
    spaceship_flooring_tile.variants = table.deepcopy(refined_concrete.variants)
    spaceship_flooring_tile.allows_being_covered = true
end

if data.raw.tile["space-platform-foundation"] then
    data.raw.tile["space-platform-foundation"].allows_being_covered = true
end

-- =============================================================================
-- DATA EXTEND - Register all prototypes with the game
-- =============================================================================

data:extend({
    -- Custom Control Hub Container Entity
    {
        type = "container",
        name = "spaceship-control-hub",
        localised_name = "Spaceship Control Hub",
        localised_description = "Main control hub for the spaceship.",
        placeable_by = data.raw["item"]["spaceship-control-hub"],
        flags = { "placeable-neutral", "player-creation", "not-rotatable" },
        icon = "__SpaceShipMod__/control-hub.png",
        icon_size = 500,
        circuit_connector = data.raw["container"]["iron-chest"].circuit_connector,
        circuit_wire_max_distance = data.raw["container"]["iron-chest"].circuit_wire_max_distance,
        draw_circuit_wires = true,
        inventory_size = 50,
        create_ghost_on_death = true,
        surface_conditions = nil,
        collision_box = { { -3.8, -3.8 }, { 3.8, 3.8 } },
        selection_box = { { -3.8, -3.8 }, { 3.5, 3.8 } },
        minable = { mining_time = 0.2, result = "spaceship-control-hub" },
        picture = {
            layers = {
                {
                    filename = "__SpaceShipMod__/control-hub.png",
                    priority = "high",
                    width = 500,
                    height = 500,
                    shift = { 0, 0 },
                    scale = .65
                },
            }
        },
    },

    -- Control Hub Car Entity (for driving mechanics)
    {
        type = "car",
        name = "spaceship-control-hub-car",
        weight = 1,
        braking_force = 1,
        friction_force = 100,
        energy_per_hit_point = 1,
        effectivity = 0,
        consumption = "1W",
        rotation_speed = 0,
        inventory_size = 1,
        energy_source = { type = "void" },
        allow_remote_driving = false,
        collision_box = { { -0.4, -0.05 }, { 0.4, 0.05 } },
    },
    {
        type = "space-platform-starter-pack",
        name = "space-ship-starter-pack",
        localised_name = "Space Platform Starter Pack",
        icon = "__space-age__/graphics/icons/thruster.png",
        subgroup = "space-rocket",
        stack_size = 1,
        weight = 1 * tons,
        surface = "space-ship-surface",
        hidden = true,
        hidden_in_factoriopedia = true,
        trigger =
        {
            {
                type = "direct",
                action_delivery =
                {
                    type = "instant",
                    source_effects =
                    {
                        {
                            type = "create-entity",
                            entity_name = "spaceship-control-hub"
                        }
                    }
                }
            }
        },
        tiles = make_tile_area({ { -5, -5 }, { 5, 5 } }, "spaceship-flooring"),
        initial_items = { { type = "item", name = "spaceship-flooring", amount = 10 } },
        create_electric_network = true,
    },
    -- Custom Space Ship Surface
    {
        type = "surface",
        name = "space-ship-surface",
        icon = "__space-age__/graphics/icons/thruster.png",
        subgroup = "planets",
        order = "a[space-platform]",
        surface_properties = {
            gravity = 0,
            pressure = 0,
            ["magnetic-field"] = 0,
            ["day-night-cycle"] = 0
        }
    },

    -- Spaceship Construction Technology
    {
        type = "technology",
        name = "spaceship-construction",
        localised_name = "Spaceship Construction",
        localised_description = "Advanced spaceship components for interstellar travel.",
        icon = "__SpaceShipMod__/control-hub.png",
        icon_size = 500,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "spaceship-flooring"
            },
            {
                type = "unlock-recipe",
                recipe = "spaceship-control-hub"
            },
            {
                type = "unlock-recipe",
                recipe = "spaceship-docking-port"
            },
            {
                type = "unlock-recipe",
                recipe = "spaceship-armor"
            }
        },
        prerequisites = { "space-science-pack" },
        unit = {
            count = 1000,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack",   1 },
                { "chemical-science-pack",   1 },
                { "production-science-pack", 1 },
                { "utility-science-pack",    1 },
                { "space-science-pack",      1 }
            },
            time = 30
        },
        order = "e-g"
    },

    -- Modified prototype items/recipes/entities
    dockingPortItem,
    dockingPortRecipe,
    dockingPortEntity,
    floorItem,
    floorRecipe,
    controlHubItem,
    controlHubRecipe,
    wallEntity,
    wallItem,
    wallRecipe,
    controlHubEntityHub,
    controlHubItemCar,
})

-- Add the custom spaceship flooring tile if it was created successfully
if spaceship_flooring_tile then
    data:extend({ spaceship_flooring_tile })
end

-- Allow quick replacement between space-platform-foundation <-> spaceship-flooring
local function ensure_tile_condition(item_name, tile_name)
    local item = data.raw.item[item_name]
    if not item or not item.place_as_tile then return end

    -- If tile_condition is absent, seed it with empty-space so normal space placement remains valid.
    if not item.place_as_tile.tile_condition then
        item.place_as_tile.tile_condition = { "empty-space" }
    end

    for _, existing in pairs(item.place_as_tile.tile_condition) do
        if existing == tile_name then
            return
        end
    end

    table.insert(item.place_as_tile.tile_condition, tile_name)
end

ensure_tile_condition("space-platform-foundation", "space-platform-foundation")
ensure_tile_condition("space-platform-foundation", "spaceship-flooring")
ensure_tile_condition("spaceship-flooring", "empty-space")
ensure_tile_condition("spaceship-flooring", "space-platform-foundation")
ensure_tile_condition("spaceship-flooring", "spaceship-flooring")

-- =============================================================================
-- BASE GAME SPACE PLATFORM LOCALISATION OVERRIDES
-- =============================================================================

if data.raw["space-platform-starter-pack"] and data.raw["space-platform-starter-pack"]["space-platform-starter-pack"] then
    data.raw["space-platform-starter-pack"]["space-platform-starter-pack"].localised_name = "Space Station Starter Pack"
end

if data.raw["space-platform-hub"] and data.raw["space-platform-hub"]["space-platform-hub"] then
    data.raw["space-platform-hub"]["space-platform-hub"].localised_name = "Space Station Control Hub"
end

if data.raw.item and data.raw.item["space-platform-hub"] then
    data.raw.item["space-platform-hub"].localised_name = "Space Station Control Hub"
end

if data.raw.recipe and data.raw.recipe["space-platform-hub"] then
    data.raw.recipe["space-platform-hub"].localised_name = "Space Station Control Hub"
end

if data.raw.item and data.raw.item["space-platform-foundation"] then
    data.raw.item["space-platform-foundation"].localised_name = "Space Station Platform"
end

if data.raw.recipe and data.raw.recipe["space-platform-foundation"] then
    data.raw.recipe["space-platform-foundation"].localised_name = "Space Station Platform"
end

if data.raw.tile and data.raw.tile["space-platform-foundation"] then
    data.raw.tile["space-platform-foundation"].localised_name = "Space Station Platform"
end

-- =============================================================================
-- TECHNOLOGY MODIFICATIONS
-- =============================================================================

-- Modify existing technology prerequisites
if data.raw.technology["space-platform-thruster"] then
    data.raw.technology["space-platform-thruster"].prerequisites = { "spaceship-construction" }
end

-- Update power-armor-mk2 technology to reflect spaceship armor
if data.raw.technology["power-armor-mk2"] then
    -- Change the technology name and description to reflect spaceship armor
    data.raw.technology["power-armor-mk2"].localised_name = {"technology-name.spaceship-armor-tech"}
    data.raw.technology["power-armor-mk2"].localised_description = {"technology-description.spaceship-armor-tech"}
    
    -- Use the same dark grey-tinted icon as the spaceship armor
    data.raw.technology["power-armor-mk2"].icon = nil
    data.raw.technology["power-armor-mk2"].icons = {
        {
            icon = data.raw["armor"]["mech-armor"].icon,
            icon_size = data.raw["armor"]["mech-armor"].icon_size or 64,
            tint = {r = 0.4, g = 0.4, b = 0.4, a = 1.0}  -- Dark grey to match armor
        }
    }
end

-- Hide the original power-armor-mk2 from all discovery interfaces
if data.raw.armor["power-armor-mk2"] then
    data.raw.armor["power-armor-mk2"].hidden = true
    data.raw.armor["power-armor-mk2"].hidden_in_factoriopedia = true
end

if data.raw.item["power-armor-mk2"] then
    data.raw.item["power-armor-mk2"].hidden = true
    data.raw.item["power-armor-mk2"].hidden_in_factoriopedia = true
end

if data.raw.recipe["power-armor-mk2"] then
    data.raw.recipe["power-armor-mk2"].hidden = true
    data.raw.recipe["power-armor-mk2"].hidden_in_factoriopedia = true
end

-- =============================================================================
-- CORE GAME ENTITY MODIFICATIONS
-- =============================================================================

-- Modify thrusters to only be placeable on spaceship flooring
if data.raw.thruster and data.raw.thruster.thruster then
    -- Note: Tile placement restrictions for thrusters need to be handled in control.lua
    -- because tile_buildability_rules expects collision mask layers, not tile names

    -- Add localised description about placement requirement to the item
    if data.raw.item and data.raw.item.thruster then
        -- Add localised description about placement requirement
        data.raw.item.thruster.localised_description = { "",
            data.raw.item.thruster.localised_description or "",
            "\n[color=yellow]Can only be placed on Spaceship Flooring.[/color]"
        }
    end
end

-- =============================================================================
-- SPACESHIP ARMOR
-- =============================================================================

-- Create spaceship armor based on mech-armor with grey tint
local spaceshipArmor = table.deepcopy(data.raw["armor"]["mech-armor"])
spaceshipArmor.name = "spaceship-armor"
spaceshipArmor.icons = {
    {
        icon = data.raw["armor"]["mech-armor"].icon,
        icon_size = data.raw["armor"]["mech-armor"].icon_size or 64,
        tint = {r = 0.4, g = 0.4, b = 0.4, a = 1.0}  -- Darker grey to match character
    }
}
spaceshipArmor.icon = nil  -- Remove single icon since we're using icons array

-- Debug: Let's check ALL properties of both armors to understand how visuals work
local mech_armor = data.raw["armor"]["mech-armor"]
local power_armor_mk2 = data.raw["armor"]["power-armor-mk2"]

-- Now I understand how armor visuals work in Factorio 2.0!
-- Armor visuals are defined in the CharacterPrototype's animations array
-- Each CharacterArmorAnimation has an 'armors' property that lists which armors use those animations

-- Find the character prototype and add spaceship-armor to the mech-armor animation set
if data.raw["character"] and data.raw["character"]["character"] then
    local character = data.raw["character"]["character"]
    log("SpaceShipMod DEBUG: Found character prototype")
    
    if character.animations then
        log("SpaceShipMod DEBUG: Character has " .. #character.animations .. " animation sets")
        -- Look for the animation set that includes mech-armor
        for i, animation_set in ipairs(character.animations) do
            if animation_set.armors then
                log("SpaceShipMod DEBUG: Animation set " .. i .. " has armors list with " .. #animation_set.armors .. " armors")
                for j, armor_name in ipairs(animation_set.armors) do
                    log("SpaceShipMod DEBUG: Animation set " .. i .. " includes armor: " .. armor_name)
                    if armor_name == "mech-armor" then
                        -- Found the mech-armor animation set! 
                        -- First, create a deep copy of this animation set for spaceship armor
                        local spaceship_animation_set = table.deepcopy(animation_set)
                        
                        -- Set up the armors list to only include spaceship-armor
                        spaceship_animation_set.armors = {"spaceship-armor"}
                        
                        -- Apply grey tint to all animations in this set
                        local grey_tint = {r = 0.4, g = 0.4, b = 0.4, a = 1.0}  -- Darker grey
                        
                        -- Function to apply tint to a RotatedAnimation
                        local function apply_tint_to_animation(animation)
                            if animation then
                                if animation.layers then
                                    -- Animation has layers
                                    for _, layer in ipairs(animation.layers) do
                                        layer.tint = grey_tint
                                    end
                                elseif animation.filename then
                                    -- Single animation
                                    animation.tint = grey_tint
                                end
                            end
                        end
                        
                        -- Apply tint to all animation types
                        apply_tint_to_animation(spaceship_animation_set.idle)
                        apply_tint_to_animation(spaceship_animation_set.idle_with_gun)
                        apply_tint_to_animation(spaceship_animation_set.running)
                        apply_tint_to_animation(spaceship_animation_set.running_with_gun)
                        apply_tint_to_animation(spaceship_animation_set.mining_with_tool)
                        apply_tint_to_animation(spaceship_animation_set.flipped_shadow_running_with_gun)
                        apply_tint_to_animation(spaceship_animation_set.idle_in_air)
                        apply_tint_to_animation(spaceship_animation_set.idle_with_gun_in_air)
                        apply_tint_to_animation(spaceship_animation_set.flying)
                        apply_tint_to_animation(spaceship_animation_set.flying_with_gun)
                        apply_tint_to_animation(spaceship_animation_set.take_off)
                        apply_tint_to_animation(spaceship_animation_set.landing)
                        
                        -- Add the new grey-tinted animation set to the character
                        table.insert(character.animations, spaceship_animation_set)
                        
                        log("SpaceShipMod DEBUG: Created grey-tinted animation set for spaceship-armor!")
                        break
                    end
                end
            else
                log("SpaceShipMod DEBUG: Animation set " .. i .. " has no armors list (default/no armor)")
            end
        end
    else
        log("SpaceShipMod DEBUG: Character has no animations property")
    end
else
    log("SpaceShipMod DEBUG: Character prototype not found")
end

-- Create spaceship armor recipe (uses power-armor-mk2 ingredients since it's replacing it)
local spaceshipArmorRecipe = table.deepcopy(data.raw["recipe"]["mech-armor"])
spaceshipArmorRecipe.name = "spaceship-armor"
spaceshipArmorRecipe.results = { {type = "item", name = "spaceship-armor", amount = 1} }

-- Use the exact same ingredients as power-armor-mk2 since this is replacing it
spaceshipArmorRecipe.ingredients = {
    {type = "item", name = "efficiency-module-2", amount = 25},
    {type = "item", name = "electric-engine-unit", amount = 40},
    {type = "item", name = "low-density-structure", amount = 30},
    {type = "item", name = "processing-unit", amount = 60},
    {type = "item", name = "speed-module-2", amount = 25}
}
spaceshipArmorRecipe.energy_required = 25

data:extend({
    spaceshipArmor,
    spaceshipArmorRecipe
})

-- =============================================================================
-- RECIPE AND TECHNOLOGY MODIFICATIONS
-- =============================================================================

-- Replace power-armor-mk2 in technology effects (immediate replacements)
if data.raw.technology then
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == "power-armor-mk2" then
                    effect.recipe = "spaceship-armor"
                end
            end
        end
    end
end

-- =============================================================================
-- NOTE: Global power-armor-mk2 replacement is handled in data-final-fixes.lua
-- =============================================================================
