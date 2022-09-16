{ pkgs ? import <nixpkgs> {
    crossSystem = {
      config = "aarch64-unknown-linux-musl";
    };
  }}:

{
  combined = import img/imx8qxp/default.nix { inherit pkgs; };
}
