--[[ User patch for Project: Title plugin to add faded look for finished books in mosaic view ]]--

--========================== Edit your preferences here ================================
local fading_amount = 0.5 --Set your desired value from 0 to 1.
--======================================================================================

--========================== Do not modify this section ================================
local userpatch = require("userpatch")
local logger = require("logger")

local function patchCoverBrowserFaded(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    
    -- Store original MosaicMenuItem paintTo method
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo
    
    function MosaicMenuItem:paintTo(bb, x, y)
        -- Paint normally first
        orig_MosaicMenuItem_paint(self, bb, x, y)

        -- Only apply fade once per item using a flag
        if self.status == "complete" then
            -- Try to locate the same "target" the base code uses
            local target = nil
            if self[1] and self[1][1] and self[1][1][1] then
                target = self[1][1][1]
            end

            if target then
                -- Compute outer frame rect
                local has_wh = (target.width and target.height)
                local has_dimen = (target.dimen and target.dimen.w and target.dimen.h)

                local tw = has_wh and target.width  or (has_dimen and target.dimen.w) or self.width
                local th = has_wh and target.height or (has_dimen and target.dimen.h) or self.height

                -- Centered position
                local fx = x + math.floor((self.width  - tw) / 2)
                local fy = y + math.floor((self.height - th) / 2)

                -- Apply the fade only once
                bb:lightenRect(fx, fy, tw, th, fading_amount)
                -- fading_amount = 0
            end
        end
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserFaded)
