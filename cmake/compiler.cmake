# Copyright 2020-2022 The Mumble Developers. All rights reserved.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

include(CheckCXXCompilerFlag)

if(${CMAKE_SIZEOF_VOID_P} EQUAL 8)
	set(64_BIT TRUE)
elseif(${CMAKE_SIZEOF_VOID_P} EQUAL 4)
	set(32_BIT TRUE)
else()
	message(FATAL_ERROR "Unknown architecture - only 32bit and 64bit are supported")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(WIN32)
	message(STATUS "Using Win7 as the oldest supported Windows version")
	add_compile_definitions(_WIN32_WINNT=0x0601)
endif()

if(MSVC)
	add_compile_options(
		"$<$<CONFIG:Release>:/Ox>"
		"$<$<CONFIG:Release>:/fp:fast>"
	)

	# Needed in order to not run into C1128: number of sections exceeded object file format limit
	add_compile_options(/bigobj)

	if(32_BIT)
		# SSE2 code is generated by default, unless an explicit arch is set.
		# Our 32 bit binaries should not contain any SSE2 code, so override the default.
		add_compile_options("-arch:SSE")
	endif()

	if(symbols)
		# Configure build to be able to properly debug release builds (https://docs.microsoft.com/cpp/build/how-to-debug-a-release-build).
		# This includes explicitly disabling /Oy to help debugging (https://docs.microsoft.com/cpp/build/reference/oy-frame-pointer-omission).
		# Also set /Zo to enhance optimized debugging (https://docs.microsoft.com/cpp/build/reference/zo-enhance-optimized-debugging).
		add_compile_options(
			"/GR"
			"/Zi"
			"/Zo"
			"/Oy-"
		)
		add_link_options(
			"/DEBUG"
			"/OPT:REF"
			"/OPT:ICF"
			"/INCREMENTAL:NO"
			# Ignore warnings about PDBs not being found (happens e.g. for vc140 as vcpkg's portfile doesn't install the PDB files)
			"/ignore:4099"
		)
	endif()

	if(warnings-as-errors)
		add_compile_options("/WX")
		add_link_options("/WX")
	endif()
elseif(UNIX OR MINGW)
	add_compile_options(
		"-fvisibility=hidden"
		"-Wall"
		"-Wextra"
	)

	# Avoid "File too big" error
	check_cxx_compiler_flag("-Wa,-mbig-obj" COMPILER_HAS_MBIG_OBJ)
	if (${COMPILER_HAS_MBIG_OBJ})
		add_compile_options("-Wa,-mbig-obj")
	endif()

	if(optimize)
		add_compile_options(
			"-O3"
			"-march=native"
		)
	endif()

	if(warnings-as-errors)
		add_compile_options("-Werror")
	endif()

	if(APPLE)
		add_link_options("-Wl,-dead_strip")

		if(symbols)
			add_compile_options(
				"-gfull"
				"-gdwarf-2"
			)
		endif()
	else()
		if(NOT MINGW)
			add_link_options(
				"-Wl,-z,relro"
				"-Wl,-z,now"
			)
		endif()

		# Ensure _FORTIFY_SOURCE is not used in debug builds.
		#
		# First, ensure _FORTIFY_SOURCE is undefined.
		# Then -- and, only for release builds -- set _FORTIFY_SOURCE=2.
		#
		# We can't use _FORTIFY_SOURCE in debug builds (which are built with -O0) because _FORTIFY_SOURCE=1 requires -O1 and _FORTIFY_SOURCE=2 requires -O2.
		# Modern GLIBCs warn about this since https://sourceware.org/bugzilla/show_bug.cgi?id=13979.
		# In Mumble builds with warnings-as-errors, this will cause build failures.
		add_compile_options("-U_FORTIFY_SOURCE")

		if(NOT MINGW)
			add_compile_options($<$<CONFIG:Debug>:-fstack-protector>)
		endif()

		add_compile_options(
			$<$<NOT:$<CONFIG:Debug>>:-D_FORTIFY_SOURCE=2>
		)

		add_link_options(
			$<$<CONFIG:Debug>:-Wl,--no-add-needed>
		)

		if(symbols)
			add_compile_options("-g")
		endif()
	endif()
endif()

function(target_disable_warnings TARGET)
	if(MSVC)
		target_compile_options(${TARGET} PRIVATE "/w")
	else()
		target_compile_options(${TARGET} PRIVATE "-w")
	endif()
endfunction()
