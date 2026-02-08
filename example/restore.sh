#!/bin/bash
echo "Available backups in this folder:"
ls -1 *.tar.gz 2>/dev/null || echo "No backups found."

read -p "Enter the full filename of the backup to restore: " RESTORE_FILE

if [ -f "$RESTORE_FILE" ]; then
  echo "Warning: This will wipe the current project volume and replace it with the backup."
  read -p "Are you sure? (y/n): " CONFIRM
  if [ "$CONFIRM" == "y" ]; then
    echo "Stopping containers to ensure a safe restore..."
    docker-compose stop
    echo "Restoring data..."
    MSYS_NO_PATHCONV=1 docker run --rm \
      -v example_data:/dest \
      -v $(pwd):/backup \
      alpine sh -c "rm -rf /dest/* && tar xzf /backup/$RESTORE_FILE -C /dest" \
      && echo "Restore complete! Run 'docker-compose up -d' to start your environment again." \
      || echo "ERROR: Restore failed!"
  fi
else
  echo "Error: File '$RESTORE_FILE' not found."
fi
