#!/bin/sh
# --fast avoids trying to build nixos-rebuild for the target platform
nixos-rebuild switch \
	--target-host root@c-nixos.testrun.org \
	--build-host root@c-nixos.testrun.org \
	--fast \
	--flake .#c-nixos
