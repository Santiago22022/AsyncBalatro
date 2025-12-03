return {
    descriptions = {
        Mod = {
            AsyncScore = {
                name = "AsyncScore",
                text = {
                    "Asynchronous scoring optimization",
                    "Reduces lag in heavily modded games",
                    "Compatible with Cryptid and Talisman"
                }
            }
        }
    },
    misc = {
        async_score = {
            config_title = "AsyncScore Configuration",
            complexity_threshold_name = "Async Threshold",
            performance_monitoring_name = "Performance Monitoring",
            debug_logging_name = "Debug Logging",
            fallback_mode_name = "Fallback Mode",
            cache_enabled_name = "Enable Caching",
            adaptive_threshold_name = "Adaptive Threshold",
            show_overlay_name = "Performance Overlay",
            retrigger_optimization_name = "Retrigger Optimization",
            retrigger_batch_size_name = "Retrigger Batch Size",
            complexity_threshold_desc = "Number of jokers before async processing activates",
            performance_monitoring_desc = "Monitor and log performance metrics",
            debug_logging_desc = "Enable detailed debug logging to console",
            fallback_mode_desc = "Fallback to sync calculation if async fails",
            cache_enabled_desc = "Cache calculation results for repeated scenarios",
            adaptive_threshold_desc = "Automatically adjust threshold based on performance",
            show_overlay_desc = "Show performance information overlay in-game",
            retrigger_optimization_desc = "Fast retrigger processing when animations are disabled",
            retrigger_batch_size_desc = "Similar retriggers to process together",
            status_enabled = "AsyncScore: Enabled",
            status_disabled = "AsyncScore: Disabled",
            performance_good = "Performance: Good",
            performance_poor = "Performance: Poor",
            performance_critical = "Performance: Critical",
            error_calculation = "Calculation error in async mode",
            error_compatibility = "Compatibility issue detected",
            error_memory = "Memory limit exceeded",
            debug_async_started = "Async calculation started",
            debug_async_completed = "Async calculation completed",
            debug_cache_hit = "Cache hit for calculation",
            debug_cache_miss = "Cache miss for calculation",
            debug_fallback = "Falling back to synchronous calculation",
            overlay_fps = "FPS: #1#",
            overlay_frame_time = "Frame: #1#ms",
            overlay_async_percent = "Async: #1#%",
            overlay_cache_hits = "Cache: #1#%",
            overlay_joker_count = "Jokers: #1#"
        }
    }
}
