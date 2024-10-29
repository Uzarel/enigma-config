#!/usr/bin/env bash

# enigma adduser script.
#
# Mattia Fonisto <mattia.fonisto@unina.it>
# Roberto Masocco <robmasocco@gmail.com>
# Intelligent Systems Lab <isl.torvergata@gmail.com>
#
# October 20, 2024

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

function usage {
  echo >&2 "Usage:"
  echo >&2 "    add_user.sh [--cpu-quota=CPU_QUOTA_%] [--memory-quota=MEMORY_QUOTA_GB] [--disk-quota=DISK_QUOTA_GB] [--sudo] [--docker] USERNAME PUBKEY"
  echo >&2 " --cpu-quota=CPU_QUOTA_%: CPU quota for the new user in cgroup v2 format (default: 12800%)."
  echo >&2 " --memory-quota=MEMORY_QUOTA_GB: memory quota for the new user in GB (default: 64 GB)."
  echo >&2 " --disk-quota=DISK_QUOTA_GB: disk quota for the new user in GB (default: 100 GB)."
  echo >&2 " --sudo: add the new user to the sudoers group."
  echo >&2 " --docker: add the new user to the docker group."
  echo >&2 " USERNAME: name of the new user."
  echo >&2 " PUBKEY: path to the public key to be added to the new user's authorized_keys file."
}

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
  usage
  exit 1
fi

# Check that we're root
if [[ $EUID -ne 0 ]]; then
  echo >&2 "ERROR: This script must be run as root."
  exit 1
fi

# Parse input arguments
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi
while [[ $# -gt 0 ]]
do
  case $1 in
    --cpu-quota=*)
      CPU_QUOTA_ARG="${1#*=}"
      shift
      ;;
    --memory-quota=*)
      MEMORY_QUOTA_ARG="${1#*=}"
      shift
      ;;
    --disk-quota=*)
      DISK_QUOTA_ARG="${1#*=}"
      shift
      ;;
    --sudo)
      SUDO=1
      shift
      ;;
    --docker)
      DOCKER=1
      shift
      ;;
    *)
      break
      ;;
  esac
done
CPU_QUOTA="${CPU_QUOTA_ARG-12800}"
MEMORY_QUOTA="${MEMORY_QUOTA_ARG-64}"
DISK_QUOTA="${DISK_QUOTA_ARG-100}"
NEW_USER="$1"
PUBKEY="$2"
echo "User name: $NEW_USER"
echo "Public key: $PUBKEY"
echo "CPU quota: $CPU_QUOTA %"
echo "Memory quota: $MEMORY_QUOTA GB"
echo "Disk quota: $DISK_QUOTA GB"
if [[ "${SUDO-0}" == "1" ]]; then
  echo "Adding user to sudoers."
fi
if [[ "${DOCKER-0}" == "1" ]]; then
  echo "Adding user to docker group."
fi

# Check that the new user is not already present
if id -u "${NEW_USER}" >/dev/null 2>&1; then
  echo >&2 "ERROR: User ${NEW_USER} already exists."
  exit 1
fi

# Add new user
adduser --home "/home/${NEW_USER}"
NEW_UID=$(id -u "${NEW_USER}")

# Add new user to sudoers
if [[ "${SUDO-0}" == "1" ]]; then
  usermod -aG sudo "${NEW_USER}"
fi

# Add new user to docker group
if [[ "${DOCKER-0}" == "1" ]]; then
  usermod -aG docker "${NEW_USER}"
fi

# Configure groups for new user
usermod -aG plugdev "${NEW_USER}"

# Configure resource quotas for this user
mkdir -p "/etc/systemd/system/user-${NEW_UID}.slice.d"
printf "[Unit]\nDescription=%s user unit\nDocumentation=man:systemd.special(7)\nBefore=slices.target\n\n[Slice]\nCPUQuota=%s%%\n\n[Install]\nWantedBy=multi-user.target\n" "${NEW_USER}" "${CPU_QUOTA}" > "/etc/systemd/system/user-${NEW_UID}.slice.d/cpu.conf"
printf "[Unit]\nDescription=%s user unit\nDocumentation=man:systemd.special(7)\nBefore=slices.target\n\n[Slice]\nMemoryMax=%sG\n\n[Install]\nWantedBy=multi-user.target\n" "${NEW_USER}" "${MEMORY_QUOTA}" > "/etc/systemd/system/user-${NEW_UID}.slice.d/memory.conf"
systemctl daemon-reload
systemctl status "user-${NEW_UID}.slice" || true

# Configure disk quota for this user
setquota -u "${NEW_USER}" "${DISK_QUOTA}G" "$((DISK_QUOTA + 2))G" 0 0 /
quota -vs -u "${NEW_USER}"

# Add public key to authorized_keys
mkdir -p "/home/${NEW_USER}/.ssh" || true
cp "${PUBKEY}" "/home/${NEW_USER}/.ssh/authorized_keys"
chmod 700 "/home/${NEW_USER}/.ssh"
chmod 600 "/home/${NEW_USER}/.ssh/authorized_keys"
chown -R "${NEW_USER}:${NEW_USER}" "/home/${NEW_USER}/.ssh"

# Add ssh/config file
cp "./config/ssh_config" "/home/${NEW_USER}/.ssh/config"
chown "${NEW_USER}:${NEW_USER}" "/home/${NEW_USER}/.ssh/config"
chmod 600 "/home/${NEW_USER}/.ssh/config"

# Add new user to SSH allowed users
sed -i "/^AllowUsers/ s/$/ $NEW_USER/" /etc/ssh/sshd_config

# Restart services
systemctl restart ssh
