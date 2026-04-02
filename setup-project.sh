#!/bin/bash

# Code Vault
# v1.2.0
# https://github.com/farhanjiwani/code-vault

# 00. Pinned Versions && User UID ARGs
## TODO: Pin new hashes/digests to known-good builds every 6 months or o
NODE_IMG_DIGEST="sha256:5373f1906319b3a1f291da5d102f4ce5c77ccbe29eb637f072b6c7b70443fc36"
GIT_PROMPT_HASH="fbcdfab34852329929e6bfdd2bac8e49f2e3d8e3"
GITIGNORE_HASH="10b26ce43da9337f75fb3d4e8d034c4a30ea6f96"
USER_UID="5001"

# 0. Passed Args (optional)
PROJ_NAME=$1     # [(string) <PROJECT_NAME>] dir of same name will be made
AUTO_BUILD=$2    # [--build | -b] build and perform default `init` commands

# 1. Project Name
# 1a. Prompt for the name (if not passed as arg $1)
if [ -z "$PROJ_NAME" ]; then
    read -p "Enter project name [claude_workspace]: " PROJ_NAME
fi
# 1b. Use default name as failsafe
PROJ_NAME=${PROJ_NAME:-claude_workspace}

# 2. Create project directory and enter it
MSYS_NO_PATHCONV=1 mkdir -p "$PROJ_NAME" \
  && MSYS_NO_PATHCONV=1 cd "$PROJ_NAME" \
  || { echo "Failed to enter '${PROJ_NAME}' directory"; exit 1; }

# 3. Create .env template
# If not using `/login`, add the API key to .env (not the example!)
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
cat <<EOF > Dockerfile
# Uses:
#  - node-slim: https://hub.docker.com/layers/library/node/22-slim/
# Installs:
#  - passwd (usermod/groupmod), curl
#  - Claude helpers: git, ripgrep, jq, tree
#  - git-prompt.sh
FROM node:22-slim@${NODE_IMG_DIGEST}
ARG GIT_PROMPT_HASH=${GIT_PROMPT_HASH}
ARG USER_UID=${USER_UID}

EOF
cat <<'EOF' >> Dockerfile
# Create app dir
WORKDIR /app

# !! UPDATE UID & Group ID if same as your WSL UID to prevent "escapes"
RUN apt-get update \
  && apt-get install -y --no-install-recommends passwd \
  && usermod -u ${USER_UID} node && groupmod -g ${USER_UID} node

RUN apt-get install -y git ripgrep curl jq tree \
  && curl -fSL --retry 3 --max-time 30 \
  "https://raw.githubusercontent.com/git/git/${GIT_PROMPT_HASH}/contrib/completion/git-prompt.sh" -o /tmp/.git-prompt.sh \
  && chown -R node:node /app \
  && rm -rf /var/lib/apt/lists/*

# Install Claude (globally)
RUN npm install -g @anthropic-ai/claude-code

# Clean PATH
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/node/.local/bin"

# Stage dotfiles in a safe read-only location.
# These get copied into the writable /home/node tmpfs at boot by the entrypoint.
RUN mkdir -p /opt/node-dotfiles \
  && mv /tmp/.git-prompt.sh /opt/node-dotfiles/.git-prompt.sh

RUN cat <<'GIT_PROMPT' > /opt/node-dotfiles/.bashrc
source /home/node/.git-prompt.sh
export PS1='[\[\e[1;37;104m\]\u\[\e[0m\]@\[\e[1;30m\]\h\[\e[0m\] \[\e[93m\]\W\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\]]\$ '

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
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --all'

# Save/Export Claude's memory before exiting the container.
alias c-exit='echo -e "\e[33mSaving memory...\e[0m" && mkdir -p /app/.vault_memory && cp -r /home/node/.claude /app/.vault_memory/ && cp /home/node/.claude.json /app/.vault_memory/.claude.json 2>/dev/null && exit'

echo -e "\n\e[92m--- Code Vault Ready --- \e[0m"
echo -e "Type \e[96mclaude\e[0m to start the AI assistant."
echo -e "Type \e[96mc-exit\e[0m to save memory to the host & exit.\n"
GIT_PROMPT

# Create entrypoint script that hydrates the writable /home/node tmpfs
RUN cat <<'ENTRYPOINT_SCRIPT' > /opt/node-dotfiles/entrypoint.sh
#!/bin/bash

# 1. Hydrate Shell
# Copy staged dotfiles into the writable /home/node (tmpfs)
cp -n /opt/node-dotfiles/.bashrc /home/node/.bashrc
cp -n /opt/node-dotfiles/.git-prompt.sh /home/node/.git-prompt.sh

# 2. Create standard dirs Claude Code expects
mkdir -p /home/node/.npm /home/node/.config /home/node/.cache \
  /home/node/.claude /home/node/.local/share /home/node/.local/bin \
  /home/node/.npm-global

# 3. WARM START: Restore Claude memory from persistent volume if it exists
if [ -d "/app/.vault_memory/.claude" ]; then
    echo -e "\e[33mRestoring Claude memory from Vault...\e[0m"
    cp -r /app/.vault_memory/.claude/. /home/node/.claude/
    cp /app/.vault_memory/.claude.json /home/node/.claude.json
fi

exec "$@"
ENTRYPOINT_SCRIPT

RUN chmod +x /opt/node-dotfiles/entrypoint.sh \
  && chown -R node:node /opt/node-dotfiles

# Ensure user isn't root
USER node

ENTRYPOINT ["/opt/node-dotfiles/entrypoint.sh"]
CMD ["/bin/bash"]
EOF

# 4c. Create docker-compose.yml
#   - Ports bound to 127.0.0.1 (localhost only) by default
#   - tmpfs mounts have size limits to prevent RAM exhaustion
cat <<EOF > docker-compose.yml
services:
  claude-dev:
    build: .
    container_name: ${PROJ_NAME}_container
    read_only: true
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
    ports:
      - "127.0.0.1:5173:5173"
      - "127.0.0.1:3000:3000"
      - "127.0.0.1:4321:4321"
    volumes:
      - ${PROJ_NAME}_data:/app
    tmpfs:
      - /home/node:size=512M,uid=${USER_UID},gid=${USER_UID}
      - /tmp:size=512M,exec
    dns:
      - 8.8.8.8
      - 8.8.4.4
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
#!/bin/bash

TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${PROJ_NAME}_\${TIMESTAMP}.tar.gz"

echo -e "\e[94;103m Creating backup: \e[0m \e[96m\${BACKUP_NAME}\e[0m..."
MSYS_NO_PATHCONV=1 docker run --rm \\
  -v ${PROJ_NAME}_data:/source:ro \\
  -v "\$(pwd)":/backup \\
  alpine tar czf /backup/\${BACKUP_NAME} -C /source .

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
#!/bin/bash

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
      alpine sh -c "rm -rf /dest/* && tar xzf /backup/\$RESTORE_FILE -C /dest" \\
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
#!/bin/bash

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
#!/bin/bash

echo -e "\e[94m--- Code Vault Import ---\e[0m"
echo -e "\e[33mThis will copy files from your CURRENT folder into the container.\e[0m"
read -p $'\n\e[93;44m Are you in the root of the project you want to import? (y/n): \e[0m ' CONFIRM

if [ "\$CONFIRM" == "y" ]; then
  echo -e "\e[33mCopying files..."
  # Copy current directory contents into /app inside the container
  MSYS_NO_PATHCONV=1 docker cp . ${PROJ_NAME}_container:/app

  echo "Fixing permissions..."
  # Ensure node owns the new files
  docker exec -u root ${PROJ_NAME}_container chown -R node:node /app

  echo -e "\e[92m✓ Import Complete!\e[0m"
  echo "You can now \e[96mc-enter\e[0m the vault."
else
  echo "\e[93;41m Aborting. \e[0;96m Please navigate to the source code folder first.\e[0m"
fi
EOF
chmod +x import.sh


if [ "$AUTO_BUILD" == "-b" ] || [ "$AUTO_BUILD" == "--build" ]; then
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
  echo -e "\e[36m1b.\e[0m If using Personal Pro: Just run \e[96mclaude\e[0m and type \e[96m/login\e[0m from within the" \ "        container."
  echo -e "\e[36m2.\e[0m Update ports section in \e[96mdocker-compose.yml\e[0m if needed."
  echo -e "\e[36m3.\e[0m Run: \e[96mcd $PROJ_NAME && docker compose up -d --build\e[0m"
  echo -e "\e[36m4.\e[0m Enter the container: \e[96mdocker exec -it ${PROJ_NAME}_container bash\e[0m"
fi