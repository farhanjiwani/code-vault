#!/bin/bash

echo -e "\e[4;36mAvailable backups in this folder:\e[0;96m"
ls -1 *.tar.gz 2>/dev/null || echo -e "\e[31m No backups found.\e[0m"

read -p $'\n\e[93;44m Enter the full filename of the backup to restore: \e[0m ' RESTORE_FILE

if [ -f "$RESTORE_FILE" ]; then
echo -e "\e[4;43m Warning: \e[0m This will wipe the current project volume and replace it with the\n           backup."
  read -p $'\n\e[93;44m Are you sure? (y/n): \e[0m ' CONFIRM
  if [ "$CONFIRM" == "y" ]; then
    echo -e "\e[33mStopping containers to ensure a safe restore..."
    docker compose stop
    echo "Restoring data..."
    MSYS_NO_PATHCONV=1 docker run --rm \
      -v example_data:/dest \
      -v "$(pwd)":/backup \
      alpine sh -c "rm -rf /dest/* && tar xzf /backup/$RESTORE_FILE -C /dest" \
      && echo -e "\e[93;42m Restore complete! \e[0m Run \e[96mdocker compose up -d\e[0m to start your environment again." \
      || echo "\e[93;41m ERROR: \e[0m Restore failed!"
  fi
else
  echo -e "\e[93;41m ERROR: \e[0m File \e[96m${RESTORE_FILE}\e[0m not found."
fi
