# Matematica Superpiatta — iOS (versione 1.3)

Client **iOS** di *Matematica Superpiatta*: un gioco educativo di matematica
costruito su [Luanti](https://github.com/luanti-org/luanti) **5.16** (protocollo
di rete 51). È il porting su iOS delle modifiche custom del fork desktop **ms_mac**
(basato su Minetest 1.2.1): l'app si autentica e si collega ai **server MS**
esattamente come fanno le versioni mac/Android.

- App: **Matematica Superpiatta** — bundle id `com.stemblocks.matematicasuperpiatta`
- Versione app: **1.3** (`version` inviata al backend: `1.3.0`); motore Luanti: 5.16.0
- Base: fork di [sfence/luanti](https://github.com/sfence/luanti), branch `sfence_ios`

## Cos'è / come funziona

A differenza di Luanti "vanilla" (scegli un server da una lista e ti autentichi
con SRP), il client MS ha un **menu principale custom** (`builtin/ms-mainmenu/`)
che pilota un flusso di connessione automatico:

1. **Login** — il menu MS chiede username/password e li manda a **WISCOMS**
   (`/api/token/`), ottenendo un token di `access` + `refresh`.
2. **Service discovery** — interroga una **AWS Lambda** che assegna IP/porta di
   un server di gioco, fa il controllo versione e restituisce messaggi/news.
3. **Connessione** — `core.start()` collega il client al server assegnato,
   inviando il **token** nel pacchetto di rete `TOSERVER_INIT` (campo custom),
   con cui il server MS autorizza l'accesso.

Specifiche complete in `docs_ms/01_Flusso_Connessione_Server_MS.md` e
`docs_ms/02_Pipeline_Modifiche_ms_ios.md`.

## Stato del port

Portato e funzionante end-to-end (login → discovery → mondo su server MS reale):

- Branding iOS: nome, **icona** (`misc/ios/Assets.xcassets`), bundle id, lock
  **landscape** + ATS (`misc/ios/Info.plist.in`).
- Default grafici/touch nel conf di bundle (vedi sotto): nebbia, `viewing_range`,
  `translucent_liquids`, `node_highlighting=halo`, `selectionbox_width=16`
  (cap alzato a 20 in `hud.cpp`), scala GUI/HUD, `font_size`, `touch_gui`,
  `touch_layout`, `touch_long_tap_delay=200`, `show_debug=false`.
- `core.get_language()` Lua API (`src/script/lua_api/l_util.cpp`).
- **Token in `TOSERVER_INIT`** (`src/client/client.*`, `networkprotocol.h`,
  `l_mainmenu.cpp`, `clientlauncher.cpp`, `gameparams.h`).
- Menu MS `builtin/ms-mainmenu/` adattato a Luanti 5.16 (HTTP async, ecc.).
- Indirizzo del server remoto mostrato nel pause menu.
- `configure_ms_release.py` per la config di release iOS (vedi sotto).

Aperto/da rifinire: modalità di avvio PANEL/CMD (deep link), test estesi su
device fisico.

Icona app: `misc/ios/Assets.xcassets/AppIcon.appiconset` usa un singolo
`icon-1024.png` **1024×1024 senza canale alfa** con `idiom: universal` — il
formato consigliato da iOS 14+/Xcode: l'asset catalog genera automaticamente
tutte le taglie in `Assets.car`. (Verificabile con `tools/ios/preflight-appstore.sh`.)
Se il 1024 fosse un upscale da un sorgente più piccolo, sostituirlo con un
render nativo alla stessa risoluzione.

## Branch

- `master` — mirror di `luanti-org/luanti` master via `sfence/master`
- `sfence_ios` — branch di lavoro iOS (parte da `sfence/sfence_ios` + nostri fix)

## Compilazione iOS

**1.** Scarica le deps precompilate (~45 MB): <https://drive.google.com/file/d/1j8HauemtUTDFaqd8OnLUuUjEGvGeiqlH/view?usp=sharing>

**2.** Estraile alla root del repo:

```bash
mkdir -p luanti_ios_deps
tar -xzf ~/Downloads/ios18.2_deps.tar.gz -C luanti_ios_deps
```

Risultato atteso: `luanti_ios_deps/ios18.2_deps/{iPhoneOS,iPhoneSimulator}/{bin,include,lib,share}/`.

**3.** Genera gli xcodeproj:

```bash
./tools/ios/build-ios.sh
```

**4.** Apri in Xcode e Run:

```bash
open build-ios-simulator/luanti.xcodeproj   # simulator
open build-ios-device/luanti.xcodeproj      # device (richiede team di signing)
```

> Il bundle id `com.stemblocks.matematicasuperpiatta` richiede un provisioning
> profile per il build su device.

### ⚠️ Due build dir separate — riconfigurarle entrambe

`build-ios-simulator/` e `build-ios-device/` sono **build CMake indipendenti**.

- Modifiche a **Lua / `misc/ios/minetest.conf` / texture / `builtin/`**: entrano
  da sole al prossimo build (le copia il POST_BUILD `install_resources.cmake`).
- Modifiche a **C++ / `CMakeLists.txt` / `src/CMakeLists.txt` / `Info.plist.in`**
  (nome, bundle id, icona, orientamento, versione, ATS): richiedono di
  **riconfigurare CMake su entrambe** le dir, altrimenti una resta indietro
  (sintomo tipico: il device mostra ancora "Luanti" vanilla):

  ```bash
  cmake build-ios-simulator
  cmake build-ios-device
  ```

  poi ricompila in Xcode. (In alternativa rigenera da zero con `build-ios.sh`
  dopo aver rimosso le build dir.)

### Motore Lua: LuaJIT (default) vs Lua 5.1 vanilla (release App Store)

Di default la build linka **LuaJIT** (`libluajit-5.1.a`, interprete più veloce).
Per la **release su App Store** conviene invece linkare il **Lua 5.1 vanilla**
bundled (`lib/lua/`), tramite la variabile d'ambiente `MS_LUA`:

```bash
MS_LUA=vanilla ./tools/ios/build-ios.sh
```

Perché per la release: la linea guida App Store **2.5.2** vieta la generazione
di codice eseguibile a runtime. LuaJIT spedisce il compilatore JIT anche se su
iOS non può girare (nessun entitlement `allow-jit`, cfr. preflight STEP 4):
la macchina di codegen resta linkata e *tenta* `mmap(PROT_EXEC)`. Il Lua vanilla
non ha alcun percorso di codegen → conforme senza ambiguità.

Costo: su un workload rappresentativo (formspec del menu, string/table/math)
LuaJIT-interprete è ~2× più veloce del vanilla, ma il Lua qui è colla (non
l'hot path: rendering/mesh/rete sono in C++), quindi in gioco la differenza è
impercettibile. **Raccomandazione: `MS_LUA=vanilla` per la build di release**,
LuaJIT per lo sviluppo (iterazione più rapida). Il gioco è identico: Luanti
supporta ufficialmente entrambi i motori.

### Fallback: ricompilare le deps da zero

Se il pacchetto non è raggiungibile e hai Homebrew funzionante, prima installa i tool:

```bash
brew install cmake nasm wget m4 autoconf automake libtool
```

Poi popola `luanti_ios_deps/` usando **`step=libs_all`** (mai `all` né `clone`, vedi avviso sotto):

```bash
./tools/ios/ios_build_with_deps_ios26-v2.sh \
    "" "" "$PWD" "$PWD/luanti_ios_deps/ios18.2_deps/iPhoneSimulator" \
    Debug iPhoneSimulator 26 libs_all build-ios-simulator

./tools/ios/ios_build_with_deps_ios26-v2.sh \
    "" "" "$PWD" "$PWD/luanti_ios_deps/ios18.2_deps/iPhoneOS" \
    Debug iPhoneOS 26 libs_all build-ios-device
```

Quando finisce, `./tools/ios/build-ios.sh` per gli xcodeproj.

> ⚠️ **Mai `step=all` o `step=clone` con `where_luanti=$PWD`**: lo script eseguirebbe `rm -fr $PWD` distruggendo il checkout corrente. `libs_all` non tocca `where_luanti`.

## Impostazioni di default

Il file `misc/ios/minetest.conf` contiene le impostazioni di default del fork (grafica, touch UI, accessibilità, menu MS, backend, ecc.). Viene incluso nel bundle iOS in `path_share/minetest.conf`. Al **primo lancio** dell'app, se l'utente non ha ancora un `Documents/minetest.conf`, la logica in `src/porting.cpp` (`#if TARGET_OS_IPHONE`) ce lo copia. Da quel momento in poi le modifiche in-game si scrivono solo in `Documents/`, e il file shipped non viene più toccato.

### Modificare i default

1. Edita `misc/ios/minetest.conf` (aggiungi/cambia le righe `chiave = valore`).
2. Ricompila in Xcode (⌘B). Il POST_BUILD step di `util/xcode/install_resources.cmake` copia il file aggiornato dentro `luanti.app/minetest.conf`.
3. **Per propagare ai simulator/device già installati**: l'app va disinstallata e reinstallata, perché il copy-on-first-launch è gated su `!fs::PathExists(user_conf)`. Su simulator:

   ```bash
   xcrun simctl uninstall booted com.stemblocks.matematicasuperpiatta
   ```

   Su device: long-press → Remove App, poi Run da Xcode.
4. Commit + push.

### Esportare i settings dopo aver giocato

Pratico per catturare configurazioni complesse (touch layout, key bindings, ecc.) testandole sul simulator e poi promuoverle a default:

```bash
# 1) simulator booted, app installata e usata almeno una volta (poi "Exit to OS"
#    per fare il flush dei settings su disco: su iOS il salvataggio avviene
#    solo alla chiusura pulita, non con simctl terminate)
APP_DATA="$(xcrun simctl get_app_container booted com.stemblocks.matematicasuperpiatta data)"
cat "$APP_DATA/Documents/minetest.conf"

# 2) confronta col bundle e promuovi le righe che vuoi a default
#    (escludi screen_w/screen_h = dimensione finestra, e name = account)
```

Su device fisico: Xcode → Window → Devices and Simulators → seleziona il device → Matematica Superpiatta nella lista → ingranaggio → Download Container → estrai `AppData/Documents/minetest.conf`.

## Config di release (`configure_ms_release.py`)

Imposta in un colpo i parametri di release iniettandoli in `builtin/ms-mainmenu/*`
e `misc/ios/minetest.conf` (solo sostituzione di testo; **non** builda nulla):

```bash
python3 configure_ms_release.py
```

Valori in cima al file (`class Configuration`): `version` (versione app inviata al
backend), `api` (release/dev), `os` (`ios`), `dev_phase` (release/beta),
`server_type` (ecs/multi/local), `debug`. La versione del **motore** (CMake
`VERSION_*`, 5.16.0) **non** viene toccata: è indipendente dalla versione app MS.

## Personalizzazioni UI touch (e come ripristinarle)

Per l'uso in classe l'interfaccia touch è stata semplificata. Per riabilitare le
voci rimosse:

- **Menu overflow (⊞): solo "Cambia vista" e "Uscita".** Gli altri pulsanti
  (chat, inventario, drop, vola, veloce, noclip, debug, minimappa, ecc.) sono
  nascosti dal menu overflow in `src/gui/touchcontrols.cpp` (nel filtro
  `overflow_buttons.erase(...)`, il check `id != camera_id && id != exit_id`).
  Rimuovere quel check ripristina il menu completo.
- **Menu di pausa: niente pulsante "Settings".** Rimosso in
  `src/client/game_formspec.cpp` (blocco `btn_settings`, commentato con `MS:`).
  Reinserirlo per riavere l'accesso alle impostazioni in gioco.
- **Joystick** (posizione/dimensione) e **layout dei pulsanti**: rispettivamente
  in `src/gui/touchcontrols.cpp` (rect del `joystick_off_id`) e nel
  `touch_layout` di `misc/ios/minetest.conf`.

## Sincronizzare il fork con sfence/luanti

GitHub considera il fork "sincronizzato" guardando solo `master`. `sfence_ios` viene invece riscritto regolarmente da sfence (rebase/force-push), quindi serve un sync esplicito:

```bash
git remote add upstream https://github.com/sfence/luanti.git   # one-time
git fetch upstream
git push origin upstream/sfence_ios:sfence_ios --force-with-lease
```
