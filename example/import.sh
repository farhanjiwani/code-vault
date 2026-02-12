#!/bin/bash

echo -e "\e[94m--- Code Vault Import ---\e[0m"
echo -e "\e[33mThis will copy files from your CURRENT folder into the container.\e[0m"
read -p $'\n\e[93;44m Are you in the root of the project you want to import? (y/n): \e[0m " CONFIRM

if [ "$CONFIRM" == "y" ]; then
  echo -e "\e[33mCopying files..."
  # Copy current directory contents into /app inside the container
  MSYS_NO_PATHCONV=1 docker cp . example_container:/app

  echo "Fixing permissions..."
  # Ensure node owns the new files
  docker exec -u root example_container chown -R node:node /app

  echo -e "\e[92m✓ Import Complete!\e[0m"
  echo "You can now \e[96mc-enter\e[0m the vault."
else
  echo "\e[93;41m Aborting. \e[0;96m Please navigate to the source code folder first.\e[0m"
fi
