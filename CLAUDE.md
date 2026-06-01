# CLAUDE.md — Istruzioni per Claude Code su questo repo

## Cosa stiamo facendo

Questo è il fork **iOS** (`matematicasuperpiattaios/luanti`, basato su **Luanti 5.16.0**, protocollo di rete 51).
L'obiettivo è **portare su iOS le modifiche custom** del nostro fork desktop **ms_mac** (`matematicasuperpiattamac/minetest`, Minetest 1.2.1, protocollo 43), in modo che il client iOS si autentichi e si colleghi ai **server MS** esattamente come fanno le versioni mac/android.

Due documenti di riferimento (già in questo repo, cartella `docs_ms/`):

- **`docs_ms/01_Flusso_Connessione_Server_MS.md`** — specifica precisa del flusso di connessione (WISCOMS auth → Lambda discovery → token nel pacchetto `TOSERVER_INIT` → server di gioco). Leggilo per capire *come deve funzionare*.
- **`docs_ms/02_Pipeline_Modifiche_ms_ios.md`** — la pipeline operativa: 12 step, ognuno autoconsistente e testabile. Leggilo per sapere *cosa fare e in che ordine*. **È la tua to-do list.**

Se non l'hai ancora fatto, **leggi entrambi i documenti prima di scrivere codice.**

## Regole operative (importanti)

1. **Un branch per step.** Parti da un tag `ios-baseline` (STEP 0). Per ogni step crea un branch dedicato (es. `step-03-selectionbox`), lavora lì, e fai merge solo a step verde.
2. **Compila e testa OGNI step prima di passare al successivo.** La pipeline è progettata apposta perché ogni feature sia verificabile singolarmente. Non accumulare più step non testati.
3. **Non marcare uno step come completato se:** la build fallisce, il test della feature non passa, o ci sono errori irrisolti.
4. **Fermati e chiedi** quando uno step diverge in modo non banale da ms_mac (tipico: il refactor touch/UI di Luanti rende alcune modifiche non copiabili 1:1 — vedi STEP 5/6). Meglio chiedere che indovinare.
5. **Commit piccoli e descrittivi**, un commit verde per step.

## ⚠️ Comandi distruttivi da NON eseguire

Dal README: **mai** usare `step=all` o `step=clone` con `where_luanti=$PWD` negli script `tools/ios/ios_build_with_deps_*.sh` — eseguirebbero `rm -fr $PWD` **distruggendo il checkout**. Usare sempre `step=libs_all` per costruire le deps. Non lanciare nessuno script di build delle deps senza averne capito gli argomenti.

## Build & test loop (iOS, richiede macOS + Xcode)

Workflow dal README (dettagli completi lì):

```bash
# deps precompilate già estratte in luanti_ios_deps/ios18.2_deps/{iPhoneOS,iPhoneSimulator}/
./tools/ios/build-ios.sh                      # genera gli xcodeproj
open build-ios-simulator/luanti.xcodeproj     # poi Run da Xcode (simulator)
open build-ios-device/luanti.xcodeproj        # device
```

- La build vera e il Run avvengono in **Xcode** (⌘B / Run). Per le modifiche C++ è lì che vedi gli errori del compilatore: itera su quelli.
- Bundle id attuale: `org.luanti.luanti` (non ancora rebrandizzato — vedi note sotto).

## Impostazioni di default iOS

I default del fork stanno in **`misc/ios/minetest.conf`** (NON in un `minetest.conf` di root). Vengono inclusi nel bundle in `path_share/minetest.conf` e copiati in `Documents/minetest.conf` al **primo lancio** (`src/porting.cpp`, `#if TARGET_OS_IPHONE`).

Conseguenza pratica per il testing: dopo aver cambiato `misc/ios/minetest.conf`, per propagare i nuovi default a un'installazione esistente devi **disinstallare e reinstallare** (il copy è gated su `!PathExists(user_conf)`):

```bash
xcrun simctl uninstall booted org.luanti.luanti   # simulator
```

Quindi tutti gli step della pipeline che dicono "aggiungere al conf di bundle" → vanno in `misc/ios/minetest.conf`.

## Punti critici da tenere a mente

- **STEP 8 (token in `TOSERVER_INIT`) è la modifica più rischiosa** ed è *wire-level*. In ms_ios oggi `sendInit(playerName)` non manda il token; va aggiunto il campo `token` lungo tutta la catena (Lua `gamedata.token` → `l_mainmenu.cpp` → `MainMenuData`/`GameStartData` → `Client`/`LocalPlayer`/`m_token` → `sendInit` → pacchetto). Testabile in **regressione** contro un server vanilla (che ignora i byte finali) prima di provarlo sul server MS.
- **Compatibilità protocollo:** client iOS 51 vs server MS ~43. Verifica con chi gestisce il backend che la negoziazione e il formato del token combacino.
- **HTTP/ATS iOS:** tutto il login dipende da `core.get_http_api()` (cURL/HTTPS). Conferma che la build includa cURL+SSL e che le ATS di iOS non blocchino le fetch (attenzione ai fallback `_local` in HTTP in chiaro, usati solo dagli account demo).
- **`main_menu_script`:** il meccanismo esiste già in Luanti, ma il path viene aperto "as-is". Allinea come valorizzarlo (path nel bundle) con quanto fa `builtin/ms-mainmenu/init.lua` (STEP 9).
- **`l_get_language` su iOS:** `setlocale(LC_MESSAGES, NULL)` potrebbe tornare `"C"`; in tal caso ricava la lingua da `NSLocale`/impostazioni Luanti (STEP 7).
- **Rebrand bundle id** (`org.luanti.luanti` → `it.matematicasuperpiatta...`): su mac/android è stato fatto; valuta se/quando farlo su iOS (impatta provisioning, container path, comandi `simctl`).

## Riferimenti incrociati al fork desktop

Quando uno step dice "come in ms_mac", la fonte è il repo `matematicasuperpiattamac/minetest`. I file chiave citati nei documenti: `builtin/ms-mainmenu/*`, `src/script/lua_api/l_mainmenu.cpp`, `src/script/lua_api/l_util.cpp`, `src/client/client.cpp`, `src/client/clientlauncher.cpp`, `src/client/hud.cpp`, `src/network/networkprotocol.h`, `configure_ms_release.py`.

## Come iniziare

1. Leggi `docs_ms/01_...` e `docs_ms/02_...`.
2. Esegui **STEP 0** (baseline build + tag) e conferma che parte e si connette a un server di prova.
3. Procedi step per step secondo la checklist del Documento 2, rispettando le regole operative qui sopra.
