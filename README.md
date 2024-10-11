# TVP 

This flake/repo is used to contain old packages that have been dropped.
Mainly for dev and build tools.

## Reason
Sometimes just using old packages doesn't work (e.g. Some old versions of ruby are inaccessible since there were change to flakes).
Or just overriding parameters is too difficult.
Or maybe they are difficult to find.
While nowadays you can create a nix flake and lock it so that the version will remain the same, trying to bring an old projects to a flake is difficult.
