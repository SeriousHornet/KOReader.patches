--[[ User patch for KOReader to add collection indicator in mosaic view ]]
--

local Blitbuffer = require("ffi/blitbuffer")
local IconWidget = require("ui/widget/iconwidget")
local ReadCollection = require("readcollection")
local logger = require("logger")
local userpatch = require("userpatch")
local Screen = require("device").screen

local function patchCoverBrowserCollectionIndicator(plugin)
    -- Grab Cover Grid mode and the individual Cover Grid items
    local MosaicMenu = require("mosaicmenu")
    local builder = MosaicMenu._simpleui_native_build or MosaicMenu._updateItemsBuildUI
    local MosaicMenuItem = userpatch.getUpValue(builder, "MosaicMenuItem")

    if not MosaicMenuItem then
        logger.warn("Patch: MosaicMenuItem not found; skipping")
        return
    end

    if MosaicMenuItem.patched_new_collections_star then
        return
    end
    MosaicMenuItem.patched_new_collections_star = true

    -- Store original MosaicMenuItem paintTo method
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo

    -- Override paintTo method to add collection indicator
    function MosaicMenuItem:paintTo(bb, x, y)
        -- Call the original paintTo method to draw the cover normally
        orig_MosaicMenuItem_paint(self, bb, x, y)

        -- Get the cover image widget (target) and dimensions
        local target = self[1][1][1]
        if not target or not target.dimen then
            return
        end

        -- Add collection indicator for books in collections
        if self.menu and self.menu.name ~= "collections" and ReadCollection:isFileInCollections(self.filepath) then
            local left_margin = Screen:scaleBySize(7)
            local radius = Screen:scaleBySize(10)
            local top_margin = Screen:scaleBySize(7)

            -- Use target.dimen.x and target.dimen.y which are relative to the cell
            local center_x = target.dimen.x + left_margin + radius
            local center_y = target.dimen.y + top_margin + radius

            -- draw filled black circle
            bb:paintCircle(center_x, center_y, radius, Blitbuffer.COLOR_BLACK)

            -- Create smaller star (half the size)
            local collection_mark = IconWidget:new({
                icon = "star.white",
                width = Screen:scaleBySize(25), -- Half the size of corner_mark_size
                height = Screen:scaleBySize(25),
                alpha = true,
            })

            -- position icon centered inside circle
            local icon_x = center_x - math.floor(collection_mark.width / 2)
            local icon_y = center_y - math.floor(collection_mark.height / 2)

            collection_mark:paintTo(bb, icon_x, icon_y)
        end
    end
end

local disabled = G_reader_settings:readSetting("plugins_disabled") or {}
local plugin_name = disabled["coverbrowser"] and "projecttitle" or "coverbrowser"
userpatch.registerPatchPluginFunc(plugin_name, patchCoverBrowserCollectionIndicator)
