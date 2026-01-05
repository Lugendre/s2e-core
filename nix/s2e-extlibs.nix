{ lib
, stdenv
, fetchurl
, fetchgit
, cmake
, ncompress
}:

stdenv.mkDerivation rec {
  pname = "s2e-extlibs";
  version = "1.0.0";

  # No source directory - we're assembling from fetched components
  dontUnpack = true;
  dontConfigure = true;

  nativeBuildInputs = [ cmake ncompress ];

  # Download cspice (64-bit Linux)
  cspice = fetchurl {
    url = "https://naif.jpl.nasa.gov/pub/naif/toolkit/C/PC_Linux_GCC_64bit/packages/cspice.tar.Z";
    sha256 = "60a95b51a6472f1afe7e40d77ebdee43c12bb5b8823676ccc74692ddfede06ce";
  };

  # Download generic SPICE kernels
  kernel_lsk = fetchurl {
    url = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/a_old_versions/naif0010.tls";
    sha256 = "a3826c1f418a9601afdf92be815298aedfd7960b5c00f3a5c469df674e1436b4";
  };

  kernel_pck1 = fetchurl {
    url = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/de-403-masses.tpc";
    sha256 = "5cd68fcd3f59ddc21ed8bbad3a341126b8e092a29ac8f0ae585db718af8e7468";
  };

  kernel_pck2 = fetchurl {
    url = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/gm_de431.tpc";
    sha256 = "15756c162151853f329d473fa00c38d35e62d83c3e25ddceece6516bbd98738b";
  };

  kernel_pck3 = fetchurl {
    url = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00010.tpc";
    sha256 = "59468328349aa730d18bf1f8d7e86efe6e40b75dfb921908f99321b3a7a701d2";
  };

  kernel_spk = fetchurl {
    url = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de430.bsp";
    sha256 = "6e1b277c5f07135a84950604b83e56b736be696a7f3560bcddb1d4aeb944fca1";
  };

  # Fetch nrlmsise00 source
  nrlmsise00_src = fetchgit {
    url = "https://git.linta.de/~brodo/nrlmsise-00.git";
    rev = "bc9a2feba4344e74201281e563332688a4d09cc3";
    hash = "sha256-xfiTwO5Puq7itxHHGck7UvwviJHUGn1jmZdGHJ/lbCI=";
  };

  # Space weather data (for NRLMSISE-00 atmospheric model)
  space_weather = fetchurl {
    url = "https://ftp.agi.com/pub/DynamicEarthData/SpaceWeather-v1.2.txt";
    sha256 = "1wa6srcisfa801a5q41lva2riq8l5qy7ic6yfl9cp5wvm630fz80";
  };

  buildPhase = ''
    runHook preBuild

    # Extract cspice
    mkdir -p cspice_build
    cd cspice_build
    uncompress < ${cspice} | tar xf -
    cd ..

    # Build nrlmsise00
    mkdir -p nrlmsise00_build
    cd nrlmsise00_build

    # Create a simple CMakeLists.txt for nrlmsise00
    cat > CMakeLists.txt << 'EOF'
    cmake_minimum_required(VERSION 3.18)
    project(nrlmsise00 C)

    add_library(nrlmsise00 STATIC
      ''${CMAKE_SOURCE_DIR}/nrlmsise-00.c
      ''${CMAKE_SOURCE_DIR}/nrlmsise-00_data.c
    )

    install(TARGETS nrlmsise00
      ARCHIVE DESTINATION lib64
    )

    install(FILES
      ''${CMAKE_SOURCE_DIR}/nrlmsise-00.h
      ''${CMAKE_SOURCE_DIR}/nrlmsise-00.c
      ''${CMAKE_SOURCE_DIR}/nrlmsise-00_data.c
      DESTINATION src
    )
EOF

    # Copy nrlmsise00 sources
    cp -r ${nrlmsise00_src}/* .

    cmake . -DCMAKE_INSTALL_PREFIX=$out/nrlmsise00
    cmake --build .
    cmake --install .

    cd ..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/cspice/cspice_unix64/lib
    mkdir -p $out/cspice/include
    mkdir -p $out/cspice/generic_kernels/lsk
    mkdir -p $out/cspice/generic_kernels/pck
    mkdir -p $out/cspice/generic_kernels/spk/planets

    # Install cspice
    cp -r cspice_build/cspice/lib/* $out/cspice/cspice_unix64/lib/
    cp -r cspice_build/cspice/include/* $out/cspice/include/

    # Install generic kernels
    cp ${kernel_lsk} $out/cspice/generic_kernels/lsk/naif0010.tls
    cp ${kernel_pck1} $out/cspice/generic_kernels/pck/de-403-masses.tpc
    cp ${kernel_pck2} $out/cspice/generic_kernels/pck/gm_de431.tpc
    cp ${kernel_pck3} $out/cspice/generic_kernels/pck/pck00010.tpc
    cp ${kernel_spk} $out/cspice/generic_kernels/spk/planets/de430.bsp

    # nrlmsise00 is already installed to $out/nrlmsise00

    # Install space weather file
    mkdir -p $out/space_weather
    cp ${space_weather} $out/space_weather/SpaceWeather-v1.2.txt

    runHook postInstall
  '';

  meta = with lib; {
    description = "External libraries for S2E (cspice, nrlmsise00, SPICE kernels)";
    platforms = platforms.linux;
  };
}
