	@echo on
	setlocal EnableDelayedExpansion

	rem get rid of build variables that might be kicking around on desktop environment
	if not defined source_dir (
		set WORK_DIR=
		set source_dir=
		set spec_dir=
		set GRAAL_SRC_DIR=
		set JAVA_HOME=
		set m1=
		set m2=
		set m3=
		set m4=
		set modules=
		set EA_SUFFIX="_ea"
		set set DEV_REPO=
		set BUILD_JDK=
		set JAVA_HOME=
		set BUILD_WITH_JFR=
	)
	
	rem define source version
	set UPDATE=322
	set BUILD=b03
	set MILESTONE=redhat
	set OJDK_MILESTONE=8u
	set OJDK_UPDATE=322
	set OJDK_BUILD=b03
	set OJDK_TAG=jdk%OJDK_MILESTONE%%OJDK_UPDATE%-%OJDK_BUILD%
	set EA_SUFFIX="_ea"

	rem uncomment to retrieve from jdk8u-dev repository
	rem set DEV_REPO=-dev

	rem define build characteristics

	set DOWNLOAD_JDK=1
	set DOWNLOAD_TOOLS=1

	rem define to clean the build before compile
	set CLEAN_JDK=

	set CONFIGURE_JDK=1

	rem define to revert to checked out sources
	set REVERT_JDK=

	rem define to build jdk
	set BUILD_JDK=1
	set BUILD_JRE=1
	set BUILD_DEMOS=1

	rem valid choices: release slowdebug fastdebug
	set OJDK_DEBUG_LEVEL=release

	rem try to shorten paths for cygwin
	rem perform all work in cygwins /tmp directory
	rem use forward slashes
	if not defined source_dir (
		rem batch file build
		set WORK_DIR=C:/tmp/build-8
		set source_dir=!WORK_DIR!
		set spec_dir=%~dp0
	) else (
		rem brew build
		set WORK_DIR=C:/tmp/build-8
		if not defined spec_dir (
			set spec_dir=%source_dir:\=/%
		)
	)
	if not exist %WORK_DIR% mkdir "%WORK_DIR%"

	rem local directory for build toolchain, tools and libraries
	set OJDKBUILD_DIR=%WORK_DIR%/ojdkbuild

	rem CPU build or regular vanilla upstream
	rem set CPU_MODE=1

	rem Mercurial checkout or copy source from build server
	rem use of build server is only valid for CPU builds
	set USE_MERCURIAL=1

	rem JDK configure script options

	rem log level for JDK 'make': valid choices info debug
	set LOG_LEVEL=debug

	rem if set, delete debug files
	if ".%OJDK_DEBUG_LEVEL%" == ".release" (
		set DELETE_DEBUG_FILES=1
	)

	set OJDK_CONF=windows-x86_64-server-%OJDK_DEBUG_LEVEL%

	rem define build tools repo and version
	set OJDKBUILD_REPOBASE=https://github.com/ojdkbuild
	set OJDKBUILD_TAG=b7bc723e18deefef701752b57dbd25c0072ef4a7


	set PATH=C:/Windows/system32;C:/Windows
	set PATH=C:/cygwin64/bin;%PATH%

	rem uncomment to enable AV scan
	rem set CLAMSCAN=C:/cygwin64/bin/clamscan.exe

	rem local directory to clone JDK repo into
	set OJDK_SRC_DIR=jdk%OJDK_MILESTONE%%DEV_REPO%
	set OJDK_SRC_PATH=%WORK_DIR%/%OJDK_SRC_DIR%

	rem the remote repo for JDK sources
	if defined USE_MERCURIAL (		
		set OJDK_REMOTE_REPO_PROTOCOL=https://
		set OJDK_REMOTE_REPO=hg.openjdk.java.net/jdk%OJDK_MILESTONE%/jdk%OJDK_MILESTONE%%DEV_REPO%
	)

	@echo *** work directory %WORK_DIR%
	@echo *** JDK tag %OJDK_TAG%
	@echo *** debug level %OJDK_DEBUG_LEVEL%

	rem ZIP_DIR_NAME is the directory the zipfile (RELEASE_ZIPFILE) will unpack into
	set ZIP_DIR_NAME=openjdk-%OJDK_MILESTONE%%OJDK_UPDATE%-%OJDK_BUILD%
	set RELEASE_ZIPFILE=OpenJDK8U-jdk_x64_windows_%OJDK_MILESTONE%%OJDK_UPDATE%%OJDK_BUILD%%EA_SUFFIX%.zip
	@echo final JDK product will be !RELEASE_ZIPFILE! directory !ZIP_DIR_NAME!

	set ZIP_JRE_DIR_NAME=openjdk-%OJDK_MILESTONE%%OJDK_UPDATE%-%OJDK_BUILD%-jre
	set RELEASE_JRE_ZIPFILE=OpenJDK8U-jre_x64_windows_%OJDK_MILESTONE%%OJDK_UPDATE%%OJDK_BUILD%%EA_SUFFIX%.zip
	@echo final JRE product will be !RELEASE_JRE_ZIPFILE! directory !ZIP_JRE_DIR_NAME!

	call :download_git || exit /b 1
	set SAVEPATH=%PATH% 
	if defined DOWNLOAD_TOOLS ( 
		call :download_ojdkbuild || exit /b 1
		call :download_mercurial || exit /b 1
		call :build_freetype || exit /b 1
	) else (
		@echo *** skipping JDK build downloads
	)

	if defined DOWNLOAD_JDK (
		call :checkout_jdk_source || exit /b 1
	)
	
	if defined CONFIGURE_JDK (
		call :configure_jdk_build || exit /b 1
	)

	if defined CLEAN_JDK (
		call :clean_jdk || exit /b 1
	)

	if defined BUILD_JDK (
		call :build_jdk || exit /b 1
		call :build_jdk_zip || exit /b 1
		if defined BUILD_JRE (
			call :build_jre_zip || exit /b 1
		)
		@echo *** JDK build completed
	) else (
		@echo *** skipping jdk build
	)

	rem call :test_jdk_version || exit /b 1

	@echo *** build is complete
	exit /b 

:test_jdk_version
	@echo testing JDK version strings
	rem EA build:
	rem  $ java -version
	rem  openjdk version "1.8.0_242-ea"
	rem  OpenJDK Runtime Environment (build 1.8.0_242-ea-b01)
	rem  OpenJDK 64-Bit Server VM (build 25.242-b01, mixed mode)
	rem 
	rem GA build:
	rem  $ java -version
	rem  openjdk version "1.8.0_232"
	rem  OpenJDK Runtime Environment (build 1.8.0_232-b09)
	rem  OpenJDK 64-Bit Server VM (build 25.232-b09, mixed mode)
	rem 
	set TEMPDIR=%WORK_DIR:/=\%
	set EXPECTED_VERSION_FILE=%TEMPDIR%\expected_version.txt
	set ACTUAL_VERSION_FILE=%TEMPDIR%\actual_version.txt
	if defined EA_SUFFIX (
		echo openjdk version "1.8.0_%OJDK_UPDATE%-ea" >%EXPECTED_VERSION_FILE% || exit /b 1
		echo OpenJDK Runtime Environment (build 1.8.0_%OJDK_UPDATE%-ea-%OJDK_BUILD%^) >>%EXPECTED_VERSION_FILE%
		echo OpenJDK 64-Bit Server VM (build 25.%OJDK_UPDATE%-%OJDK_BUILD%, mixed mode^) >>%EXPECTED_VERSION_FILE%
	) else (
		echo openjdk version "1.8.0_%OJDK_UPDATE%" >%EXPECTED_VERSION_FILE% || exit /b 1
		echo OpenJDK Runtime Environment (build 1.8.0_%OJDK_UPDATE%-%OJDK_BUILD%^) >>%EXPECTED_VERSION_FILE%
		echo OpenJDK 64-Bit Server VM (build 25.%OJDK_UPDATE%-%OJDK_BUILD%, mixed mode^) >>%EXPECTED_VERSION_FILE%
	)
	set JDK_HOME=
	if exist "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/%ZIP_DIR_NAME%" (
		set JDK_HOME=%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/%ZIP_DIR_NAME%
	)
	if exist "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image" (
		set JDK_HOME=%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image
	)
	if not defined JDK_HOME (
		@echo *** no JDK_HOME found in %OJDK_SRC_PATH%/build/%OJDK_CONF%/images
		exit /b 1
	)
	%JDK_HOME:/=\%\bin\java -version 2>%ACTUAL_VERSION_FILE% || exit /b 1
	c:\cygwin64\bin\diff -b %EXPECTED_VERSION_FILE% %ACTUAL_VERSION_FILE%
	if not %ERRORLEVEL% == 0 (
		echo *** Version strings do not match.
		echo expected:
		type %EXPECTED_VERSION_FILE%
		echo actual:
		type %ACTUAL_VERSION_FILE%
		exit /b 1
	) else (
		echo version string passes test:
		type %ACTUAL_VERSION_FILE%
	)
	exit /b

:checkout_jdk_source
	@echo *** checkout the JDK
	@echo *** - fetch JDK base repo
	cd "%WORK_DIR%"
	set PATH=%HG_DIR%;%PATH%
	if not exist "%OJDK_SRC_PATH%" (
		if defined OJDK_TAG (
			%HG% clone -u %OJDK_TAG% %OJDK_REMOTE_REPO_PROTOCOL%%OJDK_REMOTE_REPO% %OJDK_SRC_DIR% || exit /b 1
		) else (
			%HG% clone %OJDK_REMOTE_REPO_PROTOCOL%%OJDK_REMOTE_REPO% %OJDK_SRC_DIR% || exit /b 1
		)
	) else (
		if defined REVERT_JDK (
			call :revert_jdk_repo || exit /b 1
			pushd "%OJDK_SRC_PATH%" || exit /b 1
			%HG% pull -u || exit /b 1
			if defined OJDK_TAG %HG% update --rev %OJDK_TAG% || exit /b 1
			popd
		)
	)
	@echo *** - fetch JDK subrepos
	pushd "%OJDK_SRC_PATH%"
	set jdkmodules=corba hotspot jaxp jaxws jdk langtools nashorn
	for %%G in (!jdkmodules!) do (
		set module=%%G
		set repo=!module:/=_!
		if not exist %%G (
			if defined OJDK_TAG (
				%HG% clone -u %OJDK_TAG% %OJDK_REMOTE_REPO_PROTOCOL%%OJDK_REMOTE_REPO%/!repo! %%G || exit /b 1
			) else (
				%HG% clone %OJDK_REMOTE_REPO_PROTOCOL%%OJDK_REMOTE_REPO%/!repo! %%G || exit /b 1
			)
		) else (
			if defined REVERT_JDK (
				pushd %%G
				%HG% pull -u || exit /b 1
				if defined OJDK_TAG %HG% update --rev %OJDK_TAG% || exit /b 1
				popd
			)
		)
		pushd %%G
		%HG% id
		popd
	)
	popd

	@echo *** fix permissions of jdk source code
	takeown /f "%OJDK_SRC_PATH:/=\%" /r > nul || exit /b 1
	icacls "%OJDK_SRC_PATH:/=\%" /reset /T /C /Q || exit /b 1
	@echo off
	call :setsdkenv
	set PATH=C:/cygwin64/bin;%PATH%
	@echo *** current mercurial changeset
	pushd "%OJDK_SRC_PATH%"
	%HG% id || exit /b 1
	popd
	exit /b

:revert_jdk_repo
	@echo *** revert JDK base repo
	set PATH=%HG_DIR%;%PATH%
	if exist "%OJDK_SRC_PATH%" (
		pushd "%OJDK_SRC_PATH%" || exit /b 1
		%HG% revert --all || exit /b 1
		@echo *** revert JDK subrepos
		set jdkmodules=corba hotspot jaxp jaxws jdk langtools nashorn
		for %%G in (!jdkmodules!) do (
			set module=%%G
			set repo=!module:/=_!
			if exist %%G (
				pushd %%G || exit /b 1
				%HG% revert --all || exit /b 1
				popd
			)
		)
		popd
	)
	exit /b

:configure_jdk_build
	@echo *** configure JDK build
	rem create this file so that the JDK configure script can see it and confirm the existence of a VS toolchain
	if not exist %OJDKBUILD_DIR%/tools/toolchain/vs2010e/VC/bin/x86_amd64/vcvarsx86_amd64.bat (
		echo "rem placeholder for JDK configure script toolchain detection" >%OJDKBUILD_DIR%/tools/toolchain/vs2010e/VC/bin/x86_amd64/vcvarsx86_amd64.bat
	)
	set CFGARGS=--enable-unlimited-crypto=yes
	set CFGARGS=%CFGARGS% --with-conf-name=%OJDK_CONF% 
	set CFGARGS=%CFGARGS% --enable-debug-symbols=yes
	set CFGARGS=%CFGARGS% --with-debug-level=%OJDK_DEBUG_LEVEL%
	set CFGARGS=%CFGARGS% --with-boot-jdk=%OJDKBUILD_DIR%/tools/bootjdk7
	set CFGARGS=%CFGARGS% --with-toolchain-path=%OJDKBUILD_DIR%/tools/toolchain
	set CFGARGS=%CFGARGS% --with-toolchain-version=2010
	set CFGARGS=%CFGARGS% --with-msvcr-dll=%OJDKBUILD_DIR%/tools/toolchain/msvcr100/amd64/msvcr100.dll
	set CFGARGS=%CFGARGS% --with-freetype-include=%OJDKBUILD_DIR%/lookaside/freetype/include
	set CFGARGS=%CFGARGS% --with-freetype-lib=%OJDKBUILD_DIR%/deps/freetype/build/bin
	set CFGARGS=%CFGARGS% --with-num-cores=2
	if defined EA_SUFFIX (
		set CFGARGS=!CFGARGS! --with-milestone="ea"
		set CFGARGS=!CFGARGS! --with-build-number=%OJDK_BUILD%
		rem set CFGARGS=!CFGARGS! --with-user-release-suffix="ea"
	) else (
		set CFGARGS=!CFGARGS! --with-milestone="fcs"
		set CFGARGS=!CFGARGS! --with-build-number=%OJDK_BUILD%
	)
	set CFGARGS=!CFGARGS! --with-update-version=%OJDK_UPDATE%
	if defined JTREG_HOME (
		set CFGARGS=!CFGARGS! --with-jtreg=%JTREG_HOME%
	)
	call :setsdkenv
	pushd "%OJDK_SRC_PATH%"
	C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -c "dir . -R | foreach { $_.LastWriteTime = [System.DateTime]::Now }"
	bash configure %CFGARGS% || exit /b 1
	popd || exit /b 1
	exit /b

:build_jdk
	@echo *** build JDK
	call :setsdkenv
	pushd "%OJDK_SRC_PATH%"
	if ".%OJDK_DEBUG_LEVEL%" == ".slowdebug" (
		set JDK_TARGETS=images
	) else (
		set JDK_TARGETS=images
	)
	make LOG=%LOG_LEVEL% CONF=%OJDK_CONF% %JDK_TARGETS% || exit /b 1
	if defined BUILD_STATIC_LIBS (
		@echo *** prepare JDK for JVMCI build
		cd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/"
		bash -c "find . -name \*.diz -exec rm {} \;"
		copy "%OJDK_SRC_PATH%/build/%OJDK_CONF%/jdk/objs\java_static.lib" "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image/jre/lib/java.lib" || exit /b 1
		copy "%OJDK_SRC_PATH%/build/%OJDK_CONF%/jdk/objs\net_static.lib" "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image/jre/lib/net.lib" || exit /b 1
		copy "%OJDK_SRC_PATH%/build/%OJDK_CONF%/jdk/objs\nio_static.lib" "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image/jre/lib/nio.lib" || exit /b 1
		copy "%OJDK_SRC_PATH%/build/%OJDK_CONF%/jdk/objs\zip_static.lib" "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image/jre/lib/zip.lib" || exit /b 1
		copy "%OJDK_SRC_PATH%/build/%OJDK_CONF%/jdk/objs\fdlibm.lib" "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image/jre/lib/fdlibm.lib" || exit /b 1
	)
	if not defined BUILD_DEMOS (
		rd /q/s "%OJDK_SRC_PATH:/=\%\build\%OJDK_CONF%\images\j2sdk-image\demo"
	)
	popd || exit /b 1
	@echo *** JDK build completed: JDK in "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/j2sdk-image"
	exit /b

:build_jdk_zip
	@echo *** zip JDK release
	if exist %source_dir%\%RELEASE_ZIPFILE% del %source_dir%\%RELEASE_ZIPFILE%
	pushd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/"
	if defined DELETE_DEBUG_FILES (
		@echo *** remove debug files
		bash -c "find j2sdk-image -name \*.diz -exec rm {} \;"
		bash -c "find j2sdk-image -name \*.pdb -exec rm {} \;"
		bash -c "find j2sdk-image -name \*.map -exec rm {} \;"
	)
	if exist %ZIP_DIR_NAME% (
		rd /s/q %ZIP_DIR_NAME%
	)
	if exist %source_dir:/=\%\%RELEASE_ZIPFILE% (
		del %source_dir:/=\%\%RELEASE_ZIPFILE%
	)
	ren j2sdk-image %ZIP_DIR_NAME% || exit /b 1
	rem %OJDKBUILD_DIR%/tools/zip/zip -r %source_dir%\%RELEASE_ZIPFILE% ./%ZIP_DIR_NAME% || exit /b 1
	bash -c "zip -r %source_dir:\=/%/%RELEASE_ZIPFILE% ./%ZIP_DIR_NAME%" || exit /b 1
	popd || exit /b 1
	exit /b

:build_jre_zip
	@echo *** zip JRE release
	if exist %source_dir:/=\%\%RELEASE_JRE_ZIPFILE% del %source_dir:/=\%\%RELEASE_JRE_ZIPFILE%
	pushd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/" || exit /b 1
	if defined DELETE_DEBUG_FILES (
		@echo *** remove debug files
		bash -c "find j2re-image -name \*.diz -exec rm {} \;"
		bash -c "find j2re-image -name \*.pdb -exec rm {} \;"
		bash -c "find j2re-image -name \*.map -exec rm {} \;"
	)
	if exist %ZIP_JRE_DIR_NAME% (
		rd /s/q %ZIP_JRE_DIR_NAME%
	)
	if exist %source_dir:/=\%\%RELEASE_JRE_ZIPFILE% (
		del %source_dir:/=\%\%RELEASE_JRE_ZIPFILE%
	)
	ren j2re-image %ZIP_JRE_DIR_NAME% || exit /b 1
	rem %OJDKBUILD_DIR%/tools/zip/zip -r %source_dir%\%RELEASE_JRE_ZIPFILE% ./%ZIP_JRE_DIR_NAME% || exit /b 1
	bash -c "zip -r %source_dir:\=/%/%RELEASE_JRE_ZIPFILE% ./%ZIP_JRE_DIR_NAME%" || exit /b 1
	popd || exit /b 1
	exit /b

:remove_debug_files
	@echo *** remove debug files
	cd "%OJDK_SRC_PATH%/build/%OJDK_CONF%/images/"
	bash -c "find j2sdk-image j2re-image -name \*.diz -exec rm {} \;"
	bash -c "find j2sdk-image j2re-image -name \*.pdb -exec rm {} \;"
	bash -c "find j2sdk-image j2re-image -name \*.map -exec rm {} \;"
	exit /b

:build_freetype
	@echo *** build freetype
	if not exist "%OJDKBUILD_DIR%/deps/freetype/build" (
		mkdir "%OJDKBUILD_DIR%/deps/freetype/build"
	)
	copy "%spec_dir:/=\%\ojdkbuild_freetype.def" "%OJDKBUILD_DIR:/=\%/deps\freetype\resources"
	pushd "%OJDKBUILD_DIR%/deps/freetype/build"
	call :setsdkenv
	cmake -G "NMake Makefiles" -DOJDKBUILD_DIR=%OJDKBUILD_DIR% -Dopenjdk_EXE_VERSION=%OJDK_BUILD:b=% .. || exit /b 1
	nmake || exit /b 1
	popd
	exit /b

:download_ojdkbuild
	@echo *** fetch and check ojdkbuild
	if not exist %WORK_DIR%/ojdkbuild (
		set OJDKBUILD_REPO=%OJDKBUILD_REPOBASE%/ojdkbuild.git
		pushd "%WORK_DIR%" || exit /b 1
		%GIT% clone -q !OJDKBUILD_REPO! ojdkbuild || exit /b 1
		cd ojdkbuild || exit /b 1
		%GIT% reset --hard %OJDKBUILD_TAG% || exit /b 1
		popd
	)
	@echo *** fetch ojdkbuild submodules
	cd "%OJDKBUILD_DIR%"
	if defined BUILD_JDK (
		set m1=deps/freetype external/freetype lookaside/freetype
		set m2=tools/bootjdk7 tools/cmake tools/make tools/zip
	)
	set m3=tools/toolchain/directx tools/toolchain/msvcr100 tools/toolchain/sdk71 tools/toolchain/vs2010e
	set modules=%m1% %m2% %m3%
	if not exist %OJDKBUILD_DIR%/deps      mkdir %OJDKBUILD_DIR:/=\%\deps
	if not exist %OJDKBUILD_DIR%/external  mkdir %OJDKBUILD_DIR:/=\%\external
	if not exist %OJDKBUILD_DIR%/lookaside mkdir %OJDKBUILD_DIR:/=\%\lookaside
	if not exist %OJDKBUILD_DIR%/tools     mkdir %OJDKBUILD_DIR:/=\%\tools
	for %%G in (%modules%) do (
		set module=%%G
		set repo=!module:/=_!
		rem if exist %%G rmdir /S/Q !module:/=\!
		if not exist %%G/.git (
			%GIT% clone -q %OJDKBUILD_REPOBASE%/!repo! %%G || exit /b 1
		)
	)
	if not exist "%OJDKBUILD_DIR%/lookaside" mkdir "%OJDKBUILD_DIR%/lookaside"
	PATH C:/cygwin64/bin;%PATH%

	@echo *** checkout and update freetype
	rem pushd "%OJDKBUILD_DIR%/lookaside/freetype"
	rem %GIT% checkout freetype-2.8-1 || exit /b 1
	rem popd

	@echo ** fix permissions
	cd "%WORK_DIR%" || exit /b 1
	takeown /f "%OJDKBUILD_DIR:/=\%" /r > nul || exit /b 1
	icacls "%OJDKBUILD_DIR:/=\%" /reset /T /C /Q || exit /b 1
	if defined CLAMSCAN %CLAMSCAN% --quiet --recursive ojdkbuild || exit /b 1
	exit /b

:clean_jdk
	@echo *** clean JDK
	call :setsdkenv
	pushd "%OJDK_SRC_PATH%"
	make CONF=%OJDK_CONF% clean
	popd || exit /b 1
	exit /b

:download_mercurial
	@echo *** install mercurial
	set HG=call :hg_cmd
	set HG_DIR=.
	exit /b
	
	:hg_cmd
	@echo calling mercurial %*
	c:\cygwin64\bin\bash -c "/bin/hg %*" || exit /b 1
	exit /b

:download_git
	@echo *** set git global options and path
	git config --global core.autocrlf input || exit /b 1
	git config --global http.sslverify false || exit /b 1
	set GIT="C:/cygwin64/bin/git.exe"
	exit /b

	rem subroutines
:setsdkenv
	@echo *** set MSVC environment

	rem tools dirs
	set VS=%OJDKBUILD_DIR%/tools/toolchain/vs2010e
	set WINSDK=%OJDKBUILD_DIR%/tools/toolchain/sdk71

	rem set compiler environment manually
	set WINDOWSSDKDIR=%WINSDK%
	set VS100COMNTOOLS=%VS%/Common7/Tools
	set Configuration=Release
	set WindowsSDKVersionOverride=v7.1
	set ToolsVersion=4.0
	set TARGET_CPU=x64
	set CURRENT_CPU=x64
	set PlatformToolset=Windows7.1SDK
	set TARGET_PLATFORM=XP
	set LIB=%VS%/VC/Lib/amd64;%WINSDK%/Lib/x64
	set VS_LIB=%LIB%
	set LIBPATH=%VS%/VC/Lib/amd64
	set INCLUDE=%VS%/VC/INCLUDE;%WINSDK%/INCLUDE;%WINSDK%/INCLUDE/gl;
	set VS_INCLUDE=%INCLUDE%

	rem additional tools
	set WINLD=%VS%/VC/Bin/x86_amd64/link.exe
	set MT=%WINSDK%/Bin/mt.exe
	set RC=%WINSDK%/Bin/rc.exe
	set WINAR=%VS%/VC/Bin/x86_amd64/lib.exe
	set DUMPBIN=%VS%/VC/Bin/x86_amd64/dumpbin.exe

	rem misc vars
	set CYGWIN=nodosfilewarning
	set OBJCOPY=NOT_NEEDED_ON_WINDOWS

	rem set path
	set PATH=c:/cygwin64/bin
	set PATH=%PATH%;C:/WINDOWS/System32;C:/WINDOWS;C:/WINDOWS/System32/wbem
	set PATH=%PATH%;%VS%/Common7/IDE;%VS%/Common7/Tools;%VS%/VC/Bin/x86_amd64;%VS%/VC/Bin;%VS%/VC/Bin/VCPackages
	set PATH=%PATH%;%WINSDK%/Bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/toolchain/msvcr100/amd64;%OJDKBUILD_DIR%/tools/toolchain/msvcr100/i586
	set PATH=%PATH%;%VS%/Common7/IDE
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/cmake/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/pkgconfig/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/nasm
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/make
	set PATH=%PATH%;%OJDKBUILD_DIR%/tools/perl520/perl/bin
	set PATH=%PATH%;%OJDKBUILD_DIR%/resources/scripts
	exit /b

