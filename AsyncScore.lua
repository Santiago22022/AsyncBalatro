--- STEAMODDED HEADER
--- MOD_NAME: AsyncScore
--- MOD_ID: AsyncScore
--- MOD_AUTHOR: [AsyncScore Team]
--- MOD_DESCRIPTION: Asynchronous scoring optimization mod for reducing lag in heavily modded games
--- BADGE_COLOUR: 3FC7EB
--- PREFIX: async

local function safe_load(path)
    if not SMODS or not SMODS.load_file then
        return nil
    end
    local chunk = SMODS.load_file(path)
    if type(chunk) == "table" then
        return chunk
    end
    if type(chunk) == "function" then
        local ok, mod = pcall(chunk)
        if ok then
            return mod
        end
    end
    return nil
end

local function merge_config(defaults, overrides)
    local result = {}
    if defaults then
        for k, v in pairs(defaults) do
            result[k] = v
        end
    end
    if overrides then
        for k, v in pairs(overrides) do
            result[k] = v
        end
    end
    return result
end

local function make_logger(enabled)
    return function(message, level)
        if enabled or level == "error" then
            print("[AsyncScore] " .. (level and ("[" .. level:upper() .. "] ") or "") .. tostring(message))
        end
    end
end

local default_config = safe_load("config.lua") or {}
local saved_config = SMODS.current_mod and SMODS.current_mod.config or {}
local config = merge_config(default_config, saved_config)
local logger = make_logger(config.debug_logging)

local function instantiate(mod, ...)
    if type(mod) ~= "table" then
        return nil
    end
    if type(mod.new) == "function" then
        local ok, instance = pcall(mod.new, mod, ...)
        if ok and type(instance) == "table" then
            return instance
        end
    end
    if mod.calculate_hand or mod.is_performance_poor or mod.check_mods then
        return mod
    end
    return nil
end

local AsyncCoreModule = safe_load("lib/async_core.lua") or {}
local PerformanceMonitorModule = safe_load("lib/performance_monitor.lua") or {}
local CompatibilityModule = safe_load("lib/compatibility.lua") or {}

local async_core = instantiate(AsyncCoreModule, config, logger) or {
    init = function() end,
    update = function() end,
    generate_calculation_id = function(_, cards, hand)
        local parts = {}
        if cards then
            for i, card in ipairs(cards) do
                parts[#parts + 1] = card.base and card.base.id or ("card" .. tostring(i))
            end
        end
        return table.concat(parts, "_") .. "_" .. (hand or "none")
    end,
    generate_joker_id = function(_, card, context)
        local card_id = card and card.config and card.config.center and card.config.center.key or "unknown"
        local context_type = context and context.cardarea and context.cardarea.config and context.cardarea.config.type or "unknown"
        return card_id .. "_" .. context_type
    end,
    calculate_hand = function(_, cards, hand, mult, base_mult, base_scoring, scoring_hand, original_func)
        if not original_func then
            return false, "no original calculate_hand"
        end
        local ok, result = pcall(original_func, cards, hand, mult, base_mult, base_scoring, scoring_hand)
        if not ok then
            return false, result
        end
        return true, result, {async = false}
    end,
    calculate_joker = function(_, card, context, original_func)
        if not original_func then
            return false, "no original calculate_joker"
        end
        local ok, result = pcall(original_func, card, context)
        if not ok then
            return false, result
        end
        return true, result, {async = false}
    end
}

local performance_monitor = instantiate(PerformanceMonitorModule, config, logger) or {
    init = function() end,
    update = function() end,
    is_performance_poor = function() return false end,
    start_timing = function() end,
    end_timing = function() end
}

local compatibility = instantiate(CompatibilityModule, config, logger) or {
    check_mods = function() end,
    is_cryptid_joker = function() return false end
}

AsyncScore = {
    config = config,
    async_core = async_core,
    performance_monitor = performance_monitor,
    compatibility = compatibility,
    version = "1.1.0",
    enabled = config.enabled ~= false,
    debug = config.debug_logging or false,
    original_calculate_hand = nil,
    original_calculate_joker = nil,
    logger = logger
}

function AsyncScore:init()
    self.performance_monitor:init()
    self.compatibility:check_mods()
    self:hook_scoring_system()
    self:setup_config_ui()
end

function AsyncScore:hook_scoring_system()
    if not calculate_hand then
        self.logger("calculate_hand missing", "error")
        self.enabled = false
        return
    end
    if not self.original_calculate_hand then
        self.original_calculate_hand = calculate_hand
    end
    calculate_hand = function(cards, hand, mult, base_mult, base_scoring, scoring_hand)
        if not AsyncScore.enabled then
            return AsyncScore.original_calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand)
        end
        return AsyncScore:handle_calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand)
    end
    if calculate_joker then
        if not self.original_calculate_joker then
            self.original_calculate_joker = calculate_joker
        end
        calculate_joker = function(card, context)
            if not AsyncScore.enabled then
                return AsyncScore.original_calculate_joker(card, context)
            end
            return AsyncScore:handle_calculate_joker(card, context)
        end
    end
end

function AsyncScore:should_use_async(cards, hand)
    local joker_count = G.jokers and #G.jokers.cards or 0
    local complexity_threshold = self.config.complexity_threshold or 10
    if joker_count >= complexity_threshold then
        return true
    end
    return self.performance_monitor:is_performance_poor()
end

function AsyncScore:should_use_async_joker(card, context)
    if self.compatibility:is_cryptid_joker(card) then
        return true
    end
    return self.performance_monitor:is_performance_poor()
end

function AsyncScore:setup_config_ui()
    if SMODS.current_mod and SMODS.current_mod.config_tab then
        local config_tab = SMODS.current_mod.config_tab
        config_tab:add_setting({
            id = "complexity_threshold",
            name = "Async Threshold",
            desc = "Number of jokers before async processing kicks in",
            type = "slider",
            min = 5,
            max = 50,
            default = 10,
            step = 1
        })
        config_tab:add_setting({
            id = "performance_monitoring",
            name = "Performance Monitoring",
            desc = "Monitor and log performance metrics",
            type = "toggle",
            default = true
        })
        config_tab:add_setting({
            id = "debug_logging",
            name = "Debug Logging",
            desc = "Enable detailed debug logging",
            type = "toggle",
            default = false
        })
        config_tab:add_setting({
            id = "fallback_mode",
            name = "Fallback Mode",
            desc = "Automatically fallback to sync calculation if async fails",
            type = "toggle",
            default = true
        })
        config_tab:add_setting({
            id = "retrigger_optimization",
            name = "Retrigger Optimization",
            desc = "Fast retrigger processing (requires Talisman's 'Disable Scoring Animations')",
            type = "toggle",
            default = true
        })
        config_tab:add_setting({
            id = "retrigger_batch_size",
            name = "Retrigger Batch Size",
            desc = "Maximum number of retriggers to process together",
            type = "slider",
            min = 5,
            max = 50,
            default = 10,
            step = 1
        })
    end
end

function AsyncScore:update(dt)
    if not self.enabled then return end
    self.async_core:update(dt or 0)
    self.performance_monitor:update(dt)
end

function AsyncScore:handle_calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand)
    if not self.original_calculate_hand then
        return nil
    end
    if not self:should_use_async(cards, hand) then
        return self.original_calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand)
    end
    local calc_id = self.async_core:generate_calculation_id(cards, hand)
    self.performance_monitor:start_timing(calc_id)
    local ok, result, meta = self.async_core:calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand, self.original_calculate_hand)
    self.performance_monitor:end_timing(calc_id, "hand", meta and meta.async)
    if not ok then
        self.logger(result, "error")
        return self.original_calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand)
    end
    return result
end

function AsyncScore:handle_calculate_joker(card, context)
    if not self.original_calculate_joker then
        return nil
    end
    if not self:should_use_async_joker(card, context) then
        return self.original_calculate_joker(card, context)
    end
    local calc_id = self.async_core:generate_joker_id(card, context)
    self.performance_monitor:start_timing(calc_id)
    local ok, result, meta = self.async_core:calculate_joker(card, context, self.original_calculate_joker)
    self.performance_monitor:end_timing(calc_id, "joker", meta and meta.async)
    if not ok then
        self.logger(result, "error")
        return self.original_calculate_joker(card, context)
    end
    return result
end

AsyncScore:init()

return AsyncScore
