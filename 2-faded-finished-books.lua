--[[
User patch for Cover Browser plugin to add faded look for finished books in mosaic view
]]--

--========================== Edit your preferences here ================================
local fading_amount = 0.33 --Set your desired value from 0 to 1.
--======================================================================================

--========================== Do not modify this section ================================
local userpatch = require("userpatch")
local logger = require("logger")


local function patchCoverBrowserFaded(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    
    -- Store original MosaicMenuItem paintTo method
    local origMosaicMenuItemPaintTo = MosaicMenuItem.paintTo
    
    -- Override paintTo method to add faded look for finished books
    function MosaicMenuItem:paintTo(bb, x, y)
        -- Call the original paintTo method to draw the cover normally
        origMosaicMenuItemPaintTo(self, bb, x, y)
        
        -- Get the cover image widget (target)
        local target = self.cover_image or self[1]
        
        -- ADD faded look to finished books
        if target and target.dimen and self.status == "complete" and not self._fade_applied then
            -- Calculate cover position and dimensions
            local fx = x + math.floor((self.width - target.dimen.w) / 2)
            local fy = y + math.floor((self.height - target.dimen.h) / 2)
            local fw, fh = target.dimen.w, target.dimen.h
            
            -- Apply faded effect
            bb:lightenRect(fx, fy, fw, fh, fading_amount)
            self._fade_applied = true
        end
    end

    local origMosaicMenuItemInit = MosaicMenuItem.init
    function MosaicMenuItem:init(item)
        origMosaicMenuItemInit(self, item)
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserFaded)
