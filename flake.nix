{
  description = "SimpleRisk's Docker and related artifacts";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    gorinapp.url = "git+https://codeberg.org/wolfangaukang/gorin";
  };

  outputs = { nixpkgs, gorinapp, ... }:
    let
      overlays = [
        gorinapp.overlays.default
      ];
      forEachSystem = nixpkgs.lib.genAttrs (nixpkgs.lib.systems.flakeExposed);
      pkgsFor = forEachSystem (system: import nixpkgs { inherit overlays system; });

    in
    {
      devShells = forEachSystem (system:
        let
          pkgs = pkgsFor.${system};

        in {
          default = pkgs.mkShell { packages = (with pkgs; [ docker-compose dockle grype gorin ]); };
        });
      };
}
