{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    zls-overlay = {
      url = "github:zigtools/zls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig-overlay";
      };
    };
  };

  outputs =
    {
      nixpkgs,
      zig-overlay,
      zls-overlay,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        zig = zig-overlay.packages.${system}.master;
        zls = zls-overlay.packages.${system}.zls.overrideAttrs { nativeBuildInputs = [ zig ]; };
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            zig
            pkgs.opencl-headers
            pkgs.ocl-icd
            pkgs.spirv-tools
            pkgs.clinfo
            pkgs.stb
          ];
          packages = [ zls ];
        };
      }
    );
}
