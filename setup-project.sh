#!/usr/bin/env bash
set -eo pipefail

# Code Vault
# v2.1.1
# https://github.com/farhanjiwani/code-vault

# 00. Pinned Versions && User UID ARGs
## TODO: Pin new hashes/digests to known-good builds every 6 months or so
## Current: https://hub.docker.com/_/node/tags?name=24.18.0-bookworm-slim
## - [x] linux/amd64
## - [ ] linux/arm64/v8
## - [ ] linux/ppc64le
NODE_VERSION="24.18.0"
NODE_IMG_DIGEST="sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d"
GIT_PROMPT_HASH="fbcdfab34852329929e6bfdd2bac8e49f2e3d8e3"
GITIGNORE_HASH="10b26ce43da9337f75fb3d4e8d034c4a30ea6f96"

## SSH Config
KEY_NAME="id_ed25519_code-vault"
KEY_PATH="$HOME/.ssh/$KEY_NAME"
SSH_CONFIG="$HOME/.ssh/config"

echo -e "\e[92m=== Code Vault Configuration Wizard ===\e[0m\n"
echo -e "\e[34m[1/4] Checking SSH Key Pair...\e[0m"
if [ ! -f "$KEY_PATH" ]; then
  echo "Generating dedicated vault key pair..."
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "code-vault-key"
else
  echo "Key pair already exists at $KEY_PATH"
fi

echo -e "\e[34m[2/4] Updating Host SSH Config...\e[0m"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"

if ! grep -q "Host code-vault" "$SSH_CONFIG"; then
  cat <<EOF >> "$SSH_CONFIG"

Host code-vault
    HostName 127.0.0.1
    Port 2222
    User node
    IdentityFile ~/.ssh/$KEY_NAME
    IdentitiesOnly yes
    LogLevel QUIET
EOF
  echo "Appended 'code-vault' profile to $SSH_CONFIG"
else
  echo "SSH config profile 'code-vault' already present."
fi

# 0. Check for existing configuration
CONFIG_FILE=".harness-config"
if [ -f "$CONFIG_FILE" ]; then
    read -p $'\e[33mExisting configuration found. Use it?\e[0m (Y/n): ' USE_EXISTING
    USE_EXISTING=${USE_EXISTING:-Y}
    if [[ "${USE_EXISTING,,}" == "y" ]]; then
        source "$CONFIG_FILE"
        echo "Loaded saved configuration."
        SKIP_WIZARD=true
    fi
fi

if [ "${SKIP_WIZARD:-false}" != true ]; then
    ## 1. Project Name
    PROJ_NAME="${PROJ_NAME}"
    if [ -z "${PROJ_NAME-}" ]; then
        read -p $'\e[36m1. Project Name\e[0m [claude_workspace]: ' PROJ_NAME
	PROJ_NAME=${PROJ_NAME:-claude_workspace}
    fi

    ## 2. Host UID (Auto-detects the current user's ID to prevent Docker file lockouts)
    USER_UID="${USER_UID}"
    if [ -z "${USER_UID-}" ]; then
        DETECTED_UID=$(id -u 2>/dev/null || echo 5001)
	read -p $'\e[36m2. Container User UID\e[0m [Host UID: '"$DETECTED_UID"']: ' USER_UID
	USER_UID=${USER_UID:-$DETECTED_UID}
    fi

    ## 3. Exposed Ports (Defaults cover Astro, Vue/Nuxt, and Vite)
    PROJ_PORTS="${PROJ_PORTS}"
    if [ -z "${PROJ_PORTS-}" ]; then
        read -p $'\e[36m3. Exposed Ports\e[0m (Space-separated) [2222 5173 3000 4321]: ' PROJ_PORTS
	PROJ_PORTS=${PROJ_PORTS:-2222 5173 3000 4321}
    fi

    ## 4. Resource Limits (Native Bash select menu)
    CPUS="${CPUS}"
    MEM="${MEM}"
    if [ -z "${CPUS-}" ] || [ -z "${MEM-}" ] ; then
        echo -e "\n\e[36m4. Container Resource Limits:\e[0m"
	PS3="Select a profile (1-3): "
	select RES_PROFILE in "Lightweight (1 CPU / 2GB)" "Standard (2 CPU / 4GB)" "Uncapped (Use all host resources)"; do
	    case $REPLY in
		1) CPUS="1.0"; MEM="2G"; break ;;
		2) CPUS="2.0"; MEM="4G"; break ;;
		3) CPUS="0"; MEM="0"; break ;;
		*) echo "Invalid option. Please enter 1, 2, or 3." ;;
	    esac
        done
	echo ""
    fi

    ## 5. Optional Packages
    APT_PKGS="${APT_PKGS}"
    if [ -z "${APT_PKGS-}" ]; then
        read -p $'\e[36m5. Extra apt packages\e[0m (Space-separated) [vim]: ' APT_PKGS
	APT_PKGS=${APT_PKGS:-vim}
    fi

    ## 6. DNS Resolution
    CUSTOM_DNS="${CUSTOM_DNS}"
    if [ -z "${CUSTOM_DNS-}" ]; then
	read -p $'\e[36m6. Custom DNS\e[0m (e.g., 8.8.8.8. Leave blank for Docker default): ' CUSTOM_DNS
    fi

    ## 7. Auto-Build
    AUTO_BUILD="${AUTO_BUILD}"
    if [ -z "${AUTO_BUILD-}" ]; then
	read -p $'\e[36m8. Initialize and build container immediately?\e[0m (Y/n): ' AUTO_BUILD
	AUTO_BUILD=${AUTO_BUILD:-Y}
    fi

    ## 8. Save Configuration (Stateless by default, persistent by choice)
    SAVE_CONF="${SAVE_CONF}"
    if [ -z "${SAVE_CONF-}" ]; then
	read -p $'\e[36m9. Save these settings to \e[1m'"$CONFIG_FILE"$'\e[22m for future runs?\e[0m (Y/n): ' SAVE_CONF
	SAVE_CONF=${SAVE_CONF:-Y}
    fi

    if [[ "${SAVE_CONF,,}" == "y" ]]; then
        cat <<EOF > "$CONFIG_FILE"
PROJ_NAME="$PROJ_NAME"
USER_UID="$USER_UID"
PROJ_PORTS="$PROJ_PORTS"
CPUS="$CPUS"
MEM="$MEM"
APT_PKGS="$APT_PKGS"
CUSTOM_DNS="$CUSTOM_DNS"
NODE_VERSION="$NODE_VERSION"
AUTO_BUILD="$AUTO_BUILD"
EOF
        echo -e "\e[92mConfiguration saved to $CONFIG_FILE\e[0m"
    fi
fi

# 1. Format YAML
## Format Ports
PORT_BINDINGS=""
for port in $PROJ_PORTS; do
  PORT_BINDINGS="$PORT_BINDINGS
      - \"127.0.0.1:${port}:${port}\""
done

## Format DNS conditionally
DNS_BLOCK=""
if [ -n "$CUSTOM_DNS" ]; then
  DNS_BLOCK="
    dns:
      - ${CUSTOM_DNS}"
fi

echo -e "\n\e[92m=== Generating Environment ===\e[0m"
## Format Resource Limits conditionally
RESOURCE_BLOCK=""
if [ "$CPUS" != "0" ]; then
  RESOURCE_BLOCK="
    deploy:
      resources:
        limits:
          cpus: '${CPUS}'
          memory: ${MEM}"
fi

# 2. Create project directory and enter it
## MSYS_NO_PATHCONV=1 disables converting Unix-style paths to Windows-style ones
MSYS_NO_PATHCONV=1 mkdir -p "$PROJ_NAME" \
  && MSYS_NO_PATHCONV=1 cd "$PROJ_NAME" \
  || { echo "Failed to enter '${PROJ_NAME}' directory"; exit 1; }

# 3. Create .env template
# If not using '/login', add the API key to .env (not the example!)
echo "ANTHROPIC_API_KEY=sk-ant-xxxxxxxxx..." > .env.example
cp .env.example .env

# 4. Docker
# 4a. Create .dockerignore
cat <<EOF > .dockerignore
.git
.env
!.env.example
node_modules
*.tar.gz
Dockerfile
docker-compose.yml
backup.sh
restore.sh
EOF

# 4b. Create Dockerfile
echo -e "\e[34m[3/4] Generating Dockerfile...\e[0m"
cat <<EOF > Dockerfile
# syntax=docker/dockerfile:1

# Uses:
#  - node-slim: https://hub.docker.com/layers/library/node/${NODE_VERSION}-bookworm-slim/
# Installs:
#  - passwd (usermod/groupmod), curl
#  - Claude helpers: git, ripgrep, jq, tree
#  - git-prompt.sh
FROM node:${NODE_VERSION}-bookworm-slim@${NODE_IMG_DIGEST}
ARG GIT_PROMPT_HASH=${GIT_PROMPT_HASH}
ARG USER_UID=${USER_UID}

# Create app dir
WORKDIR /app

RUN apt-get update \\
  && apt-get install -y --no-install-recommends passwd \\
  && usermod -u \${USER_UID} node && groupmod -g \${USER_UID} node

# Inject the dynamic apt packages
RUN apt-get install -y git ripgrep curl jq tree ${APT_PKGS} \\
  && curl -fSL --retry 3 --max-time 30 \\
  "https://raw.githubusercontent.com/git/git/\${GIT_PROMPT_HASH}/contrib/completion/git-prompt.sh" -o /tmp/.git-prompt.sh \\
  && chown -R node:node /app

# Setup SSH Server
RUN apt-get install -y openssh-server \\
  && mkdir /var/run/sshd \\
  && mkdir -p /home/node/.ssh /home/node/sshd_keys \\
  && chown -R node:node /home/node/.ssh /home/node/sshd_keys \\
  && rm -rf /var/lib/apt/lists/* # DO THIS LAST, ONCE DONE W? apt-get installs

# Install Claude (globally)
RUN npm install -g @anthropic-ai/claude-code

# Clean PATH
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/node/.local/bin"

# Stage dotfiles in a safe read-only location.
# These get copied into the writable /home/node tmpfs at boot by the entrypoint.
RUN mkdir -p /opt/node-dotfiles \\
  && mv /tmp/.git-prompt.sh /opt/node-dotfiles/.git-prompt.sh

COPY --chown=node:node <<'BASHRC' /opt/node-dotfiles/.bashrc
source /home/node/.git-prompt.sh
export PS1='[\[\e[1;37;104m\]\u\[\e[0m\]@\[\e[1;30m\]\h\[\e[0m\] \[\e[93m\]\W\[\e[33m\]\$(__git_ps1 " (%s)")\[\e[0m\]]\$ '

# Helpful aliases
alias ls='ls --color=auto'
alias la='ls -la'
alias lsg='ls --group-directories-first'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

alias gfp='git fetch --all -p'
alias gco='git checkout'
alias gs='git status'
alias ga='git add'
alias gd='git diff --ignore-all-space'
alias gds='git diff --staged'
alias gdwd='git diff --word-diff --color-words'
alias gl='git log --oneline --graph --all'

# Save/Export Claude's memory before exiting the container (force overwriting read-only Git pack files).
alias c-exit='echo -e "\e[33mSaving memory...\e[0m" && mkdir -p /app/.vault_memory && chmod -R +w /app/.vault_memory/.claude 2>/dev/null; cp -rf /home/node/.claude /app/.vault_memory/ && cp -f /home/node/.claude.json /app/.vault_memory/.claude.json 2>/dev/null && exit'

echo -e "\n\e[92m--- Code Vault Ready --- \e[0m" >&2
echo -e "Type \e[96mclaude\e[0m to start the AI assistant." >&2
echo -e "Type \e[96mc-exit\e[0m to save memory to the host & exit.\n" >&2
BASHRC

# Create entrypoint script that hydrates the writable /home/node tmpfs
COPY --chown=node:node --chmod=0755 <<'ENTRYPOINT_SCRIPT' /opt/node-dotfiles/entrypoint.sh
#!/usr/bin/env bash
set -e

# 0. SSH setup for non-root user
mkdir -p /home/node/.ssh /home/node/sshd_keys
chmod 700 /home/node/.ssh

## Copy mounted vault public key if present
if [ -f /tmp/$KEY_NAME.pub ]; then
  cp /tmp/$KEY_NAME.pub /home/node/.ssh/authorized_keys
  chmod 600 /home/node/.ssh/authorized_keys
fi

## Generate SSH server host keys in dedicated UNPRIVILEGED directory (non-root)
if [ ! -f /home/node/sshd_keys/ssh_host_ed25519_key ]; then
  ssh-keygen -t ed25519 -f /home/node/sshd_keys/ssh_host_ed25519_key -N ""
  chmod 600 /home/node/sshd_keys/ssh_host_ed25519_key
fi

## Ensure strict permissions to authorized_keys if writable
if [ -f /home/node/.ssh/authorized_keys ] && [ -w /home/node/.ssh/authorized_keys ]; then
  chmod 400 /home/node/.ssh/authorized_keys
fi

## Non-root SSH Config to run SSHD
### NOTE: OpenSSH strictly checks that .ssh and authlrized_keys are owned by the user, and not writable by anyone else.
###    However, 'StrictModes no' turns this safety check OFF. For now, this is kept as a cross-platform development
###    tradeoff because Docker Desktop on Windows/MacOS translates host file permissions into the container
###    unpredictably, (often mounting read-only files as root), OpenSSH will silently reject valid keys if StrictModes
###    is enabled. But because this container is an ephemeral local sandbox and the SSH port should only be bound to
###    localhost via docker-compose.yml, the risk of disabling strict permissions inside the container is minimum to 0.
cat <<'SSHD_CONFIG' > /home/node/sshd_config
Port 2222
HostKey /home/node/sshd_keys/ssh_host_ed25519_key
AuthorizedKeysFile /home/node/.ssh/authorized_keys
PidFile /home/node/sshd.pid
StrictModes no
Subsystem sftp /usr/lib/openssh/sftp-server
SSHD_CONFIG

## Start non-root SSH daemon in the background, pointing to user config
/usr/sbin/sshd -f /home/node/sshd_config

# 1. Hydrate Shell
# Copy staged dotfiles into the writable /home/node (tmpfs)
cp -n /opt/node-dotfiles/.bashrc /home/node/.bashrc 2>/dev/null || true
cp -n /opt/node-dotfiles/.git-prompt.sh /home/node/.git-prompt.sh 2>/dev/null || true

# 2. Create standard dirs Claude Code expects
mkdir -p /home/node/.npm /home/node/.config /home/node/.cache \\
  /home/node/.claude /home/node/.local/share /home/node/.local/bin \\
  /home/node/.npm-global

# 3. WARM START: Restore Claude memory from persistent volume if it exists
if [ -d "/app/.vault_memory/.claude" ]; then
    echo -e "\e[33mRestoring Claude memory from Vault...\e[0m" >&2
    cp -r /app/.vault_memory/.claude/. /home/node/.claude/
    cp /app/.vault_memory/.claude.json /home/node/.claude.json 2>/dev/null || true
fi

exec "\$@"
ENTRYPOINT_SCRIPT

# Ensure user isn't root
USER node

ENTRYPOINT ["/opt/node-dotfiles/entrypoint.sh"]
CMD ["/bin/bash"]
EOF

# 4c. Create docker-compose.yml
#   - Ports bound to 127.0.0.1 (localhost only) by default
#   - tmpfs mounts have size limits to prevent RAM exhaustion
echo -e "\e[34m[4/4] Generating docker-compose.yml...\e[0m"
cat <<EOF > docker-compose.yml
services:
  claude-dev:
    build: .
    container_name: ${PROJ_NAME}_container
    read_only: true${RESOURCE_BLOCK}
    ports:${PORT_BINDINGS}
    volumes:
      # Mount host's public key as the container's authorized_key file
      - ~/.ssh/${KEY_NAME}.pub:/tmp/id_ed25519_code-vault.pub:ro
      - ${PROJ_NAME}_data:/app
    tmpfs:
      - /home/node:size=512M,uid=${USER_UID},gid=${USER_UID}
      - /tmp:size=2G,exec
    environment:
      - ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY}
    stdin_open: true
    tty: true
    healthcheck:
      test: ["CMD", "node", "-e", "process.exit(0)"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 10s
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL

volumes:
  ${PROJ_NAME}_data:
    name: ${PROJ_NAME}_data
EOF

# 5. Helpful Tools (Host)
# 5a. Create local backup script
cat <<EOF > backup.sh
#!/usr/bin/env bash

TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${PROJ_NAME}_\${TIMESTAMP}.tar.gz"

echo -e "\e[94;103m Creating backup: \e[0m \e[96m\${BACKUP_NAME}\e[0m..."
MSYS_NO_PATHCONV=1 docker run --rm \\
  -v ${PROJ_NAME}_data:/source:ro \\
  -v "\$(pwd)":/backup \\
  node:24.18.0-bookworm-slim \
  tar --no-xattrs --warning=no-file-changed \
      --exclude='./node_modules' \
      --exclude='./.git' \
      --exclude='./.astro' \
      -czf /backup/\${BACKUP_NAME} -C /source .

# Verification
if [ -f "\${BACKUP_NAME}" ]; then
  echo -e "\e[93;42m Done! \e[0m Snapshot saved.\n"
  echo -e "\e[4;36mContents summary:\e[0;96m"
  tar -tf "\${BACKUP_NAME}" | head -n 5
else
  echo -e "\e[93;41m ERROR: \e[0m Backup file was not created."
fi
EOF
chmod +x backup.sh

# 5b. Create local restore script
cat <<EOF > restore.sh
#!/usr/bin/env bash

echo -e "\e[4;36mAvailable backups in this folder:\e[0;96m"
ls -1 *.tar.gz 2>/dev/null || echo -e "\e[31m No backups found.\e[0m"

read -p $'\n\e[93;44m Enter the full filename of the backup to restore: \e[0m ' RESTORE_FILE

if [ -f "\$RESTORE_FILE" ]; then
echo -e "\e[4;43m Warning: \e[0m This will wipe the current project volume and replace it with the\n           backup."
  read -p $'\n\e[93;44m Are you sure? (y/n): \e[0m ' CONFIRM
  if [ "\$CONFIRM" == "y" ]; then
    echo -e "\e[33mStopping containers to ensure a safe restore..."
    docker compose stop
    echo "Restoring data..."
    MSYS_NO_PATHCONV=1 docker run --rm \\
      -v ${PROJ_NAME}_data:/dest \\
      -v "\$(pwd)":/backup \\
      node:24.18.0-bookworm-slim \\
      sh -c "rm -rf /dest/* && tar xzf /backup/\$RESTORE_FILE -C /dest" \\
      && echo -e "\e[93;42m Restore complete! \e[0m Run \e[96mdocker compose up -d\e[0m to start your environment again." \\
      || echo "\e[93;41m ERROR: \e[0m Restore failed!"
  fi
else
  echo -e "\e[93;41m ERROR: \e[0m File \e[96m\${RESTORE_FILE}\e[0m not found."
fi
EOF
chmod +x restore.sh

# 5c. Create local memory backup script
cat <<EOF > backup-memory.sh
#!/usr/bin/env bash

PROJ_NAME=\$(basename "\$(pwd)")
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./memory_backup/\${TIMESTAMP}"

mkdir -p "\$BACKUP_DIR"

echo -e "\n\e[33mSnapshoting Claude's brain to \$BACKUP_DIR...\e[0m"
# Copy from the running container's tmpfs to your host
docker cp \${PROJ_NAME}_container:/home/node/.claude "\${BACKUP_DIR}/.claude"
docker cp \${PROJ_NAME}_container:/home/node/.claude.json "\${BACKUP_DIR}/.claude.json"
docker cp \${PROJ_NAME}_container:/app/.claude.json "\${BACKUP_DIR}/.claude.json" 2>/dev/null

echo -e "\e[93;42m Done. \e[0m"
EOF
chmod +x backup-memory.sh

# 5d. Create local import script (The Bridge)
cat <<EOF > import.sh
#!/usr/bin/env bash

echo -e "\e[94m--- Code Vault Import ---\e[0m"
echo -e "\e[33mThis will securely inject files from your CURRENT folder into the vault.\e[0m"
read -p \$'\n\e[93;44m Are you in the root of the project you want to import? (y/n): \e[0m ' CONFIRM

if [ "\$CONFIRM" == "y" ]; then
  echo -e "\e[33mInjecting files via secure Sidecar container...\e[0m"

  # Spin up a temporary Bookworm container with full capabilities to copy and chown the files,
  # bypassing the security restrictions of the locked-down Claude container.
  MSYS_NO_PATHCONV=1 docker run --rm \\
    -v "\$(pwd):/source:ro" \\
    -v ${PROJ_NAME}_data:/app \\
    node:24.18.0-bookworm-slim \\
    sh -c "cp -a /source/. /app/ && chown -R ${USER_UID}:${USER_UID} /app"

  echo -e "\e[92m✓ Import and Permission Fix Complete!\e[0m"
  echo -e "You can now \e[96mc-enter\e[0m the vault."
else
  echo -e "\e[93;41m Aborting. \e[0;96m Please navigate to the source code folder first.\e[0m"
fi
EOF
chmod +x import.sh


if [[ "${AUTO_BUILD,,}" == "y" ]]; then
  MSYS_NO_PATHCONV=1 docker compose up -d --build

  echo -e "\n\e[94;103m Initializing project files inside the volume... \e[0m\n"
  docker exec -u node -it "${PROJ_NAME}_container" sh -c " \
    git init \
    && git branch -m main \
    && npm init -y \
    && echo 'ANTHROPIC_API_KEY=sk-ant-xxx' > /app/.env \
    && curl -fSL --retry 3 --max-time 30 \
    'https://raw.githubusercontent.com/github/gitignore/${GITIGNORE_HASH}/Node.gitignore' -o /app/.gitignore \
    && cat <<'GIT_IGNORE' >> /app/.gitignore

# Named volume backups
*.tar.gz

# Claude Code Memory Vault
.vault_memory/
.claude/
GIT_IGNORE"

  printf -- "\e[93m-%0.s" {1..80}
  echo -e "\n\n\e[93;42m Setup complete! \e[0m"
  echo -e "Enter the container: \e[96mcd ${PROJ_NAME} && docker exec -it ${PROJ_NAME}_container bash\e[0m"
  echo ""
  echo -e "\e[33m⚠  REMINDER:\e[0m Add your real API key to \e[96m${PROJ_NAME}/.env\e[0m on the host"
  echo -e "   (unless using \e[96m/login\e[0m), then restart: \e[96mdocker compose restart\e[0m"
else
  echo -e "\n\e[93;42m Setup complete! \e[0m\n"
  echo -e "\e[4;36mNext steps:\e[0m"
  echo -e "\e[36m1a.\e[0m If using Workplace API: Add key to \e[96m$PROJ_NAME/.env\e[0m (see \e[96m.env.example\e[0m)"
  echo -e "\e[36m1b.\e[0m If using Personal Pro: Just run \e[96mclaude\e[0m and type \e[96m/login\e[0m from within the container."
  echo -e "\e[36m2.\e[0m Update ports section in \e[96mdocker-compose.yml\e[0m if needed."
  echo -e "\e[36m3.\e[0m Run: \e[96mcd $PROJ_NAME && docker compose up -d --build\e[0m"
  echo -e "\e[36m4.\e[0m Enter the container: \e[96mdocker exec -it ${PROJ_NAME}_container bash\e[0m"
fi
