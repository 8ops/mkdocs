# PAM

[Reference](https://clearsky.me/vaultwarden/)

```bash

Bitwarden


Vaultwarden

https://github.com/dani-garcia/vaultwarden
https://hub.docker.com/r/vaultwarden/server
https://github.com/dani-garcia/vaultwarden/wiki

https://bitwarden.com/download/

docker pull vaultwarden/server:latest
docker run -d --name vaultwarden -v ./vw-data/:/data/ --restart unless-stopped -p 8087:80 vaultwarden/server:latest

docker pull vaultwarden/server:1.32.7
docker run -d --name vaultwarden -v /vw-data/:/data/ -p 80:80 vaultwarden/server:latest

```

