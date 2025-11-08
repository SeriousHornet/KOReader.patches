--[[ 
User patch for KOReader to disable specific UI elements
This patch disables:
1. Progress bar
2. Collections star
3. Description hint (permanently)
]]--

local userpatch = require("userpatch")

local function patchDisableUIElements(plugin)
    local ProgressWidget = require("ui/widget/progresswidget")
    local MosaicMenu = require("mosaicmenu")
    local ReadCollection = require("readcollection")
    local BookInfoManager = require("bookinfomanager")
    
    -- Disable progress bar, collection star, and description hint
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo
    
    function MosaicMenuItem:paintTo(bb, x, y)
        -- Store original methods
        local orig_ProgressWidget_paint = ProgressWidget.paintTo
        local orig_isFileInCollections = ReadCollection.isFileInCollections
        
        -- Disable Progress Bar
        ProgressWidget.paintTo = function() end
        
        -- Disable Collection Star by making isFileInCollections always return false
        ReadCollection.isFileInCollections = function(filepath)
            return false
        end
        
        -- Permanently disable description hint by overriding the setting check
        local orig_getSetting = BookInfoManager.getSetting
        BookInfoManager.getSetting = function(self, setting_name)
            if setting_name == "no_hint_description" then
                return true
            end
            return orig_getSetting(self, setting_name)
        end
    
        -- Call original paint method
        orig_MosaicMenuItem_paint(self, bb, x, y)
      
        -- Restore original methods (but keep description hint permanently disabled)
        ProgressWidget.paintTo = orig_ProgressWidget_paint
        ReadCollection.isFileInCollections = orig_isFileInCollections
        BookInfoManager.getSetting = orig_getSetting
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchDisableUIElements)
