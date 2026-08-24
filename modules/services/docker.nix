{ ... }:

{
  virtualisation.docker = {
    enable = true;
    # Reclaim space by pruning dangling images/containers weekly
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
