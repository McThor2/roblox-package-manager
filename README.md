
# <img src=https://tr.rbxcdn.com/1941e3ed5e94e8dd0bbc17f84af893e1/420/420/Decal/Png width=40 height=40> Roblox Package Manager

## [Roblox Marketplace](https://create.roblox.com/marketplace/asset/12442691141/Roblox-Package-Manager)

## Let's talk about packages

The idea of packages / modules / libraries is to reuse and share code, right? Currently I find this process quite cumbersome, particularly when trying to use tools / plugins within Roblox Studio only. However, if you do some digging you are likely to come across [Wally](https://github.com/UpliftGames/wally).

For those who don't know, Wally is a package index & package management tool that is primarily used for a Rojo style workflow (i.e. using a separate editor such as VSCode and syncing changes into studio). There's a growing number of packages becoming available via Wally, such as . Naturally there is a barrier to using Wally if you stick solely to using Studio.

Enter the RPM plugin. This allows you to search the full Wally package index from studio, and to download specific packages into studio directly.

## Installation

You can install the plugin straight from the creator [marketplace](https://create.roblox.com/marketplace/asset/12442691141/Roblox-Package-Manager).

Alternatively you can clone the repo, build the plugin using `rojo build` and move to your local plugins folder.

### Windows + PowerShell

For quickly building and re-installing the plugin locally this command has proved useful:

```powershell
rojo build --output dist/RPM.rbxmx; copy -Force .\dist\RPM.rbxmx $ENV:LOCALAPPDATA\Roblox\Plugins\
```

Note: ***this will overwrite the existing plugin in your local plugins folder***.

## Usage

There are currently two menus that exist. One headed with "Download", the other with "Search Wally".

If you know what package you want then you can use the download menu by simply entering the package in `<scope>/<name>@<version>` format e.g. `evaera/promise@4.0.0` . When you click download, the package will be downloaded and installed into the `PackageLocation` in the config (currently set to the default of `ReplicatedStorage/Packages`).

The search menu is for finding specific packages on the Wally index. You can enter any search term and see results (if there are any). Each result is seperated by `scope/name` and each result can be clicked to reveal the available versions of that package. A typical use case is searching by a creator / scope and seeing what packages they have.

## Existing work

In order to create the most useful tool possible it is important to understand the existing infrastrucure & standards that are being used.

- [StudioCLI](https://devforum.roblox.com/t/v140-introducing-studiocli-terminal-built-in-git-package-manager/1441569) provides a package manager that allows you to install from the Roblox market place either by name using it's own package index or via asset id. This is all done through a command line that the plugin provides.

- [Why you should use Wally](https://devforum.roblox.com/t/why-you-should-use-wally-a-package-manager-for-roblox/1977617)

- [Rojo](https://github.com/rojo-rbx/rojo) &  [rbx-dom](https://github.com/rojo-rbx/rbx-dom) provide a widely used standard for converting between a standard file system layout and Roblox instances.

There have been some other attempts at creating a plugin of a similar nature before. There doesn't seem to be much current activity for them now.

- [Roarn](https://devforum.roblox.com/t/roarn-102-a-roblox-package-manager-for-an-organized-workspace/1560554)

- [Existing RPM](https://devforum.roblox.com/t/rpm-roblox-package-manager/1482114)

## Roadmap

- Install from local zip file (e.g. from a downloaded source .zip file from github)

- Resolving dependencies

- Updating currently installed packages / inform if an update is available

- Uploading packages to Wally from Studio

- Developing a standard dependency import style

- Authentication checks for package installs (checksum/hash/public-private key etc.)
