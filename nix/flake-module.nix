{ self, ... }:
{
  perSystem = { system, ... }: {
    packages.gerrit-autosubmit = self.packages.${system}.default;
  };
}
