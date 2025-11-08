--[[ Patch to add series indicator to the right side of the book cover ]]--
local userpatch = require("userpatch")
local logger = require("logger")
local TextWidget = require("ui/widget/textwidget")
local FrameContainer = require("ui/widget/container/framecontainer")
local Font = require("ui/font")
local Screen = require("device").screen
local Size = require("ui/size")
local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")

local function patchAddSeriesIndicator(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

    -- Store the original paintTo method first
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

    -- Override paintTo method
    function MosaicMenuItem:paintTo(bb, x, y)
        -- Call the original paintTo method to draw the cover normally
        orig_MosaicMenuItem_paint(self, bb, x, y)
        
        -- Get the cover image widget (target) and dimensions
        local target = self[1][1][1]
        if not target or not target.dimen then
            return
        end
        -- Use the same corner_mark_size as the original code for consistency
        local corner_mark_size = Screen:scaleBySize(10)	
		
		-- Check if book has series info and set flag
		if not self.is_directory and not self.file_deleted then
			local bookinfo = require("bookinfomanager"):getBookInfo(self.filepath, self.do_cover_image)
			if bookinfo and bookinfo.series then
				self.in_series = true
			end
		end
		
		-- Draw series indicator
		if self.in_series then
			local target = self[1][1][1]
			if target and target.dimen then               
				local d_w = Screen:scaleBySize(6)
				local d_h = math.ceil(target.dimen.h / 8)
				
				local ix
				
				if BD.mirroredUILayout() then
					ix = - d_w + 1
					local x_overflow_left = x - target.dimen.x+ix
					if x_overflow_left > 0 then
						self.refresh_dimen = self[1].dimen:copy()
						self.refresh_dimen.x = self.refresh_dimen.x - x_overflow_left
						self.refresh_dimen.w = self.refresh_dimen.w + x_overflow_left
					end
					
				else
					ix = target.dimen.w-1
					local x_overflow_right = target.dimen.x+ix+d_w - x - self.dimen.w
					if x_overflow_right > 0 then
						self.refresh_dimen = self[1].dimen:copy()
						self.refresh_dimen.w = self.refresh_dimen.w + x_overflow_right
					end
				end
				
				-- Move down on y axis
				local iy = 40 -- was 0
				
				bb:paintRect(target.dimen.x + ix, target.dimen.y + iy, d_w, d_h, Blitbuffer.COLOR_GRAY)
				bb:paintBorder(target.dimen.x + ix, target.dimen.y + iy, d_w, d_h, 1)
			end
		end
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchAddSeriesIndicator)
