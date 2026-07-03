--Minetest
--Copyright (C) 2013 sapier
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

--------------------------------------------------------------------------------

-- Sviluppatori di Matematica Superpiatta (client + server), in ordine.
local matematica_superpiatta = {
	"Leonardo Guidoni <leonardo.guidoni@stemblocks.it>",
	"Robin Short <robin.short@stemblocks.it>",
	"Giulio Leoni <giulio.stemblocks@gmail.com>",
	"Alessio Cecchin <acecchin@gmail.com>",
	"Avry Titouan",
	"Marine Vincent",
	"Matteo Bouvier",
	"Ilyas Belhadj",
}

local core_developers = {
	"Perttu Ahola (celeron55) <celeron55@gmail.com>",
	"sfan5 <sfan5@live.de>",
	"Nathanaël Courant (Nore/Ekdohibs) <nore@mesecons.net>",
	"Loic Blot (nerzhul/nrz) <loic.blot@unix-experience.fr>",
	"paramat",
	"Andrew Ward (rubenwardy) <rw@rubenwardy.com>",
	"Krock/SmallJoker <mk939@ymail.com>",
	"Lars Hofhansl <larsh@apache.org>",
	"Pierre-Yves Rollo <dev@pyrollo.com>",
	"v-rob <robinsonvincent89@gmail.com>",
	"hecks",
	"Hugues Ross <hugues.ross@gmail.com>",
	"Dmitry Kostenko (x2048) <codeforsmile@gmail.com>",
}

-- For updating active/previous contributors, see the script in ./util/gather_git_credits.py

local active_contributors = {
	"Wuzzy [I18n for builtin, liquid features, fixes]",
	"Zughy [Various features and fixes]",
	"numzero [Graphics and rendering]",
	"Desour [Internal fixes, Clipboard on X11]",
	"Lars Müller [Various internal fixes]",
	"JosiahWI [CMake, cleanups and fixes]",
	"HybridDog [builtin, documentation]",
	"Jude Melton-Houghton [Database implementation]",
	"savilli [Fixes]",
	"Liso [Shadow Mapping]",
	"MoNTE48 [Build fix]",
	"Jean-Patrick Guerrero (kilbith) [Fixes]",
	"ROllerozxa [Code cleanups]",
	"Lejo [bitop library integration]",
	"LoneWolfHT [Build fixes]",
	"NeroBurner [Joystick]",
	"Elias Fleckenstein [Internal fixes]",
	"David CARLIER [Unix & Haiku build fixes]",
	"pecksin [Clickable web links]",
	"srfqi [Android & rendering fixes]",
	"EvidenceB [Formspec]",
}

local previous_core_developers = {
	"BlockMen",
	"Maciej Kasatkin (RealBadAngel) [RIP]",
	"Lisa Milne (darkrose) <lisa@ltmnet.com>",
	"proller",
	"Ilya Zhuravlev (xyz) <xyz@minetest.net>",
	"PilzAdam <pilzadam@minetest.net>",
	"est31 <MTest31@outlook.com>",
	"kahrl <kahrl@gmx.net>",
	"Ryan Kwolek (kwolekr) <kwolekr@minetest.net>",
	"sapier",
	"Zeno",
	"ShadowNinja <shadowninja@minetest.net>",
	"Auke Kok (sofar) <sofar@foo-projects.org>",
	"Aaron Suen <warr1024@gmail.com>",
}

local previous_contributors = {
	"Nils Dagsson Moskopp (erlehmann) <nils@dieweltistgarnichtso.net> [Minetest Logo]",
	"red-001 <red-001@outlook.ie>",
	"Giuseppe Bilotta",
	"Dániel Juhász (juhdanad) <juhdanad@gmail.com>",
	"MirceaKitsune <mirceakitsune@gmail.com>",
	"Constantin Wenger (SpeedProg)",
	"Ciaran Gultnieks (CiaranG)",
	"Paul Ouellette (pauloue)",
	"stujones11",
	"Rogier <rogier777@gmail.com>",
	"Gregory Currie (gregorycu)",
	"JacobF",
	"Jeija <jeija@mesecons.net> [HTTP, particles]",
}

local function buildCreditList(source)
	local ret = {}
	for i = 1, #source do
		ret[i] = core.formspec_escape(source[i])
	end
	return table.concat(ret, ",,")
end

return {
	name = "about",
	caption = fgettext("About"),
	cbf_formspec = function(tabview, name, tabdata)
		local logofile = defaulttexturedir .. "logo.png"
		local fs = "formspec_version[6]" ..
			-- Smaller fonts so captions and the long credits lines fit this panel
			"style_type[button;font_size=*0.85]" ..
			"style_type[label;font_size=*0.9]" ..
			"style_type[table;font_size=*0.8]" ..

			-- Left column: MS cube icon + Luanti logo side by side, title, links
			"image[0.5,0.55;2.0,2.0;" .. core.formspec_escape(defaulttexturedir .. "ms_cube_icon.png") .. "]" ..
			"image[2.6,0.55;2.0,2.0;" .. core.formspec_escape(logofile) .. "]" ..
			"style[label_button;border=false]" ..
			"button[0.2,2.85;5.3,0.7;label_button;" .. core.formspec_escape("Matematica Superpiatta") .. "]" ..
			"button[0.4,3.75;4.8,0.8;ms_site;" .. core.formspec_escape("matematicasuperpiatta.it") .. "]" ..
			"button[0.4,4.8;4.8,0.8;homepage;luanti.org]" ..

			-- Right column: scrolling credits table (starts below the tab header)
			"tablecolumns[color;text]" ..
			"tableoptions[background=#00000000;highlight=#00000000;border=false]" ..
			"table[6.0,0.15;12.7,6.2;list_credits;" ..
			"," .. ms_S("Matematica Superpiatta is an open-source fork of Luanti.") .. ",," ..
			ms_S("Source code:") .. " github.com/matematicasuperpiattaios/luanti" .. ",,," ..
			"#FFFF00," .. ms_S("Matematica Superpiatta developers (client and server)") .. ",," ..
			buildCreditList(matematica_superpiatta) .. ",,," ..
			"#FFFF00,Luanti — " .. ms_S("Core Developers") .. ",," ..
			buildCreditList(core_developers) .. ",,," ..
			"#FFFF00,Luanti — " .. ms_S("Active Contributors") .. ",," ..
			buildCreditList(active_contributors) .. ",,," ..
			"#FFFF00,Luanti — " .. ms_S("Previous Core Developers") .. ",," ..
			buildCreditList(previous_core_developers) .. ",,," ..
			"#FFFF00,Luanti — " .. ms_S("Previous Contributors") .. ",," ..
			buildCreditList(previous_contributors) .. "," ..
			";1]" ..

			-- Renderer info along the bottom, below the table
			"label[0.3,6.6;" .. ms_S("Active renderer:") .. " " ..
				core.formspec_escape(core.get_active_renderer()) .. "]"

		return fs
	end,
	cbf_button_handler = function(this, fields, name, tabdata)
		if fields.homepage then
			core.open_url("https://www.luanti.org")
		end

		if fields.ms_site then
			core.open_url("https://www.matematicasuperpiatta.it")
		end
	end,
}
