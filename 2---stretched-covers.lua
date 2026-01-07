--[[ User patch for Project title plugin to add rounded corners to book covers ]]
--
-- Based on https://github.com/koreader/koreader/pull/11838#issuecomment-2119136574

-- stylua: ignore start
--========================== Edit your preferences here ======================================================
local aspect_ratio = 1280 / 1920    -- width / height of book covers you want
local stretch_limit_percentage = 30 -- Max percentage to stretch beyond original size to fill the aspect ratio
local fill = false                  -- if true, covers will fit the full grid cell, ignoring aspect_ratio
--============================================================================================================
-- stylua: ignore end

local ImageWidget = require("ui/widget/imagewidget")
local Size = require("ui/size")
local userpatch = require("userpatch")

local function patchBookCoverRoundedCorners(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    if MosaicMenuItem.patched_stretched_covers then
        return
    end
    MosaicMenuItem.patched_stretched_covers = true

    local ImageWidget
    local n = 1
    while true do
        local name, value = debug.getupvalue(MosaicMenuItem.update, n)
        if not name then
            break
        end
        if name == "ImageWidget" then
            ImageWidget = value
            break
        end
        n = n + 1
    end
    if not ImageWidget then
        return
    end
    local setupvalue_n = n -- we will replace it with a small subclass

    -- We can't access max_img_w/h, which are defined in MosaicMenuItem.update
    -- for each instance. We need to intercept each instantiation via :init()
    -- and compute them the same way they are computed in MosaicMenuItem.update
    local max_img_w, max_img_h
    local border_size = Size.border.thin -- defined in MosaicMenuItem:update()
    local underline_h = 1 -- defined in MosaicMenuItem:init()
    local orig_MosaicMenuItem_init = MosaicMenuItem.init
    MosaicMenuItem.init = function(self)
        -- Witnessed a crash where self.width was nil, not sure how,
        -- so better check and do less well, but better than crashing.
        if self.width and self.height then
            -- We compute and set our local upvalues, that will be used by StretchingImageWidget
            max_img_w = self.width - 2 * border_size
            max_img_h = self.height - 2 * border_size - underline_h
        end
        orig_MosaicMenuItem_init(self)
    end

    -- Small subclass of ImageWidget to force the setting we could just have inserted
    -- in mosaicmenu, as in top post of https://github.com/koreader/koreader/issues/11835
    local StretchingImageWidget = ImageWidget:extend({})
    -- (ImageWidget has no :init(), so no tedious gymnastic needed)
    StretchingImageWidget.init = function(self)
        if not max_img_w and not max_img_h then
            -- As above, do nothing if we were not able to compute them
            return
        end
        self.scale_factor = nil -- reset the one set
        self.stretch_limit_percentage = stretch_limit_percentage
        local ratio = fill and (max_img_w / max_img_h) or aspect_ratio
        if max_img_w / max_img_h > ratio then
            -- Cell is wider than target ratio → use full height
            self.height = max_img_h
            self.width = max_img_h * ratio
        else
            -- Cell is taller than target ratio → use full width
            self.width = max_img_w
            self.height = max_img_w / ratio
        end
    end

    -- Have mosaicmenu.lua's local ImageWidget be our StretchingImageWidget
    debug.setupvalue(MosaicMenuItem.update, setupvalue_n, StretchingImageWidget)
end
userpatch.registerPatchPluginFunc("coverbrowser", patchBookCoverRoundedCorners)
