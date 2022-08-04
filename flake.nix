{
  description = "A POSIX-compatible shell written in Zig";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      devShells.x86_64-linux.default =
        pkgs.mkShell { buildInputs = [ pkgs.zig pkgs.zls ]; };
    };
}
