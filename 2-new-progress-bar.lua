--[[
User patch for Cover Browser plugin to increase progress widget height
]]--

local userpatch = require("userpatch")

local function patchCoverBrowserProgressHeight(plugin)
    local MosaicMenu = require("mosaicmenu")
    
    -- Hijack the progress widget creation by patching the method that contains it
    local originalUpdateItemsBuildUI = MosaicMenu._updateItemsBuildUI
    
    function MosaicMenu:_updateItemsBuildUI(...)
        -- First, ensure _recalculateDimen is called and creates the widget
        if not userpatch.getUpValue(originalUpdateItemsBuildUI, "progress_widget") then
            self:_recalculateDimen()
        end
        
        -- Now modify the progress_widget height
        local progress_widget = userpatch.getUpValue(originalUpdateItemsBuildUI, "progress_widget")
        if progress_widget then
            local Screen = require("device").screen
            progress_widget.height = Screen:scaleBySize(12) -- Increase height
        end
        
        -- Call original function
        return originalUpdateItemsBuildUI(self, ...)
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserProgressHeight)