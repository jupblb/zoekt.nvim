{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url     = "github:NixOS/nixpkgs/release-25.05";
  };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (import nixpkgs) { inherit system; };
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            lua-language-server pandoc pre-commit stylua universal-ctags zoekt
          ];

          NVIM_LAZYDEV = "${pkgs.vimPlugins.lazydev-nvim}";
          NVIM_TELESCOPE = "${pkgs.vimPlugins.telescope-nvim}";
        };
      }
    );
}
