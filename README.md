The canonical URL for the upstream Spectrum git repository is
<https://spectrum-os.org/git/spectrum/>.

Currently, the cross-compiled version of Spectrum is for i.MX 8QXP board only.

---

## Planning and Preparation

To try Spectrum, you can:
* [build it from the source](#build-and-run) or
* [use the prebuild image](#installing-spectrum).


Building Spectrum from the source can take a very long time. We recommend to [set up the Spectrum binary cache](#setting-up-binary-cache) before building to speed up the build process.

Also, make sure you have the [Nix package manager](https://nixos.org/download.html) installed, and the hardware that you plan to use supports the virtualization.



## Setting Up Binary Cache

Set up the Spectrum binary cache so that Nix will download build outputs from the cache instead of building them locally. For more information, see the [Using a binary cache](https://nixos.wiki/wiki/Binary_Cache#Using_a_binary_cache) section of the NixOS Wiki.

The custom binary cache is <http://binarycache.vedenemo.dev>.

The public key of this cache is:
`binarycache.vedenemo.dev:Yclq5TKpx2vK7WVugbdP0jpln0/dPHrbUYfsH3UXIps=`

For information on the Spectrum binary cache, see the [Setting Up Binary Cache](https://spectrum-os.org/doc/binary-cache.html) section of the Spectrum Docs.

##### For NixOS
Add the following to your `/etc/nixos/configuration.nix` file:

``` 
  nix.settings.trusted-substituters = [
    "http://binarycache.vedenemo.dev"
  ];

  nix.settings.trusted-public-keys = [
    "binarycache.vedenemo.dev:Yclq5TKpx2vK7WVugbdP0jpln0/dPHrbUYfsH3UXIps="
  ];
```

To apply changes, rebuild your system with the [nixos-rebuild](https://nixos.wiki/wiki/Nixos-rebuild) command.

See the [trusted-substitutors](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-trusted-substituters)
	configuration option for further details.

##### For Non-NixOS

Change non-NixOS machine configuration. All configurations are made in the `/etc/nix/nix.conf` file.

To get custom binary caches in use, add it to the `substitutes` list inside the `nix.conf` file and then add its public key to the `trusted-public-keys` list in the same file:

      trusted-substituters = http://binarycache.vedenemo.dev
      trusted-public-keys = binarycache.vedenemo.dev:Yclq5TKpx2vK7WVugbdP0jpln0/dPHrbUYfsH3UXIps=

> :balloon: After every change in the Nix configuration, run `systemctl restart nix-daemon.service`. In this case, the binary cache will be used automatically when `nix-build` is run.

If necessary, you can make Nix to use specific binary cache with the`--substituters` argument:

	$ nix-build /nix/store/<derivation>.drv --substituters <binary cache address>

Check if a package or derivation is in the binary cache:

	$ curl <binary-cache-address>/<package-or-.drv-hashsum>.narinfo


## Building Spectrum Image

> :balloon: Make sure the [Spectrum binary cache](#setting-up-binary-cache) is set up to save you time waiting for builds.

Clone sources of spec and nix-spec (cross-compile branches for i.MX 8QXP):

	$ git clone -b aarch64-imx8-crosscompile https://github.com/tiiuae/nixpkgs-spectrum/
	$ git clone -b aarch64-imx8-crosscompile https://github.com/tiiuae/spectrum/

To build the image utilizing binary-cache, run:

	$ NIXPKGS_ALLOW_UNFREE=1 nix-build spectrum/img/imx8qm/ -I nixpkgs=nixpkgs-spectrum --option substituters http://binarycache.vedenemo.dev

To build the image from source (slower complete build), run:

	$ NIXPKGS_ALLOW_UNFREE=1 nix-build spectrum/img/imx8qxp/ -I nixpkgs=nixpkgs-spectrum

After you can use the image from the `./result` directory and flash it to an SD card.


## Installing Spectrum

Before installation:

* Prepare a 4 GB SD card.
* Make sure that the i.MX 8QXP board is configured to boot from an SD card.

To run Spectrum on i.MX 8QXP board:

* Use the image from the previous step or download the latest version of the prebuilt image with "imx8qxp" in the file name from here: https://vedenemo.dev/files/images/.
* Copy the downloaded image to your SD card to create bootable media. Change **sdx** to match the one used by the SD card.

	  $ sudo dd if=spectrum-live.img of=/dev/sdx bs=1M conv=fsync

	There are several Linux commands that you can use to get information details about mounted devices. In the most common case, the easiest way to find your device's name is to use the [lsblk](https://man7.org/linux/man-pages/man8/lsblk.8.html) command twice: before plugging an SD card and then after.
    
    Check the device from kernel logs after inserting the SD card to your computer. Using the wrong device can make your computer not boot.