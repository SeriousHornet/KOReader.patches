--[[ Patch to add series indicator to top right side of the book cover ]]
--
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local userpatch = require("userpatch")
local Screen = require("device").screen
local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")

-- stylua: ignore start
--========================== [[Edit your preferences here]] ================================
local font_size = 11                                       -- Adjust from 0 to 1
local border_thickness = 1                                 -- Adjust from 0 to 5
local border_corner_radius = 9                             -- Adjust from 0 to 20
local text_color = Blitbuffer.colorFromString("#000000")   -- Choose your desired color
local border_color = Blitbuffer.colorFromString("#000000") -- Choose your desired color
local background_color = Blitbuffer.COLOR_GRAY_E           -- Choose your desired color
--==========================================================================================
-- stylua: ignore end

local function patchAddSeriesIndicator(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local BookInfoManager = require("bookinfomanager")

    if not MosaicMenuItem then
        return
    end
	
	if MosaicMenuItem.patched_series_badge then
        return
    end
    MosaicMenuItem.patched_series_badge = true
	
    -- Store original methods
    local orig_MosaicMenuItem_init = MosaicMenuItem.init
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo
    local orig_MosaicMenuItem_free = MosaicMenuItem.free

     -- Override init to compute series info once
    function MosaicMenuItem:init()
        orig_MosaicMenuItem_init(self)

        -- Only compute series info if not a directory or deleted file
        if self.is_directory or self.file_deleted then
            return
        end

		-- Get book info once during initialization
		local bookinfo = BookInfoManager:getBookInfo(self.filepath, false)
		if bookinfo and bookinfo.series and bookinfo.series_index then
			self.series_index = bookinfo.series_index
			
			-- Create the series badge widget here.
			local series_text = TextWidget:new{
				text = "#" .. self.series_index,
				face = Font:getFace("cfont", font_size),
				bold = true,
				fgcolor = text_color,
			}
			
			self.series_badge = FrameContainer:new{
				linesize = Screen:scaleBySize(2),
				radius = Screen:scaleBySize(border_corner_radius),
				color = border_color,
				bordersize = border_thickness,
				background = background_color,
				padding = Screen:scaleBySize(2),
				margin = 0,
				series_text,
			}
			
			-- Store text widget reference for cleanup
			self._series_text = series_text	

			-- Mark that we have a series badge
			self.has_series_badge = true
        end
    end

    function MosaicMenuItem:paintTo(bb, x, y)
        -- Call original paintTo
        orig_MosaicMenuItem_paint(self, bb, x, y)


        -- Draw series badge if applicable
        if self.has_series_badge and self.series_badge then
            
            local target = self[1][1][1]
            if not target or not target.dimen then
                return
            end

            -- Calculate position
            local d_w = math.ceil(target.dimen.w / 5)
            local d_h = math.ceil(target.dimen.h / 10)

			local ix, iy = 0, 5
            
            if BD.mirroredUILayout() then
                ix = -math.floor(d_w)  -- on left side
            else
                ix = target.dimen.w - math.floor(d_w)  -- on right side
            end

            -- Calculate badge position (relative to target)
			local series_badge_size = self.series_badge:getSize()
			local badge_x = target.dimen.x + ix + (d_w - series_badge_size.w) / 2
			local badge_y = target.dimen.y + iy + (d_h - series_badge_size.h) / 2

            -- Paint the badge
            self.series_badge:paintTo(bb, badge_x, badge_y)
        end
    end
	
	if orig_MosaicMenuItem_free then
		function MosaicMenuItem:free()
			-- Free our created widgets
			if self._series_text then
				self._series_text:free(true)
				self._series_text = nil
			end
			
			if self.series_badge then
				self.series_badge:free(true)
				self.series_badge = nil
			end
			
			-- Clear other instance variables
			self.series_index = nil
			self.has_series_badge = nil
			
			-- Call original free
			orig_MosaicMenuItem_free(self)
		end
	end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchAddSeriesIndicator)
