#!/bin/bash

# 0. Args
PROJ_NAME=$1     # string, project name
AUTO_BUILD=$2    # --build, -b

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
  || { echo "Failed to enter directory"; exit 1; }

# 3. Create .env template
# If not using `/login`, add the API key to .env (not the example!)
echo "ANTHROPIC_API_KEY=sk-ant-xxxxxxxxx..." > .env.example
cp .env.example .env

# 4. Docker
# 4a. Create .dockerignore
cat <<EOF > .dockerignore
.git
.env
node_modules
*.tar.gz
Dockerfile
docker-compose.yml
backup.sh
restore.sh
EOF

# 4b. Create Dockerfile
cat <<'EOF' > Dockerfile
# ! UPDATE version for official Node.js image if needed
FROM node:22-slim

# Create app dir
WORKDIR /app

# ! UPDATE UID & Group ID if it is the same as your WSL UID to prevent "escapes"
RUN apt-get update \
  && apt-get install -y --no-install-recommends passwd \
  && usermod -u 5001 node && groupmod -g 5001 node

# Install helpful tools, and system dependencies so Claude may work effectively
RUN apt-get install -y git ripgrep curl jq tree \
  && curl -L https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o /home/node/.git-prompt.sh \
  && chown node:node /home/node/.git-prompt.sh \
  && chown -R node:node /home/node \
  && chown -R node:node /app \
  && rm -rf /var/lib/apt/lists/*

# Install Claude (globally)
RUN npm install -g @anthropic-ai/claude-code

# Clean PATH
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/node/.local/bin"

# Config git-prompt, add helpful aliases, append .bashrc
RUN cat <<'GIT_PROMPT' >> /home/node/.bashrc
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

echo -e "\n\e[92m--- Code Vault Ready --- \e[0m"
echo -e "Type \e[96mclaude\e[0m to start the AI assistant.\n"
GIT_PROMPT

# Ensure user isn't root
USER node

# Entry point
CMD ["/bin/bash"]
EOF

# 4c. Create docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  claude-dev:
    build: .
    container_name: ${PROJ_NAME}_container
    read_only: true
    tmpfs:
      - /tmp
      - /home/node/.npm
      - /home/node/.config
      - /home/node/.cache
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
    ports:
      - "5173:5173"
      - "3000:3000"
      - '4321:4321'
    volumes:
      - ${PROJ_NAME}_data:/app
    environment:
      - ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY}
    stdin_open: true
    tty: true
    healthcheck:
      test: ["CMD", "pgrep", "claude"] # Checks if 'claude' process exists
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s # Gives Claude time to initialize first
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN

volumes:
  ${PROJ_NAME}_data:
    name: ${PROJ_NAME}_data
EOF

# 6. Create local backup script
cat <<EOF > backup.sh
#!/bin/bash
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${PROJ_NAME}_\${TIMESTAMP}.tar.gz"

echo "Creating backup: \${BACKUP_NAME}..."
MSYS_NO_PATHCONV=1 docker run --rm \\
  -v ${PROJ_NAME}_data:/source \\
  -v \$(pwd):/backup \\
  alpine tar czf /backup/\${BACKUP_NAME} -C /source .

# Verification
if [ -f "\${BACKUP_NAME}" ]; then
  echo "Done! Snapshot saved to \${BACKUP_NAME}"
  echo "Contents summary:"
  tar -tf "\${BACKUP_NAME}" | head -n 5
else
  echo "ERROR: Backup file was not created."
fi
EOF

chmod +x backup.sh

# 7. Create local restore script
cat <<EOF > restore.sh
#!/bin/bash
echo "Available backups in this folder:"
ls -1 *.tar.gz 2>/dev/null || echo "No backups found."

read -p "Enter the full filename of the backup to restore: " RESTORE_FILE

if [ -f "\$RESTORE_FILE" ]; then
  echo "Warning: This will wipe the current project volume and replace it with the backup."
  read -p "Are you sure? (y/n): " CONFIRM
  if [ "\$CONFIRM" == "y" ]; then
    echo "Stopping containers to ensure a safe restore..."
    docker compose stop
    echo "Restoring data..."
    MSYS_NO_PATHCONV=1 docker run --rm \\
      -v ${PROJ_NAME}_data:/dest \\
      -v \$(pwd):/backup \\
      alpine sh -c "rm -rf /dest/* && tar xzf /backup/\$RESTORE_FILE -C /dest" \\
      && echo "Restore complete! Run 'docker compose up -d' to start your environment again." \\
      || echo "ERROR: Restore failed!"
  fi
else
  echo "Error: File '\$RESTORE_FILE' not found."
fi
EOF

chmod +x restore.sh

if [ "$AUTO_BUILD" == "-b" ] || [ "$AUTO_BUILD" == "--build" ]; then
  MSYS_NO_PATHCONV=1 docker compose up -d --build

  echo -e "\n\e[94;103m Initializing project files inside the volume... \e[0m\n"
  docker exec -it "${PROJ_NAME}_container" sh -c " \
    git init \
    && git branch -m main \
    && npm init -y \
    && echo 'ANTHROPIC_API_KEY=sk-ant-xxx' > /app/.env \
    && curl -L https://raw.githubusercontent.com/github/gitignore/refs/heads/main/Node.gitignore -o /app/.gitignore \
    && cat <<'GIT_IGNORE' >> /app/.gitignore

    # Named volume backups
    *.tar.gz
    GIT_IGNORE"

  printf -- "\e[93m-%0.s" {1..80}
  echo -e "\n\n\e[93;42m Setup complete! \e[0m"
  echo -e "Enter the container: \e[96mcd ${PROJ_NAME} && docker exec -it ${PROJ_NAME}_container bash\e[0m"
else
  echo -e "\n\e[93;42m Setup complete! \e[0m\n"
  echo -e "\e[4;36mNext steps:\e[0m"
  echo -e "\e[36m0.\e[0m Ignore any '\e[96m__git_ps1\e[0m: command not found' errors."
  echo -e "\e[36m1a.\e[0m If using Workplace API: Add key to \e[96m$PROJ_NAME/.env\e[0m (see \e[96m.env.example\e[0m)"
  echo -e "\e[36m1b.\e[0m If using Personal Pro: Just run \e[96mclaude\e[0m and type \e[96m/login\e[0m from within the" \ "        container."
  echo -e "\e[36m2.\e[0m Update ports section in \e[96mdocker-compose.yml\e[0m if needed."
  echo -e "\e[36m3.\e[0m Run: \e[96mcd $PROJ_NAME && docker compose up -d --build\e[0m"
  echo -e "\e[36m4.\e[0m Enter the container: \e[96mdocker exec -it ${PROJ_NAME}_container bash\e[0m"
fi
