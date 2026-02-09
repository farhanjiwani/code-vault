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
