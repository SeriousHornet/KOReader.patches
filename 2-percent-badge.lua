--[[ User patch for KOReader to add progress percentage badges in top right corner of cover ]]
--

-- stylua: ignore start
--========================== [[Edit your preferences here]] ================================
local text_size = 0.42 -- Adjust from 0 to 1
local move_on_x = 5    -- Adjust how far left the badge should sit.
local move_on_y = -2   -- Adjust how far up the badge should sit.
local badge_w = 70     -- Adjust badge width
local badge_h = 32     -- Adjust badge height
--==========================================================================================
-- stylua: ignore end

local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local userpatch = require("userpatch")
local Screen = require("device").screen
local Blitbuffer = require("ffi/blitbuffer")
local IconWidget = require("ui/widget/iconwidget")
local logger = require("logger")

local function patchCoverBrowserProgressPercent(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    if MosaicMenuItem.patched_percent_badge then
        return
    end
    MosaicMenuItem.patched_percent_badge = true

    -- Store original MosaicMenuItem paintTo method
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

    -- Override paintTo method to add progress percentage badges
    function MosaicMenuItem:paintTo(bb, x, y)
        -- Call the original paintTo method to draw the cover normally
        orig_MosaicMenuItem_paint(self, bb, x, y)

        -- Do not add badge for directories or completed items or items without percent_finished
        if self.is_directory or self.status == "complete" or not self.percent_finished then
            return
        end

        -- Get the cover image widget
        local target = self[1][1][1]
        if not target or not target.dimen then
            return
        end

        -- Use the same corner_mark_size as the original code for consistency
        local corner_mark_size = Screen:scaleBySize(20)

        -- ADD percent badge to top right corner
        if
            (self.do_hint_opened and self.been_opened)
            or self.menu.name == "history"
            or self.menu.name == "collections"
        then
            -- Parse percent text and store as text widget
            local percent_text = string.format("%d%%", math.floor(self.percent_finished * 100))
            local font_size = math.floor(corner_mark_size * text_size)
            local percent_widget = TextWidget:new({
                text = percent_text,
                font_size = font_size,
                face = Font:getFace("cfont", font_size),
                alignment = "center",
                fgcolor = Blitbuffer.COLOR_BLACK,
                bold = true,
                max_width = corner_mark_size,
                truncate_with_ellipsis = true,
            })

            local BADGE_W = Screen:scaleBySize(badge_w) -- badge width
            local BADGE_H = Screen:scaleBySize(badge_h) -- badge height
            local INSET_X = Screen:scaleBySize(move_on_x) -- push inward from the right edge
            local INSET_Y = Screen:scaleBySize(move_on_y) -- sit on the inner top edge
            local TEXT_PAD = Screen:scaleBySize(6) -- breathing room inside the badge

            -- Outer frame
            local fx = x + math.floor((self.width - target.dimen.w) / 2)
            local fy = y + math.floor((self.height - target.dimen.h) / 2)
            local fw = target.dimen.w

            -- Badge size & position
            local percent_badge = IconWidget:new({ icon = "percent.badge", alpha = true })
            percent_badge.width = BADGE_W
            percent_badge.height = BADGE_H

            local bx = fx + fw - BADGE_W - INSET_X
            local by = fy + INSET_Y
            bx, by = math.floor(bx), math.floor(by)

            -- Paint the SVG badge
            percent_badge:paintTo(bb, bx, by)
            percent_widget.alignment = "center"
            percent_widget.truncate_with_ellipsis = false
            percent_widget.max_width = BADGE_W - 2 * TEXT_PAD

            local ts = percent_widget:getSize()
            local tx = bx + math.floor((BADGE_W - ts.w) / 2)
            local ty = by + math.floor((BADGE_H - ts.h) / 2) - Screen:scaleBySize(1) -- tiny upward nudge
            percent_widget:paintTo(bb, math.floor(tx), math.floor(ty))
        end
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserProgressPercent)
