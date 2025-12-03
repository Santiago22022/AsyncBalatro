local PerformanceMonitor = {}

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

function PerformanceMonitor:new(config, logger)
    local obj = {
        enabled = not (config and config.performance_monitoring == false),
        frame_times = {},
        max_frame_history = 60,
        performance_threshold = config and config.performance_threshold or 1 / 30,
        poor_performance_count = 0,
        poor_performance_threshold = 5,
        calculation_times = {},
        total_calculations = 0,
        async_calculations = 0,
        sync_calculations = 0,
        last_report_time = 0,
        report_interval = config and config.report_interval or 30,
        log = logger or function() end,
        debug_enabled = config and config.debug_logging or false
    }
    setmetatable(obj, {__index = self})
    return obj
end

function PerformanceMonitor:init()
    self.frame_times = {}
    self.calculation_times = {}
    self.last_report_time = now()
end

function PerformanceMonitor:update(dt)
    if not self.enabled then
        return
    end
    if not dt then
        return
    end
    self:record_frame_time(dt)
    self:check_performance()
    self:check_report_time()
end

function PerformanceMonitor:record_frame_time(dt)
    table.insert(self.frame_times, dt)
    if #self.frame_times > self.max_frame_history then
        table.remove(self.frame_times, 1)
    end
end

function PerformanceMonitor:is_performance_poor()
    if not self.enabled then
        return false
    end
    if #self.frame_times < 10 then
        return false
    end
    local slow_frames = 0
    local recent_frames = math.min(#self.frame_times, 10)
    for i = #self.frame_times - recent_frames + 1, #self.frame_times do
        if self.frame_times[i] > self.performance_threshold then
            slow_frames = slow_frames + 1
        end
    end
    return slow_frames >= 3
end

function PerformanceMonitor:check_performance()
    if self:is_performance_poor() then
        self.poor_performance_count = self.poor_performance_count + 1
    else
        self.poor_performance_count = math.max(0, self.poor_performance_count - 1)
    end
end

function PerformanceMonitor:record_calculation(calc_type, duration, was_async)
    self.total_calculations = self.total_calculations + 1
    if was_async then
        self.async_calculations = self.async_calculations + 1
    else
        self.sync_calculations = self.sync_calculations + 1
    end
    if not self.calculation_times[calc_type] then
        self.calculation_times[calc_type] = {}
    end
    table.insert(self.calculation_times[calc_type], {
        duration = duration,
        async = was_async,
        timestamp = now()
    })
    local max_calc_history = 100
    if #self.calculation_times[calc_type] > max_calc_history then
        table.remove(self.calculation_times[calc_type], 1)
    end
end

function PerformanceMonitor:get_average_frame_time()
    if #self.frame_times == 0 then
        return 0
    end
    local total = 0
    for _, ft in ipairs(self.frame_times) do
        total = total + ft
    end
    return total / #self.frame_times
end

function PerformanceMonitor:get_fps()
    local avg_frame_time = self:get_average_frame_time()
    if avg_frame_time <= 0 then
        return 0
    end
    return 1 / avg_frame_time
end

function PerformanceMonitor:get_stats()
    return {
        fps = self:get_fps(),
        avg_frame_time = self:get_average_frame_time(),
        poor_performance_count = self.poor_performance_count,
        total_calculations = self.total_calculations,
        async_calculations = self.async_calculations,
        sync_calculations = self.sync_calculations,
        async_percentage = self.total_calculations > 0 and (self.async_calculations / self.total_calculations * 100) or 0
    }
end

function PerformanceMonitor:check_report_time()
    local current_time = now()
    if current_time - self.last_report_time >= self.report_interval then
        self:generate_report()
        self.last_report_time = current_time
    end
end

function PerformanceMonitor:generate_report()
    if not self.debug_enabled then
        return
    end
    local stats = self:get_stats()
    self.log(string.format("FPS: %.1f", stats.fps))
    self.log(string.format("Avg Frame Time: %.3fms", stats.avg_frame_time * 1000))
    self.log(string.format("Total Calculations: %d", stats.total_calculations))
    self.log(string.format("Async: %d (%.1f%%)", stats.async_calculations, stats.async_percentage))
    self.log(string.format("Sync: %d", stats.sync_calculations))
    self.log(string.format("Poor Performance Events: %d", stats.poor_performance_count))
end

function PerformanceMonitor:start_timing(calc_id)
    if not self.enabled then
        return
    end
    if not self.timing_data then
        self.timing_data = {}
    end
    self.timing_data[calc_id] = now()
end

function PerformanceMonitor:end_timing(calc_id, calc_type, was_async)
    if not self.enabled then
        return
    end
    if not self.timing_data or not self.timing_data[calc_id] then
        return
    end
    local duration = now() - self.timing_data[calc_id]
    self:record_calculation(calc_type, duration, was_async)
    self.timing_data[calc_id] = nil
end

function PerformanceMonitor:get_calculation_stats(calc_type)
    local calc_data = self.calculation_times[calc_type]
    if not calc_data or #calc_data == 0 then
        return nil
    end
    local total_duration = 0
    local async_count = 0
    local sync_count = 0
    for _, data in ipairs(calc_data) do
        total_duration = total_duration + data.duration
        if data.async then
            async_count = async_count + 1
        else
            sync_count = sync_count + 1
        end
    end
    return {
        count = #calc_data,
        avg_duration = total_duration / #calc_data,
        async_count = async_count,
        sync_count = sync_count,
        async_percentage = async_count / #calc_data * 100
    }
end

return PerformanceMonitor
