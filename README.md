The canonical URL for the upstream Spectrum git repository is
<https://spectrum-os.org/git/spectrum/>.

To try Spectrum OS, you need to build it from source and then install it to an SD card.

> Cross-compiled version of Spectrum OS is for i.MX 8QXP board only.

## Building a Spectrum OS Image

Clone sources of spec and nix-spec (cross-compile branches for i.MX 8QXP):

	$ git clone -b aarch64-imx8-crosscompile https://github.com/tiiuae/nixpkgs-spectrum/
    $ git clone -b aarch64-imx8-crosscompile https://github.com/tiiuae/spectrum/

Set up the Spectrum binary cache.

* Change non-NixOS machine configuration.

	Note the following:

	- The custom binary cache is located here: <http://binarycache.vedenemo.dev>.
	- The public key of this cache is:
      `binarycache.vedenemo.dev:Yclq5TKpx2vK7WVugbdP0jpln0/dPHrbUYfsH3UXIps=`
    - Spectrum OS own binary cache is located here: <https://cache.dataaturservice.se/spectrum/>.
    - The public key of this cache is:
        `spectrum-os.org-1:rnnSumz3+Dbs5uewPlwZSTP0k3g/5SRG4hD7Wbr9YuQ=`

    All configurations are made in the `/etc/nix/nix.conf` file. It should be possible to carry everything to the NixOS configuration with little effort.

    To get custom binary caches in use, add them to the `substitutes` list inside the `nix.conf` file and then add their public keys to the `trusted-public-keys` list in the same file:

      substituters = http://binarycache.vedenemo.dev https://cache.dataaturservice.se/spectrum/ https://cache.nixos.org/
      trusted-public-keys = binarycache.vedenemo.dev:Yclq5TKpx2vK7WVugbdP0jpln0/dPHrbUYfsH3UXIps= spectrum-os.org-1:rnnSumz3+Dbs5uewPlwZSTP0k3g/5SRG4hD7Wbr9YuQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=

	> After every change in the Nix configuration, run `systemctl restart nix-daemon.service`. In this case, the binary cache will be used automatically when `nix-build` is run.

    If necessary, you can make Nix to use specific binary cache with the`--substituters` argument:

	  $ nix-build /nix/store/<derivation>.drv --substituters <binary cache address>

* Check if a package or derivation is in the binary cache:

	  $ curl <binary-cache-address>/<package-or-.drv-hashsum>.narinfo

To build the image, run:

	$ NIXPKGS_ALLOW_UNFREE=1 nix-build spectrum/img/imx8qxp/ -I nixpkgs=nixpkgs-spectrum

After you can use the image from the `./result` directory and flash it to an SD card.

## Installing Spectrum OS

Before installation:

* Prepare a 4 GB SD card.
* Make sure that the i.MX 8QXP board is configured to boot from an SD card.

To run Spectrum OS on i.MX 8QXP board, perform the following steps:

* Use the image from the previous step or download the prebuilt image _20220826-spectrum-live-imx8qxp-yuriy-custom.img_ from the page: <http://arm-kal.us.to:20080/>.

* Copy the downloaded image to your SD card to create bootable media:

	  $ sudo dd if=spectrum-live.img of=/dev/sdx bs=1M conv=fsync

	Change **sdx** to match the one used by the SD card.
