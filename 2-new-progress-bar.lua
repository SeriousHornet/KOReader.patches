--[[ User patch for KOReader to add custom rounded progress bar ]]--

local userpatch   = require("userpatch")
local logger      = require("logger")
local Screen      = require("device").screen
local Blitbuffer  = require("ffi/blitbuffer")
local ProgressWidget = require("ui/widget/progresswidget")
local ImageWidget = require("ui/widget/imagewidget")
local FrameContainer = require("ui/widget/container/framecontainer")

--========================== Edit your preferences here ================================
local BAR_H       = Screen:scaleBySize(9)    -- bar height
local BAR_RADIUS  = Screen:scaleBySize(3)    -- rounded ends
local INSET_X     = Screen:scaleBySize(6)    -- from inner cover edges
local INSET_Y     = Screen:scaleBySize(12)   -- from bottom inner edge
local GAP_TO_ICON = Screen:scaleBySize(0)    -- gap before corner icon
local TRACK_COLOR = Blitbuffer.colorFromString("#F4F0EC")  -- bar color
local FILL_COLOR  = Blitbuffer.colorFromString("#555555")   -- fill color
local ABANDONED_COLOR = Blitbuffer.colorFromString("#C0C0C0") -- fill when abandoned/paused
local BORDER_W    = Screen:scaleBySize(0.5)    -- border width around track (0 to disable)
local BORDER_COLOR = Blitbuffer.COLOR_BLACK  -- border color
--======================================================================================

--========================== Do not modify this section ================================
local function patchCustomProgress(plugin)
	local MosaicMenu     = require("mosaicmenu")
	local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

	local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

	-- Corner mark size (fallback if not found)
	local corner_mark_size = userpatch.getUpValue(orig_MosaicMenuItem_paint, "corner_mark_size") or Screen:scaleBySize(24)

	local function I(v) return math.floor(v + 0.5) end

	function MosaicMenuItem:paintTo(bb, x, y)
	
		orig_MosaicMenuItem_paint(self, bb, x, y)
		
		-- Locate the cover frame
		local target = self[1][1][1]

		-- Use the real percent
		local pf = self.percent_finished
		if not target or not target.dimen or not pf then return end

		-- Outer cover rect; then inner content rect
		local fx = x + math.floor((self.width  - target.dimen.w) / 2)
		local fy = y + math.floor((self.height - target.dimen.h) / 2)
		local fw, fh = target.dimen.w, target.dimen.h

		local b   = target.bordersize or 0
		local pad = target.padding    or 0
		local ix  = fx + b + pad
		local iy  = fy + b + pad
		local iw  = fw - 2 * (b + pad)
		local ih  = fh - 2 * (b + pad)

		-- Horizontal span inside the cover
		local left  = ix + INSET_X
		local right = ix + iw - INSET_X

		-- Shorten for corner icon if present
		local has_corner_icon =
		  (self.been_opened or self.do_hint_opened)
		  and (self.status == "reading" or self.status == "complete" or self.status == "abandoned")
		if has_corner_icon then
		  right = right - (corner_mark_size + GAP_TO_ICON)
		end

		-- Bar rect
		local bar_w = math.max(1, right - left)
		local bar_h = BAR_H
		local bar_x = I(left)
		local bar_y = I(iy + ih - INSET_Y - bar_h)
		
		if self.status ~= "complete" then
			-- Border
			bb:paintRoundedRect(bar_x - BORDER_W, bar_y - BORDER_W, bar_w + 2*BORDER_W, bar_h + 2*BORDER_W, BORDER_COLOR, BAR_RADIUS + BORDER_W)

			-- Track
			bb:paintRoundedRect(bar_x, bar_y, bar_w, bar_h, TRACK_COLOR, BAR_RADIUS)
		
			-- Fill
			local p = math.max(0, math.min(1, pf))
			local fw_w = math.max(1, math.floor(bar_w * p + 0.5))
			local fill_color = (self.status == "abandoned") and ABANDONED_COLOR or FILL_COLOR
			bb:paintRoundedRect(bar_x, bar_y, fw_w, bar_h, fill_color, BAR_RADIUS)
		end
	end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCustomProgress)

