#-----------------------------------------------------------------
# Setup Features
#-----------------------------------------------------------------

# If we change architecture we need to force rescan of libraries
if(NOT OLD_CROSS_COMPILE32 STREQUAL CROSS_COMPILE32)
	force_rescan_library(SDL32)
	force_rescan_library(CURL)
	force_rescan_library(JPEG)
	force_rescan_library(JPEGTURBO)
	# TODO: recheck optional libs
	set(OLD_CROSS_COMPILE32 ${CROSS_COMPILE32} CACHE INTERNAL "Previous value for CROSS_COMPILE32")
	message(STATUS "Libraries rescanned")
endif(NOT OLD_CROSS_COMPILE32 STREQUAL CROSS_COMPILE32)

# Helper to src folder
set(SRC "${PROJECT_SOURCE_DIR}/src")

#-----------------------------------------------------------------
# Client features
#-----------------------------------------------------------------
if(BUILD_CLIENT)

	if(NOT WIN32 AND NOT APPLE AND NOT ANDROID) # Dependency of GLEW and SDL_syswm.h
		find_package(X11 REQUIRED)
		target_include_directories(client_libraries INTERFACE ${X11_INCLUDE_DIR})
	endif()

	if(ARM AND NOT ANDROID)
		#check if we're running on Raspberry Pi
		MESSAGE("Looking for bcm_host.h")
		if(EXISTS "/opt/vc/include/bcm_host.h")
			MESSAGE("bcm_host.h found")
			set(BCMHOST found)
		else()
			MESSAGE("bcm_host.h not found")
		endif()

		if(DEFINED BCMHOST)
			set(COMMON_INCLUDE_DIRS
					"/opt/vc/include"
					"/opt/vc/include/interface/vcos/pthreads"
					"/opt/vc/include/interface/vmcs_host/linux"
			)

			target_include_directories(client_libraries INTERFACE ${COMMON_INCLUDE_DIRS})
			target_link_directories(client_libraries INTERFACE "/opt/vc/lib")
			target_link_libraries(client_libraries INTERFACE bcm_host pthread)
		endif()
	endif(ARM AND NOT ANDROID)

	if(NOT FEATURE_RENDERER_GLES)
		if(NOT BUNDLED_GLEW)
			find_package(GLEW REQUIRED)
			target_link_libraries(renderer_libraries INTERFACE ${GLEW_LIBRARY})
			target_include_directories(renderer_libraries INTERFACE ${GLEW_INCLUDE_PATH})
		else()
			target_link_libraries(renderer_libraries INTERFACE bundled_glew)
			target_compile_definitions(renderer_libraries INTERFACE BUNDLED_GLEW)
		endif()

		# On 2.77 release the default usage of GLVND just caused issues as
		# libOpenGL was not installed on systems by default
		# cmake_policy(SET CMP0072 NEW) # use GLVND by default
		# Revert to using legacy libraries if available for now
		# FIXME: recheck before a new release
		if(CLIENT_GLVND)
			message(STATUS "Using GLVND instead of legacy GL library")
			set(OpenGL_GL_PREFERENCE GLVND)
		else()
			message(STATUS "Using legacy OpenGL instead of GLVND")
			set(OpenGL_GL_PREFERENCE LEGACY)
		endif ()
		find_package(OpenGL REQUIRED COMPONENTS OpenGL)
		target_link_libraries(renderer_libraries INTERFACE OpenGL::GL)
		target_include_directories(renderer_libraries INTERFACE ${OPENGL_INCLUDE_DIR})
	else() # FEATURE_RENDERER_GLES
		find_package(GLES REQUIRED)
		target_link_libraries(renderer_libraries INTERFACE ${GLES_LIBRARY})
		target_include_directories(renderer_libraries INTERFACE ${GLES_INCLUDE_DIR})
	endif()

	if(NOT BUNDLED_SDL)
		find_package(SDL2 2.0.8 REQUIRED)
		target_link_libraries(client_libraries INTERFACE ${SDL2_LIBRARY})
		target_include_directories(client_libraries INTERFACE ${SDL2_INCLUDE_DIR})
	else() # BUNDLED_SDL
		if(MINGW AND WIN32)
			# We append the mingw32 library to the client list since SDL2Main requires it
			target_link_libraries(client_libraries INTERFACE mingw32)
		endif()
		target_link_libraries(client_libraries INTERFACE bundled_sdl_int)
		target_compile_definitions(client_libraries INTERFACE BUNDLED_SDL)
	endif()
	# for tinygettext (always force SDL icons -> less dependancies)
	target_compile_definitions(client_libraries INTERFACE HAVE_SDL)

	if(NOT BUNDLED_JPEG)
		find_package(JPEGTURBO)
		if(JPEGTURBO_FOUND)
			target_link_libraries(renderer_libraries INTERFACE ${JPEG_LIBRARIES})
			target_include_directories(renderer_libraries INTERFACE ${JPEG_INCLUDE_DIR})

			# Check for libjpeg-turbo v1.3
			include(CheckFunctionExists)
			set(CMAKE_REQUIRED_INCLUDES ${JPEG_INCLUDE_DIR})
			set(CMAKE_REQUIRED_LIBRARIES ${JPEG_LIBRARY})
			# FIXME: function is checked, but HAVE_JPEG_MEM_SRC is empty. Why?
			check_function_exists("jpeg_mem_src" HAVE_JPEG_MEM_SRC)
		else()
			find_package(JPEG 8 REQUIRED)
			target_link_libraries(renderer_libraries INTERFACE ${JPEG_LIBRARIES})
			target_include_directories(renderer_libraries INTERFACE ${JPEG_INCLUDE_DIR})

			# Check for libjpeg v8
			include(CheckFunctionExists)
			set(CMAKE_REQUIRED_INCLUDES ${JPEG_INCLUDE_DIR})
			set(CMAKE_REQUIRED_LIBRARIES ${JPEG_LIBRARY})
			# FIXME: function is checked, but HAVE_JPEG_MEM_SRC is empty. Why?
			check_function_exists("jpeg_mem_src" HAVE_JPEG_MEM_SRC)
		endif()
	else()
		target_link_libraries(renderer_libraries INTERFACE bundled_jpeg_int)
	endif()

	if(FEATURE_GETTEXT)
		target_compile_definitions(client_libraries INTERFACE FEATURE_GETTEXT)
		FILE(GLOB GETTEXT_SRC
			"src/qcommon/i18n_main.cpp"
			"src/qcommon/i18n_findlocale.c"
			"src/qcommon/i18n_findlocale.h"
			"src/tinygettext/tinygettext/dictionary.hpp"
			"src/tinygettext/tinygettext/dictionary_manager.hpp"
			"src/tinygettext/tinygettext/file_system.hpp"
			"src/tinygettext/tinygettext/iconv.hpp"
			"src/tinygettext/tinygettext/language.hpp"
			"src/tinygettext/tinygettext/log.hpp"
			"src/tinygettext/tinygettext/log_stream.hpp"
			"src/tinygettext/tinygettext/plural_forms.hpp"
			"src/tinygettext/tinygettext/po_parser.hpp"
			"src/tinygettext/tinygettext/tinygettext.hpp"
			"src/tinygettext/dictionary.cpp"
			"src/tinygettext/dictionary_manager.cpp"
			"src/tinygettext/iconv.cpp"
			"src/tinygettext/language.cpp"
			"src/tinygettext/log.cpp"
			"src/tinygettext/plural_forms.cpp"
			"src/tinygettext/po_parser.cpp"
			"src/tinygettext/tinygettext.cpp"
		)
		if(MSVC)
			list(APPEND GETTEXT_SRC "${SRC}/tinygettext/windows_file_system.cpp")
			list(APPEND GETTEXT_SRC "${SRC}/tinygettext/tinygettext/windows_file_system.hpp")
		else()
			list(APPEND GETTEXT_SRC "${SRC}/tinygettext/unix_file_system.cpp")
			list(APPEND GETTEXT_SRC "${SRC}/tinygettext/tinygettext/unix_file_system.hpp")
		endif()
		target_sources(client_libraries INTERFACE ${GETTEXT_SRC})
	endif(FEATURE_GETTEXT)

	if(FEATURE_IPV6)
		target_compile_definitions(engine_libraries INTERFACE FEATURE_IPV6)
	endif(FEATURE_IPV6)

	if(FEATURE_FREETYPE)
		if(NOT BUNDLED_FREETYPE)
			find_package(Freetype REQUIRED)
			target_link_libraries(renderer_libraries INTERFACE ${FREETYPE_LIBRARIES})
			target_include_directories(renderer_libraries INTERFACE ${FREETYPE_INCLUDE_DIRS})
		else()
			target_link_libraries(renderer_libraries INTERFACE bundled_freetype_int)
		endif()
		target_compile_definitions(renderer_libraries INTERFACE FEATURE_FREETYPE)
	endif(FEATURE_FREETYPE)

	if(FEATURE_PNG)
		if(NOT BUNDLED_PNG)
			find_package(PNG REQUIRED)
			target_link_libraries(renderer_libraries INTERFACE ${LIBPNG_LIBRARIES})
			target_include_directories(renderer_libraries INTERFACE ${LIBPNG_INCLUDE_DIRS})
		else()
			target_link_libraries(renderer_libraries INTERFACE bundled_png_int)
		endif()
		target_compile_definitions(renderer_libraries INTERFACE FEATURE_PNG)
		target_compile_definitions(client_libraries INTERFACE FEATURE_PNG)
	endif(FEATURE_PNG)

	if(FEATURE_OPENAL)
		if(NOT BUNDLED_OPENAL)
			find_package(OpenAL 1.14 REQUIRED)
			target_link_libraries(client_libraries INTERFACE ${OPENAL_LIBRARY})
			target_include_directories(client_libraries INTERFACE ${OPENAL_INCLUDE_DIR})
			target_compile_definitions(client_libraries INTERFACE FEATURE_OPENAL_DLOPEN)
		else()
			target_link_libraries(client_libraries INTERFACE bundled_openal_int)
		endif()
		target_compile_definitions(client_libraries INTERFACE FEATURE_OPENAL)
	endif(FEATURE_OPENAL)

	if(FEATURE_OGG_VORBIS)
		if(NOT BUNDLED_OGG_VORBIS)
			find_package(Vorbis REQUIRED)
			target_link_libraries(client_libraries INTERFACE ${VORBIS_FILE_LIBRARY} ${OGG_LIBRARY} ${VORBIS_LIBRARY})
			target_include_directories(client_libraries INTERFACE ${VORBIS_INCLUDE_DIR})
		else() # BUNDLED_OGG_VORBIS
			target_link_libraries(client_libraries INTERFACE bundled_ogg_full)
		endif()
		target_compile_definitions(client_libraries INTERFACE FEATURE_OGG_VORBIS)
	endif(FEATURE_OGG_VORBIS)

	if(FEATURE_THEORA)
		if(NOT BUNDLED_THEORA)
			find_package(Theora REQUIRED)
			target_link_libraries(client_libraries INTERFACE ${THEORA_LIBRARY})
			target_include_directories(client_libraries INTERFACE ${THEORA_INCLUDE_DIR})
		else() # BUNDLED_THEORA
			target_link_libraries(client_libraries INTERFACE bundled_theora)
		endif()
		target_compile_definitions(client_libraries INTERFACE FEATURE_THEORA)
	endif(FEATURE_THEORA)

	if(FEATURE_IRC_CLIENT)
		target_compile_definitions(engine_libraries INTERFACE FEATURE_IRC_CLIENT)
		list(APPEND CLIENT_SRC ${IRC_CLIENT_FILES})
	endif(FEATURE_IRC_CLIENT)

	if(FEATURE_PAKISOLATION)
		target_compile_definitions(engine_libraries INTERFACE FEATURE_PAKISOLATION)
	endif(FEATURE_PAKISOLATION)
endif(BUILD_CLIENT)

if(BUILD_CLIENT OR BUILD_SERVER)
	if(FEATURE_CURL)
		if(NOT BUNDLED_CURL)
			find_package(CURL REQUIRED)

			target_link_libraries(engine_libraries INTERFACE ${CURL_LIBRARIES})
			target_include_directories(engine_libraries INTERFACE ${CURL_INCLUDE_DIR})

			if(MINGW)
				target_compile_definitions(engine_libraries INTERFACE CURL_STATICLIB)
			endif(MINGW)
		else() # BUNDLED_CURL
			target_link_libraries(engine_libraries INTERFACE bundled_curl_int)
			target_compile_definitions(engine_libraries INTERFACE CURL_STATICLIB)
		endif()
		target_sources(engine_libraries INTERFACE "${SRC}/qcommon/dl_main_curl.c")
	else()
		target_sources(engine_libraries INTERFACE "${SRC}/qcommon/dl_main_stubs.c")
	endif()

	if(FEATURE_SSL)
		if(NOT BUNDLED_WOLFSSL AND NOT BUNDLED_OPENSSL)
			if(NOT APPLE AND NOT WIN32)
				find_package(OpenSSL REQUIRED)
				target_link_libraries(engine_libraries INTERFACE ${OPENSSL_LIBRARIES})
				target_include_directories(engine_libraries INTERFACE ${OPENSSL_INCLUDE_DIR})
				target_compile_definitions(engine_libraries INTERFACE USING_OPENSSL)
			else()
				# System SSL (Schannel on windows or Secure transport on mac)
				target_compile_definitions(engine_libraries INTERFACE USING_SCHANNEL)
			endif ()
		elseif(BUNDLED_OPENSSL)
			target_link_libraries(engine_libraries INTERFACE bundled_openssl_int)
			target_compile_definitions(engine_libraries INTERFACE USING_OPENSSL)
		else() #BUNDLED_WOLFSSL
			target_link_libraries(engine_libraries INTERFACE bundled_wolfssl_int)
			target_compile_definitions(engine_libraries INTERFACE USING_WOLFSSL)
		endif()

		if(FEATURE_AUTH)
			target_compile_definitions(engine_libraries INTERFACE LEGACY_AUTH)
		endif()
		target_compile_definitions(engine_libraries INTERFACE FEATURE_SSL)
	else()
	endif()

	if(FEATURE_DBMS)
		if(NOT BUNDLED_SQLITE3)
			find_package(SQLite3 REQUIRED)
			target_link_libraries(engine_libraries INTERFACE ${SQLITE3_LIBRARY})
			target_include_directories(engine_libraries INTERFACE ${SQLITE3_INCLUDE_DIR})
		else() # BUNDLED_SQLITE3
			target_link_libraries(engine_libraries INTERFACE bundled_sqlite3)
		endif()
		target_compile_definitions(engine_libraries INTERFACE FEATURE_DBMS)

		FILE(GLOB DBMS_SRC
			"src/db/db_sql.h"
			"src/db/db_sqlite3.c"
			"src/db/db_sql_cmds.c"
		)
		target_sources(engine_libraries INTERFACE ${DBMS_SRC})
	endif(FEATURE_DBMS)

	if(FEATURE_AUTOUPDATE)
		target_compile_definitions(engine_libraries INTERFACE FEATURE_AUTOUPDATE)
	endif(FEATURE_AUTOUPDATE)
endif()

if(BUILD_SERVER)
	# FIXME: this is actually DEDICATED only
	if(FEATURE_IRC_SERVER)
		target_compile_definitions(server_libraries INTERFACE FEATURE_IRC_SERVER)
		#list(APPEND SERVER_SRC ${IRC_CLIENT_FILES})
		target_sources(server_libraries INTERFACE ${IRC_CLIENT_FILES})
	endif(FEATURE_IRC_SERVER)
endif(BUILD_SERVER)

#-----------------------------------------------------------------
# Mod features
#-----------------------------------------------------------------
if(BUILD_MOD)
	if(FEATURE_MULTIVIEW)
		target_compile_definitions(mod_libraries INTERFACE FEATURE_MULTIVIEW)
	endif(FEATURE_MULTIVIEW)

	if(FEATURE_RATING)
		target_compile_definitions(mod_libraries INTERFACE FEATURE_RATING)
	endif(FEATURE_RATING)

	if(FEATURE_PRESTIGE)
		target_compile_definitions(mod_libraries INTERFACE FEATURE_PRESTIGE)
	endif(FEATURE_PRESTIGE)

	if(FEATURE_LUA)
		if(NOT BUNDLED_LUA)
			find_package(Lua 5.4 REQUIRED)
			target_link_libraries(qagame_libraries INTERFACE ${LUA_LIBRARIES})
			target_include_directories(qagame_libraries INTERFACE ${LUA_INCLUDE_DIR})
		else() # BUNDLED_LUA
			target_link_libraries(qagame_libraries INTERFACE bundled_lua_int)
		endif()
		target_compile_definitions(qagame_libraries INTERFACE FEATURE_LUA)
	endif(FEATURE_LUA)

	if(FEATURE_OMNIBOT)
		# LIST(APPEND QAGAME_SRC "src/game/g_etbot_interface.cpp")
		# LIST(APPEND QAGAME_SRC "src/Omnibot/Common/BotLoadLibrary.cpp")
		target_compile_definitions(qagame_libraries INTERFACE FEATURE_OMNIBOT)
		target_sources(qagame_libraries INTERFACE
			"${SRC}/game/g_etbot_interface.cpp"
			"${SRC}/Omnibot/Common/BotLoadLibrary.cpp"
		)
	endif(FEATURE_OMNIBOT)

	if(FEATURE_EDV)
		target_compile_definitions(cgame_libraries INTERFACE FEATURE_EDV)
	endif(FEATURE_EDV)
endif(BUILD_MOD)

#-----------------------------------------------------------------
# Server/Common features
#-----------------------------------------------------------------
if(NOT BUNDLED_ZLIB)
	find_package(ZLIB 1.2.8 REQUIRED)
	target_link_libraries(engine_libraries INTERFACE ${ZLIB_LIBRARIES})
	target_include_directories(engine_libraries INTERFACE ${ZLIB_INCLUDE_DIRS})

	if (FEATURE_PNG)
		target_link_libraries(renderer_libraries INTERFACE ${ZLIB_LIBRARIES})
		target_include_directories(renderer_libraries INTERFACE ${ZLIB_INCLUDE_DIRS})
	endif()
else()
	target_link_libraries(engine_libraries INTERFACE bundled_zlib)
	if (FEATURE_PNG)
		target_link_libraries(renderer_libraries INTERFACE bundled_zlib)
	endif()
endif()

if(NOT BUNDLED_MINIZIP)
	find_package(MiniZip REQUIRED)
	target_link_libraries(engine_libraries INTERFACE ${MINIZIP_LIBRARIES})
	target_include_directories(engine_libraries INTERFACE ${MINIZIP_INCLUDE_DIRS})
else()
	target_link_libraries(engine_libraries INTERFACE bundled_minizip)
	target_compile_definitions(engine_libraries INTERFACE BUNDLED_MINIZIP)
endif()

if(FEATURE_ANTICHEAT)
	target_compile_definitions(server_libraries INTERFACE FEATURE_ANTICHEAT)
endif(FEATURE_ANTICHEAT)
