--[[ Patch to add series indicator to the right side of the book cover ]]
--
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local logger = require("logger")
local userpatch = require("userpatch")
local Screen = require("device").screen
local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")

--========================== [[Edit your preferences here]] ================================
local font_size = 11 -- Adjust from 0 to 1
local border_thickness = 1 -- Adjust from 0 to 5
local border_corner_radius = 9 -- Adjust from 0 to 20
local text_color = Blitbuffer.colorFromString("#000000") -- Choose your desired color
local border_color = Blitbuffer.colorFromString("#000000") -- Choose your desired color
local background_color = Blitbuffer.COLOR_GRAY_E -- Choose your desired color

--==========================================================================================

-- Caching for series indicators to avoid repeated calculations
local series_badge_cache = {}

-- Function to get or create cached badge
local function get_series_badge(series_index)
  if series_badge_cache[series_index] then
    return series_badge_cache[series_index]
  end

  local series_text = TextWidget:new({
    text = "#" .. series_index,
    face = Font:getFace("cfont", font_size),
    bold = true,
    fgcolor = text_color,
  })

  local series_badge = FrameContainer:new({
    linesize = Screen:scaleBySize(2),
    radius = Screen:scaleBySize(border_corner_radius),
    color = border_color,
    bordersize = border_thickness,
    background = background_color,
    padding = Screen:scaleBySize(2),
    margin = 0,
    series_text,
  })

  -- Caching the badge
  series_badge_cache[series_index] = {
    badge = series_badge,
    text = series_text,
    width = series_text:getSize().w,
    height = series_text:getSize().h,
  }

  return series_badge_cache[series_index]
end

local function patchAddSeriesIndicator(plugin)
  local MosaicMenu = require("mosaicmenu")
  local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")

  if not MosaicMenuItem then
    return
  end

  -- Store original methods
  local orig_MosaicMenuItem_init = MosaicMenuItem.init
  local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

  -- Override init to compute series info once
  function MosaicMenuItem:init()
    orig_MosaicMenuItem_init(self)

    -- Only compute series info for books, not directories
    if not self.is_directory and not self.file_deleted then
      -- Get book info once during initialization
      local bookinfo = require("bookinfomanager"):getBookInfo(self.filepath, self.do_cover_image)
      if bookinfo and bookinfo.series and bookinfo.series_index then
        self.series_index = bookinfo.series_index
        self.has_series = true

        -- Pre-calculate badge dimensions
        local cached = get_series_badge(self.series_index)
        self.series_badge = cached.badge
        self.series_badge_width = cached.width
        self.series_badge_height = cached.height
      end
    end
  end

  function MosaicMenuItem:paintTo(bb, x, y)
    -- Call original paintTo
    orig_MosaicMenuItem_paint(self, bb, x, y)

    -- Only draw if we have series info
    if self.has_series and self.series_badge then
      local target = self[1][1][1]
      if not target or not target.dimen then
        return
      end

      -- Calculate position once
      local d_w = math.ceil(target.dimen.w / 5)
      local d_h = math.ceil(target.dimen.h / 10)

      local ix

      if BD.mirroredUILayout() then
        ix = -math.floor(d_w) -- Half outside on left side
        if not self.overflow_checked then
          local x_overflow_left = x - target.dimen.x + ix
          if x_overflow_left > 0 then
            self.refresh_dimen = self[1].dimen:copy()
            self.refresh_dimen.x = self.refresh_dimen.x - x_overflow_left
            self.refresh_dimen.w = self.refresh_dimen.w + x_overflow_left
          end
          self.overflow_checked = true
        end
      else
        ix = target.dimen.w - math.floor(d_w) -- Half outside on right side
        if not self.overflow_checked then
          local x_overflow_right = target.dimen.x + ix + d_w - x - self.dimen.w
          if x_overflow_right > 0 then
            self.refresh_dimen = self[1].dimen:copy()
            self.refresh_dimen.w = self.refresh_dimen.w + x_overflow_right
          end
          self.overflow_checked = true
        end
      end

      -- Move down on y axis
      iy = 0

      -- Calculate badge position (relative to target)
      local badge_x = target.dimen.x + ix + (d_w - self.series_badge_width) / 2
      local badge_y = target.dimen.y + iy + (d_h - self.series_badge_height) / 2

      -- Paint the cached badge
      self.series_badge:paintTo(bb, badge_x, badge_y)
    end
  end

  -- Clean up cache when item is destroyed
  local orig_MosaicMenuItem_free = MosaicMenuItem.free
  if orig_MosaicMenuItem_free then
    function MosaicMenuItem:free()
      -- Clear series-related data
      self.has_series = nil
      self.series_index = nil
      self.series_badge = nil
      self.series_badge_width = nil
      self.series_badge_height = nil
      self.overflow_checked = nil

      -- Call original free
      orig_MosaicMenuItem_free(self)
    end
  end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchAddSeriesIndicator)
