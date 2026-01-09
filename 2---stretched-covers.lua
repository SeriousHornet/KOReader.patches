--[[ Patch to stretch the book covers to set aspect-ratio ]]
--

-- stylua: ignore start
--========================== Edit your preferences here ======================================================
local aspect_ratio = 2 / 3          -- width / height
local stretch_limit_percentage = 50 -- Max percentage to stretch beyond original size
local fill = false                  -- if true, covers will fit the full grid cell
--============================================================================================================
-- stylua: ignore end

local ImageWidget = require("ui/widget/imagewidget")
local Size = require("ui/size")
local logger = require("logger")
local userpatch = require("userpatch")

local function patchBookCoverRoundedCorners(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    if MosaicMenuItem.patched_stretched_covers then
        return
    end
    MosaicMenuItem.patched_stretched_covers = true

    -- Find the local ImageWidget in the closure
    local local_ImageWidget
    local n = 1
    while true do
        local name, value = debug.getupvalue(MosaicMenuItem.update, n)
        if not name then
            break
        end
        if name == "ImageWidget" then
            local_ImageWidget = value
            break
        end
        n = n + 1
    end

    if not local_ImageWidget then
        logger.warn("Could not find ImageWidget in MosaicMenuItem.update closure")
        return
    end

    local setupvalue_n = n

    -- Get the original init method
    local orig_MosaicMenuItem_init = MosaicMenuItem.init
    local max_img_w, max_img_h

    -- Override init to store dimensions per instance
    function MosaicMenuItem:init()
        if self.width and self.height then
            -- Store dimensions for this specific instance
            local border_size = Size.border.thin

            -- Calculate available space for the image
            max_img_w = self.width - 2 * border_size -- Available width inside border
            max_img_h = self.height - 2 * border_size -- Available height inside border
        end

        -- Call original init
        if orig_MosaicMenuItem_init then
            orig_MosaicMenuItem_init(self)
        end
    end

    -- Create custom ImageWidget subclass
    local StretchingImageWidget = local_ImageWidget:extend({})

    StretchingImageWidget.init = function(self)
        -- Call original ImageWidget init if it exists
        if local_ImageWidget.init then
            local_ImageWidget.init(self)
        end
        if not max_img_w and not max_img_h then
            -- As above, do nothing if we were not able to compute them
            return
        end
        -- Reset scale factor
        self.scale_factor = nil

        -- Set stretch limit
        self.stretch_limit_percentage = stretch_limit

        -- Calculate dimensions based on aspect ratio
        local ratio = Fill and (max_img_w / max_img_h) or aspect_ratio

        if max_img_w / max_img_h > ratio then
            -- Cell is wider than target ratio - use full height
            self.height = max_img_h
            self.width = max_img_h * ratio
        else
            -- Cell is taller than target ratio - use full width
            self.width = max_img_w
            self.height = max_img_w / ratio
        end
    end

    -- Replace the local ImageWidget with our custom one
    debug.setupvalue(MosaicMenuItem.update, setupvalue_n, StretchingImageWidget)

    logger.info("Aspect ratio control applied successfully")
end
userpatch.registerPatchPluginFunc("coverbrowser", patchBookCoverRoundedCorners)
