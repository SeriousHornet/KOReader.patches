--[[ User patch for KOReader to add custom rounded progress bar with green/red colors ]]
--

local userpatch = require("userpatch")
local Screen = require("device").screen
local Blitbuffer = require("ffi/blitbuffer")
local logger = require("logger")

-- stylua: ignore start
--========================== Edit your preferences here ================================
local BAR_H = Screen:scaleBySize(9) -- bar height
local BAR_RADIUS = Screen:scaleBySize(3) -- rounded ends
local INSET_X = Screen:scaleBySize(6) -- from inner cover edges
local INSET_Y = Screen:scaleBySize(12) -- from bottom inner edge
local GAP_TO_ICON = Screen:scaleBySize(0) -- gap before corner icon
local TRACK_COLOR = Blitbuffer.COLOR_LIGHT_GRAY -- bar track color (grayscale)
local FILL_COLOR = {0x4C, 0xAF, 0x50} -- Material Green (RGB components)
local ABANDONED_COLOR = {0xF4, 0x43, 0x36} -- Material Red (RGB components)
local BORDER_W = Screen:scaleBySize(0.5) -- border width around track (0 to disable)
local BORDER_COLOR = Blitbuffer.COLOR_BLACK -- border color
--======================================================================================
-- stylua: ignore end

-- Custom colored progress bar using RGB32
local function paintRoundedRectRGB32(bb, x, y, w, h, color, radius)
    if not color or type(color) ~= "table" then
        bb:paintRoundedRect(x, y, w, h, Blitbuffer.COLOR_BLACK, radius)
        return
    end

    -- Create a temporary buffer for the colored rectangle
    local tmp_bb = Blitbuffer.new(w, h)
    tmp_bb:paintRoundedRect(0, 0, w, h, Blitbuffer.COLOR_WHITE, radius)

    -- Blit with color tint
    bb:colorblitFromRGB32(tmp_bb, x, y, 0, 0, w, h, Blitbuffer.ColorRGB32(color[1], color[2], color[3], 0xFF))

    tmp_bb:free()
end

local function patchCustomProgress(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    if MosaicMenuItem.patched_new_progress_bar then
        return
    end
    MosaicMenuItem.patched_new_progress_bar = true

    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

    -- Corner mark size (fallback if not found)
    local corner_mark_size =
        userpatch.getUpValue(orig_MosaicMenuItem_paint, "corner_mark_size") or Screen:scaleBySize(24)

    local function I(v)
        return math.floor(v + 0.5)
    end

    function MosaicMenuItem:paintTo(bb, x, y)
        orig_MosaicMenuItem_paint(self, bb, x, y)

        -- Locate the cover frame
        local target = self[1][1][1]

        -- Use the real percent
        local pf = self.percent_finished
        if not target or not target.dimen or not pf then
            return
        end

        -- Only show progress bar for non-complete books
        if self.status == "complete" then
            return
        end

        -- Outer cover rect; then inner content rect
        local fx = x + math.floor((self.width - target.dimen.w) / 2)
        local fy = y + math.floor((self.height - target.dimen.h) / 2)
        local fw, fh = target.dimen.w, target.dimen.h

        local b = target.bordersize or 0
        local pad = target.padding or 0
        local ix = fx + b + pad
        local iy = fy + b + pad
        local iw = fw - 2 * (b + pad)
        local ih = fh - 2 * (b + pad)

        -- Horizontal span inside the cover
        local left = ix + INSET_X
        local right = ix + iw - INSET_X

        -- Shorten for corner icon if present
        local has_corner_icon =
            (self.been_opened or self.do_hint_opened) and (self.status == "reading" or self.status == "abandoned")
        if has_corner_icon then
            right = right - (corner_mark_size + GAP_TO_ICON)
        end

        -- Bar rect
        local bar_w = math.max(1, right - left)
        local bar_h = BAR_H
        local bar_x = I(left)
        local bar_y = I(iy + ih - INSET_Y - bar_h)

        -- Border
        bb:paintRoundedRect(
            bar_x - BORDER_W,
            bar_y - BORDER_W,
            bar_w + 2 * BORDER_W,
            bar_h + 2 * BORDER_W,
            BORDER_COLOR,
            BAR_RADIUS + BORDER_W
        )

        -- Track (grayscale)
        bb:paintRoundedRect(bar_x, bar_y, bar_w, bar_h, TRACK_COLOR, BAR_RADIUS)

        -- Fill (color: green for reading, red for abandoned)
        local p = math.max(0, math.min(1, pf))
        local fw_w = math.max(1, math.floor(bar_w * p + 0.5))
        local fill_color = (self.status == "abandoned") and ABANDONED_COLOR or FILL_COLOR

        -- Use RGB32 color rendering
        paintRoundedRectRGB32(bb, bar_x, bar_y, fw_w, bar_h, fill_color, BAR_RADIUS)
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCustomProgress)
