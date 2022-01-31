# Getting Started with Power-Multipass

Get ready your Ubuntu VM with dotnet based api and react front in 6 minutes.

## Install Multipass
https://multipass.run/

## Install module

- Open an **elevated PowerShell** prompt window.

- Run the following command to add nuget.org feed:

```powershell
Register-PSRepository -Name "NuGet" -SourceLocation "https://api.nuget.org/v3/index.json";
```
***Warning: In some versions of PowerShell, you must start a new session after you run the Register-PSRepository cmdlet to avoid the Unable to resolve package source warning.***

- To confirm that the repository was registered successfully run the Get-PSRepository cmdlet. This command gets all module repositories registered for the current user:
```powershell
Get-PSRepository
```

- Find modules in our repository:
```powershell
Find-Module -Name "Power-Multipass" -Repository "NuGet"
```

- To install it, run the following command:
```powershell
Install-Module -Name "Power-Multipass" -Repository "NuGet"
```

- You can check for your module by running the following command:
```powershell
Get-Module -ListAvailable "Power-Multipass"
```
## Available Scripts

In the project directory, you can run:

```powershell
New-PSInstance [name] -pipeline-dir [pipeline] -cloud-init [yaml-file]
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
New-PMInstance 'foo' -pipeline-dir '.\sample-pipeline\' -cloud-init '.\cloud-config.yaml' -network "name='External Switch',mac='58:54:A0:59:37:8F'" -memory 4G -cpus 2
```
