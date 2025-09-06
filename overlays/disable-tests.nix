_: super: {
  tailscale = super.tailscale.overrideAttrs (_: {doCheck = false;});
}
