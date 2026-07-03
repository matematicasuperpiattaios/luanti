-- Matematica Superpiatta main menu
-- Copyright (C) 2023 Matematica Superpiatta
-- Copyright (C) 2014 sapier
-- SPDX-License-Identifier: LGPL-2.1-or-later
--
-- Adapted to Luanti 5.16: based on builtin/mainmenu/init.lua (vanilla 5.16
-- framework + file layout) with the MS login/handshake flow grafted in.
-- The MS-specific leaf files (tab_ms, tab_about, dlg_whoareu, dlg_errors,
-- dlg_version_info, oop/handshake, oop/oo_formspec, lib/delay) are ported
-- from ms_mac.

MAIN_TAB_W = 19
MAIN_TAB_H = 7.1
TABHEADER_H = 0.85
GAMEBAR_H = 1.25
GAMEBAR_OFFSET_DESKTOP = 0.375
GAMEBAR_OFFSET_TOUCH = 0.15

-- Matematica Superpiatta environment (backend URLs from settings)
SERVER_ADDRESS = core.settings:get("ms_address") or "mt.matematicasuperpiatta.it"
SERVER_PORT = core.settings:get("ms_port") or 29999
URL_GET = "http://" .. SERVER_ADDRESS .. ":" .. SERVER_PORT

SERVICE_DISCOVERY = core.settings:get("ms_discovery") or "fvqyugucy1.execute-api.eu-south-1.amazonaws.com/release"
SERVICE_DISCOVERY_LOCAL = core.settings:get("ms_discovery_local") or "192.168.0.4"
WISCOMS_URL = core.settings:get("wiscoms_url") or "https://wiscoms.matematicasuperpiatta.it/wiscom"
WISCOMS_URL_LOCAL = core.settings:get("wiscoms_url_local") or "http://" .. SERVICE_DISCOVERY_LOCAL .. ":8000/wiscom"
PANEL_DATA = core.settings:get("panel_data") or ""
CMD_USR = core.settings:get("cmd_usr") or ""
CMD_PWD = core.settings:get("cmd_pwd") or ""

mt_color_grey       = "#AAAAAA"
mt_color_blue       = "#6389FF"
mt_color_green      = "#72FF63"
mt_color_dark_green = "#25C191"
mt_color_orange     = "#FF8800"

local menupath = core.get_mainmenu_path()
local basepath = core.get_builtin_path()
local mspath = basepath .. "ms-mainmenu" .. DIR_DELIM
defaulttexturedir = core.get_texturepath_share() .. DIR_DELIM .. "base" ..
					DIR_DELIM .. "pack" .. DIR_DELIM

ms_mainmenu = {}

-- Vanilla 5.16 framework + shared dialogs
dofile(basepath .. "common" .. DIR_DELIM .. "menu.lua")
dofile(basepath .. "common" .. DIR_DELIM .. "filterlist.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "buttonbar.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "dialog.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "tabview.lua")
dofile(basepath .. "fstk" .. DIR_DELIM .. "ui.lua")
dofile(menupath .. DIR_DELIM .. "async_event.lua")
dofile(menupath .. DIR_DELIM .. "common.lua")
dofile(menupath .. DIR_DELIM .. "serverlistmgr.lua")
dofile(menupath .. DIR_DELIM .. "game_theme.lua")
dofile(menupath .. DIR_DELIM .. "content" .. DIR_DELIM .. "init.lua")
dofile(menupath .. DIR_DELIM .. "dlg_config_world.lua")
dofile(basepath .. "common" .. DIR_DELIM .. "settings" .. DIR_DELIM .. "init.lua")
dofile(menupath .. DIR_DELIM .. "dlg_confirm_exit.lua")
dofile(menupath .. DIR_DELIM .. "dlg_create_world.lua")
dofile(menupath .. DIR_DELIM .. "dlg_delete_content.lua")
dofile(menupath .. DIR_DELIM .. "dlg_delete_world.lua")
dofile(menupath .. DIR_DELIM .. "dlg_register.lua")
dofile(menupath .. DIR_DELIM .. "dlg_rename_modpack.lua")

-- Compatibility shim: ms_mac's fstk provided ui.cleanup() (hide every child so
-- the next dialog shown becomes the only visible toplevel). Luanti 5.16 removed
-- it in favour of dlg:set_parent()/parent:hide(); the ported MS dialogs still
-- call ui.cleanup(), so reinstate it with the original semantics.
function ui.cleanup()
	for _, value in pairs(ui.childlist) do
		if value.hide then
			value:hide()
		end
	end
end

-- Matematica Superpiatta-specific pieces (MS dlg_version_info overrides the
-- vanilla one: it drives the launchpad/handshake update check).
dofile(mspath .. "lib" .. DIR_DELIM .. "i18n.lua")
dofile(mspath .. "lib" .. DIR_DELIM .. "delay.lua")
dofile(mspath .. "oop" .. DIR_DELIM .. "handshake.lua")
dofile(mspath .. "oop" .. DIR_DELIM .. "oo_formspec.lua")
dofile(mspath .. "dlg_whoareu.lua")
dofile(mspath .. "dlg_errors.lua")
dofile(mspath .. "dlg_version_info.lua")

handshake = Handshake:new()
global_data = {
	message_type = "default",
	message_text = fgettext("Unable to connect to the server!\n\n" ..
		"Check your internet connection and restart Matematica Superpiatta.\n" ..
		"If the problem persists contact us at:\nassistenza@matematicasuperpiatta.it")
}
global_version_checked = false
global_os = "ios"
global_ms_type = "full"
global_language = "en"
lambda_waiting = false
lambda_read = true
lambda_error = false

local tabs = {
	ms    = dofile(mspath .. "tab_ms.lua"),
	about = dofile(mspath .. "tab_about.lua"),
}

local function main_event_handler(tabview, event)
	if event == "MenuQuit" then
		core.close()
	end
	return true
end

local function init_globals()
	-- Permanent warning if on an unoptimized debug build
	if core.is_debug_build() then
		local set_topleft_text = core.set_topleft_text
		core.set_topleft_text = function(s)
			s = (s or "") .. "\n"
			s = s .. core.colorize("#f22", core.gettext("Debug build, expect worse performance"))
			set_topleft_text(s)
		end
	end

	-- Init gamedata
	gamedata.worldindex = 0

	menudata.worldlist = filterlist.create(
		core.get_worlds,
		compare_worlds,
		-- Unique id comparison function
		function(element, uid)
			return element.name == uid
		end,
		-- Filter function
		function(element, gameid)
			-- Keep in sync with the logic in pkgmgr.find_by_gameid
			local el_gameid = pkgmgr.normalize_game_id(element.gameid)
			if el_gameid == gameid then
				return true
			end
			local game = pkgmgr.find_by_gameid(el_gameid)
			if (not game or game.id ~= el_gameid)
					and pkgmgr.find_by_gameid(gameid).aliases[el_gameid] then
				return true
			end
			return false
		end
	)

	menudata.worldlist:add_sort_mechanism("alphabetic", sort_worlds_alphabetic)
	menudata.worldlist:set_sortmode("alphabetic")

	mm_game_theme.init()
	-- hide_decorations=true: drop the engine's stale "MINETEST" header/footer
	-- wordmark (we show our own MS logo inside the tab).
	mm_game_theme.set_engine(true)

	-- Dynamic scaling: render the fixed MAIN_TAB_W-wide design at ~90% of the
	-- screen width on ANY device. A fixed formspec size otherwise ends up a
	-- different physical fraction on each device (its density is auto-detected),
	-- which is why the menu looked smaller on some phones than in the simulator.
	-- max_formspec_size scales as 1/gui_scaling, so we solve for the gui_scaling
	-- that fills 90% width, capped so the whole menu still fits the height. This
	-- is a fixed point: once it fills 90%, re-running yields the same value.
	do
		local wi = core.get_window_info()
		local cur_gs = tonumber(core.settings:get("gui_scaling")) or 1.0
		local touch = core.settings:get_bool("touch_gui")
		local total_h = MAIN_TAB_H + TABHEADER_H +
			(touch and GAMEBAR_OFFSET_TOUCH or GAMEBAR_OFFSET_DESKTOP) + GAMEBAR_H
		local gs_w = cur_gs * wi.max_formspec_size.x * 0.90 / MAIN_TAB_W
		local gs_h = cur_gs * wi.max_formspec_size.y * 0.98 / total_h
		-- Higher gui_scaling => smaller menu; take whichever constraint binds.
		core.settings:set("gui_scaling", string.format("%.4f", math.max(gs_w, gs_h)))
	end

	-- Create main tabview: MS login tab + About (Settings is an end button)
	local tv_main = tabview_create("maintab", {x = MAIN_TAB_W, y = MAIN_TAB_H}, {x = 0, y = 0})

	tv_main:set_autosave_tab(true)
	tv_main:add(tabs.ms)
	tv_main:add(tabs.about)

	tv_main:set_global_event_handler(main_event_handler)
	tv_main:set_fixed_size(false)

	-- Settings dialog (5.16 refactor: an end button, not a tab_settings.lua)
	tv_main:set_end_button({
		icon = defaulttexturedir .. "settings_btn.png",
		label = fgettext("Settings"),
		name = "open_settings",
		on_click = function(tabview)
			local dlg = create_settings_dlg()
			dlg:set_parent(tabview)
			tabview:hide()
			dlg:show()
			return true
		end,
	})

	ui.set_default("maintab")
	tv_main:set_tab("online")
	tv_main:show()
	ui.update()

	-- MS version/update check (asynchronous via the handshake/launchpad)
	check_new_version(handshake)
end

assert(os.execute == nil)
init_globals()
