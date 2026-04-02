#!/bin/bash

PROJ_NAME=$(basename "$(pwd)")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./memory_backup/${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"

echo -e "\n\e[33mSnapshoting Claude's brain to $BACKUP_DIR...\e[0m"
# Copy from the running container's tmpfs to your host
docker cp ${PROJ_NAME}_container:/home/node/.claude "${BACKUP_DIR}/.claude"
docker cp ${PROJ_NAME}_container:/home/node/.claude.json "${BACKUP_DIR}/.claude.json"
docker cp ${PROJ_NAME}_container:/app/.claude.json "${BACKUP_DIR}/.claude.json" 2>/dev/null

echo -e "\e[93;42m Done. \e[0m"
