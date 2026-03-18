-- Bottom Navigation Bar patch for KOReader File Manager
-- Merged version combining features from qewer333, Pedro and Marcos' patches
-- Adds a tab bar at the bottom with configurable tabs, colors, and sizes
-- Enhanced with "Add folder tab" feature with custom icon name input

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local IconWidget = require("ui/widget/iconwidget")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local _ = require("gettext")
local lfs = require("libs/libkoreader-lfs")

-- === Layout constants (will be updated based on config) ===

local navbar_icon_size = Screen:scaleBySize(34)
local navbar_font = Font:getFace("smallinfofont")
local navbar_font_bold = Font:getFace("smallinfofontbold")
local navbar_v_padding = Screen:scaleBySize(4)
local corner_dead_zone = math.floor(Screen:getWidth() / 12)
local navbar_top_gap = Screen:scaleBySize(10)
local underline_thickness = Screen:scaleBySize(2)

-- Size presets from Marcos with organic proportions
local size_presets = {
    tiny = {icon = 16, font = "xx_smallinfofont", bold_font = "smallinfofontbold", padding = 2, font_size = 12},
    small = {icon = 22, font = "xx_smallinfofont", bold_font = "x_smallinfofont", padding = 3, font_size = 14},
    medium = {icon = 30, font = "x_smallinfofont", bold_font = "smallinfofontbold", padding = 4, font_size = 18},
    large = {icon = 40, font = "smallinfofont", bold_font = "smallinfofontbold", padding = 6, font_size = 22},
    huge = {icon = 50, font = "infofont", bold_font = "tfont", padding = 8, font_size = 26}
}

-- Kaleido-optimized color presets from Marcos
local kaleido_colors = {
    {name = "Ocean Blue", color = {0x1E, 0x88, 0xE5}},
    {name = "Forest Green", color = {0x43, 0xA0, 0x47}},
    {name = "Sunset Orange", color = {0xFF, 0x6F, 0x00}},
    {name = "Royal Purple", color = {0x7B, 0x1F, 0xA2}},
    {name = "Coral Pink", color = {0xFF, 0x70, 0x43}},
    {name = "Mint Green", color = {0x00, 0x89, 0x7B}},
    {name = "Gold", color = {0xFF, 0xA7, 0x26}},
    {name = "Ruby Red", color = {0xE5, 0x39, 0x35}},
    {name = "Slate Blue", color = {0x5C, 0x6B, 0xC0}},
    {name = "Teal", color = {0x00, 0x97, 0xA7}}
}

-- === Persistent config (merged from both) ===

local config_default = {
    show_tabs = {
        books = true,
        manga = true,
        news = true,
        continue = true,
        history = false,
        favorites = false,
        collections = false,
        zlib = false,
        annas = false,
        appstore = false,
        opds = false,
        exit = false,
        page_left = false,
        page_right = false,
        sleep = false,
        restart = false,
        stats = false
    },
    tab_order = {
        "page_left",
        "books",
        "manga",
        "news",
        "continue",
        "history",
        "favorites",
        "collections",
        "zlib",
        "annas",
        "appstore",
        "opds",
        "exit",
        "page_right",
        "sleep",
        "restart",
        "stats"
    },
    custom_tabs = {}, -- list of { id, label, icon, dispatcher_action, source, fm_key, fm_method, folder_path }
    show_labels = true,
    show_top_border = true,
    books_label = "Books",
    manga_action = "rakuyomi",
    manga_folder = "",
    news_action = "quickrss",
    news_folder = "",
    colored = false,
    active_tab_color = {0x33, 0x99, 0xFF},
    show_in_standalone = true,
    show_top_gap = false,
    active_tab_styling = true,
    active_tab_bold = true,
    active_tab_underline = true,
    underline_above = true,
    navbar_size = "medium",
    active_color_index = 0,
    label_font_size = 14
}

local function loadConfig()
    local config = G_reader_settings:readSetting("bottom_navbar", config_default)
    for k, v in pairs(config_default) do
        if config[k] == nil then
            config[k] = v
        end
    end
    if type(config.show_tabs) == "table" then
        for k, v in pairs(config_default.show_tabs) do
            if config.show_tabs[k] == nil then
                config.show_tabs[k] = v
            end
        end
    else
        config.show_tabs = config_default.show_tabs
    end
    -- Ensure tab_order contains all known tabs
    if type(config.tab_order) ~= "table" then
        config.tab_order = config_default.tab_order
    else
        local order_set = {}
        for _, tab_id in ipairs(config.tab_order) do
            order_set[tab_id] = true
        end
        for _, tab_id in ipairs(config_default.tab_order) do
            if not order_set[tab_id] then
                table.insert(config.tab_order, tab_id)
            end
        end
        -- Also ensure custom tab ids are in tab_order
        if type(config.custom_tabs) == "table" then
            for _, ct in ipairs(config.custom_tabs) do
                if ct.id and not order_set[ct.id] then
                    table.insert(config.tab_order, ct.id)
                    order_set[ct.id] = true
                end
            end
        end
    end
    -- Ensure custom_tabs exists
    if type(config.custom_tabs) ~= "table" then
        config.custom_tabs = {}
    end
    return config
end

local config = loadConfig()

-- === Dynamic layout updates ===

local function createCustomFont(font_name, size)
    local Font = require("ui/font")
    return Font:getFace(font_name, size)
end

local function updateLayoutConstants()
    local size_preset = size_presets[config.navbar_size] or size_presets.medium
    navbar_icon_size = Screen:scaleBySize(size_preset.icon)

    local font_size = config.label_font_size or size_preset.font_size

    navbar_font = Font:getFace(size_preset.font, font_size)
    navbar_font_bold = Font:getFace(size_preset.bold_font, font_size)

    navbar_v_padding = Screen:scaleBySize(size_preset.padding)

    -- Update active tab color based on selection
    if config.active_color_index == 0 then
        config.active_tab_color = {0x33, 0x99, 0xFF}
    elseif kaleido_colors[config.active_color_index] then
        config.active_tab_color = kaleido_colors[config.active_color_index].color
    end
end

-- Initialize layout constants
updateLayoutConstants()

-- === Tab definitions ===

local function getBooksLabel()
    return config.books_label ~= "" and config.books_label or "Books"
end

local tabs = {
    {
        id = "books",
        label = getBooksLabel(),
        icon = "tab_books"
    },
    {
        id = "manga",
        label = _("Manga"),
        icon = "tab_manga"
    },
    {
        id = "news",
        label = _("News"),
        icon = "tab_news"
    },
    {
        id = "continue",
        label = _("Continue"),
        icon = "tab_continue"
    },
    {
        id = "history",
        label = _("History"),
        icon = "tab_history"
    },
    {
        id = "favorites",
        label = _("Favorites"),
        icon = "tab_favorites"
    },
    {
        id = "collections",
        label = _("Collections"),
        icon = "tab_collections"
    },
    {
        id = "zlib",
        label = _("Z-Lib"),
        icon = "appbar.search"
    },
    {
        id = "annas",
        label = _("Anna's"),
        icon = "appbar.search"
    },
    {
        id = "appstore",
        label = _("AppStore"),
        icon = "tab_collections"
    },
    {
        id = "opds",
        label = _("OPDS"),
        icon = "appbar.filebrowser"
    },
    {
        id = "exit",
        label = _("Exit"),
        icon = "tab_exit"
    },
    {
        id = "page_left",
        label = _("Prev"),
        icon = "tab_left"
    },
    {
        id = "page_right",
        label = _("Next"),
        icon = "tab_right"
    },
    {
        id = "sleep",
        label = _("Sleep"),
        icon = "tab_sleep"
    },
    {
        id = "restart",
        label = _("Restart"),
        icon = "tab_restart"
    },
    {
        id = "stats",
        label = _("Stats"),
        icon = "tab_stats"
    }
}

local tabs_by_id = {}
for _, tab in ipairs(tabs) do
    tabs_by_id[tab.id] = tab
end

-- Register custom tabs from config into tabs/tabs_by_id
local function registerCustomTabs()
    for i = #tabs, 1, -1 do
        if tabs[i].is_custom then
            table.remove(tabs, i)
        end
    end
    for k, v in pairs(tabs_by_id) do
        if v.is_custom then
            tabs_by_id[k] = nil
        end
    end
    for _, ct in ipairs(config.custom_tabs) do
        if ct.id and ct.label then
            local entry = {
                id = ct.id,
                label = ct.label,
                icon = ct.icon or "appbar.search",
                is_custom = true
            }
            table.insert(tabs, entry)
            tabs_by_id[ct.id] = entry
            if config.show_tabs[ct.id] == nil then
                config.show_tabs[ct.id] = true
            end
        end
    end
end

registerCustomTabs()

-- === Active tab tracking ===

local active_tab = "books"

-- Forward declarations
local injectNavbar
local injectStandaloneNavbar
local hookQuickRSSInit

local function setActiveTab(tab_id)
    active_tab = tab_id
    updateLayoutConstants()
    local fm = FileManager.instance
    if fm then
        injectNavbar(fm)
        UIManager:setDirty(fm, "full")
    end
end

-- === Tab callbacks ===

local function onTabBooks()
    local fm = FileManager.instance
    if not fm then
        return
    end
    local home_dir =
        G_reader_settings:readSetting("home_dir") or require("apps/filemanager/filemanagerutil").getDefaultDir()
    fm.file_chooser.path_items[home_dir] = nil
    fm.file_chooser:changeToPath(home_dir)
end

local function onTabManga()
    local fm = FileManager.instance
    if not fm then
        return
    end

    if config.manga_action == "folder" and config.manga_folder ~= "" then
        if lfs.attributes(config.manga_folder, "mode") == "directory" then
            fm.file_chooser:changeToPath(config.manga_folder)
        else
            UIManager:show(
                InfoMessage:new {
                    text = _("Manga folder not found: ") .. config.manga_folder
                }
            )
        end
        return
    end

    local rakuyomi = fm.rakuyomi
    if rakuyomi then
        rakuyomi:openLibraryView()
    else
        UIManager:show(
            InfoMessage:new {
                text = _("Rakuyomi plugin is not installed.")
            }
        )
    end
end

local function onTabNews()
    local fm = FileManager.instance
    if not fm then
        return
    end

    if config.news_action == "folder" and config.news_folder ~= "" then
        if lfs.attributes(config.news_folder, "mode") == "directory" then
            fm.file_chooser:changeToPath(config.news_folder)
        else
            UIManager:show(
                InfoMessage:new {
                    text = _("News folder not found: ") .. config.news_folder
                }
            )
        end
        return
    end

    hookQuickRSSInit()
    local ok, QuickRSSUI = pcall(require, "modules/ui/feed_view")
    if ok and QuickRSSUI then
        UIManager:show(QuickRSSUI:new {})
    else
        UIManager:show(
            InfoMessage:new {
                text = _("QuickRSS plugin is not installed.")
            }
        )
    end
end

local function onTabContinue()
    local last_file = G_reader_settings:readSetting("lastfile")
    if not last_file or lfs.attributes(last_file, "mode") ~= "file" then
        UIManager:show(
            InfoMessage:new {
                text = _("Cannot open last document")
            }
        )
        return
    end
    local ReaderUI = require("apps/reader/readerui")
    ReaderUI:showReader(last_file)
end

local function onTabHistory()
    local fm = FileManager.instance
    if fm and fm.history then
        fm.history:onShowHist()
    end
end

local function onTabFavorites()
    local fm = FileManager.instance
    if fm and fm.collections then
        fm.collections:onShowColl()
    end
end

local function onTabCollections()
    local fm = FileManager.instance
    if fm and fm.collections then
        fm.collections:onShowCollList()
    end
end

local function onTabExit()
    local fm = FileManager.instance
    UIManager:show(
        ConfirmBox:new {
            text = _("Exit KOReader?"),
            ok_text = _("Exit"),
            cancel_text = _("Cancel"),
            ok_callback = function()
                if fm then
                    fm:onClose()
                end
            end
        }
    )
end

local function onTabPageLeft()
    local fm = FileManager.instance
    if fm and fm.file_chooser then
        fm.file_chooser:onPrevPage()
    end
end

local function onTabPageRight()
    local fm = FileManager.instance
    if fm and fm.file_chooser then
        fm.file_chooser:onNextPage()
    end
end

local function onTabSleep()
    UIManager:show(
        ConfirmBox:new {
            text = _("Put device to sleep?"),
            ok_text = _("Sleep"),
            ok_callback = function()
                if Device:canSuspend() then
                    UIManager:broadcastEvent(Event:new("RequestSuspend"))
                elseif Device:canPowerOff() then
                    UIManager:broadcastEvent(Event:new("RequestPowerOff"))
                end
            end
        }
    )
end

local function onTabRestart()
    UIManager:show(
        ConfirmBox:new {
            text = _("Restart KOReader?"),
            ok_text = _("Restart"),
            ok_callback = function()
                UIManager:restartKOReader()
            end
        }
    )
end

local function onTabStats()

    -- Check both possible patch filenames
    local patch_paths = {
        "./patches/2-reading-insights-popup-colored.lua",
        "./patches/2-reading-insights-popup.lua",
    }
    
    local patch_found = false
    for _, path in ipairs(patch_paths) do
        if lfs.attributes(path, "mode") == "file" then
            patch_found = true
            break
        end
    end
    
    if patch_found then
		setActiveTab("stats")
        UIManager:sendEvent(Event:new("ShowReadingInsightsPopup"))
    else
        UIManager:show(
            InfoMessage:new {
                text = _("Reading Insights Popup patch is not installed.")
            }
        )
    end
end

local function onTabZlib()
    local fm = FileManager.instance
    if not fm then
        return
    end

    local zlibrary = fm["Z-library"] or fm["zlibrary"] or fm["Zlibrary"] or fm["z-library"]
    if zlibrary then
        zlibrary:showMultiSearchDialog()
    else
        for k, v in pairs(fm) do
            if type(k) == "string" and k:lower():find("z.lib") and type(v) == "table" and v.showMultiSearchDialog then
                v:showMultiSearchDialog()
                return
            end
        end
        UIManager:show(
            InfoMessage:new {
                text = _("zlibrary.koplugin is not installed.")
            }
        )
    end
end

local function onTabAnnas()
    local fm = FileManager.instance
    if not fm then
        return
    end

    local annas = fm["Anna's Archive"] or fm["annas"] or fm["annasarchive"]
    if not annas then
        for k, v in pairs(fm) do
            if type(k) == "string" and k:lower():find("anna") and type(v) == "table" and v.showSearchDialog then
                annas = v
                break
            end
        end
    end
    if annas then
        if annas.showSearchDialog then
            annas:showSearchDialog()
        elseif annas.onZlibrarySearch then
            annas:onZlibrarySearch()
        elseif annas.showMultiSearchDialog then
            annas:showMultiSearchDialog()
        else
            UIManager:show(
                InfoMessage:new {
                    text = _("Could not open Anna's Archive plugin.")
                }
            )
        end
    else
        UIManager:show(
            InfoMessage:new {
                text = _("annas.koplugin is not installed.")
            }
        )
    end
end

local function onTabAppStore()
    local fm = FileManager.instance
    if not fm then
        return
    end

    local appstore = fm.appstore
    if appstore then
        appstore:showBrowser()
    else
        UIManager:show(
            InfoMessage:new {
                text = _("appstore.koplugin is not installed.")
            }
        )
    end
end

local function onTabOpds()
    local fm = FileManager.instance
    if not fm then
        return
    end

    local opds = fm.opds
    if not opds then
        UIManager:show(
            InfoMessage:new {
                text = _("OPDS plugin is not enabled.\nEnable it in Settings > Plugins."),
                timeout = 4
            }
        )
        return
    end

    local servers = opds.servers or {}

    local function openFullBrowser()
        opds:onShowOPDSCatalog()
    end

    local function openServer(server)
        local OPDSBrowser = require("opdsbrowser")
        local browser =
            OPDSBrowser:new {
            servers = opds.servers,
            downloads = opds.downloads,
            settings = opds.settings,
            pending_syncs = opds.pending_syncs,
            title = server.title,
            is_popout = false,
            is_borderless = true,
            title_bar_fm_style = true,
            _manager = opds,
            file_downloaded_callback = function(file)
                opds:showFileDownloadedDialog(file)
            end,
            close_callback = function()
                if browser.download_list then
                    browser.download_list.close_callback()
                end
                UIManager:close(browser)
                opds.opds_browser = nil
                if opds.last_downloaded_file then
                    if fm.file_chooser then
                        local util = require("util")
                        local pathname = util.splitFilePathName(opds.last_downloaded_file)
                        fm.file_chooser:changeToPath(pathname, opds.last_downloaded_file)
                    end
                    opds.last_downloaded_file = nil
                end
            end
        }
        opds.opds_browser = browser
        UIManager:show(browser)
        browser:updateCatalog(server.url, server.username, server.password)
    end

    if #servers == 0 then
        openFullBrowser()
        return
    end

    if #servers == 1 then
        openServer(servers[1])
        return
    end

    local ButtonDialog = require("ui/widget/buttondialog")
    local buttons = {}

    for _, server in ipairs(servers) do
        local s = server
        table.insert(
            buttons,
            {
                {
                    text = s.title,
                    align = "left",
                    callback = function()
                        UIManager:close(dialog)
                        openServer(s)
                    end
                }
            }
        )
    end

    table.insert(buttons, {})
    table.insert(
        buttons,
        {
            {
                text = _("All catalogs"),
                align = "left",
                callback = function()
                    UIManager:close(dialog)
                    openFullBrowser()
                end
            }
        }
    )

    local dialog =
        ButtonDialog:new {
        title = _("Open OPDS catalog"),
        title_align = "center",
        buttons = buttons,
        shrink_unneeded_width = true
    }
    UIManager:show(dialog)
end

-- Custom tab callback with folder support
local function onTabCustom(tab_id)
    local ct
    for _, c in ipairs(config.custom_tabs) do
        if c.id == tab_id then
            ct = c
            break
        end
    end
    if not ct then
        return
    end

    -- Handle folder tabs
    if ct.source == "folder" and ct.folder_path then
        local fm = FileManager.instance
        if fm and fm.file_chooser then
            if lfs.attributes(ct.folder_path, "mode") == "directory" then
                fm.file_chooser:changeToPath(ct.folder_path)
                setActiveTab(ct.id)
            else
                UIManager:show(
                    InfoMessage:new {
                        text = _("Folder not found: ") .. ct.folder_path,
                        timeout = 3
                    }
                )
            end
        end
        return
    end

    -- Handle dispatcher actions
    if ct.source == "dispatcher" and ct.dispatcher_action then
        local action = Dispatcher.settingsList and Dispatcher.settingsList[ct.dispatcher_action]
        if action then
            local Event = require("ui/event")
            UIManager:sendEvent(Event:new(action.event, action.arg))
            return
        end
    end

    -- Handle plugin method calls
    if ct.fm_key and ct.fm_method then
        local fm = FileManager.instance
        local plugin = fm and fm[ct.fm_key]
        if plugin and type(plugin[ct.fm_method]) == "function" then
            plugin[ct.fm_method](plugin)
            return
        end

        UIManager:show(
            InfoMessage:new {
                text = _("Plugin not available: ") .. ct.fm_key,
                timeout = 3
            }
        )
        return
    end

    -- Legacy dispatcher action
    if ct.dispatcher_action then
        local action = Dispatcher.settingsList and Dispatcher.settingsList[ct.dispatcher_action]
        if action then
            local Event = require("ui/event")
            UIManager:sendEvent(Event:new(action.event, action.arg))
            return
        end
    end

    UIManager:show(
        InfoMessage:new {
            text = _("Custom tab action not configured correctly."),
            timeout = 3
        }
    )
end

local tab_callbacks = {
    books = onTabBooks,
    manga = onTabManga,
    news = onTabNews,
    continue = onTabContinue,
    history = onTabHistory,
    favorites = onTabFavorites,
    collections = onTabCollections,
    zlib = onTabZlib,
    annas = onTabAnnas,
    appstore = onTabAppStore,
    opds = onTabOpds,
    exit = onTabExit,
    page_left = onTabPageLeft,
    page_right = onTabPageRight,
    sleep = onTabSleep,
    restart = onTabRestart,
    stats = onTabStats
}

local function getTabCallback(tab_id)
    if tab_callbacks[tab_id] then
        return tab_callbacks[tab_id]
    end
    for _, ct in ipairs(config.custom_tabs) do
        if ct.id == tab_id then
            return function()
                onTabCustom(tab_id)
            end
        end
    end
    return nil
end

-- === Color text support ===

local RenderText = require("ui/rendertext")

local ColorTextWidget = TextWidget:extend {}

function ColorTextWidget:paintTo(bb, x, y)
    self:updateSize()
    if self._is_empty then
        return
    end

    if not self.fgcolor or Blitbuffer.isColor8(self.fgcolor) or not Screen:isColorScreen() then
        TextWidget.paintTo(self, bb, x, y)
        return
    end

    if not self.use_xtext then
        TextWidget.paintTo(self, bb, x, y)
        return
    end

    if not self._xshaping then
        self._xshaping =
            self._xtext:shapeLine(self._shape_start, self._shape_end, self._shape_idx_to_substitute_with_ellipsis)
    end

    local text_width = bb:getWidth() - x
    if self.max_width and self.max_width < text_width then
        text_width = self.max_width
    end
    local pen_x = 0
    local baseline = self.forced_baseline or self._baseline_h
    for _, xglyph in ipairs(self._xshaping) do
        if pen_x >= text_width then
            break
        end
        local face = self.face.getFallbackFont(xglyph.font_num)
        local glyph = RenderText:getGlyphByIndex(face, xglyph.glyph, self.bold)
        bb:colorblitFromRGB32(
            glyph.bb,
            x + pen_x + glyph.l + xglyph.x_offset,
            y + baseline - glyph.t - xglyph.y_offset,
            0,
            0,
            glyph.bb:getWidth(),
            glyph.bb:getHeight(),
            self.fgcolor
        )
        pen_x = pen_x + xglyph.x_advance
    end
end

-- === Colored icon widget ===

local ColorIconWidget =
    IconWidget:extend {
    _tint_color = nil
}

function ColorIconWidget:paintTo(bb, x, y)
    if not self._tint_color or not Screen:isColorScreen() then
        IconWidget.paintTo(self, bb, x, y)
        return
    end

    if self.hide then
        return
    end
    local size = self:getSize()
    if not self.dimen then
        self.dimen = Geom:new {x = x, y = y, w = size.w, h = size.h}
    else
        self.dimen.x = x
        self.dimen.y = y
    end
    self._bb:invert()
    bb:colorblitFromRGB32(self._bb, x, y, self._offset_x, self._offset_y, size.w, size.h, self._tint_color)
    self._bb:invert()
end

-- === Build a single tab ===

local function createTabWidget(tab, tab_w, is_active)
    local styled = is_active and config.active_tab_styling
    local use_color = styled and config.colored and Screen:isColorScreen()
    local active_color
    if use_color then
        local c = config.active_tab_color
        if c and type(c) == "table" then
            active_color = Blitbuffer.ColorRGB32(c[1], c[2], c[3], 0xFF)
        end
    end

    local use_bold = styled and config.active_tab_bold

    local icon
    if active_color then
        icon =
            ColorIconWidget:new {
            icon = tab.icon,
            width = navbar_icon_size,
            height = navbar_icon_size,
            _tint_color = active_color
        }
    else
        icon =
            IconWidget:new {
            icon = tab.icon,
            width = navbar_icon_size,
            height = navbar_icon_size
        }
    end

    local label
    if active_color then
        label =
            ColorTextWidget:new {
            text = tab.label,
            face = use_bold and navbar_font_bold or navbar_font,
            fgcolor = active_color
        }
    else
        label =
            TextWidget:new {
            text = tab.label,
            face = use_bold and navbar_font_bold or navbar_font
        }
    end

    local icon_label_group
    if config.show_labels then
        icon_label_group =
            VerticalGroup:new {
            align = "center",
            icon,
            label
        }
    else
        icon_label_group =
            VerticalGroup:new {
            align = "center",
            icon
        }
    end

    local show_underline = styled and config.active_tab_underline
    local underline
    if show_underline then
        local underline_color = Blitbuffer.COLOR_BLACK
        if config.colored then
            local c = config.active_tab_color
            if c and type(c) == "table" then
                underline_color = Blitbuffer.ColorRGB32(c[1], c[2], c[3], 0xFF)
            end
        end
        if config.colored and Screen:isColorScreen() then
            local Widget = require("ui/widget/widget")
            local color_line =
                Widget:new {
                dimen = Geom:new {w = tab_w, h = underline_thickness}
            }
            function color_line:paintTo(bb, x, y)
                bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h, underline_color)
            end
            underline = color_line
        else
            underline =
                LineWidget:new {
                dimen = Geom:new {w = tab_w, h = underline_thickness},
                background = underline_color
            }
        end
    else
        underline = VerticalSpan:new {width = underline_thickness}
    end

    local v_pad = config.show_labels and navbar_v_padding or navbar_v_padding * 2

    local children
    if config.underline_above then
        children = {
            align = "center",
            underline,
            VerticalSpan:new {width = v_pad},
            icon_label_group,
            VerticalSpan:new {width = v_pad}
        }
    else
        children = {
            align = "center",
            VerticalSpan:new {width = v_pad},
            icon_label_group,
            VerticalSpan:new {width = v_pad},
            underline
        }
    end

    return CenterContainer:new {
        dimen = Geom:new {w = tab_w, h = icon_label_group:getSize().h + v_pad * 2 + underline_thickness},
        VerticalGroup:new(children)
    }
end

-- === Build the full navbar ===

local HorizontalSpan = require("ui/widget/horizontalspan")
local navbar_h_padding = Screen:scaleBySize(10)

local function getVisibleTabs()
    local visible = {}
    for _, tab_id in ipairs(config.tab_order) do
        if (tab_id == "books" or config.show_tabs[tab_id]) and tabs_by_id[tab_id] then
            table.insert(visible, tabs_by_id[tab_id])
        end
    end
    return visible
end

local function createNavBar()
    tabs_by_id["books"].label = getBooksLabel()

    local visible_tabs = getVisibleTabs()
    if #visible_tabs == 0 then
        return nil
    end

    local screen_w = Screen:getWidth()
    local inner_w = screen_w - navbar_h_padding * 2
    local tab_w = math.floor(inner_w / #visible_tabs)

    local row = HorizontalGroup:new {}
    for _, tab in ipairs(visible_tabs) do
        table.insert(row, createTabWidget(tab, tab_w, tab.id == active_tab))
    end

    local OverlapGroup = require("ui/widget/overlapgroup")
    local row_with_padding =
        HorizontalGroup:new {
        HorizontalSpan:new {width = navbar_h_padding},
        row,
        HorizontalSpan:new {width = navbar_h_padding}
    }
    local row_h = row_with_padding:getSize().h

    local visual_children = {}

    if config.show_top_border then
        local separator =
            LineWidget:new {
            dimen = Geom:new {w = inner_w, h = Size.line.medium},
            background = Blitbuffer.COLOR_LIGHT_GRAY
        }
        local separator_and_row =
            OverlapGroup:new {
            dimen = Geom:new {w = screen_w, h = row_h},
            allow_mirroring = false,
            CenterContainer:new {
                dimen = Geom:new {w = screen_w, h = Size.line.medium},
                separator
            },
            row_with_padding
        }
        if config.show_top_gap then
            table.insert(visual_children, VerticalSpan:new {width = navbar_top_gap})
        end
        table.insert(visual_children, separator_and_row)
    else
        if config.show_top_gap then
            table.insert(visual_children, VerticalSpan:new {width = navbar_top_gap})
        end
        table.insert(visual_children, row_with_padding)
    end

    local visual = VerticalGroup:new(visual_children)

    -- Wrap in InputContainer to handle taps on the whole navbar
    local navbar =
        InputContainer:new {
        dimen = Geom:new {w = screen_w, h = visual:getSize().h},
        ges_events = {
            TapNavBar = {
                GestureRange:new {
                    ges = "tap",
                    range = Geom:new {x = 0, y = 0, w = screen_w, h = Screen:getHeight()}
                }
            }
        }
    }

    navbar.onTapNavBar = function(self, _, ges)
        if not self.dimen or not self.dimen:contains(ges.pos) then
            return false
        end
        -- Corner dead zone
        if ges.pos.x < corner_dead_zone or ges.pos.x > screen_w - corner_dead_zone then
            return false
        end
        local tap_x = ges.pos.x - navbar_h_padding
        local idx = math.floor(tap_x / tab_w) + 1
        idx = math.max(1, math.min(#visible_tabs, idx))
        local tapped_id = visible_tabs[idx].id
        local cb = getTabCallback(tapped_id)
        if cb then
            cb()
        end
        local stays_in_browser =
            tapped_id == "books" or
            (tapped_id == "manga" and config.manga_action == "folder" and config.manga_folder ~= "") or
            (tapped_id == "news" and config.news_action == "folder" and config.news_folder ~= "") or
            -- Custom folder tabs also stay in browser
            (tapped_id:match("^folder_") ~= nil)
        if stays_in_browser and tapped_id ~= active_tab then
            setActiveTab(tapped_id)
        end
        return true
    end

    navbar[1] = visual
    return navbar
end

-- === Hook Menu:init() to reduce height ===

local Menu = require("ui/widget/menu")

local function getNavbarHeight()
    local nb = createNavBar()
    return nb and nb:getSize().h or 0
end

local standalone_view_names = {
    history = true,
    collections = true,
    library_view = true -- Rakuyomi
}

local standalone_nexttick_tab_ids = {
    library_view = "manga"
}

local function isStandaloneNavbarView(menu)
    if standalone_view_names[menu.name] then
        return true
    end
    if not menu.name and menu.covers_fullscreen and menu.is_borderless and menu.title_bar_fm_style then
        return true
    end
    return false
end

local _skip_standalone_navbar = false

local orig_menu_init = Menu.init

function Menu:init()
    if self.name == "filemanager" and not self.height then
        self.height = Screen:getHeight() - getNavbarHeight()
    elseif config.show_in_standalone and not _skip_standalone_navbar and isStandaloneNavbarView(self) then
        self.height = Screen:getHeight() - getNavbarHeight()
        if not self.is_borderless then
            self.is_borderless = true
        end
    end
    orig_menu_init(self)
    local nexttick_tab_id = standalone_nexttick_tab_ids[self.name]
    if nexttick_tab_id and config.show_in_standalone then
        local menu = self
        UIManager:nextTick(
            function()
                injectStandaloneNavbar(menu, nexttick_tab_id)
            end
        )
    end
end

-- === Auto-switch active tab on folder change ===

local orig_onPathChanged = FileManager.onPathChanged

function FileManager:onPathChanged(path)
    if orig_onPathChanged then
        orig_onPathChanged(self, path)
    end

    local function startsWith(str, prefix)
        return str:sub(1, #prefix) == prefix
    end

    local new_tab
    if config.manga_action == "folder" and config.manga_folder ~= "" then
        if path == config.manga_folder or startsWith(path, config.manga_folder .. "/") then
            new_tab = "manga"
        end
    end
    if not new_tab and config.news_action == "folder" and config.news_folder ~= "" then
        if path == config.news_folder or startsWith(path, config.news_folder .. "/") then
            new_tab = "news"
        end
    end
    if not new_tab then
        local home_dir =
            G_reader_settings:readSetting("home_dir") or require("apps/filemanager/filemanagerutil").getDefaultDir()
        if path == home_dir or startsWith(path, home_dir .. "/") then
            new_tab = "books"
        end
    end

    -- Also check custom folder tabs
    if not new_tab then
        for _, ct in ipairs(config.custom_tabs) do
            if ct.source == "folder" and ct.folder_path then
                if path == ct.folder_path or startsWith(path, ct.folder_path .. "/") then
                    new_tab = ct.id
                    break
                end
            end
        end
    end

    if new_tab and new_tab ~= active_tab then
        active_tab = new_tab
        injectNavbar(self)
        UIManager:setDirty(self, "full")
    end
end

-- === Inject navbar into FileManager ===

injectNavbar = function(fm)
    local fm_ui = fm[1]
    if not fm_ui then
        return
    end

    local file_chooser
    if fm._navbar_injected then
        file_chooser = fm_ui[1] and fm_ui[1][1]
    else
        file_chooser = fm_ui[1]
    end
    if not file_chooser then
        return
    end

    fm._navbar_injected = true

    local navbar = createNavBar()
    if not navbar then
        fm_ui[1] = file_chooser
        return
    end

    local navbar_h = navbar:getSize().h
    local new_height = Screen:getHeight() - navbar_h
    if file_chooser.height ~= new_height then
        local chrome = file_chooser.dimen.h - file_chooser.inner_dimen.h
        file_chooser.height = new_height
        file_chooser.dimen.h = new_height
        file_chooser.inner_dimen.h = new_height - chrome
        file_chooser:updateItems()
    end

    fm_ui[1] =
        VerticalGroup:new {
        align = "left",
        file_chooser,
        navbar
    }
end

-- === Inject navbar into standalone views ===

injectStandaloneNavbar = function(menu, view_tab_id)
    if not menu or not menu[1] then
        return
    end

    local saved_active = active_tab
    active_tab = view_tab_id
    local navbar = createNavBar()
    active_tab = saved_active

    if not navbar then
        return
    end

    navbar.onTapNavBar = function(self_nb, _, ges)
        if not self_nb.dimen or not self_nb.dimen:contains(ges.pos) then
            return false
        end
        local screen_w = Screen:getWidth()
        if ges.pos.x < corner_dead_zone or ges.pos.x > screen_w - corner_dead_zone then
            return false
        end
        local vis_tabs = getVisibleTabs()
        if #vis_tabs == 0 then
            return false
        end
        local inner_w = screen_w - navbar_h_padding * 2
        local tab_w_local = math.floor(inner_w / #vis_tabs)
        local tap_x = ges.pos.x - navbar_h_padding
        local idx = math.floor(tap_x / tab_w_local) + 1
        idx = math.max(1, math.min(#vis_tabs, idx))
        local tapped_id = vis_tabs[idx].id

        if tapped_id == view_tab_id then
            return true
        end

        if menu.close_callback then
            menu.close_callback()
        elseif menu.onClose then
            menu:onClose()
        else
            UIManager:close(menu)
        end

        setActiveTab(tapped_id)

        local cb = getTabCallback(tapped_id)
        if cb then
            cb()
        end

        return true
    end

    menu.dimen.h = Screen:getHeight()

    local FrameContainer = require("ui/widget/container/framecontainer")
    menu[1] =
        FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        VerticalGroup:new {
            align = "left",
            menu[1],
            navbar
        }
    }
end

local orig_setupLayout = FileManager.setupLayout

function FileManager:setupLayout()
    orig_setupLayout(self)

    self._navbar_injected = false

    local fm = self
    UIManager:nextTick(
        function()
            injectNavbar(fm)
            UIManager:setDirty(fm, "ui")
        end
    )
end

-- === Hook standalone views ===

local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
local orig_onShowHist = FileManagerHistory.onShowHist

function FileManagerHistory:onShowHist(search_info)
    local result = orig_onShowHist(self, search_info)
    if config.show_in_standalone and self.booklist_menu then
        injectStandaloneNavbar(self.booklist_menu, "history")
    end
    return result
end

local FileManagerCollection = require("apps/filemanager/filemanagercollection")
local orig_onShowColl = FileManagerCollection.onShowColl

function FileManagerCollection:onShowColl(collection_name)
    local from_coll_list = self.coll_list ~= nil
    local result = orig_onShowColl(self, collection_name)
    if config.show_in_standalone and self.booklist_menu then
        injectStandaloneNavbar(self.booklist_menu, from_coll_list and "collections" or "favorites")
    end
    return result
end

local orig_onShowCollList = FileManagerCollection.onShowCollList

function FileManagerCollection:onShowCollList(file_or_selected_collections, caller_callback, no_dialog)
    if file_or_selected_collections ~= nil then
        _skip_standalone_navbar = true
    end
    local result = orig_onShowCollList(self, file_or_selected_collections, caller_callback, no_dialog)
    _skip_standalone_navbar = false
    if config.show_in_standalone and self.coll_list and file_or_selected_collections == nil then
        injectStandaloneNavbar(self.coll_list, "collections")
    end
    return result
end

-- === Hook QuickRSS ===

local _qrss_hooked = false

hookQuickRSSInit = function()
    if _qrss_hooked then
        return
    end
    local ok, QuickRSSUI_class = pcall(require, "modules/ui/feed_view")
    if not ok or not QuickRSSUI_class then
        return
    end
    _qrss_hooked = true

    local ok_ai, ArticleItemModule = pcall(require, "modules/ui/article_item")
    local QRSS_ITEM_HEIGHT = ok_ai and ArticleItemModule.ITEM_HEIGHT

    local orig_qrss_init = QuickRSSUI_class.init
    function QuickRSSUI_class:init()
        orig_qrss_init(self)

        if not config.show_in_standalone then
            return
        end

        local navbar_h = getNavbarHeight()
        if navbar_h <= 0 then
            return
        end

        self[1].height = self[1].height - navbar_h
        self.list_h = self.list_h - navbar_h
        if QRSS_ITEM_HEIGHT then
            self.items_per_page = math.max(1, math.floor(self.list_h / QRSS_ITEM_HEIGHT))
        end

        local saved_active = active_tab
        active_tab = "news"
        local navbar = createNavBar()
        active_tab = saved_active
        if not navbar then
            return
        end

        navbar.onTapNavBar = function(self_nb, _, ges)
            if not self_nb.dimen or not self_nb.dimen:contains(ges.pos) then
                return false
            end
            local screen_w = Screen:getWidth()
            if ges.pos.x < corner_dead_zone or ges.pos.x > screen_w - corner_dead_zone then
                return false
            end
            local vis_tabs = getVisibleTabs()
            if #vis_tabs == 0 then
                return false
            end
            local inner_w = screen_w - navbar_h_padding * 2
            local tab_w_local = math.floor(inner_w / #vis_tabs)
            local tap_x = ges.pos.x - navbar_h_padding
            local idx = math.floor(tap_x / tab_w_local) + 1
            idx = math.max(1, math.min(#vis_tabs, idx))
            local tapped_id = vis_tabs[idx].id
            if tapped_id == "news" then
                return true
            end
            self:onClose()
            setActiveTab(tapped_id)
            local cb = getTabCallback(tapped_id)
            if cb then
                cb()
            end
            return true
        end

        local FrameContainer = require("ui/widget/container/framecontainer")
        self[1] =
            FrameContainer:new {
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 0,
            padding = 0,
            margin = 0,
            VerticalGroup:new {
                align = "left",
                self[1],
                navbar
            }
        }

        self.dimen = Geom:new {w = Screen:getWidth(), h = Screen:getHeight()}

        if #self.articles > 0 then
            self:_populateItems()
        end
    end

    local orig_qrss_onClose = QuickRSSUI_class.onClose
    function QuickRSSUI_class:onClose()
        orig_qrss_onClose(self)
        setActiveTab("books")
    end
end

-- === Settings menu ===

local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local FileManagerMenuOrder = require("ui/elements/filemanager_menu_order")

local orig_setUpdateItemTable = FileManagerMenu.setUpdateItemTable

function FileManagerMenu:setUpdateItemTable()
    table.insert(FileManagerMenuOrder.filemanager_settings, "navbar_settings")

    self.menu_items.navbar_settings = {
        text = _("Navbar settings"),
        sub_item_table = {
            -- Size options
            {
                text = _("Navbar Size"),
                sub_item_table = {
                    {
                        text = _("Tiny"),
                        checked_func = function()
                            return config.navbar_size == "tiny"
                        end,
                        callback = function()
                            config.navbar_size = "tiny"
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Small"),
                        checked_func = function()
                            return config.navbar_size == "small"
                        end,
                        callback = function()
                            config.navbar_size = "small"
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Medium"),
                        checked_func = function()
                            return config.navbar_size == "medium"
                        end,
                        callback = function()
                            config.navbar_size = "medium"
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Large"),
                        checked_func = function()
                            return config.navbar_size == "large"
                        end,
                        callback = function()
                            config.navbar_size = "large"
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Huge"),
                        checked_func = function()
                            return config.navbar_size == "huge"
                        end,
                        callback = function()
                            config.navbar_size = "huge"
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    }
                }
            },
            -- Basic options
            {
                text = _("Show labels"),
                checked_func = function()
                    return config.show_labels
                end,
                callback = function()
                    config.show_labels = not config.show_labels
                    G_reader_settings:saveSetting("bottom_navbar", config)
                end
            },
            {
                text = _("Label font size"),
                enabled_func = function()
                    return config.show_labels
                end,
                sub_item_table = {
                    {
                        text = _("Small (12)"),
                        checked_func = function()
                            return config.label_font_size == 12
                        end,
                        callback = function()
                            config.label_font_size = 12
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Medium (14)"),
                        checked_func = function()
                            return config.label_font_size == 14
                        end,
                        callback = function()
                            config.label_font_size = 14
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Large (16)"),
                        checked_func = function()
                            return config.label_font_size == 16
                        end,
                        callback = function()
                            config.label_font_size = 16
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Extra Large (18)"),
                        checked_func = function()
                            return config.label_font_size == 18
                        end,
                        callback = function()
                            config.label_font_size = 18
                            updateLayoutConstants()
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Custom"),
                        keep_menu_open = true,
                        callback = function(touchmenu_instance)
                            local dlg
                            dlg =
                                InputDialog:new {
                                title = _("Font size"),
                                input = tostring(config.label_font_size),
                                hint = _("Enter font size (5-30)"),
                                buttons = {
                                    {
                                        {
                                            text = _("Cancel"),
                                            callback = function()
                                                UIManager:close(dlg)
                                            end
                                        },
                                        {
                                            text = _("Set"),
                                            is_enter_default = true,
                                            callback = function()
                                                local size = tonumber(dlg:getInputText())
                                                if size and size >= 5 and size <= 30 then
                                                    config.label_font_size = size
                                                    updateLayoutConstants()
                                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                                    UIManager:close(dlg)
                                                    if touchmenu_instance then
                                                        touchmenu_instance:updateItems()
                                                    end
                                                end
                                            end
                                        }
                                    }
                                }
                            }
                            UIManager:show(dlg)
                            dlg:onShowKeyboard()
                        end
                    }
                }
            },
            {
                text = _("Show top border"),
                checked_func = function()
                    return config.show_top_border
                end,
                callback = function()
                    config.show_top_border = not config.show_top_border
                    G_reader_settings:saveSetting("bottom_navbar", config)
                end
            },
            -- Active tab styling
            {
                text = _("Active tab"),
                sub_item_table = {
                    {
                        text = _("Enable active tab styling"),
                        checked_func = function()
                            return config.active_tab_styling
                        end,
                        callback = function()
                            config.active_tab_styling = not config.active_tab_styling
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Bold active tab"),
                        enabled_func = function()
                            return config.active_tab_styling
                        end,
                        checked_func = function()
                            return config.active_tab_bold
                        end,
                        callback = function()
                            config.active_tab_bold = not config.active_tab_bold
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Active tab underline"),
                        enabled_func = function()
                            return config.active_tab_styling
                        end,
                        checked_func = function()
                            return config.active_tab_underline
                        end,
                        callback = function()
                            config.active_tab_underline = not config.active_tab_underline
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text_func = function()
                            return _("Underline location: ") .. (config.underline_above and _("above") or _("below"))
                        end,
                        enabled_func = function()
                            return config.active_tab_styling and config.active_tab_underline
                        end,
                        callback = function()
                            config.underline_above = not config.underline_above
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Colored active tab"),
                        enabled_func = function()
                            return config.active_tab_styling
                        end,
                        checked_func = function()
                            return config.colored
                        end,
                        callback = function()
                            config.colored = not config.colored
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    -- Color presets
                    {
                        text_func = function()
                            if config.active_color_index == 0 then
                                return _("Color: Default")
                            elseif kaleido_colors[config.active_color_index] then
                                return _("Color: ") .. kaleido_colors[config.active_color_index].name
                            end
                            return _("Color")
                        end,
                        enabled_func = function()
                            return config.active_tab_styling and config.colored and Screen:isColorScreen()
                        end,
                        sub_item_table = {
                            {
                                text = _("Default Blue"),
                                checked_func = function()
                                    return config.active_color_index == 0
                                end,
                                callback = function()
                                    config.active_color_index = 0
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Ocean Blue"),
                                checked_func = function()
                                    return config.active_color_index == 1
                                end,
                                callback = function()
                                    config.active_color_index = 1
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Forest Green"),
                                checked_func = function()
                                    return config.active_color_index == 2
                                end,
                                callback = function()
                                    config.active_color_index = 2
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Sunset Orange"),
                                checked_func = function()
                                    return config.active_color_index == 3
                                end,
                                callback = function()
                                    config.active_color_index = 3
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Royal Purple"),
                                checked_func = function()
                                    return config.active_color_index == 4
                                end,
                                callback = function()
                                    config.active_color_index = 4
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Coral Pink"),
                                checked_func = function()
                                    return config.active_color_index == 5
                                end,
                                callback = function()
                                    config.active_color_index = 5
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Mint Green"),
                                checked_func = function()
                                    return config.active_color_index == 6
                                end,
                                callback = function()
                                    config.active_color_index = 6
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Gold"),
                                checked_func = function()
                                    return config.active_color_index == 7
                                end,
                                callback = function()
                                    config.active_color_index = 7
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Ruby Red"),
                                checked_func = function()
                                    return config.active_color_index == 8
                                end,
                                callback = function()
                                    config.active_color_index = 8
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Slate Blue"),
                                checked_func = function()
                                    return config.active_color_index == 9
                                end,
                                callback = function()
                                    config.active_color_index = 9
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Teal"),
                                checked_func = function()
                                    return config.active_color_index == 10
                                end,
                                callback = function()
                                    config.active_color_index = 10
                                    updateLayoutConstants()
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            }
                        }
                    }
                }
            },
            -- Tab configuration
            {
                text = _("Tabs"),
                sub_item_table = {
                    {
                        text = _("Arrange tabs"),
                        keep_menu_open = true,
                        callback = function()
                            local SortWidget = require("ui/widget/sortwidget")
                            local sort_items = {}
                            for _, tab_id in ipairs(config.tab_order) do
                                local tab = tabs_by_id[tab_id]
                                if tab then
                                    table.insert(
                                        sort_items,
                                        {
                                            text = tab.label,
                                            orig_item = tab_id,
                                            dim = not config.show_tabs[tab_id]
                                        }
                                    )
                                end
                            end
                            UIManager:show(
                                SortWidget:new {
                                    title = _("Arrange navbar tabs"),
                                    item_table = sort_items,
                                    callback = function()
                                        for i, item in ipairs(sort_items) do
                                            config.tab_order[i] = item.orig_item
                                        end
                                        G_reader_settings:saveSetting("bottom_navbar", config)
                                    end
                                }
                            )
                        end
                    },
                    {
                        text_func = function()
                            return _("Books tab label: ") .. getBooksLabel()
                        end,
                        separator = true,
                        sub_item_table = {
                            {
                                text = _("Books"),
                                checked_func = function()
                                    return config.books_label == "Books" or config.books_label == ""
                                end,
                                callback = function()
                                    config.books_label = "Books"
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Home"),
                                checked_func = function()
                                    return config.books_label == "Home"
                                end,
                                callback = function()
                                    config.books_label = "Home"
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text = _("Library"),
                                checked_func = function()
                                    return config.books_label == "Library"
                                end,
                                callback = function()
                                    config.books_label = "Library"
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text_func = function()
                                    local presets = {[""] = true, Books = true, Home = true, Library = true}
                                    if presets[config.books_label] then
                                        return _("Custom")
                                    end
                                    return _("Custom: ") .. config.books_label
                                end,
                                checked_func = function()
                                    local presets = {[""] = true, Books = true, Home = true, Library = true}
                                    return not presets[config.books_label]
                                end,
                                keep_menu_open = true,
                                callback = function(touchmenu_instance)
                                    local InputDialog = require("ui/widget/inputdialog")
                                    local dlg
                                    dlg =
                                        InputDialog:new {
                                        title = _("Books tab label"),
                                        input = config.books_label,
                                        buttons = {
                                            {
                                                {
                                                    text = _("Cancel"),
                                                    id = "close",
                                                    callback = function()
                                                        UIManager:close(dlg)
                                                    end
                                                },
                                                {
                                                    text = _("Set"),
                                                    is_enter_default = true,
                                                    callback = function()
                                                        local text = dlg:getInputText()
                                                        config.books_label = text ~= "" and text or "Books"
                                                        G_reader_settings:saveSetting("bottom_navbar", config)
                                                        UIManager:close(dlg)
                                                        if touchmenu_instance then
                                                            touchmenu_instance:updateItems()
                                                        end
                                                    end
                                                }
                                            }
                                        }
                                    }
                                    UIManager:show(dlg)
                                    dlg:onShowKeyboard()
                                end
                            }
                        }
                    },
                    -- Manga tab
                    {
                        text = _("Manga"),
                        checked_func = function()
                            return config.show_tabs.manga
                        end,
                        callback = function()
                            config.show_tabs.manga = not config.show_tabs.manga
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text_func = function()
                            if config.manga_action == "folder" then
                                return _("Manga tab action: ") .. _("Folder")
                            end
                            return _("Manga tab action: ") .. _("Rakuyomi")
                        end,
                        separator = true,
                        sub_item_table = {
                            {
                                text = _("Open Rakuyomi"),
                                checked_func = function()
                                    return config.manga_action ~= "folder"
                                end,
                                callback = function()
                                    config.manga_action = "rakuyomi"
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text_func = function()
                                    if config.manga_action == "folder" and config.manga_folder ~= "" then
                                        local util = require("util")
                                        local _dir, folder_name = util.splitFilePathName(config.manga_folder)
                                        return _("Open folder: ") .. folder_name
                                    end
                                    return _("Open folder")
                                end,
                                checked_func = function()
                                    return config.manga_action == "folder"
                                end,
                                keep_menu_open = true,
                                callback = function(touchmenu_instance)
                                    local PathChooser = require("ui/widget/pathchooser")
                                    local start_path =
                                        config.manga_folder ~= "" and config.manga_folder or
                                        G_reader_settings:readSetting("lastdir") or
                                        "/"
                                    local path_chooser =
                                        PathChooser:new {
                                        select_file = false,
                                        show_files = false,
                                        path = start_path,
                                        onConfirm = function(dir_path)
                                            config.manga_action = "folder"
                                            config.manga_folder = dir_path
                                            G_reader_settings:saveSetting("bottom_navbar", config)
                                            if touchmenu_instance then
                                                touchmenu_instance:updateItems()
                                            end
                                        end
                                    }
                                    UIManager:show(path_chooser)
                                end
                            }
                        }
                    },
                    -- News tab
                    {
                        text = _("News"),
                        checked_func = function()
                            return config.show_tabs.news
                        end,
                        callback = function()
                            config.show_tabs.news = not config.show_tabs.news
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text_func = function()
                            if config.news_action == "folder" then
                                return _("News tab action: ") .. _("Folder")
                            end
                            return _("News tab action: ") .. _("QuickRSS")
                        end,
                        separator = true,
                        sub_item_table = {
                            {
                                text = _("Open QuickRSS"),
                                checked_func = function()
                                    return config.news_action ~= "folder"
                                end,
                                callback = function()
                                    config.news_action = "quickrss"
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end
                            },
                            {
                                text_func = function()
                                    if config.news_action == "folder" and config.news_folder ~= "" then
                                        local util = require("util")
                                        local _dir, folder_name = util.splitFilePathName(config.news_folder)
                                        return _("Open folder: ") .. folder_name
                                    end
                                    return _("Open folder")
                                end,
                                checked_func = function()
                                    return config.news_action == "folder"
                                end,
                                keep_menu_open = true,
                                callback = function(touchmenu_instance)
                                    local PathChooser = require("ui/widget/pathchooser")
                                    local start_path =
                                        config.news_folder ~= "" and config.news_folder or
                                        G_reader_settings:readSetting("lastdir") or
                                        "/"
                                    local path_chooser =
                                        PathChooser:new {
                                        select_file = false,
                                        show_files = false,
                                        path = start_path,
                                        onConfirm = function(dir_path)
                                            config.news_action = "folder"
                                            config.news_folder = dir_path
                                            G_reader_settings:saveSetting("bottom_navbar", config)
                                            if touchmenu_instance then
                                                touchmenu_instance:updateItems()
                                            end
                                        end
                                    }
                                    UIManager:show(path_chooser)
                                end
                            }
                        }
                    },
                    -- Basic tabs
                    {
                        text = _("Continue"),
                        checked_func = function()
                            return config.show_tabs.continue
                        end,
                        callback = function()
                            config.show_tabs.continue = not config.show_tabs.continue
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("History"),
                        checked_func = function()
                            return config.show_tabs.history
                        end,
                        callback = function()
                            config.show_tabs.history = not config.show_tabs.history
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Favorites"),
                        checked_func = function()
                            return config.show_tabs.favorites
                        end,
                        callback = function()
                            config.show_tabs.favorites = not config.show_tabs.favorites
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Collections"),
                        checked_func = function()
                            return config.show_tabs.collections
                        end,
                        callback = function()
                            config.show_tabs.collections = not config.show_tabs.collections
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    -- Extended tabs
                    {
                        text = _("Z-Lib"),
                        checked_func = function()
                            return config.show_tabs.zlib
                        end,
                        callback = function()
                            config.show_tabs.zlib = not config.show_tabs.zlib
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Anna's Archive"),
                        checked_func = function()
                            return config.show_tabs.annas
                        end,
                        callback = function()
                            config.show_tabs.annas = not config.show_tabs.annas
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("AppStore"),
                        checked_func = function()
                            return config.show_tabs.appstore
                        end,
                        callback = function()
                            config.show_tabs.appstore = not config.show_tabs.appstore
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("OPDS"),
                        checked_func = function()
                            return config.show_tabs.opds
                        end,
                        callback = function()
                            config.show_tabs.opds = not config.show_tabs.opds
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Reading Stats"),
                        checked_func = function()
                            return config.show_tabs.stats
                        end,
                        callback = function()
                            config.show_tabs.stats = not config.show_tabs.stats
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    -- Exit tab
                    {
                        text = _("Exit"),
                        checked_func = function()
                            return config.show_tabs.exit
                        end,
                        callback = function()
                            config.show_tabs.exit = not config.show_tabs.exit
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    -- Sleep tab
                    {
                        text = _("Sleep"),
                        checked_func = function()
                            return config.show_tabs.sleep
                        end,
                        callback = function()
                            config.show_tabs.sleep = not config.show_tabs.sleep
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    -- Restart tab
                    {
                        text = _("Restart"),
                        checked_func = function()
                            return config.show_tabs.restart
                        end,
                        callback = function()
                            config.show_tabs.restart = not config.show_tabs.restart
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    -- Page navigation tabs
                    {
                        text = _("Previous page"),
                        checked_func = function()
                            return config.show_tabs.page_left
                        end,
                        callback = function()
                            config.show_tabs.page_left = not config.show_tabs.page_left
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Next page"),
                        checked_func = function()
                            return config.show_tabs.page_right
                        end,
                        callback = function()
                            config.show_tabs.page_right = not config.show_tabs.page_right
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    }
                }
            },
            -- Custom tabs (with enhanced folder support and icon name input)
            {
                text = _("Custom tabs"),
                sub_item_table_func = function()
                    local items = {}

                    -- List existing custom tabs
                    for i, ct in ipairs(config.custom_tabs) do
                        local idx = i
                        table.insert(
                            items,
                            {
                                text_func = function()
                                    local detail
                                    if ct.source == "folder" then
                                        local util = require("util")
                                        local _dir, folder_name = util.splitFilePathName(ct.folder_path or "")
                                        detail = "" .. (folder_name or "folder")
                                    elseif ct.fm_key then
                                        detail = ct.fm_key .. ":" .. (ct.fm_method or "?")
                                    elseif ct.dispatcher_action then
                                        detail = ct.dispatcher_action
                                    else
                                        detail = "?"
                                    end
                                    return ct.label .. "  [" .. detail .. "]"
                                end,
                                checked_func = function()
                                    return config.show_tabs[ct.id] == true
                                end,
                                callback = function()
                                    config.show_tabs[ct.id] = not config.show_tabs[ct.id]
                                    G_reader_settings:saveSetting("bottom_navbar", config)
                                end,
                                hold_callback = function(touchmenu_instance)
                                    local ConfirmBox = require("ui/widget/confirmbox")
                                    UIManager:show(
                                        ConfirmBox:new {
                                            text = _("Remove tab '") .. ct.label .. _("'?"),
                                            ok_callback = function()
                                                config.show_tabs[ct.id] = nil
                                                for j = #config.tab_order, 1, -1 do
                                                    if config.tab_order[j] == ct.id then
                                                        table.remove(config.tab_order, j)
                                                    end
                                                end
                                                table.remove(config.custom_tabs, idx)
                                                registerCustomTabs()
                                                G_reader_settings:saveSetting("bottom_navbar", config)
                                                if touchmenu_instance then
                                                    touchmenu_instance:updateItems()
                                                end
                                            end
                                        }
                                    )
                                end
                            }
                        )
                    end

                    -- Add new custom tab options
                    table.insert(
                        items,
                        {
                            text = _("+ Add folder tab️"),
                            separator = true,
                            callback = function(touchmenu_instance)
                                local PathChooser = require("ui/widget/pathchooser")
                                local start_path = G_reader_settings:readSetting("lastdir") or "/"
                                local path_chooser =
                                    PathChooser:new {
                                    select_file = false,
                                    show_files = false,
                                    path = start_path,
                                    onConfirm = function(dir_path)
                                        -- Create dialog variables at this scope level
                                        local icon_dialog
                                        local label_dialog

                                        -- Define showLabelDialog
                                        local function showLabelDialog(icon_name, folder_path)
                                            local util = require("util")
                                            local _dir, folder_name = util.splitFilePathName(folder_path)

                                            label_dialog =
                                                InputDialog:new {
                                                title = _("Tab label"),
                                                input = folder_name or "Folder",
                                                buttons = {
                                                    {
                                                        {
                                                            text = _("Cancel"),
                                                            id = "close",
                                                            callback = function()
                                                                UIManager:close(label_dialog)
                                                            end
                                                        },
                                                        {
                                                            text = _("Add tab"),
                                                            is_enter_default = true,
                                                            callback = function()
                                                                local tab_label = label_dialog:getInputText()
                                                                if tab_label == "" then
                                                                    tab_label = folder_name or "Folder"
                                                                end
                                                                UIManager:close(label_dialog)

                                                                local new_id =
                                                                    "folder_" .. folder_path:gsub("[^%w]", "_")
                                                                local new_ct = {
                                                                    id = new_id,
                                                                    label = tab_label,
                                                                    icon = icon_name,
                                                                    source = "folder",
                                                                    folder_path = folder_path
                                                                }

                                                                local found = false
                                                                for i, ct in ipairs(config.custom_tabs) do
                                                                    if ct.id == new_id then
                                                                        config.custom_tabs[i] = new_ct
                                                                        found = true
                                                                        break
                                                                    end
                                                                end
                                                                if not found then
                                                                    table.insert(config.custom_tabs, new_ct)
                                                                    config.show_tabs[new_id] = true
                                                                    table.insert(config.tab_order, new_id)
                                                                end

                                                                registerCustomTabs()
                                                                G_reader_settings:saveSetting("bottom_navbar", config)

                                                                UIManager:show(
                                                                    InfoMessage:new {
                                                                        text = _("Folder tab '") ..
                                                                            tab_label ..
                                                                                _(
                                                                                    "' added!\nTap 'Refresh navbar' to apply."
                                                                                ),
                                                                        timeout = 3
                                                                    }
                                                                )

                                                                if touchmenu_instance then
                                                                    touchmenu_instance:updateItems()
                                                                end
                                                            end
                                                        }
                                                    }
                                                }
                                            }
                                            UIManager:show(label_dialog)
                                            label_dialog:onShowKeyboard()
                                        end

                                        -- Define showIconDialog
                                        local function showIconDialog()
                                            icon_dialog =
                                                InputDialog:new {
                                                title = _("Icon filename"),
                                                hint = _("e.g., appbar.search, tab_books, or custom icon name"),
                                                input = "appbar.filebrowser",
                                                description = _("Enter the icon filename (without .png/.svg extension)"),
                                                buttons = {
                                                    {
                                                        {
                                                            text = _("Cancel"),
                                                            id = "close",
                                                            callback = function()
                                                                UIManager:close(icon_dialog)
                                                            end
                                                        },
                                                        {
                                                            text = _("Next"),
                                                            is_enter_default = true,
                                                            callback = function()
                                                                local icon_name = icon_dialog:getInputText()
                                                                if icon_name == "" then
                                                                    icon_name = "appbar.filebrowser"
                                                                end
                                                                UIManager:close(icon_dialog)

                                                                showLabelDialog(icon_name, dir_path)
                                                            end
                                                        }
                                                    }
                                                }
                                            }
                                            UIManager:show(icon_dialog)
                                            icon_dialog:onShowKeyboard()
                                        end

                                        -- Start the process
                                        showIconDialog()
                                    end
                                }
                                UIManager:show(path_chooser)
                            end
                        }
                    )

                    -- Add action-based custom tab option
                    table.insert(
                        items,
                        {
                            text = _("+ Add action tab"),
                            sub_item_table_func = function()
                                local fm = FileManager.instance

                                local settings_list = Dispatcher.settingsList or {}
                                local action_items = {}
                                local seen_ids = {}

                                for action_id, action_data in pairs(settings_list) do
                                    if (action_data.general or action_data.filemanager) and not seen_ids[action_id] then
                                        seen_ids[action_id] = true
                                        table.insert(
                                            action_items,
                                            {
                                                id = action_id,
                                                title = action_data.title or action_id,
                                                source = "dispatcher"
                                            }
                                        )
                                    end
                                end

                                if fm then
                                    local skip_keys = {
                                        file_chooser = true,
                                        _name = true,
                                        _classname = true,
                                        ui = true,
                                        dialog = true,
                                        history = true,
                                        collections = true,
                                        toolbar = true,
                                        menu = true
                                    }
                                    for key, val in pairs(fm) do
                                        if
                                            type(key) == "string" and not skip_keys[key] and type(val) == "table" and
                                                val.addToMainMenu
                                         then
                                            local open_methods = {}
                                            for mname, mval in pairs(val) do
                                                if
                                                    type(mname) == "string" and type(mval) == "function" and
                                                        (mname:find("^show") or mname:find("^open") or
                                                            mname:find("^launch") or
                                                            mname:find("^on[A-Z]"))
                                                 then
                                                    table.insert(open_methods, mname)
                                                end
                                            end
                                            table.sort(open_methods)
                                            local plugin_name = (val.name and tostring(val.name)) or key
                                            for _, mname in ipairs(open_methods) do
                                                local synthetic_id = "fm:" .. key .. ":" .. mname
                                                if not seen_ids[synthetic_id] then
                                                    seen_ids[synthetic_id] = true
                                                    table.insert(
                                                        action_items,
                                                        {
                                                            id = synthetic_id,
                                                            title = plugin_name .. " → " .. mname,
                                                            source = "fm",
                                                            fm_key = key,
                                                            fm_method = mname
                                                        }
                                                    )
                                                end
                                            end
                                        end
                                    end
                                end

                                table.sort(
                                    action_items,
                                    function(a, b)
                                        return a.title < b.title
                                    end
                                )

                                if #action_items == 0 then
                                    return {
                                        {
                                            text = _("No actions found. Make sure plugins are loaded."),
                                            callback = function()
                                            end
                                        }
                                    }
                                end

                                local result = {}
                                for _, a in ipairs(action_items) do
                                    local a_copy = a
                                    table.insert(
                                        result,
                                        {
                                            text = a_copy.title,
                                            callback = function(touchmenu_instance)
                                                -- Create dialog variables at this scope level
                                                local icon_dialog
                                                local label_dialog

                                                -- Define showLabelDialog
                                                local function showLabelDialog(icon_name, action_data)
                                                    label_dialog =
                                                        InputDialog:new {
                                                        title = _("Tab label"),
                                                        input = action_data.title,
                                                        buttons = {
                                                            {
                                                                {
                                                                    text = _("Cancel"),
                                                                    id = "close",
                                                                    callback = function()
                                                                        UIManager:close(label_dialog)
                                                                    end
                                                                },
                                                                {
                                                                    text = _("Add tab"),
                                                                    is_enter_default = true,
                                                                    callback = function()
                                                                        local tab_label = label_dialog:getInputText()
                                                                        if tab_label == "" then
                                                                            tab_label = action_data.title
                                                                        end
                                                                        UIManager:close(label_dialog)

                                                                        local new_id =
                                                                            "custom_" ..
                                                                            action_data.id:gsub("[^%w]", "_")
                                                                        local new_ct = {
                                                                            id = new_id,
                                                                            label = tab_label,
                                                                            icon = icon_name,
                                                                            source = action_data.source
                                                                        }
                                                                        if action_data.source == "dispatcher" then
                                                                            new_ct.dispatcher_action = action_data.id
                                                                        else
                                                                            new_ct.fm_key = action_data.fm_key
                                                                            new_ct.fm_method = action_data.fm_method
                                                                        end

                                                                        local found = false
                                                                        for i, ct in ipairs(config.custom_tabs) do
                                                                            if ct.id == new_id then
                                                                                config.custom_tabs[i] = new_ct
                                                                                found = true
                                                                                break
                                                                            end
                                                                        end
                                                                        if not found then
                                                                            table.insert(config.custom_tabs, new_ct)
                                                                            config.show_tabs[new_id] = true
                                                                            table.insert(config.tab_order, new_id)
                                                                        end

                                                                        registerCustomTabs()
                                                                        G_reader_settings:saveSetting(
                                                                            "bottom_navbar",
                                                                            config
                                                                        )

                                                                        UIManager:show(
                                                                            InfoMessage:new {
                                                                                text = _("Tab '") ..
                                                                                    tab_label ..
                                                                                        _(
                                                                                            "' added!\nTap 'Refresh navbar' to apply."
                                                                                        ),
                                                                                timeout = 3
                                                                            }
                                                                        )

                                                                        if touchmenu_instance then
                                                                            touchmenu_instance:updateItems()
                                                                        end
                                                                    end
                                                                }
                                                            }
                                                        }
                                                    }
                                                    UIManager:show(label_dialog)
                                                    label_dialog:onShowKeyboard()
                                                end

                                                local function showIconDialog()
                                                    icon_dialog =
                                                        InputDialog:new {
                                                        title = _("Icon filename"),
                                                        hint = _("e.g., appbar.search, tab_books, or custom icon name"),
                                                        input = "appbar.search",
                                                        description = _(
                                                            "Enter the icon filename (without .png/.svg extension)"
                                                        ),
                                                        buttons = {
                                                            {
                                                                {
                                                                    text = _("Cancel"),
                                                                    id = "close",
                                                                    callback = function()
                                                                        UIManager:close(icon_dialog)
                                                                    end
                                                                },
                                                                {
                                                                    text = _("Next"),
                                                                    is_enter_default = true,
                                                                    callback = function()
                                                                        local icon_name = icon_dialog:getInputText()
                                                                        if icon_name == "" then
                                                                            icon_name = "appbar.search"
                                                                        end
                                                                        UIManager:close(icon_dialog)

                                                                        showLabelDialog(icon_name, a_copy)
                                                                    end
                                                                }
                                                            }
                                                        }
                                                    }
                                                    UIManager:show(icon_dialog)
                                                    icon_dialog:onShowKeyboard()
                                                end

                                                -- Start the process
                                                showIconDialog()
                                            end
                                        }
                                    )
                                end
                                return result
                            end
                        }
                    )
                    return items
                end
            },
            -- Advanced options
            {
                text = _("Advanced"),
                sub_item_table = {
                    {
                        text = _("Show navbar in standalone views"),
                        help_text = _(
                            "Show the navbar in History, Favorites, Collections, Rakuyomi, and QuickRSS views."
                        ),
                        checked_func = function()
                            return config.show_in_standalone
                        end,
                        callback = function()
                            config.show_in_standalone = not config.show_in_standalone
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    },
                    {
                        text = _("Show top gap"),
                        help_text = _("Add spacing above the navbar to separate it from the content above."),
                        checked_func = function()
                            return config.show_top_gap
                        end,
                        callback = function()
                            config.show_top_gap = not config.show_top_gap
                            G_reader_settings:saveSetting("bottom_navbar", config)
                        end
                    }
                }
            },
            {
                text = _("Refresh navbar"),
                keep_menu_open = true,
                separator = true,
                callback = function()
                    local fm = FileManager.instance
                    if fm then
                        injectNavbar(fm)
                        UIManager:setDirty(fm, "ui")
                    end
                end
            }
        }
    }

    orig_setUpdateItemTable(self)

    hookQuickRSSInit()
end
