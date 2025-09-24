{
  config,
  pkgs,
  ...
}: {
  system.activationScripts.ensureCLT.text = ''
    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
      echo "Command Line Tools not found — trying softwareupdate…"
      # Try non-interactive install via softwareupdate (preferred)
      LABEL=$(/usr/sbin/softwareupdate -l 2>/dev/null | \
        awk -F'* ' '/Command Line Tools/ {print $2}' | sed 's/^Label: //' | tail -n1)
      if [ -n "$LABEL" ]; then
        echo "Installing: $LABEL"
        /usr/sbin/softwareupdate -i "$LABEL" || true
      else
        echo "Falling back to GUI prompt…"
        /usr/bin/xcode-select --install || true
      fi
      echo "If CLT were installed just now, re-run the switch once it completes."
    fi
  '';
}
