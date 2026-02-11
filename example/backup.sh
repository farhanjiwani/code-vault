#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_example_${TIMESTAMP}.tar.gz"

echo -e "\e[94;103m Creating backup: \e[0m \e[96m${BACKUP_NAME}\e[0m..."
MSYS_NO_PATHCONV=1 docker run --rm \
  -v example_data:/source:ro \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/${BACKUP_NAME} -C /source .

# Verification
if [ -f "${BACKUP_NAME}" ]; then
  echo -e "\e[93;42m Done! \e[0m Snapshot saved.\n"
  echo -e "\e[4;36mContents summary:\e[0;96m"
  tar -tf "${BACKUP_NAME}" | head -n 5
else
  echo -e "\e[93;41m ERROR: \e[0m Backup file was not created."
fi
