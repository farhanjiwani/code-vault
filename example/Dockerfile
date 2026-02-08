# UPDATE version for official Node.js image if needed
FROM node:22-slim

# Minimum system dependencies Claude needs to work effectively
RUN apt-get update && apt-get install -y git ripgrep curl   && rm -rf /var/lib/apt/lists/*

# Install Claude (globally)
RUN npm install -g @anthropic-ai/claude-code

# Clean PATH
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/node/.local/bin"

# Create app dir
WORKDIR /app

# Set permissions
RUN chown -R node:node /app

# Download & config git-prompt, append .bashrc
RUN cat <<'GIT_PROMPT' >> /home/node/.bashrc
if [ ! -f /home/node/.git-prompt.sh ]; then
  curl -L https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o /home/node/.git-prompt.sh
fi
source /home/node/.git-prompt.sh
export PS1='[\[\e[1;37;104m\]\u\[\e[0m\]@\[\e[1;30m\]\h\[\e[0m\] \[\e[93m\]\W\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\]]$ '

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
GIT_PROMPT

# Ensure user isn't root
USER node

# Entry point
CMD ["/bin/bash"]
