--[[ User patch for Project title plugin to add rounded corners to book covers ]]--

local userpatch  = require("userpatch")
local logger     = require("logger")
local IconWidget = require("ui/widget/iconwidget")
local Screen = require("device").screen
local Blitbuffer = require("ffi/blitbuffer")

local function patchBookCoverRoundedCorners(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
	
    -- Load as IconWidget
    local function svg_widget(icon)
        return IconWidget:new{ icon = icon, alpha  = true }
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
        local sz = corners.tl:getSize() --all four SVGs are same size so grab once
        _corner_w, _corner_h = sz.w, sz.h
    end
	
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

    function MosaicMenuItem:paintTo(bb, x, y)
	
		-- First, call the original paintTo method to draw the cover normally
		orig_MosaicMenuItem_paint(self, bb, x, y)
		
        -- Locate the cover frame widget as the base code does
        local target = self[1][1][1]
      
        if target and target.dimen then
            -- Outer frame rect (already centered)
            local fx = x + math.floor((self.width  - target.dimen.w) / 2)
            local fy = y + math.floor((self.height - target.dimen.h) / 2)
            local fw, fh = target.dimen.w, target.dimen.h
    
            -- Inner content rect = cover area inside padding
            local pad = target.padding or 0
            local inset = 0--Screen:scaleBySize(1)
            local ix = math.floor(fx + pad + inset)
            local iy = math.floor(fy + pad + inset)
            local iw = math.max(1, fw - 2*(pad + inset))
            local ih = math.max(1, fh - 2*(pad + inset))
    
            local cover_border = Screen:scaleBySize(0.5)  -- tweak for thicker line
            if not self.is_directory then
                bb:paintBorder(ix, iy, iw, ih, cover_border, Blitbuffer.COLOR_BLACK, 0, false)
            end
        end

        -- Paint rounded corners on the outer frame rect
        if target and target.dimen and not self.is_directory then
            local fx = x + math.floor((self.width  - target.dimen.w) / 2)
            local fy = y + math.floor((self.height - target.dimen.h) / 2)
            local fw, fh = target.dimen.w, target.dimen.h

            local TL, TR, BL, BR = corners.tl, corners.tr, corners.bl, corners.br
			
			-- Helper to get size for IconWidget (getSize)
            local function _sz(w)
                if w.getSize then local s = w:getSize(); return s.w, s.h end
                if w.getWidth then return w:getWidth(), w:getHeight() end
                return 0, 0
            end
			
            local tlw, tlh = _sz(TL)
            local trw, trh = _sz(TR)
            local blw, blh = _sz(BL)
            local brw, brh = _sz(BR)

			-- Top-left
            if TL.paintTo then TL:paintTo(bb, fx, fy) else bb:blitFrom(TL, fx, fy) end
            -- Top-right
            if TR.paintTo then TR:paintTo(bb, fx + fw - trw, fy) else bb:blitFrom(TR, fx + fw - trw, fy) end
            -- Bottom-left
            if BL.paintTo then BL:paintTo(bb, fx, fy + fh - blh) else bb:blitFrom(BL, fx, fy + fh - blh) end
            -- Bottom-right
            if BR.paintTo then BR:paintTo(bb, fx + fw - brw, fy + fh - brh) else bb:blitFrom(BR, fx + fw - brw, fy + fh - rh) end
        end
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchBookCoverRoundedCorners)
