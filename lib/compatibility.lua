local Compatibility = {}

function Compatibility:new()
    local obj = {
        cryptid_detected = false,
        talisman_detected = false,
        cryptid_jokers = {},
        known_complex_jokers = {}
    }
    setmetatable(obj, {__index = self})
    return obj
end

function Compatibility:check_mods()
    if SMODS and SMODS.Mods then
        for mod_id, mod in pairs(SMODS.Mods) do
            if mod_id == "Cryptid" or (mod.name and string.find(mod.name:lower(), "cryptid")) then
                self.cryptid_detected = true
                self:setup_cryptid_compatibility()
            end
            if mod_id == "Talisman" or (mod.name and string.find(mod.name:lower(), "talisman")) then
                self.talisman_detected = true
                self:setup_talisman_compatibility()
            end
        end
    end
    if not self.cryptid_detected then
        self:detect_cryptid_fallback()
    end
    if not self.talisman_detected then
        self:detect_talisman_fallback()
    end
end

function Compatibility:setup_cryptid_compatibility()
    self.cryptid_jokers = {
        "cry_m",
        "cry_jimball",
        "cry_sus",
        "cry_impostor",
        "cry_unjust_dagger",
        "cry_compound_interest",
        "cry_monkey_dagger",
        "cry_exponentia",
        "cry_mprime",
        "cry_big_jimbo",
        "cry_stellar",
        "cry_morse",
        "cry_unity",
        "cry_sacrifice",
        "cry_flip_side",
        "cry_canvas",
        "cry_error",
        "cry_membership_card",
        "cry_lucky_joker",
        "cry_seal_the_deal",
        "cry_curse",
        "cry_oldblueprint"
    }
    for _, joker_key in ipairs(self.cryptid_jokers) do
        self.known_complex_jokers[joker_key] = true
    end
end

function Compatibility:setup_talisman_compatibility()
    if to_big and from_big then
        self.big_num_support = true
    end
    if to_omega and from_omega then
        self.omega_num_support = true
    end
end

function Compatibility:detect_cryptid_fallback()
    if G and G.P_CENTERS then
        for key, _ in pairs(G.P_CENTERS) do
            if string.find(key, "cry_") == 1 or string.find(key, "cryptid") then
                self.cryptid_detected = true
                self:setup_cryptid_compatibility()
                break
            end
        end
    end
end

function Compatibility:detect_talisman_fallback()
    if to_big or from_big or to_omega or from_omega then
        self.talisman_detected = true
        self:setup_talisman_compatibility()
    end
end

function Compatibility:is_cryptid_joker(card)
    if not card or not card.config or not card.config.center then
        return false
    end
    local key = card.config.center.key
    if not key then
        return false
    end
    if self.known_complex_jokers[key] then
        return true
    end
    return string.find(key, "cry_") == 1 or string.find(key, "cryptid") or string.find(key, "m_") == 1
end

function Compatibility:is_complex_joker(card)
    if not card then
        return false
    end
    if self:is_cryptid_joker(card) then
        return true
    end
    local key = card.config and card.config.center and card.config.center.key
    if key then
        if string.find(key:lower(), "exponential") or string.find(key:lower(), "factorial") or string.find(key:lower(), "fibonacci") or string.find(key:lower(), "compound") or string.find(key:lower(), "recursive") then
            return true
        end
    end
    return false
end

function Compatibility:safe_number_convert(value, target_type)
    if not self.talisman_detected then
        return value
    end
    target_type = target_type or "number"
    if target_type == "big" and to_big then
        return to_big(value)
    elseif target_type == "omega" and to_omega then
        return to_omega(value)
    elseif target_type == "number" then
        if from_big and type(value) == "table" and value.array then
            return from_big(value)
        elseif from_omega and type(value) == "table" and value.sign then
            return from_omega(value)
        end
    end
    return value
end

return Compatibility
