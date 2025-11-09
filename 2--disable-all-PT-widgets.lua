--[[ 
User patch for Project: Title - Disable specific UI elements
This patch disables:
1. Progress-related icons (trophy, pause, new, large_book)
2. progress-related widgets
3. Status widgets (complete/abandoned frames) 
4. Cover borders
5. Series indicators
]]--

local userpatch = require("userpatch")
local logger = require("logger")

local function patchDisableUIElements(plugin)
    local Device = require("device")
    local Screen = Device.screen
    local Blitbuffer = require("ffi/blitbuffer")
    local ImageWidget = require("ui/widget/imagewidget")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local TextWidget = require("ui/widget/textwidget")
    local ProgressWidget = require("ui/widget/progresswidget")
    local Size = require("ui/size")
    local MosaicMenu = require("mosaicmenu")
    local ptutil = require("ptutil")
    local BookInfoManager = require("bookinfomanager")
    
    -- Store original methods
    local orig_ImageWidget_paint = ImageWidget.paintTo
    local orig_FrameContainer_paint = FrameContainer.paintTo
    local orig_TextWidget_paint = TextWidget.paintTo
    local plugin_dir = ptutil.getPluginDir()
    
    -- Disable progress-related icons
    ImageWidget.paintTo = function(self, bb, x, y)
        if self.file then
            if self.file:match("/resources/trophy%.svg$") or 
                self.file:match("/resources/pause%.svg$") or 
                self.file:match("/resources/new%.svg$") or 
                self.file:match("/resources/large_book%.svg$") then
                return
            end
        end
        return orig_ImageWidget_paint(self, bb, x, y)
    end
    
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo
    
    function MosaicMenuItem:paintTo(bb, x, y)
        
        -- Disable cover borders
        local target = self[1][1][1]
        local original_properties = {}
        
        if target then
            original_properties.bordersize = target.bordersize
            original_properties.background = target.background  
            original_properties.color = target.color
            original_properties.padding = target.padding
    
            target.bordersize = 0
            target.background = nil
            target.color = nil
            target.padding = 0
        end
        
        -- Store original reading status
        local original_status = self.status
        local original_percent = self.percent_finished
        local original_progress_bar = self.show_progress_bar
        
        -- Clear reading status temporarily
        self.status = nil
        self.percent_finished = nil
        self.show_progress_bar = false
        
        -- Disable Progress Bar
        local orig_ProgressWidget_paint = ProgressWidget.paintTo
        ProgressWidget.paintTo = function() end
    
        -- Store original getSetting method
        local original_getSetting = BookInfoManager.getSetting
        local original_saveSetting = BookInfoManager.saveSetting
        --local orig_series_mode = BookInfoManager:getSetting("series_mode")
        
        
        -- Override getSetting to always return disabled state for these settings
        BookInfoManager.getSetting = function(self, setting_name)
            if setting_name == "hide_file_info" then
                return true
            elseif setting_name == "show_pages_read_as_progress" then
                return false
            elseif setting_name == "series_mode" then
                return nil
            else
                return original_getSetting(self, setting_name)
            end
        end
        
        BookInfoManager.saveSetting = function(self, setting_name, value)
            if setting_name == "hide_file_info" then
                return original_saveSetting(self, setting_name, true)
            elseif setting_name == "show_pages_read_as_progress" then
                return original_saveSetting(self, setting_name, false)
            else
                return original_saveSetting(self, setting_name, value)
            end
        end
        
        -- Set initial state
        BookInfoManager:saveSetting("hide_file_info", true)
        BookInfoManager:saveSetting("show_pages_read_as_progress", false)

        -- Call original paint method
        orig_MosaicMenuItem_paint(self, bb, x, y)
        
        -- Restore everything
        if target and original_properties.bordersize then
            target.bordersize = original_properties.bordersize
            target.background = original_properties.background
            target.color = original_properties.color
            target.padding = original_properties.padding
        end
        
        -- Restore original status
        self.status = original_status
        self.percent_finished = original_percent
        self.show_progress_bar = original_progress_bar
        
        ProgressWidget.paintTo = orig_ProgressWidget_paint
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchDisableUIElements)
