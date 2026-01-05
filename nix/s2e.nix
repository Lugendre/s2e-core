{ lib
, stdenv
, cmake
, s2e-extlibs
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "s2e";
  version = "8.0.0";

  # Use the s2e-core source
  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      let
        baseName = baseNameOf path;
      in
        # Include source files and necessary directories
        (type == "directory") ||
        (lib.hasSuffix ".cpp" path) ||
        (lib.hasSuffix ".hpp" path) ||
        (lib.hasSuffix ".h" path) ||
        (lib.hasSuffix ".c" path) ||
        (lib.hasSuffix ".cmake" path) ||
        (baseName == "CMakeLists.txt") ||
        (baseName == "common.cmake") ||
        # Include settings directory
        (lib.hasInfix "/settings/" path) ||
        (lib.hasSuffix ".ini" path) ||
        # Include ExtLibraries/inih
        (lib.hasInfix "/ExtLibraries/inih/" path) ||
        # Include src directory structure
        (lib.hasInfix "/src/" path);
  };

  nativeBuildInputs = [ cmake makeWrapper ];

  # Configure to build from example directory
  preConfigure = ''
    cd example
  '';

  cmakeFlags = [
    "-DBUILD_64BIT=ON"
    "-DEXT_LIB_DIR=${s2e-extlibs}"
    # Core directory points to parent
    "-DS2E_CORE_DIR=.."
    # Use relative path for settings (will be in CWD at runtime)
    "-DSETTINGS_DIR_FROM_EXE=./settings"
    # Extlibs accessible from executable
    "-DEXT_LIB_DIR_FROM_EXE=${s2e-extlibs}"
    # Core directory (for tests, not used at runtime)
    "-DCORE_DIR_FROM_EXE=${placeholder "out"}/share/s2e/core"
  ];

  installPhase = ''
    runHook preInstall

    # We're in the build directory (should be under example/)
    # Install the S2E binary
    mkdir -p $out/bin
    install -m755 S2E $out/bin/.s2e-wrapped

    # Install default settings - copy from original source
    mkdir -p $out/share/s2e
    cp -r $src/example/settings $out/share/s2e/default-settings

    # Make settings writable before patching
    chmod -R u+w $out/share/s2e/default-settings

    # Apply log path patch to copied settings
    find $out/share/s2e/default-settings -name "*.ini" -type f -exec sed -i 's|log_file_save_directory = \.\./logs/|log_file_save_directory = ./logs/|g' {} \;

    # Copy external library data files into default settings
    # CSPICE generic kernels
    mkdir -p $out/share/s2e/default-settings/environment/cspice
    cp -r ${s2e-extlibs}/cspice/generic_kernels $out/share/s2e/default-settings/environment/cspice/

    # Space weather data
    mkdir -p $out/share/s2e/default-settings/environment/space_weather
    cp ${s2e-extlibs}/space_weather/SpaceWeather-v1.2.txt $out/share/s2e/default-settings/environment/space_weather/

    # Create s2e-init wrapper script (settings initialization)
    cat > $out/bin/s2e-init << 'EOF'
#!/usr/bin/env bash
set -e

DEFAULT_SETTINGS="@out@/share/s2e/default-settings"

if [ -d "./settings" ]; then
  echo "Settings directory already exists at: ./settings"
  echo "Remove it first if you want to reinitialize."
  exit 1
fi

echo "Initializing S2E settings directory..."
cp -r "$DEFAULT_SETTINGS" ./settings
chmod -R u+w ./settings
mkdir -p ./logs
echo "Settings directory created at: ./settings"
echo "Logs directory created at: ./logs"
echo "You can now edit configuration files in ./settings/"
EOF

    # Create s2e wrapper script (simulation execution)
    cat > $out/bin/s2e << 'EOF'
#!/usr/bin/env bash
set -e

if [ ! -d "./settings" ]; then
  echo "Error: ./settings directory not found."
  echo "Run 'nix run .#init' first to initialize settings."
  exit 1
fi

mkdir -p ./logs
exec @out@/bin/.s2e-wrapped "$@"
EOF

    chmod +x $out/bin/s2e-init
    chmod +x $out/bin/s2e

    # Substitute @out@ placeholders
    substituteInPlace $out/bin/s2e-init --replace '@out@' "$out"
    substituteInPlace $out/bin/s2e --replace '@out@' "$out"

    runHook postInstall
  '';

  meta = with lib; {
    description = "S2E: Spacecraft Simulation Environment";
    longDescription = ''
      S2E is a spacecraft simulation environment for testing and validation
      of satellite attitude and orbit control systems.
    '';
    homepage = "https://github.com/ut-issl/s2e-core";
    platforms = platforms.linux;
    mainProgram = "s2e";
  };
}
