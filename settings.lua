-- =============================================================================
-- SPACESHIP MOD SETTINGS
-- =============================================================================

data:extend({
    {
        type = "bool-setting",
        name = "spaceship-show-hover-info",
        setting_type = "startup",
        default_value = false,
        order = "a[spaceship]-a[show-hover-info]"
    },
})