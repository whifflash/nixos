{ config, pkgs, ... }:
let
	# work = builtins.fromJSON (builtins.readFile config.sops.secrets.work.path);
	workUser = "TODO";
	workHosts = [ "todo.net"
       "192.168.1.*"
    ];

in
{
  programs.git = {
    enable = true;
    userName = builtins.readFile config.sops.secrets.git.userName.path;
    userEmail = "34140499+whifflash@users.noreply.github.com";
  };

      #   [includeIf "hasconfig:remote.*.url:git@*.${builtins.readFile "${work_stuff}/internal_domain"}:*/*"]
      #   path = ~/.gitconfig-work
      # [includeIf "hasconfig:remote.*.url:ssh://git@*.${work_stuff.internal_domain}/*/*"]
      #   path = ~/.gitconfig-work
      # [includeIf "hasconfig:remote.*.url:https://*.${work_stuff.internal_domain}/*/*"]
      #   path = ~/.gitconfig-work

        home.file = {
    ".gitconfig".text = ''
      [include]
        path = ~/.gitconfig-public

      [includeIf "gitdir:~/repos/work/"]
        path = ~/.gitconfig-work
      # TODO Add Sops config here
      [includeIf "gitdir:~/repos/public/"]
        path = ~/.gitconfig-public
      [includeIf "hasconfig:remote.*.url:git@github.com:*/*"]
        path = ~/.gitconfig-public
      [includeIf "hasconfig:remote.*.url:ssh://git@github.com/*/*"]
        path = ~/.gitconfig-public
      [includeIf "hasconfig:remote.*.url:https://github.com/*/*"]
        path = ~/.gitconfig-public

      [alias]
        # Useful when you have to update your last commit
        # with staged files without editing the commit message.
        oops = commit --amend --no-edit
        lg = log --color --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)'

      [init]
        defaultBranch = main

      [core]
        editor = nvim
      # pager = delta

      #[interactive]
      #  diffFilter = delta

      #[delta]
      #  navigate = true
      #  dark = true
      #  color-only = true
      #  diff-so-fancy = true
      #  line-numbers = true

      #[diff]
        # Use better, descriptive initials (c, i, w) instead of a/b.
     #  mnemonicPrefix = true
        # Show renames/moves as such
     #  renames = true
        # When using --word-diff, assume --word-diff-regex=.
     #  wordRegex = .
        # Display submodule-related information (commit listings)
     #  submodule = log
     #  tool = vscode

      #[difftool "vscode"]
      # cmd = code --wait --diff $LOCAL $REMOTE

      #[merge]
      # tool = vscode

      #[mergetool "vscode"]
      # cmd = code --wait $MERGED

      [color]
        ui = true
      [filter "lfs"]
        clean = git-lfs clean -- %f
        smudge = git-lfs smudge -- %f
        process = git-lfs filter-process
        required = true
    '';

    ".gitconfig-personal".text = ''
      [user]
        name = mhr
        email = 34140499+whifflash@users.noreply.github.com
    '';

    ".gitconfig-public".text = ''
      [user]
        name = whifflash
        email = 34140499+whifflash@users.noreply.github.com
    '';
  };


}
