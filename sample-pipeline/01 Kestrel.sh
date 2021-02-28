#!/bin/sh

# Clone repository
mkdir repos
cd repos
git clone https://github.com/examples-hfrances/HelloWorld.git
git clone https://github.com/examples-hfrances/HelloWebApplication.git

# Build dotnet
dotnet publish HelloWorld -c Release -o publish/HelloWorld
dotnet publish HelloWebApplication -c Release -o publish/HelloWebApplication

# Run projects
dotnet publish/HelloWorld/HelloWorld.dll run

# Create service folder
sudo mkdir --parents /var/www/dotnet/HelloWebApplication
# Copy bin to service folder
sudo cp -R ./publish/HelloWebApplication/* /var/www/dotnet/HelloWebApplication/

# Create service file
sudo bash -c 'cat > /usr/lib/systemd/system/helloWebApplication.dotnetapi.service' << EOF

[Unit]
Description=NET Web API App HelloWebApplication

[Service]
WorkingDirectory=/var/www/dotnet/HelloWebApplication/
ExecStart=/usr/bin/dotnet /var/www/dotnet/HelloWebApplication/HelloWebApplication.dll run --urls "http://localhost:5100"
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=dotnet-api
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5100

[Install]
WantedBy=multi-user.target
EOF

# Restart daemon when some ".service" file has been changed
sudo systemctl daemon-reload
# Start service on boot
sudo systemctl enable helloWebApplication.dotnetapi.service
# Start service
sudo systemctl start helloWebApplication.dotnetapi.service
# Get service status
sudo systemctl status helloWebApplication.dotnetapi.service --no-pager
# Wait some seconds
sleep 2
# Check that service is working
pwsh -command Invoke-WebRequest 'http://localhost:5100'