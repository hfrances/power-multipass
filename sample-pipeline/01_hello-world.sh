#/bin/sh

# Create repos folder.
[[ ! -d ~/repos ]] && mkdir ~/repos
cd ~/repos

# Clone repository
git clone https://github.com/examples-hfrances/HelloWorld.git

# Build dotnet
set DOTNET_CLI_TELEMETRY_OPTOUT=1
dotnet publish HelloWorld -c Release -o publish/HelloWorld

# Run projects
dotnet publish/HelloWorld/HelloWorld.dll run

