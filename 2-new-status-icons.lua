--[[ User patch for Project Title plugin to replace with new status icons ]]--

local userpatch = require("userpatch")
local IconWidget = require("ui/widget/iconwidget")
local BD = require("ui/bidi")

local function patchCoverBrowserStatusIcons(plugin)
    -- Store the original IconWidget.new
    local originalIconWidgetNew = IconWidget.new
    
    -- Override IconWidget.new to automatically add alpha = true for corner marks
    function IconWidget:new(o)
        -- Check if this is one of the corner mark icons
        local corner_icons = {
            "dogear.reading",
            "dogear.abandoned", 
            "dogear.abandoned.rtl",
            "dogear.complete",
            "dogear.complete.rtl",
            "star.white"
        }
        
        -- If it's a corner mark icon, ensure alpha = true
        for _, icon_name in ipairs(corner_icons) do
            if o.icon == icon_name then
                o.alpha = true
                break
            end
        end
        
        return originalIconWidgetNew(self, o)
    end
	
	local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    
    if not MosaicMenuItem then return end

    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo
    
    function MosaicMenuItem:paintTo(bb, x, y)
       
        -- Call original paintTo (this will NOT draw status icons now)
        orig_MosaicMenuItem_paint(self, bb, x, y)
        
        -- Now draw our transparent status icons
        if (self.do_hint_opened and self.been_opened and self.percent_finished) or 
   (self.menu.name == "history" and self.percent_finished) or (self.menu.name == "collections" and self.percent_finished) then
          
            local target = self[1][1][1]
            
            -- Calculate icon size
            local corner_mark_size = math.floor(math.min(self.width, self.height) / 8)
            
            -- Calculate bottom right corner position
            local ix, iy
            
            if BD.mirroredUILayout() then
                ix = math.floor((self.width - target.dimen.w)/2)
            else
                ix = self.width - math.ceil((self.width - target.dimen.w)/2) - corner_mark_size
            end
            iy = self.height - math.ceil((self.height - target.dimen.h)/2) - corner_mark_size
            
            -- Create and paint the appropriate status icon with transparency
            local mark
            
            if self.status == "abandoned" then
                mark = IconWidget:new{
                    icon = BD.mirroredUILayout() and "dogear.abandoned.rtl" or "dogear.abandoned",
                    width = corner_mark_size,
                    height = corner_mark_size,
                    alpha = true,
                }
            elseif self.status == "complete" then
                mark = IconWidget:new{
                    icon = BD.mirroredUILayout() and "dogear.complete.rtl" or "dogear.complete",
                    width = corner_mark_size,
                    height = corner_mark_size,
                    alpha = true,
                }
            else -- reading status or no status
                mark = IconWidget:new{
                    icon = "dogear.reading",
                    rotation_angle = BD.mirroredUILayout() and 270 or 0,
                    width = corner_mark_size,
                    height = corner_mark_size,
                    alpha = true,
                }
            end
            
            if mark then
                mark:paintTo(bb, x + ix, y + iy)
            end
        end
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserStatusIcons)
