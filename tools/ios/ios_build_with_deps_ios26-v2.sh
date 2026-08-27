#!/bin/bash

echo "This is script automate Luanti build process for iOS."

if [[ $# -lt 8 || $# -gt 9 ]] ; then
	echo "Usage: ios_build_with_deps_ios26.sh https_repo branch where_luanti where_deps build_type arch osver step [build_dir]"
	echo "  arch - iPhoneOS, iPhoneSimulator"
	echo "  osver  - 10.15, 11, 15, 26 etc."
	echo "  step - all"
	echo "         clone|libs_get|libs_untar|libs_build|build"
	echo "         luanti_all|libs_all"
	echo "  build_dir - optional build directory name (default: build)"
	exit 1
fi

RUN_DIR=$(pwd)
SCRIPT_DIR=$(dirname "$0")

repo=$1
branch=$2
where_luanti=$3
where_deps=$4
build_type=$5
arch=$6
osver=$7
step=$8
build_dir=${9:-build}

if [[ "$arch" != "iPhoneOS" ]] && [[ "$arch" != "iPhoneSimulator" ]]; then
	echo "Unsuported value of arch argument: $arch"
	exit 1
fi

source $SCRIPT_DIR/ios_build_deps_ios26.sh

if [[ "$step" == *"all"* ]] || [[ "$step" == *"clone"* ]] || [[ "$step" == *"luanti_all"* ]]; then
	echo "CLONING LUANTI"

	rm -fr $where_luanti
	mkdir -p $where_luanti

	git clone --depth=1 -b $branch $repo $where_luanti
fi

DEPS_PRECOMPILED=NO

if [ -d "$where_deps/bin" ] && [ -d "$where_deps/include" ] && [ -d "$where_deps/lib" ] && [ -d "$where_deps/share" ]; then
	echo "Deps directory $where_deps with precompiled deps."
	DEPS_PRECOMPILED=YES
	cd $where_deps
	DEPS_INSTALL_DIR=$(pwd)
	cd $RUN_DIR
elif [ -d "$where_deps/bin" ] || [ -d "$where_deps/include" ] || [ -d "$where_deps/lib" ] || [ -d "$where_deps/share" ]; then
	echo "Deps directory $where_deps contains unexpected folders. It cannot be decided if it is precompiled or not precompiled deps dir."
	exit 1
else
	echo "Deps directory $where_deps for compile deps from sources."
fi

if [[ "$DEPS_PRECOMPILED" == "NO" ]]; then
	if [[ "$step" == *"all"* ]] || [[ "$step" == *"libs_get"* ]] || [[ "$step" == *"libs_all"* ]]; then
		rm -fr $where_deps
	fi

	mkdir -p $where_deps

	cd $where_deps
	if [ $? -ne 0 ]; then
		echo "Bad target directory $where_deps."
		exit 1
	fi

	DEPS_DIR=$(pwd)
	DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}

	if [[ "$step" == *"all"* ]] || [[ "$step" == *"libs_get"* ]] || [[ "$step" == *"libs_all"* ]]; then
		echo "GETTING LIBRARY SOURCES"
		download_ios_deps $arch $osver
	fi

	if [[ "$step" == *"all"* ]] || [[ "$step" == *"libs_untar"* ]] || [[ "$step" == *"libs_all"* ]]; then
		echo "UNARCHIVING LIBRARY SOURCES"
		untar_ios_deps $arch $osver
	fi

	if [[ "$step" == *"all"* ]] || [[ "$step" == *"libs_build"* ]] || [[ "$step" == *"libs_all"* ]]; then
		echo "COMPILING LIBRARIES"

		compile_ios_deps $arch $osver $step
	fi
fi

cd $RUN_DIR

cd $where_luanti
if [ $? -ne 0 ]; then
	echo "Bad target directory $where_luanti."
	exit 1
fi
LUANTI_DIR=$(pwd)

if [[ "$step" == *"all"* ]] || [[ "$step" == *"build"* ]] || [[ "$step" == *"luanti_all"* ]]; then
	echo "COMPILING LUANTI"

	rm -fr "$build_dir"
	mkdir -p "$build_dir"
	cd "$build_dir"

	unset IPHONEOS_DEPLOYMENT_TARGET
	unset CMAKE_PREFIX_PATH
	unset CPPFLAGS
	unset CC
	unset CFLAGS
	unset CXX
	unset CXXFLAGS
	unset LDFLAGS

	sdk=$(echo "$arch" | tr '[:upper:]' '[:lower:]')
	sdk_path="$(xcrun --sdk ${sdk} --show-sdk-path)"
	sdk_ver="$(xcrun --sdk ${sdk} --show-sdk-version 2>/dev/null || true)"
	if [[ -n "$sdk_ver" && "$sdk_ver" != "$osver" ]]; then
		echo "Warning: requested SDK version $osver, but Xcode provides $sdk_ver for ${arch}. Using $sdk_ver SDK path."
	fi
	sdkroot="$(realpath "$sdk_path")"
	export CMAKE_PREFIX_PATH=$DEPS_DIR/install
	export SDKROOT="$sdkroot"

	# Lua engine selection. Default: LuaJIT (fastest interpreter). For an
	# App Store RELEASE build set MS_LUA=vanilla to link the bundled Lua 5.1
	# (lib/lua) instead: it contains no runtime code-generation path at all,
	# which is the unambiguously safe choice for App Store guideline 2.5.2
	# (LuaJIT ships the JIT compiler even though iOS can't run it).
	#   MS_LUA=vanilla ./tools/ios/build-ios.sh
	if [ "${MS_LUA:-luajit}" = "vanilla" ]; then
		echo "  Lua engine: bundled Lua 5.1 (ENABLE_LUAJIT=0)"
		LUA_CMAKE_FLAGS="-DENABLE_LUAJIT=0"
	else
		echo "  Lua engine: LuaJIT"
		LUA_CMAKE_FLAGS="-DLUA_LIBRARY=${DEPS_INSTALL_DIR}/lib/libluajit-5.1.a -DLUA_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include/luajit-2.1"
	fi

	echo "GENERATION XCODE PROJECT..."
					#-DSDL2_LIBRARIES="${DEPS_INSTALL_DIR}/lib/libSDL2.a;${DEPS_INSTALL_DIR}/lib/libSDL2main.a" \
	cmake .. -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=$osver -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_OSX_ARCHITECTURES=arm64 \
					-DCMAKE_INSTALL_PREFIX=../build/ios/ -DRUN_IN_PLACE=FALSE -DENABLE_GETTEXT=TRUE -DCMAKE_BUILD_TYPE=$build_type \
					-DENABLE_OPENGL=OFF \
					-DENABLE_OPENGL3=OFF \
					-DENABLE_GLES2=ON -DUSE_ANGLE=ON \
					-DUSE_SDL2_STATIC=TRUE \
					-DSDL2_DIR=${DEPS_INSTALL_DIR}/lib/cmake/SDL2 \
					-DSDL2_INCLUDE_DIRS=${DEPS_INSTALL_DIR}/include/SDL2 \
					-DOPENGLES2_LIBRARY=${DEPS_INSTALL_DIR}/lib/libGLESv2_static.a \
					-DOPENGLES2_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include/ANGLE \
					-DCURL_LIBRARY=${DEPS_INSTALL_DIR}/lib/libcurl.a \
					-DCURL_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DFREETYPE_LIBRARY=${DEPS_INSTALL_DIR}/lib/libfreetype.a \
					-DFREETYPE_INCLUDE_DIRS=${DEPS_INSTALL_DIR}/include/freetype2 \
					-DGETTEXT_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DGETTEXT_LIBRARY=${DEPS_INSTALL_DIR}/lib/libintl.a \
					${LUA_CMAKE_FLAGS} \
					-DOGG_LIBRARY=${DEPS_INSTALL_DIR}/lib/libogg.a \
					-DOGG_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DVORBIS_LIBRARY=${DEPS_INSTALL_DIR}/lib/libvorbis.a \
					-DVORBISFILE_LIBRARY=${DEPS_INSTALL_DIR}/lib/libvorbisfile.a \
					-DVORBIS_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DZSTD_LIBRARY=${DEPS_INSTALL_DIR}/lib/libzstd.a \
					-DZSTD_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DGMP_LIBRARY=${DEPS_INSTALL_DIR}/lib/libgmp.a \
					-DGMP_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DJSON_LIBRARY=${DEPS_INSTALL_DIR}/lib/libjsoncpp.a \
					-DJSON_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DENABLE_LEVELDB=OFF \
					-DENABLE_POSTGRESQL=OFF \
					-DENABLE_REDIS=OFF \
					-DJPEG_LIBRARY=${DEPS_INSTALL_DIR}/lib/libjpeg.a \
					-DJPEG_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DPNG_LIBRARY=${DEPS_INSTALL_DIR}/lib/libpng.a \
					-DPNG_PNG_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include \
					-DCMAKE_EXE_LINKER_FLAGS="-lbz2 ${DEPS_INSTALL_DIR}/lib/libANGLE_static.a ${DEPS_INSTALL_DIR}/lib/libEGL_static.a" \
					-DXCODE_CODE_SIGN_ENTITLEMENTS=${LUANTI_DIR}/misc/ios/entitlements/release.entitlements \
					-GXcode
	: '
	cmake .. -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=$osver -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_OSX_ARCHITECTURES=arm64 \
					-DCMAKE_INSTALL_PREFIX=../build/ios/ -DRUN_IN_PLACE=FALSE -DENABLE_GETTEXT=TRUE -DCMAKE_BUILD_TYPE=$build_type \
					-DCMAKE_PREFIX_PATH=${DEPS_DIR}/deps/install \
					-DENABLE_OPENGL=OFF \
					-DENABLE_OPENGL3=OFF \
					-DENABLE_GLES2=ON \
					-DUSE_SDL2=OFF \
					-DUSE_SDL3=ON \
					-DSDL3_DIR=${DEPS_DIR}/deps/install/lib/cmake/SDL3 \
					-DSDL3_LIBRARIES="${DEPS_DIR}/deps/install/lib/liSDL3.a;${DEPS_DIR}/deps/install/lib/libSDL3main.a" \
					-DSDL3_INCLUDE_DIRS=${DEPS_DIR}/deps/install/include/SDL3 \
					-DOPENGLES2_LIBRARY_NO=${DEPS_DIR}/deps/install/lib/libGLESv2_static.a \
					-DOPENGLES2_INCLUDE_DIR=/Users/sfence/Desktop/minetest/angle/include \
					-DCURL_LIBRARY=${DEPS_DIR}/deps/install/lib/libcurl.a \
					-DCURL_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DFREETYPE_LIBRARY=${DEPS_DIR}/deps/install/lib/libfreetype.a \
					-DFREETYPE_INCLUDE_DIRS=${DEPS_DIR}/deps/install/include/freetype2 \
					-DGETTEXT_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DGETTEXT_LIBRARY=${DEPS_DIR}/deps/install/lib/libintl.a \
					-DLUA_LIBRARY=${DEPS_DIR}/deps/install/lib/libluajit-5.1.a \
					-DLUA_INCLUDE_DIR=${DEPS_DIR}/deps/install/include/luajit-2.1 \
					-DOGG_LIBRARY=${DEPS_DIR}/deps/install/lib/libogg.a \
					-DOGG_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DVORBIS_LIBRARY=${DEPS_DIR}/deps/install/lib/libvorbis.a \
					-DVORBISFILE_LIBRARY=${DEPS_DIR}/deps/install/lib/libvorbisfile.a \
					-DVORBIS_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DZSTD_LIBRARY=${DEPS_DIR}/deps/install/lib/libzstd.a \
					-DZSTD_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DGMP_LIBRARY=${DEPS_DIR}/deps/install/lib/libgmp.a \
					-DGMP_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DJSON_LIBRARY=${DEPS_DIR}/deps/install/lib/libjsoncpp.a \
					-DJSON_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DENABLE_LEVELDB=OFF \
					-DENABLE_POSTGRESQL=OFF \
					-DENABLE_REDIS=OFF \
					-DJPEG_LIBRARY=${DEPS_DIR}/deps/install/lib/libjpeg.a \
					-DJPEG_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DPNG_LIBRARY=${DEPS_DIR}/deps/install/lib/libpng.a \
					-DPNG_PNG_INCLUDE_DIR=${DEPS_DIR}/deps/install/include \
					-DCMAKE_EXE_LINKER_FLAGS="-lbz2 -F/Users/sfence/Desktop/minetest/angle/out/ios -framework libGLESv2" \
					-DXCODE_CODE_SIGN_ENTITLEMENTS=${LUANTI_DIR}/misc/ios/entitlements/release.entitlements \
					-GXcode'
	cd ..
fi

cd $RUN_DIR
