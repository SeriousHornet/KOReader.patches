--[[ User patch for KOReader to add page count badges for unread books ]]
--
local Blitbuffer = require("ffi/blitbuffer")

--========================== [[Edit your preferences here]] ================================
local page_font_size = 0.95 -- Adjust from 0 to 1
local page_text_color = Blitbuffer.COLOR_WHITE -- Choose your desired color
local border_thickness = 2 -- Adjust from 0 to 5
local border_corner_radius = 12 -- Adjust from 0 to 20
local border_color = Blitbuffer.COLOR_DARK_GRAY -- Choose your desired color
local background_color = Blitbuffer.COLOR_GRAY_3 -- Choose your desired color
local move_from_border = 8 -- Choose how far in the badge should sit

--==========================================================================================

--========================== [[Do not modify this section]] ================================
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local logger = require("logger")
local userpatch = require("userpatch")
local Screen = require("device").screen
local BD = require("ui/bidi")
local Size = require("ui/size")

local function patchCoverBrowserPageCount(plugin)
  -- Grab Cover Grid mode and the individual Cover Grid items
  local MosaicMenu = require("mosaicmenu")
  local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

  -- Store original MosaicMenuItem paintTo method
  local origMosaicMenuItemPaintTo = MosaicMenuItem.paintTo

  -- Override paintTo method to add page count badges
  function MosaicMenuItem:paintTo(bb, x, y)
    -- First, call the original paintTo method to draw the cover normally
    origMosaicMenuItemPaintTo(self, bb, x, y)

    -- Get the cover image widget (target) and dimensions
    local target = self[1][1][1]
    if not target or not target.dimen then
      return
    end

    -- Using the same corner_mark_size as the original code for consistency
    local corner_mark_size = Screen:scaleBySize(10)

    -- ADD page count widget for unread books
    if not self.is_directory and not self.file_deleted and self.status ~= "complete" and not self.been_opened then
      -- Extract page count from filename
      local page_count = nil
      if self.filepath then
        local BookInfoManager = require("bookinfomanager")
        local bookinfo = BookInfoManager:getBookInfo(self.filepath, false)
        if bookinfo and bookinfo.pages then
          page_count = bookinfo.pages
        end
      end

      if not page_count then
        page_count = nil
        if self.text then
          page_count = self.text:match("[Pp]%((%d+)%)")
        end
      end

      if page_count then
        local page_text = page_count .. " p."
        local font_size = math.floor(corner_mark_size * page_font_size)

        local pages_text = TextWidget:new({
          text = page_text,
          face = Font:getFace("cfont", font_size),
          alignment = "left",
          fgcolor = page_text_color,
          bold = true,
          padding = 2,
        })

        local pages_badge = FrameContainer:new({
          linesize = Screen:scaleBySize(2),
          radius = Screen:scaleBySize(border_corner_radius),
          color = border_color,
          bordersize = border_thickness,
          background = background_color,
          padding = Screen:scaleBySize(2),
          margin = 0,
          pages_text,
        })

        -- left edge of the cover content inside the item
        local cover_left = x + math.floor((self.width - target.dimen.w) / 2)
        -- bottom edge of the cover content inside the item
        local cover_bottom = y + self.height - math.floor((self.height - target.dimen.h) / 2)
        local badge_w, badge_h = pages_badge:getSize().w, pages_badge:getSize().h

        -- Position near bottom-left
        local pad = Screen:scaleBySize(move_from_border)
        local pos_x_badge = cover_left + pad
        local pos_y_badge = cover_bottom - (pad + badge_h)

        pages_badge:paintTo(bb, pos_x_badge, pos_y_badge)
      end
    end
  end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowserPageCount)
