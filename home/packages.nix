{ config, pkgs, ... }:
let
in
{

  home.packages = [
  pkgs.whitesur-gtk-theme
  pkgs.whitesur-cursors
  pkgs.whitesur-icon-theme
  pkgs.age

  # gnupg


  # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })
  (pkgs.writeShellScriptBin "notification-audio" ''
fd='/tmp/notid'
if [ ! -f /tmp/notid ]; then
  notify-send -t 5000 -p $1 > $fd
else
  oldid=$(head -n 1 $fd)
  echo $oldid
  notify-send -r $oldid -t 5000 -p $1 > $fd
fi
  '')
  ];

}