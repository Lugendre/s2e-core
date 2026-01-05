{
  description = "S2E: Spacecraft Simulation Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system} = {
        # External libraries (cspice, nrlmsise00, generic_kernels)
        s2e-extlibs = pkgs.callPackage ./nix/s2e-extlibs.nix { };

        # S2E simulation binary
        default = pkgs.callPackage ./nix/s2e.nix {
          s2e-extlibs = self.packages.${system}.s2e-extlibs;
        };
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/s2e";
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Build tools
          cmake
          gnumake
          gcc

          # Fetch dependencies
          git
          curl

          # Plotting tools
          gnuplot
          python3
          pipenv
          yq-go  # yq for gen_graph.sh
        ];

        shellHook = ''
          echo "S2E Development Environment"
          echo "================================"
          echo "Build 64-bit: cmake -DBUILD_64BIT=ON ..."
          echo ""
          echo "Quick start:"
          echo "  cd ExtLibraries && cmake . -DEXT_LIB_DIR=\$(pwd) -DBUILD_64BIT=ON && cmake --build . && cmake --install ."
          echo "  cd ../example && cmake . -DEXT_LIB_DIR=../ExtLibraries -DBUILD_64BIT=ON && cmake --build ."
        '';
      };
    };
}
