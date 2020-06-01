#!/bin/sh

# Install Faering and start containers.
#
# You can tweak the install behavior by setting environment variables when running the script.
# For example, to change the path where the Faering repository will be checked out:
#   FAERING=~/.docker sh install.sh
#
# Available options are described in the README.md file:
# https://framagit.org/faering/faering#configuration.

set -e

# Environment variables.
set -a
[ -f "${FAERING:-~/.faering}/.env.dist" ] && . "${FAERING:-~/.faering}/.env.dist"
[ -f "${FAERING:-~/.faering}/.env" ] && . "${FAERING:-~/.faering}/.env"
set +a

# Set default environment variables.
FAERING=${FAERING:-~/.faering}
FAERING_DEBUG=${FAERING_DEBUG:-false}
FAERING_INSTALL_DNSMASQ=${FAERING_INSTALL_DNSMASQ:-yes}
FAERING_PROJECT_DOMAIN=${FAERING_PROJECT_DOMAIN:-docker.test}
FAERING_TRUST_CERTIFICATES=${FAERING_TRUST_CERTIFICATES:-yes}

# Ensure a given command exists.
command_exists() {
  command -v "$@" >/dev/null 2>&1
}

# Display error message.
error() {
  echo "${RED}Error: $*${RESET}" >&2
  exit 1
}

# Set debug mode.
set_debug() {
  if [ "${FAERING_DEBUG}" = true ]; then
    set -x
    echo "${BLUE}Debug mode active.${PLATFORM}${RESET}"
  fi
}

# Setup colors if connected to a terminal.
setup_colors() {
  if [ -t 1 ]; then
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    RESET=$(printf '\033[m')
  else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    RESET=''
  fi
}

# Identify platform for future commands.
identify_platform() {
  if [ ! -z "${PLATFORM}" ]; then
    PLATFORM="${PLATFORM}"
  elif [ -f /etc/arch-release ]; then
    PLATFORM='arch'
  elif [ "${OSTYPE}" != "${OSTYPE#darwin}" ]; then
    PLATFORM='darwin'
  elif [ -f /etc/debian-version ]; then
    PLATFORM='debian'
  else
    PLATFORM='unknown'
  fi

  echo "${BLUE}Detected platform: ${PLATFORM}${RESET}"
}

# Check if required binaries are available.
check_requirements() {
  echo "${BLUE}Requirements: checking...${RESET}"

  command_exists git || error "git is not installed."

  command_exists docker || error "docker is not installed."

  command_exists docker-compose || error "docker-compose is not installed."

  docker info >/dev/null 2>&1 || error "docker service is not running."
}

# Clone faering git repository.
install_repository() {
  if [ -d "${FAERING}/.git" ] && [ "$(git --git-dir "${FAERING}/.git" config --get remote.origin.url)" = git@framagit.org:faering/faering.git ]; then
    echo "${BLUE}Repository: git repository already exists, updating...${RESET}"
    git --git-dir "${FAERING}/.git" pull
  elif [ "$(ls -A ${FAERING})" ]; then
    error "${FAERING} is not empty."
  else
    echo "${BLUE}Repository: cloning...${RESET}"
    git clone git@framagit.org:faering/faering.git "${FAERING}"
  fi
}

# Generate and install certificates.
install_certificates() {
  echo "${BLUE}Certificates: generating...${RESET}"
  if [ -f "${FAERING}/certificates/${FAERING_PROJECT_DOMAIN}.rootCA.crt" ]; then
    echo "Certificates already exist."
  else
    docker-compose -f "${FAERING}/docker-compose.ssl-keygen.yml" run --rm sslkeygen
  fi

  if [ "${FAERING_TRUST_CERTIFICATES}" != 'yes' ]; then
    echo "${BLUE}Certificates: trust skipped.${RESET}"
    return 0
  fi

  echo "${BLUE}Certificates: trusting...${RESET}"
  case ${PLATFORM} in
  arch)
    sudo trust anchor --store "${FAERING}/certificates/${FAERING_PROJECT_DOMAIN}.rootCA.crt"
    ;;
  darwin)
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "${FAERING}/certificates/${FAERING_PROJECT_DOMAIN}.rootCA.crt"
    ;;
  debian)
    sudo cp "${FAERING}/certificates/${FAERING_PROJECT_DOMAIN}.rootCA.crt" "/usr/local/share/ca-certificates/${FAERING_PROJECT_DOMAIN}.rootCA.crt"
    sudo update-ca-certificates
    ;;
  *)
    echo "${YELLOW}Unsupported platform, certificates must be trusted manually.${RESET}"
    ;;
  esac
}

# Install and configure Dnsmasq
# This step should be the last as restarting the NetworkManager may take some time.
install_dnsmasq() {
  if [ "${FAERING_INSTALL_DNSMASQ}" != 'yes' ]; then
    echo "${BLUE}Dnsmasq: installation skipped.${RESET}"
    return 0
  fi

  if [ "$(ping -c1 faering.docker.test | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')" = '127.0.0.1' ]; then
    echo "${BLUE}Dnsmasq: *.docker.test forwarded to 127.0.0.1, installation skipped..${RESET}"
    return 0
  fi

  echo "${BLUE}Dnsmasq: installing and configuring...${RESET}"
  case ${PLATFORM} in
  arch)
    {
      echo '[main]'
      echo 'dns=dnsmasq'
    } | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf >/dev/null
    {
      echo "address=/${FAERING_PROJECT_DOMAIN}/127.0.0.1"
      echo 'strict-order'
    } | sudo tee /etc/NetworkManager/dnsmasq.d/faering.conf >/dev/null
    sudo systemctl restart NetworkManager
    ;;
  darwin)
    if [ -z "$(brew ls --versions dnsmasq)" ]; then
      echo "${BLUE}Dnsmasq: install Dnsmasq.${RESET}"
      brew up
      brew install dnsmasq
    fi
    echo "${BLUE}Dnsmasq: configure Dnsmasq.${RESET}"
    mkdir -p "$(brew --prefix)/etc/"
    {
      echo "address=/${FAERING_PROJECT_DOMAIN}/127.0.0.1"
      echo 'strict-order'
    } >"$(brew --prefix)/etc/dnsmasq.conf"
    echo "${BLUE}Dnsmasq: launch Dnsmasq.${RESET}"
    sudo cp "$(brew --prefix dnsmasq)/homebrew.mxcl.dnsmasq.plist" /Library/LaunchDaemons
    sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist
    echo "${BLUE}Dnsmasq: create resolver.${RESET}"
    sudo mkdir -p /etc/resolver
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/docker.test >/dev/null
    ;;
  debian)
    sudo apt update
    sudo apt install dnsmasq-base
    {
      echo '[main]'
      echo 'dns=dnsmasq'
    } | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf >/dev/null
    {
      echo "address=/${FAERING_PROJECT_DOMAIN}/127.0.0.1"
      echo 'strict-order'
    } | sudo tee /etc/NetworkManager/dnsmasq.d/faering.conf >/dev/null
    sudo systemctl stop systemd-resolved
    sudo mv /etc/resolv.conf /etc/resolv.conf.bck
    sudo ln -s /var/run/NetworkManager/resolv.conf /etc/resolv.conf
    sudo systemctl restart NetworkManager
    ;;
  *)
    echo "${YELLOW}Unsupported platform, dnsmasq must be installed manually.${RESET}"
    ;;
  esac
}

# Export the user ID and Faering environment variables.
export_variables() {
  command_exists bash && write_shell_profile ~/.bashrc
  command_exists fish && write_shell_profile ~/.config/fish/config.fish
  command_exists zsh && write_shell_profile ~/.zshrc
}

# Writes shell profile.
write_shell_profile() {
  profile="${1}"
  if [ -z "${profile}" ]; then
    return 0
  elif [ -z "$(grep 'export FAERING=' ${profile})" ]; then
    echo "${BLUE}Exporting environment variables to ${profile}...${RESET}"
    {
      echo ''
      echo '# Faering'
      echo "export FAERING=${FAERING:-~/.faering}"
      echo 'source ${FAERING}/config/profile.sh'
    } >>"${profile}"
  fi
}

# Start Faering containers.
start_containers() {
  echo "${BLUE}Starting containers...${RESET}"
  docker-compose -f "${FAERING}/docker-compose.yml" up -d
}

# Display success information.
display_information() {
  echo ""
  echo "${GREEN}Faering successfully installed!${RESET}"
  echo "${GREEN}- Traefik: http://traefik.${FAERING_PROJECT_DOMAIN} or https://traefik.${FAERING_PROJECT_DOMAIN}${RESET}"
  echo "${GREEN}- Portainer: http://portainer.${FAERING_PROJECT_DOMAIN} or https://portainer.${FAERING_PROJECT_DOMAIN}${RESET}"
}

# Main installer.
install() {
  setup_colors
  set_debug
  identify_platform
  check_requirements
  install_repository
  install_certificates
  export_variables
  start_containers
  install_dnsmasq
  display_information
}

install "$@"
