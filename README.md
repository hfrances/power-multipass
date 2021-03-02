# Getting Started with Power-Multipass

Get ready your Ubuntu VM with dotnet based api and react front in 6 minutes.

## Install Multipass
https://multipass.run/

## Available Scripts

In the project directory, you can run:

```powershell
PS > .\power-multipass.ps1 [name] -pipeline-dir [pipeline] -cloud-init [yaml-file]
```
**Script steps:**

Deletes `[name]` instance machine if already exists. Otherwise it returns an error.

Creates a new instance with the specified `[name]` using setup specified in the `[yaml-file]`.

Copies content of `[pipeline]` folder into the machine, in `~/pipeline` directory.

Runs scripts (files with `.sh` extension).
**Include `-skip-sh` argument for not run `.sh` files.**

Updates hosts files taking information from the machine hosts (***only for windows for the moment***).

**Example:**
```powershell
PS > .\power-multipass.ps1 'foo' -pipeline-dir 'sample-pipeline' -cloud-init 'cloud-config.yaml'
```
