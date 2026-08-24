let
  maru = "age1y7w2kna2hvwrznk2q4km96vcurcvmcgm0rx2ez0ca7lpwp9tzfkqm05rc6";
in
{
  "maru-password.age".publicKeys = [ maru ];
  "ssh-id-ed25519.age".publicKeys = [ maru ];
}
