--[[ Patch to stretch covers to aspect-ration and add rounded corners to book covers ]]
--

local IconWidget = require("ui/widget/iconwidget")
local logger = require("logger")
local userpatch = require("userpatch")
local Screen = require("device").screen
local Blitbuffer = require("ffi/blitbuffer")
local ImageWidget = require("ui/widget/imagewidget")
local Size = require("ui/size")

-- stylua: ignore start
--========================== [[Edit your preferences here]] ======================
-- Aspect ratio settings:
local aspect_ratio = 2 / 3          -- width / height
local stretch_limit = 50            -- Max percentage to stretch beyond original size
local Fill = false                  -- if true, covers will fit the full grid cell
--================================================================================
-- stylua: ignore end

local function patchAspectRatioWithRoundedCorners(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    if not MosaicMenuItem then
        logger.warn("Failed to find MosaicMenuItem")
        return
    end

    if MosaicMenuItem.patched_stretched_rounded_corners then
        return
    end
    MosaicMenuItem.patched_stretched_rounded_corners = true

    logger.info(string.format("Loading aspect ratio control (%.2f) with SVG rounded corners", aspect_ratio))

    local function svg_widget(icon)
        return IconWidget:new({ icon = icon, alpha = true })
    end

    local icons = {
        tl = "rounded.corner.tl",
        tr = "rounded.corner.tr",
        bl = "rounded.corner.bl",
        br = "rounded.corner.br",
    }
    local corners = {}
    for k, name in pairs(icons) do
        corners[k] = svg_widget(name)
        if not corners[k] then
            logger.warn("Failed to load SVG icon: " .. tostring(name))
        end
    end

    local _corner_w, _corner_h
    if corners.tl then
        local sz = corners.tl:getSize()
        _corner_w, _corner_h = sz.w, sz.h
    end

    if not MosaicMenuItem.patched_aspect_ratio then
        MosaicMenuItem.patched_aspect_ratio = true

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
        else
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
    end

    if not MosaicMenuItem.patched_rounded_corners then
        MosaicMenuItem.patched_rounded_corners = true

        -- Store original paint method
        local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

        function MosaicMenuItem:paintTo(bb, x, y)
            -- Call original paintTo
            if orig_MosaicMenuItem_paint then
                orig_MosaicMenuItem_paint(self, bb, x, y)
            end

            -- Only add rounded corners for books
            if self.is_directory or self.file_deleted then
                return
            end

            -- Locate the cover frame widget
            local target = self[1] and self[1][1] and self[1][1][1]
            if not target or not target.dimen then
                return
            end

            -- Calculate cover position
            local fx = x + math.floor((self.width - target.dimen.w) / 2)
            local fy = y + math.floor((self.height - target.dimen.h) / 2)
            local fw, fh = target.dimen.w, target.dimen.h

            -- Paint rounded corners if we have the SVG icons
            if corners.tl and corners.tr and corners.bl and corners.br then
                local TL, TR, BL, BR = corners.tl, corners.tr, corners.bl, corners.br

                -- Helper to get icon size
                local function get_icon_size(widget)
                    if widget and widget.getSize then
                        local s = widget:getSize()
                        return s.w, s.h
                    end
                    return 0, 0
                end

                local tlw, tlh = get_icon_size(TL)
                local trw, trh = get_icon_size(TR)
                local blw, blh = get_icon_size(BL)
                local brw, brh = get_icon_size(BR)

                -- Paint all four corners
                if TL and TL.paintTo then
                    TL:paintTo(bb, fx, fy)
                elseif TL then
                    bb:blitFrom(TL, fx, fy)
                end

                if TR and TR.paintTo then
                    TR:paintTo(bb, fx + fw - trw, fy)
                elseif TR then
                    bb:blitFrom(TR, fx + fw - trw, fy)
                end

                if BL and BL.paintTo then
                    BL:paintTo(bb, fx, fy + fh - blh)
                elseif BL then
                    bb:blitFrom(BL, fx, fy + fh - blh)
                end

                if BR and BR.paintTo then
                    BR:paintTo(bb, fx + fw - brw, fy + fh - brh)
                elseif BR then
                    bb:blitFrom(BR, fx + fw - brw, fy + fh - brh)
                end
            end
        end

        logger.info("Rounded corners applied successfully")
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchAspectRatioWithRoundedCorners)
