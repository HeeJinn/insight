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

set VCVARSALL="C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvarsall.bat"
set CMAKE_EXE="C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set WORKDIR=%~dp0tflite_native_build
set PROJECT_ROOT=%~dp0..

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

echo === Loading MSVC x64 build environment ===
call %VCVARSALL% x64
if errorlevel 1 exit /b 1

if not exist "%WORKDIR%" mkdir "%WORKDIR%"
cd /d "%WORKDIR%"

if not exist "%WORKDIR%\tensorflow_src" (
  echo === Cloning TensorFlow source (shallow clone, this is still a large download) ===
  git clone --depth 1 https://github.com/tensorflow/tensorflow.git tensorflow_src
  if errorlevel 1 exit /b 1
) else (
  echo === TensorFlow source already present, skipping clone ===
)

echo === Reading TensorFlow version ===
REM tf_version.bzl has a line like: TF_VERSION = "2.20.0"
set RAW_VERSION_LINE=
for /f "tokens=2 delims==" %%v in ('findstr /r "^TF_VERSION" "%WORKDIR%\tensorflow_src\tensorflow\tf_version.bzl"') do set RAW_VERSION_LINE=%%v
set RAW_VERSION_LINE=%RAW_VERSION_LINE:"=%
set RAW_VERSION_LINE=%RAW_VERSION_LINE: =%

if "%RAW_VERSION_LINE%"=="" (
  echo Could not find TF_VERSION in tensorflow\tf_version.bzl -- the file
  echo format may have changed. Open that file, find the version string, and
  echo set TF_MAJOR/TF_MINOR/TF_PATCH below manually, then re-run.
  exit /b 1
)

REM Strip any "-suffix" (e.g. "-rc0") before splitting into major.minor.patch
for /f "tokens=1 delims=-" %%v in ("%RAW_VERSION_LINE%") do set RAW_VERSION_LINE=%%v

for /f "tokens=1,2,3 delims=." %%a in ("%RAW_VERSION_LINE%") do (
  set TF_MAJOR=%%a
  set TF_MINOR=%%b
  set TF_PATCH=%%c
)
echo Detected TensorFlow version %TF_MAJOR%.%TF_MINOR%.%TF_PATCH%

if not exist "%WORKDIR%\tflite_build" mkdir "%WORKDIR%\tflite_build"
cd /d "%WORKDIR%\tflite_build"

echo === Configuring CMake for the TFLite C API ===
%CMAKE_EXE% -DCMAKE_C_FLAGS="-DTF_MAJOR_VERSION=%TF_MAJOR% -DTF_MINOR_VERSION=%TF_MINOR% -DTF_PATCH_VERSION=%TF_PATCH% -DTF_VERSION_SUFFIX=\"\"" -DCMAKE_CXX_FLAGS="-DTF_MAJOR_VERSION=%TF_MAJOR% -DTF_MINOR_VERSION=%TF_MINOR% -DTF_PATCH_VERSION=%TF_PATCH% -DTF_VERSION_SUFFIX=\"\"" "%WORKDIR%\tensorflow_src\tensorflow\lite\c"
if errorlevel 1 exit /b 1

echo === Building (this is the slow part) ===
%CMAKE_EXE% --build . -j
if errorlevel 1 exit /b 1

echo === Locating the built DLL ===
set FOUND_DLL=
for /r "%WORKDIR%\tflite_build" %%f in (tensorflowlite_c.dll) do (
  if exist "%%f" set FOUND_DLL=%%f
)

if "%FOUND_DLL%"=="" (
  echo Could not find tensorflowlite_c.dll under %WORKDIR%\tflite_build
  echo Check the build output above for errors.
  exit /b 1
)

echo Found: %FOUND_DLL%

if not exist "%PROJECT_ROOT%\blobs" mkdir "%PROJECT_ROOT%\blobs"
copy /y "%FOUND_DLL%" "%PROJECT_ROOT%\blobs\libtensorflowlite_c-win.dll"

echo.
echo === Done ===
echo Copied to: %PROJECT_ROOT%\blobs\libtensorflowlite_c-win.dll
echo.
echo windows\CMakeLists.txt has already been updated to bundle this file.
echo Next: run "flutter clean" then "flutter run -d windows" from the project
echo root so the build picks it up.
