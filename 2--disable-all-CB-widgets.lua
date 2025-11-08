--[[ 
User patch for KOReader: Disable specific UI elements
This patch disables:
1. Progress bar
2. Collections star
]]--

local userpatch = require("userpatch")

local function patchDisableUIElements(plugin)
    local ProgressWidget = require("ui/widget/progresswidget")
    local MosaicMenu = require("mosaicmenu")
    local ReadCollection = require("readcollection")
    
    -- Disable progress bar and collection star
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
    
        -- Call original paint method
        orig_MosaicMenuItem_paint(self, bb, x, y)
      
        -- Restore original methods
        ProgressWidget.paintTo = orig_ProgressWidget_paint
        ReadCollection.isFileInCollections = orig_isFileInCollections
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchDisableUIElements)
