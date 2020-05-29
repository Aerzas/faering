# Færing

Færing is a minimalist local docker setup based on Traefik and Dnsmasq. It doesn't do anything magically and doesn't
obfuscate docker core mechanisms, its intent is to provide a set of comprehensive configurations to start developing
efficiently with docker locally.

Features:
- Containers can be accessed in HTTP or HTTPS via a dedicated domain instead of an IP and a port
- Containers are load-balanced in swarm mode
- Containers can be inspected via a GUI ([http://portainer.docker.test](http://portainer.docker.test) by default)

**Færing is still under development but is already usable in the current state. We are looking for feedbacks!**

- [Setup](#setup)
    - [Requirements](#requirements)
    - [Automated installation](#automated-installation)
    - [Manual installation](#manual-installation)
    - [Configuration](#configuration)
- [Resources](#resources)

## Setup

### Requirements

- [Docker engine](https://docs.docker.com/engine/install/)
- [Docker compose](https://docs.docker.com/compose/install/)
- [Homebrew](https://brew.sh/) (MacOS only)

### Automated installation

Automated installation supports those platforms at the moment: Arch Linux, Debian, MacOS and their derivatives.

Note that some browser will not use the system keystore and will require certificates manual installation. Started
browsers need to be restarted after the installation process to take into account the new certificate.

**Via cURL**

```sh
sh -c "$(curl -fsSL https://framagit.org/faering/faering/-/raw/master/scripts/install.sh)"
```

**Via wget**

```sh
sh -c "$(wget -O- https://framagit.org/faering/faering/-/raw/master/scripts/install.sh)"
```

**Manual inspection**

It is healthy to first check scripts you downloaded from unknown projects. You can download the script first, inspect
it, and run it if you think everything is fine.
```sh
curl -Lo /tmp/install.sh https://framagit.org/faering/faering/-/raw/master/scripts/install.sh
less /tmp/install.sh
chmod +x /tmp/install.sh
sh /tmp/install.sh
```

### Manual installation

**Clone the Færing project**

```sh
git clone git@framagit.org:faering/faering.git ${FAERING:~/.faering}
```

**Generate self-signed certificates for local HTTPS**

```sh
docker-compose -f ${FAERING:~/.faering}/docker-compose.ssl-keygen.yml run --rm sslkeygen
```

**Trust root CA globally**

Note that some browser will not use the system keystore and will require certificates manual installation. Started
browsers need to be restarted to take into account the new certificate.

Archlinux:
```sh
sudo trust anchor --store ${FAERING:~/.faering}/certificates/${FAERING_PROJECT_DOMAIN:-docker.test}.rootCA.crt
```

Debian / Ubuntu:
```sh
sudo cp ${FAERING:~/.faering}/certificates/${FAERING_PROJECT_DOMAIN:-docker.test}.rootCA.crt /usr/local/share/ca-certificates/${FAERING_PROJECT_DOMAIN:-docker.test}.rootCA.crt
sudo update-ca-certificates
```

MacOS:
```sh
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${FAERING:~/.faering}/certificates/${FAERING_PROJECT_DOMAIN:-docker.test}.rootCA.crt
```

**Configure Dnsmasq**

Archlinux:
```sh
# Configure NetworkManager to use Dnsmaq
echo -e "[main]\ndns=dnsmasq" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf >/dev/null
# Configure Dnsmasq to forward any *.docker.test domain to the loopback local IPv4 interface
echo -e "address=/${FAERING_PROJECT_DOMAIN:-docker.test}/127.0.0.1\nstrict-order" | sudo tee /etc/NetworkManager/dnsmasq.d/faering.conf >/dev/null
# Restart NetworkManager
sudo systemctl restart NetworkManager
```

Debian / Ubuntu:
```sh
# Install Dnsmasq
sudo apt update
sudo apt install dnsmasq-base
# Configure NetworkManager to use Dnsmaq
echo -e "[main]\ndns=dnsmasq" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf >/dev/null
# Configure Dnsmasq to forward any *.docker.test domain to the loopback local IPv4 interface
echo -e "address=/${FAERING_PROJECT_DOMAIN:-docker.test}/127.0.0.1\nstrict-order" | sudo tee /etc/NetworkManager/dnsmasq.d/faering.conf >/dev/null
# Stop systemd-resolved and let NetworkManager handle /etc/resolv.conf
sudo systemctl stop systemd-resolved
sudo mv /etc/resolv.conf /etc/resolv.conf.bck
sudo ln -s /var/run/NetworkManager/resolv.conf /etc/resolv.conf
# Restart NetworkManager
sudo systemctl restart NetworkManager
```

MacOS:
```sh
# Install Dnsmasq
brew up
brew install dnsmasq
# Configure Dnsmasq to forward any *.docker.test domain to the loopback local IPv4 interface
mkdir -p $(brew --prefix)/etc/
echo -e "address=/${FAERING_PROJECT_DOMAIN:-docker.test}/127.0.0.1\nstrict-order" > $(brew --prefix)/etc/dnsmasq.conf
# Start Dnsmasq on every startup and launch it now
sudo cp $(brew --prefix dnsmasq)/homebrew.mxcl.dnsmasq.plist /Library/LaunchDaemons
sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist
# Create resolver
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/docker.test >/dev/null
```

**Start the Færing containers**

```sh
docker-compose -f ${FAERING:~/.faering}/docker-compose.yml up -d
```

### Configuration

A default configuration applies and should suit most cases, but it can be fine-tuned via:
- An `.env` file, simply copy the one provided and adjust to you needs: `cp .env.dist .env`.
- Global environment variables declared in your profile (`~/.profile`, `~/.bashrc` or `~/.zshrc` for example).

| Variable | Description | Default Value
| --- | --- | ---
| Installation
| `FAERING` | Færing installation folder | `~/.faering`
| `FAERING_DEBUG` | Log executed commands | `false`
| `FAERING_INSTALL_DNSMASQ` | Automatically install and configure Dnsmasq | `yes`
| `FAERING_TRUST_CERTIFICATES` | Automatically trust generated self-signed certificates | `yes`
| Docker compose
| `FAERING_PROJECT_NAME` | Scope for docker stack and containers | `faering`
| Traefik
| `FAERING_DEBUG` | Log additional information for debugging purpose | `false`
| `FAERING_PROJECT_DOMAIN` | Exposed containers will be subdomains of this domain | `docker.test`
| `FAERING_HTTP_PORT` | HTTP entrypoint port | `80`
| `FAERING_HTTPS_PORT` | HTTPS entrypoint port | `443`
| `FAERING_NETWORK` | Traefik network, exposed containers must be on this network | `faering`
| Self-signed certificate
| `FAERING_CERTIFICATE_SUBJECT_COUNTRY` | Certificate country code | `CH`
| `FAERING_CERTIFICATE_SUBJECT_STATE` | Certificate state | `FR`
| `FAERING_CERTIFICATE_SUBJECT_LOCATION` | Certificate location | `Fribourg`
| `FAERING_CERTIFICATE_SUBJECT_ORGANIZATION` | Certificate organization | `Faering`
| `FAERING_CERTIFICATE_SUBJECT_ORGANIZATION_UNIT` | Certificate organization unit | `Docker`

## Resources

- [Traefik documentation](https://docs.traefik.io/)
- [Traefik docker image](https://hub.docker.com/_/traefik)
- [Portainer documentation](https://www.portainer.io/documentation/)
- [Portainer docker image](https://hub.docker.com/r/portainer/portainer)
