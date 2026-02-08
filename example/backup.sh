#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_example_${TIMESTAMP}.tar.gz"

echo "Creating backup: ${BACKUP_NAME}..."
MSYS_NO_PATHCONV=1 docker run --rm \
  -v example_data:/source \
  -v $(pwd):/backup \
  alpine tar czf /backup/${BACKUP_NAME} -C /source .

# Verification
if [ -f "${BACKUP_NAME}" ]; then
  echo "Done! Snapshot saved to ${BACKUP_NAME}"
  echo "Contents summary:"
  tar -tf "${BACKUP_NAME}" | head -n 5
else
  echo "ERROR: Backup file was not created."
fi
