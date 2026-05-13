# Luanti — fork Matematica Superpiatta (iOS)

Fork di [sfence/luanti](https://github.com/sfence/luanti) sul branch `sfence_ios`, con i fix per la nostra pipeline di build iOS. Per la documentazione generale di Luanti vedi il [README upstream](https://github.com/luanti-org/luanti/blob/master/README.md).

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
open build-ios-device/luanti.xcodeproj      # device
```

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

## Sincronizzare il fork con sfence/luanti

GitHub considera il fork "sincronizzato" guardando solo `master`. `sfence_ios` viene invece riscritto regolarmente da sfence (rebase/force-push), quindi serve un sync esplicito:

```bash
git remote add upstream https://github.com/sfence/luanti.git   # one-time
git fetch upstream
git push origin upstream/sfence_ios:sfence_ios --force-with-lease
```

Per il push serve un PAT con scope **`workflow`** (i branch contengono `.github/workflows/ios.yml`). Se hai commit locali sopra, prima rebasa: `git rebase upstream/sfence_ios`.
