@echo off
setlocal enabledelayedexpansion

REM Builds the TensorFlow Lite C API DLL that tflite_flutter needs on Windows.
REM There is no official prebuilt download for this -- it has to be built from
REM TensorFlow source. See: https://developers.google.com/edge/litert/build/cmake
REM and tflite_flutter's README "Windows" setup section.
REM
REM This will take a while (TensorFlow is a large repo, and the C API build
REM itself can take 15-60+ minutes depending on your machine). Run this from
REM a plain Command Prompt (not required to be a special "Developer" prompt --
REM this script locates and loads the MSVC environment itself).
REM
REM TensorFlow is pinned to TF_TAG below, and tflite-v2.20.0-windows.patch
REM (next to this script) is applied on top of it. The patch fixes three
REM problems with that tag's CMake build on Windows:
REM   1. release_version.h requires TF_MAJOR/MINOR/PATCH_VERSION, which only
REM      the Bazel build defines -- the patch supplies them.
REM   2. model_building.h relies on a "friend class Tensor" that MSVC rejects
REM      (error C2248) -- the patch makes Buffer's members public.
REM   3. TFL_STATIC_LIBRARY_BUILD is defined even when building the shared C
REM      library, which turns off __declspec(dllexport) and produces a DLL
REM      with no exported functions -- the patch skips it for shared builds.
REM If you change TF_TAG, the patch (and its hard-coded version) needs updating.

set TF_TAG=v2.20.0
set VCVARSALL="C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvarsall.bat"
set CMAKE_EXE="C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set PATCH_FILE=%~dp0tflite-v2.20.0-windows.patch
set PROJECT_ROOT=%~dp0..

REM TensorFlow's dependency tree is deep enough to hit Windows' 260-character
REM path limit if built under the project folder, so default to a short path
REM on the system drive. Set TFLITE_WORKDIR to build somewhere else.
if defined TFLITE_WORKDIR (
  set WORKDIR=%TFLITE_WORKDIR%
) else (
  set WORKDIR=%SystemDrive%\tflite_build
)

if not exist %VCVARSALL% (
  echo Could not find vcvarsall.bat at %VCVARSALL%
  echo Edit this script and point VCVARSALL at your Visual Studio installation.
  exit /b 1
)

if not exist %CMAKE_EXE% (
  echo Could not find cmake.exe at %CMAKE_EXE%
  echo Edit this script and point CMAKE_EXE at your Visual Studio installation,
  echo or install CMake separately from https://cmake.org/download/ and adjust
  echo this script to call plain "cmake" instead.
  exit /b 1
)

if not exist "%PATCH_FILE%" (
  echo Could not find the TensorFlow patch at %PATCH_FILE%
  exit /b 1
)

echo === Loading MSVC x64 build environment ===
call %VCVARSALL% x64
if errorlevel 1 exit /b 1

if not exist "%WORKDIR%" mkdir "%WORKDIR%"
cd /d "%WORKDIR%"

if not exist "%WORKDIR%\tensorflow_src" (
  echo === Cloning TensorFlow %TF_TAG% - shallow clone, still a large download ===
  git -c core.longpaths=true clone --depth 1 --branch %TF_TAG% https://github.com/tensorflow/tensorflow.git tensorflow_src
  if errorlevel 1 exit /b 1
) else (
  echo === TensorFlow source already present, skipping clone ===
)

echo === Applying Windows build patch ===
git -C "%WORKDIR%\tensorflow_src" apply --reverse --check "%PATCH_FILE%" >nul 2>&1
if not errorlevel 1 (
  echo Patch already applied, skipping.
) else (
  git -C "%WORKDIR%\tensorflow_src" apply "%PATCH_FILE%"
  if errorlevel 1 (
    echo Could not apply %PATCH_FILE%. The TensorFlow checkout in
    echo %WORKDIR%\tensorflow_src may not be %TF_TAG% -- delete it and re-run.
    exit /b 1
  )
)

if not exist "%WORKDIR%\tflite_build" mkdir "%WORKDIR%\tflite_build"
cd /d "%WORKDIR%\tflite_build"

echo === Configuring CMake for the TFLite C API ===
REM CMAKE_POLICY_VERSION_MINIMUM lets CMake 4.x configure the older
REM third-party dependencies TFLite fetches (they declare minimums < 3.5).
%CMAKE_EXE% "%WORKDIR%\tensorflow_src\tensorflow\lite\c" -A x64 -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DTFLITE_ENABLE_XNNPACK=ON -DTFLITE_ENABLE_GPU=OFF
if errorlevel 1 exit /b 1

echo === Building (this is the slow part) ===
REM Release config: a Debug DLL would depend on the debug C++ runtime,
REM which isn't installed on normal (non-developer) machines.
%CMAKE_EXE% --build . --config Release --target tensorflowlite_c -j
if errorlevel 1 exit /b 1

set FOUND_DLL=%WORKDIR%\tflite_build\Release\tensorflowlite_c.dll
if not exist "%FOUND_DLL%" (
  echo Could not find %FOUND_DLL%
  echo Check the build output above for errors.
  exit /b 1
)

echo === Verifying the DLL exports the TFLite C API ===
dumpbin /exports "%FOUND_DLL%" | findstr /c:"TfLiteInterpreterCreate" >nul
if errorlevel 1 (
  echo %FOUND_DLL% does not export TfLiteInterpreterCreate -- the export
  echo fix in the patch did not take effect. tflite_flutter cannot use it.
  exit /b 1
)

echo Found: %FOUND_DLL%

if not exist "%PROJECT_ROOT%\blobs" mkdir "%PROJECT_ROOT%\blobs"
copy /y "%FOUND_DLL%" "%PROJECT_ROOT%\blobs\libtensorflowlite_c-win.dll"
if errorlevel 1 exit /b 1

echo.
echo === Done ===
echo Copied to: %PROJECT_ROOT%\blobs\libtensorflowlite_c-win.dll
echo.
echo windows\CMakeLists.txt already bundles this file next to insight.exe.
echo Next: fully stop the app, then run "flutter run -d windows" from the
echo project root so the build picks it up.
echo.
echo The TensorFlow source and build tree in %WORKDIR% can be deleted now.
