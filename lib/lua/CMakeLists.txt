project(lua CXX)

set(LUA_VERSION_MAJOR 5)
set(LUA_VERSION_MINOR 1)
set(LUA_VERSION_PATCH 4)
set(LUA_VERSION "${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}.${LUA_VERSION_PATCH}")

set(COMMON_CFLAGS)
set(COMMON_LDFLAGS)
set(LIBS)

if(APPLE AND CMAKE_SYSTEM_NAME STREQUAL "iOS")
	# iOS has no system()/popen() and no NSModule dyld loader. LUA_USE_MACOSX
	# would select the ancient DYLD backend (unavailable on iOS) and
	# LUA_USE_POSIX would pull in popen(); both fail to compile against the
	# iOS SDK. Build bundled Lua in plain-ANSI mode instead: dynamic C module
	# loading, io.popen and os.execute are unavailable anyway (Minetest's Lua
	# sandbox removes them), and the ANSI fallbacks compile cleanly.
	set(DEFAULT_POSIX FALSE)
	set(DEFAULT_DLOPEN OFF)
elseif(APPLE)
	set(DEFAULT_POSIX TRUE)
	set(DEFAULT_DLOPEN OFF)
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -DLUA_USE_MACOSX")
elseif(UNIX OR CYGWIN)
	set(DEFAULT_POSIX TRUE)
elseif(WIN32)
	set(LUA_WIN TRUE)
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -DLUA_BUILD_AS_DLL")
else()
	set(DEFAULT_ANSI TRUE)
endif()

if(MSVC)
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -D_CRT_SECURE_NO_WARNINGS")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(COMMON_LDFLAGS "${COMMON_LDFLAGS} -Wl,-E -lm")
	set(DEFAULT_DLOPEN ON)
endif()

option(LUA_USE_DLOPEN "Enable dlopen support." ${DEFAULT_DLOPEN})
mark_as_advanced(LUA_USE_DLOPEN)

option(LUA_ANSI "Disable non-ANSI features." ${DEFAULT_ANSI})
mark_as_advanced(LUA_ANSI)

if(LUA_USE_DLOPEN)
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -DLUA_USE_DLOPEN")
	if(NOT APPLE)
		set(COMMON_LDFLAGS "${COMMON_LDFLAGS} -ldl ")
	endif(NOT APPLE)
endif(LUA_USE_DLOPEN)

if(DEFAULT_POSIX)
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -DLUA_USE_POSIX")
endif(DEFAULT_POSIX)

if(LUA_ANSI)
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -DLUA_ANSI")
endif(LUA_ANSI)

# Standard flags to use
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|(Apple)?Clang")
	set(COMMON_CFLAGS "${COMMON_CFLAGS} -pipe -Wall -Wextra -Wshadow -W -pedantic")
endif()

# COMMON_CFLAGS has no effect without this line
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${COMMON_CFLAGS}")

add_subdirectory(src)
