--[[ User patch: custom rounded progress bar for Project: Title ]]--

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
local TRACK_COLOR = Blitbuffer.COLOR_WHITE  -- bar color
local FILL_COLOR  = Blitbuffer.COLOR_GRAY_7   -- fill color
local ABANDONED_COLOR = Blitbuffer.COLOR_GRAY -- fill when abandoned/paused
local BORDER_W    = Screen:scaleBySize(0.5)    -- border width around track (0 to disable)
local BORDER_COLOR = Blitbuffer.COLOR_BLACK  -- border color
--======================================================================================

--========================== Do not modify this section ================================
-- Flag to selectively mute progress-related icons during base paint
local _mute_progress_icons = false

-- Store original paint methods
local orig_IW_paint = ImageWidget.paintTo
local orig_FC_paint = FrameContainer.paintTo

-- Override ImageWidget.paintTo to selectively mute specific icons
ImageWidget.paintTo = function(self, bb, x, y)
    if _mute_progress_icons and self.file then
        -- Mute only the four specific icons used in progress section
        if self.file:match("/resources/trophy%.svg$") or 
           self.file:match("/resources/pause%.svg$") or 
           self.file:match("/resources/new%.svg$") or 
           self.file:match("/resources/large_book%.svg$") then
            return -- Skip painting these icons
        end
    end
    -- Call original method for all other ImageWidgets (covers, UI elements, etc.)
    return orig_IW_paint(self, bb, x, y)
end

-- Override FrameContainer.paintTo to mute status_widget frames
FrameContainer.paintTo = function(self, bb, x, y)
    if _mute_progress_icons then
        -- Check if first child is a muted status icon (trophy/pause)
        local child = self[1]
        if child and child.file and (
           child.file:match("/resources/trophy%.svg$") or 
           child.file:match("/resources/pause%.svg$")) then
            return -- Skip painting this status_widget container
        end
    end
    -- Call original method for all other FrameContainers
    return orig_FC_paint(self, bb, x, y)
end

local function patchCustomProgress(plugin)
  local MosaicMenu     = require("mosaicmenu")
  local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
  if not MosaicMenuItem then
    logger.err("MosaicMenuItem not found - progress patch aborted")
    return
  end

  local basePaint = MosaicMenuItem.paintTo

  -- Corner mark size (fallback if not found)
  local corner_mark_size = userpatch.getUpValue(basePaint, "corner_mark_size") or Screen:scaleBySize(24)

  local function I(v) return math.floor(v + 0.5) end

  function MosaicMenuItem:paintTo(bb, x, y)
    -- Locate the cover frame
    local target = self[1] and self[1][1] and self[1][1][1] or nil

    -- ---- Silencing stock widgets during base paint ----
    local orig_PW_paint = ProgressWidget.paintTo
    
    -- Mute ProgressWidget entirely (safe - only used for progress bars)
    ProgressWidget.paintTo = function() end
    
    -- Enable selective muting for specific icons
    _mute_progress_icons = true

    -- Paint base item with stock progress widgets muted
    local ok, err = pcall(basePaint, self, bb, x, y)

    -- Restore all methods immediately
    ProgressWidget.paintTo = orig_PW_paint
    _mute_progress_icons = false
    
    if not ok then error(err) end
    -- ---- End silencing block ----

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
