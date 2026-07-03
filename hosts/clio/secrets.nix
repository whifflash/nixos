_: {
  # Host-specific decryption key location. Secret declarations live with the
  # shared service modules that consume them.
  sops = {
    age.keyFile = "/root/.config/sops/age/keys.txt";
    validateSopsFiles = false;
  };
}
