local AsyncCore = {}

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

function AsyncCore:new(config, logger)
    local obj = {
        config = config or {},
        log = logger or function() end,
        results_cache = {},
        cache_order = {},
        cache_size_limit = config and config.cache_size_limit or 1000,
        cache_ttl = config and config.cache_ttl or 300,
        retrigger_batch_size = config and config.retrigger_batch_size or 10,
        retrigger_batch_timeout = config and config.retrigger_batch_timeout or 0.1,
        retrigger_optimization = not (config and config.retrigger_optimization == false),
        safe_retrigger_caching = not (config and config.safe_retrigger_caching == false)
    }
    setmetatable(obj, {__index = self})
    obj:init()
    return obj
end

function AsyncCore:init()
    self.results_cache = {}
    self.cache_order = {}
end

function AsyncCore:update(dt)
    self:cleanup_cache()
end

function AsyncCore:cleanup_cache()
    local ttl = self.cache_ttl
    local current = now()
    if ttl and ttl > 0 then
        local expired = {}
        for id, entry in pairs(self.results_cache) do
            if entry.expires and entry.expires <= current then
                table.insert(expired, id)
            end
        end
        for _, id in ipairs(expired) do
            self.results_cache[id] = nil
        end
    end
    if self.cache_size_limit and self.cache_size_limit > 0 then
        local size = 0
        for _ in pairs(self.results_cache) do
            size = size + 1
        end
        if size > self.cache_size_limit then
            local remove_count = size - self.cache_size_limit
            local removed = 0
            for _, id in ipairs(self.cache_order) do
                if self.results_cache[id] then
                    self.results_cache[id] = nil
                    removed = removed + 1
                    if removed >= remove_count then
                        break
                    end
                end
            end
            self.cache_order = {}
            for id in pairs(self.results_cache) do
                table.insert(self.cache_order, id)
            end
        end
    end
end

function AsyncCore:store_cache(id, result, opts)
    if self.config.enable_caching == false then
        return
    end
    local expires = self.cache_ttl and self.cache_ttl > 0 and (now() + self.cache_ttl) or nil
    self.results_cache[id] = {
        result = result,
        expires = expires,
        retriggerable = opts and opts.retriggerable or false,
        talisman_fast_mode = opts and opts.talisman_fast_mode or false
    }
    table.insert(self.cache_order, id)
end

function AsyncCore:get_cached(id, opts)
    if self.config.enable_caching == false then
        return nil
    end
    local entry = self.results_cache[id]
    if not entry then
        return nil
    end
    if entry.expires and entry.expires <= now() then
        self.results_cache[id] = nil
        return nil
    end
    if opts and opts.require_retriggerable and not entry.retriggerable then
        return nil
    end
    if opts and opts.require_fast_mode and not entry.talisman_fast_mode then
        return nil
    end
    return entry.result
end

function AsyncCore:calculate_hand(cards, hand, mult, base_mult, base_scoring, scoring_hand, original_func)
    local id = self:generate_calculation_id(cards, hand)
    local cached = self:get_cached(id)
    if cached then
        return true, cached, {cache = true}
    end
    local ok, result = pcall(original_func, cards, hand, mult, base_mult, base_scoring, scoring_hand)
    if not ok then
        return false, result
    end
    self:store_cache(id, result, {retriggerable = false})
    return true, result, {async = false}
end

function AsyncCore:calculate_joker(card, context, original_func)
    local id = self:generate_joker_id(card, context)
    local is_retrigger = context and context.retrigger_joker
    local talisman_fast_mode = self:is_talisman_fast_mode_enabled()
    local cached = self:get_cached(id, {require_retriggerable = is_retrigger, require_fast_mode = talisman_fast_mode})
    if cached then
        return true, cached, {cache = true}
    end
    local ok, result = pcall(original_func, card, context)
    if not ok then
        return false, result
    end
    if self:should_cache_joker(card, is_retrigger, talisman_fast_mode) then
        self:store_cache(id, result, {retriggerable = is_retrigger, talisman_fast_mode = talisman_fast_mode})
    end
    return true, result, {async = false}
end

function AsyncCore:should_cache_joker(card, is_retrigger, talisman_fast_mode)
    if self.config.enable_caching == false then
        return false
    end
    if is_retrigger and self.retrigger_optimization then
        if talisman_fast_mode and self.safe_retrigger_caching then
            return self:is_retrigger_safe(card)
        end
        return false
    end
    return true
end

function AsyncCore:is_retrigger_safe(card)
    local key = card and card.config and card.config.center and card.config.center.key
    if not key then
        return false
    end
    local safe_keys = {
        j_joker = true, j_greedy_joker = true, j_lusty_joker = true, j_wrathful_joker = true,
        j_glutton_joker = true, j_jolly_joker = true, j_zany_joker = true, j_mad_joker = true,
        j_crazy_joker = true, j_droll_joker = true, j_sly_joker = true, j_wily_joker = true,
        j_clever_joker = true, j_devious_joker = true, j_crafty_joker = true
    }
    if safe_keys[key] then
        return true
    end
    local safe_prefixes = {"cry_", "m_"}
    for _, prefix in ipairs(safe_prefixes) do
        if string.find(key, prefix) == 1 then
            return true
        end
    end
    return false
end

function AsyncCore:generate_calculation_id(cards, hand)
    local parts = {}
    if cards then
        for i, card in ipairs(cards) do
            parts[#parts + 1] = card.base and card.base.id or ("card" .. tostring(i))
        end
    end
    return table.concat(parts, "_") .. "_" .. (hand or "none")
end

function AsyncCore:generate_joker_id(card, context)
    local card_id = card and card.config and card.config.center and card.config.center.key or "unknown"
    local context_type = context and context.cardarea and context.cardarea.config and context.cardarea.config.type or "unknown"
    local retrigger_tag = context and context.retrigger_joker and "_retrigger" or ""
    return card_id .. "_" .. context_type .. retrigger_tag
end

function AsyncCore:is_talisman_fast_mode_enabled()
    if G and G.SETTINGS and G.SETTINGS.TALISMAN then
        local talisman_settings = G.SETTINGS.TALISMAN
        if talisman_settings.disable_anims or talisman_settings.disable_scoring_anims or talisman_settings.fast_scoring then
            return true
        end
    end
    if SMODS and SMODS.Mods and SMODS.Mods.Talisman then
        local talisman_mod = SMODS.Mods.Talisman
        if talisman_mod.config and talisman_mod.config.disable_anims then
            return true
        end
    end
    if G and G.SETTINGS then
        if G.SETTINGS.fast_play or G.SETTINGS.reduced_motion or G.SETTINGS.disable_bg_anims then
            return true
        end
    end
    return false
end

return AsyncCore
