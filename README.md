The canonical URL for the upstream Spectrum git repository is
<https://spectrum-os.org/git/spectrum/>. The official documentation is https://spectrum-os.org/doc/.

> :balloon: Currently, Wayland running on a guest VM is supported only for i.MX8QM board with SMMU.

---

## Getting Started

To try Spectrum, you can:
* [build it from the source](#build-and-run) or
* [use the prebuild image](#installing-spectrum).

Building Spectrum from the source can take a very long time. We recommend to [set up the Spectrum binary cache](#setting-up-binary-cache) before building to speed up the build process.


##### Build system

Make sure you have the [Nix package manager](https://nixos.org/download.html) installed. 

> :balloon: NixOS is not required for the building step. It is enough to have only Nix.

Linux was used for builds running. Building from other operating systems might work but was not tested.


## Setting Up Binary Cache

Set up the Spectrum binary cache so that Nix will download build outputs from the cache instead of building them locally. For more information, see the [Using a binary cache](https://nixos.wiki/wiki/Binary_Cache#Using_a_binary_cache) section of the NixOS Wiki.

* The custom binary cache is <http://cache.vedenemo.dev/>.
* The public key of this cache is:
`cache.vedenemo.dev:RGHheQnb6rXGK5v9gexJZ8iWTPX6OcSeS56YeXYzOcg="`

If you want to use the Spectrum binary cache, see the [Setting Up Binary Cache](https://spectrum-os.org/doc/binary-cache.html) section of the Spectrum Docs.

##### For NixOS
Add the following to your `/etc/nixos/configuration.nix` file:

``` 
  nix.settings.trusted-substituters = [
    "http://cache.vedenemo.dev"
  ];

  nix.settings.trusted-public-keys = [
    "cache.vedenemo.dev:RGHheQnb6rXGK5v9gexJZ8iWTPX6OcSeS56YeXYzOcg="
  ];
```

To apply changes, rebuild your system with the [nixos-rebuild](https://nixos.wiki/wiki/Nixos-rebuild) command.

See the [trusted-substitutors](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-trusted-substituters)
	configuration option for further details.

##### For Non-NixOS

Change non-NixOS machine configuration. All configurations are made in the `/etc/nix/nix.conf` file.

To get custom binary caches in use, add it to the `substitutes` list inside the `nix.conf` file and then add its public key to the `trusted-public-keys` list in the same file:

      trusted-substituters = http://cache.vedenemo.dev
      trusted-public-keys = cache.vedenemo.dev:RGHheQnb6rXGK5v9gexJZ8iWTPX6OcSeS56YeXYzOcg=

> :balloon: After every change in the Nix configuration, run `systemctl restart nix-daemon.service`. In this case, the binary cache will be used automatically when `nix-build` is run.

If necessary, you can make Nix to use specific binary cache with the`--substituters` argument:

	$ nix-build /nix/store/<derivation>.drv --substituters <binary cache address>

Check if a package or derivation is in the binary cache:

	$ curl <binary-cache-address>/<package-or-.drv-hashsum>.narinfo


## Building Spectrum Image

> :balloon: Make sure the [Spectrum binary cache](#setting-up-binary-cache) is set up to save you time waiting for builds.

To build Spectrum for i.MX 8QM board, you need three repositories:

* [Spectrum source code](https://github.com/tiiuae/spectrum/tree/wayland);
* [Nixpkgs](https://github.com/tiiuae/nixpkgs-spectrum/tree/wayland) as Spectrum is built with Nix;
* [Configuration layer](https://github.com/tiiuae/spectrum-config-imx8) to configure Spectrum build with an external configuration layer.

Clone these repositories:

    $ git clone -b wayland https://github.com/tiiuae/spectrum.git
    $ git clone -b wayland https://github.com/tiiuae/nixpkgs-spectrum.git
    $ git clone https://github.com/tiiuae/spectrum-config-imx8

For known issues on the configuration layer, see this [README](https://github.com/tiiuae/spectrum-config-imx8/blob/main/README.md) file.

To build the image utilizing binary-cache and configuration layer, run:

	$ NIXPKGS_ALLOW_UNFREE=1 nix-build spectrum-config-imx8/imx8qm/ -I nixpkgs=nixpkgs-spectrum/ -I spectrum-config=spectrum-config-imx8/config.nix

After you can use the image from the `./result` directory and flash it to an SD card.


## Installing Spectrum

Before installation:

* Prepare a 4 GB SD card.
* Make sure that the i.MX 8QM board is configured to boot from an SD card.

To run Spectrum on i.MX 8QM board:

* Use the image from the previous step or download the latest version of the prebuilt image with "imx8qm" in the file name from here: https://vedenemo.dev/files/images/.
* Copy the downloaded image to your SD card to create bootable media. Change **"your media device"** to match the one used by the SD card.

	  $ sudo dd if=<spectrum image> of=/dev/<your media device> status=progress conv=fsync bs=1M

	There are several Linux commands that you can use to get information details about mounted devices. In the most common case, the easiest way to find your device's name is to use the [lsblk](https://man7.org/linux/man-pages/man8/lsblk.8.html) command twice: before plugging an SD card and then after.
    
    Check the device from kernel logs after inserting the SD card to your computer. Using the wrong device can make your computer not boot.