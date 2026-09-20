# Host-specific test disables for packages built from this repo's nixpkgs
# pin. Darwin test fixes for the lab stack (manifold under hardened libc++)
# live in nix-labs' overlays.default — applied to every host below — so the
# standalone `labs#<env>` shells get them too, from the same definition.
_: super: {
  tailscale = super.tailscale.overrideAttrs (_: {
    doCheck = false;
  });
}
