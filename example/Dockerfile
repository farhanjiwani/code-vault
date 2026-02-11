# Uses:
#  - node-slim: https://hub.docker.com/layers/library/node/22-slim/
# Installs:
#  - passwd (usermod/groupmod), curl
#  - Claude helpers: git, ripgrep, jq, tree
#  - git-prompt.sh
FROM node:22-slim@sha256:5373f1906319b3a1f291da5d102f4ce5c77ccbe29eb637f072b6c7b70443fc36
ARG GIT_PROMPT_HASH=fbcdfab34852329929e6bfdd2bac8e49f2e3d8e3
ARG USER_UID=5001

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

echo -e "\n\e[92m--- Code Vault Ready --- \e[0m"
echo -e "Type \e[96mclaude\e[0m to start the AI assistant.\n"
GIT_PROMPT

# Create entrypoint script that hydrates the writable /home/node tmpfs
RUN cat <<'ENTRYPOINT_SCRIPT' > /opt/node-dotfiles/entrypoint.sh
#!/bin/bash
# Copy staged dotfiles into the writable /home/node (tmpfs)
cp -n /opt/node-dotfiles/.bashrc /home/node/.bashrc
cp -n /opt/node-dotfiles/.git-prompt.sh /home/node/.git-prompt.sh

# Create subdirectories Claude Code expects
mkdir -p /home/node/.npm /home/node/.config /home/node/.cache \
         /home/node/.claude /home/node/.local/share /home/node/.local/bin \
         /home/node/.npm-global

exec "$@"
ENTRYPOINT_SCRIPT

RUN chmod +x /opt/node-dotfiles/entrypoint.sh \
  && chown -R node:node /opt/node-dotfiles

# Ensure user isn't root
USER node

ENTRYPOINT ["/opt/node-dotfiles/entrypoint.sh"]
CMD ["/bin/bash"]
