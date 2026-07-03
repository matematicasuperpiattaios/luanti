-- Matematica Superpiatta menu localization (IT / EN / FR / ES).
--
-- MS-custom strings are not in the engine's gettext catalogs, so fgettext
-- leaves them untranslated. This tiny table fills that gap. It is keyed on the
-- language gettext ALREADY resolved (the LANG_CODE returned by
-- core.get_language()), so ms_S() stays consistent with fgettext for the
-- standard strings on the same screen. English is the source: the key itself.

local strings = {
	["based on"] = {
		it = "basato su",
		fr = "basé sur",
		es = "basado en",
	},
	["University of L'Aquila"] = {
		it = "Università degli Studi dell'Aquila",
		fr = "Université de L'Aquila",
		es = "Universidad de L'Aquila",
	},
	["spin-off"] = {
		it = "spin-off",
		fr = "spin-off",
		es = "spin-off",
	},
	["Start"] = {
		it = "Avvia",
		fr = "Démarrer",
		es = "Iniciar",
	},

	-- About tab
	["Matematica Superpiatta is an open-source fork of Luanti."] = {
		it = "Matematica Superpiatta è un fork open source di Luanti.",
		fr = "Matematica Superpiatta est un fork open source de Luanti.",
		es = "Matematica Superpiatta es un fork de código abierto de Luanti.",
	},
	["Source code:"] = {
		it = "Codice sorgente:",
		fr = "Code source :",
		es = "Código fuente:",
	},
	["Matematica Superpiatta developers (client and server)"] = {
		it = "Sviluppatori Matematica Superpiatta (client e server)",
		fr = "Développeurs de Matematica Superpiatta (client et serveur)",
		es = "Desarrolladores de Matematica Superpiatta (cliente y servidor)",
	},
	["Core Developers"] = {
		it = "Sviluppatori principali",
		fr = "Développeurs principaux",
		es = "Desarrolladores principales",
	},
	["Active Contributors"] = {
		it = "Collaboratori attivi",
		fr = "Contributeurs actifs",
		es = "Colaboradores activos",
	},
	["Previous Core Developers"] = {
		it = "Ex sviluppatori principali",
		fr = "Anciens développeurs principaux",
		es = "Antiguos desarrolladores principales",
	},
	["Previous Contributors"] = {
		it = "Collaboratori precedenti",
		fr = "Anciens contributeurs",
		es = "Colaboradores anteriores",
	},
	["Visit the website"] = {
		it = "Visita il sito",
		fr = "Visiter le site",
		es = "Visitar el sitio",
	},
	["Active renderer:"] = {
		it = "Renderer attivo:",
		fr = "Moteur de rendu actif :",
		es = "Renderizador activo:",
	},

	-- Login flow (dlg_whoareu)
	["Username:"] = {
		it = "Nome utente:",
		fr = "Nom d'utilisateur :",
		es = "Nombre de usuario:",
	},
	["Next"] = {
		it = "Avanti",
		fr = "Suivant",
		es = "Siguiente",
	},
	["You need a provided account"] = {
		it = "Serve un account fornito",
		fr = "Un compte fourni est requis",
		es = "Se requiere una cuenta proporcionada",
	},
	["Login failed, try again"] = {
		it = "Accesso fallito, riprova",
		fr = "Échec de la connexion, réessayez",
		es = "Error de acceso, inténtalo de nuevo",
	},
	["Welcome"] = {
		it = "Benvenuto",
		fr = "Bienvenue",
		es = "Bienvenido",
	},
	["Password:"] = {
		it = "Password:",
		fr = "Mot de passe :",
		es = "Contraseña:",
	},
	["Play!"] = {
		it = "Gioca!",
		fr = "Jouer !",
		es = "¡Jugar!",
	},
	["Loading in... "] = {
		it = "Caricamento tra... ",
		fr = "Chargement dans... ",
		es = "Cargando en... ",
	},
	["seconds"] = {
		it = "secondi",
		fr = "secondes",
		es = "segundos",
	},
}

-- Language gettext resolved for this session (e.g. "it"); "" -> English.
function ms_current_lang()
	local _, code = core.get_language()
	if not code or code == "" then
		return "en"
	end
	return code:sub(1, 2):lower()
end

-- Translate an MS-custom string; falls back to the English source (the key).
function ms_S(key)
	local entry = strings[key]
	if entry then
		local t = entry[ms_current_lang()]
		if t then
			return t
		end
	end
	return key
end
