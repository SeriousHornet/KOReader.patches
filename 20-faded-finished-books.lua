--[[ User patch for Project: Title plugin to add faded look for finished books in mosaic view ]]
--

--========================== Edit your preferences here ================================
local fading_amount = 0.5 --Set your desired value from 0 to 1.
--======================================================================================

--========================== Do not modify this section ================================
local logger = require("logger")
local userpatch = require("userpatch")

local function patchCoverBrowserFaded(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    if MosaicMenuItem.patched_faded_finished then
        return
    end
    MosaicMenuItem.patched_faded_finished = true

    -- Store original MosaicMenuItem paintTo method
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

    function MosaicMenuItem:paintTo(bb, x, y)
        -- Paint normally first (covers + rounded corners)
        if orig_MosaicMenuItem_paint then
        orig_MosaicMenuItem_paint(self, bb, x, y)   
        end

        -- Only apply fade once per item using a flag
        if self.status == "complete" then

            -- finds the actual cover image widget e.g. if stretched to new aspect ratio
            local target = self[1] and self[1][1] and self[1][1][1]

            -- The fade rectangle exactly matches the visible cover size. Rounded corners align correctly.
            if target and target.dimen then
                local tw = target.dimen.w
                local th = target.dimen.h

                -- Centered position
                local fx = x + math.floor((self.width - tw) / 2)
                local fy = y + math.floor((self.height - th) / 2)

                -- Apply the fade only once
                bb:lightenRect(fx, fy, tw, th, fading_amount)
                -- fading_amount = 0
            end
        end
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserFaded)
