--Matematica Superpiatta
--Copyright (C) 2022 Matematica Superpiatta
--
--MINETEST
--Copyright (C) 2014 sapier
--
--This program is free software; you can redistribute it and/or modify
--it under the terms of the GNU Lesser General Public License as published by
--the Free Software Foundation; either version 2.1 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Lesser General Public License for more details.
--
--You should have received a copy of the GNU Lesser General Public License along
--with this program; if not, write to the Free Software Foundation, Inc.,
--51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

local is_windows = (nil ~= string.find(defaulttexturedir, "\\"))
local texturedir = defaulttexturedir
if is_windows then
	core.log("info", "Windows release")
    texturedir = string.gsub(defaulttexturedir, "\\", "\\\\")
end

local function get_formspec(tabview, name, tabdata)
	-- Update the cached supported proto info,
	-- it may have changed after a change by the settings menu.
	common_update_cached_supp_proto()

	if not tabdata.search_for then
		tabdata.search_for = ""
	end

	-- Localized MS logo. Fixed height; width follows each artwork's aspect
	-- ratio so it isn't distorted, then centred horizontally in the 19-wide tab.
	local logos = {
		it = {file = "logo_320x132.png", w = 7.68},
		en = {file = "logo_en.png",      w = 7.45},
		fr = {file = "logo_fr.png",      w = 9.17},
		es = {file = "logo_es.png",      w = 8.92},
	}
	local logo = logos[ms_current_lang()] or logos.en

	local fs = FormspecVersion:new{version=6}:render() ..
	    -- Title logo (localized), centred horizontally in the 19-wide tab
		Image:new{
			x=(19 - logo.w) / 2, y=0.15, w=logo.w, h=3.17,
			path = texturedir .. logo.file}:render() ..

		-- Attribution: "based on" (localized) + Luanti wordmark image,
		-- tucked right under the MS logo (grouped with it, not the caption below)
		Label:new{x=7.0, y=3.4, label = ms_S("based on")}:render() ..
		Image:new{
			x=9.7, y=3.16, w=2.5, h=0.48,
			path = texturedir .. "luanti_wordmark.png"}:render() ..

		-- UnivAQ block + institutional caption, bottom-left
		Image:new{
			x=0.4, y=4.0, w=2.4, h=2.4,
			path = texturedir .."univaq_block_image_small.png"}:render() ..

		Label:new{x=3.0, y=4.3, label = ms_S("University of L'Aquila")}:render() ..
		Label:new{x=3.0, y=4.8, label = ms_S("spin-off")}:render() ..

		-- Start button, bottom-right (previously empty area, clear of the caption)
		Style:new{
			selectors = {"btn_mp_connect"},
			props = {"bgcolor=#00dc28", "font=bold", "alpha=false"} --orig: #00993b
		}:render() ..
		Button:new{x=14.6, y=4.3, w=3.8, h=2.0, name = "btn_mp_connect", label = ms_S("Start")}:render()
	return fs .. StyleType:new{selectors = {"label"}, props = {"font=italic"}}:render() ..
	Label:new{x=3.0, y=5.3, label = fgettext("www.matematicasuperpiatta.it")}:render()
end

--------------------------------------------------------------------------------

local function main_button_handler(tabview, fields, name, tabdata)
	if fields.key_enter then
		fields.btn_mp_update = handshake.roadmap.client_update.required
		fields.btn_mp_connect = not fields.btn_mp_update
	end

	if fields.btn_mp_debug then
		core.log("warning", "Update pending")
		local error_dlg = create_pending_version_dlg()
		ui.cleanup()
		error_dlg:show()
		ui.update()
		return true
	end

	if fields.btn_mp_connect then
		local whoareu_dlg = create_whoareu_dlg()
		--tabview:hide()
		ui.cleanup()
		whoareu_dlg:show()
		ui.update()
		return true
	end

	if fields.btn_mp_update then
		core.open_url(handshake.roadmap.client_update.url)
		return true
	end
	
	return false
end

local function on_change(type, old_tab, new_tab)
	if type == "LEAVE" then return end
	serverlistmgr.sync()
end


return {
	name = "online",
	caption = fgettext("Join Game"),
	cbf_formspec = get_formspec,
	cbf_button_handler = main_button_handler,
	on_change = on_change
}
