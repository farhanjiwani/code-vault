#!/usr/bin/env bats

setup() {
  # Create a temp dir for each test
  export TEST_DIR="$(mktemp -d)"
  export SCRIPT_NAME="config-project.sh"
  
  # Copy the script to temp dir
  cp "./${SCRIPT_NAME}" "${TEST_DIR}/"
  cd "${TEST_DIR}"
  chmod +x "${SCRIPT_NAME}"
}

teardown() {
  # Clean up temp dir after each test
  rm -rf "${TEST_DIR}"
}

@test "Generates standard project files via environment injection" {
  export PROJ_NAME="test_vault"
  export USER_UID="1000"
  export PROJ_PORTS="8080 3000"
  export CPUS="1.0"
  export MEM="2G"
  export APT_PKGS="nano"
  export CUSTOM_DNS="1.1.1.1"
  export AUTO_BUILD="n"
  export SAVE_CONF="n"

  run ./${SCRIPT_NAME}

  # Assert the script exited w/ success
  [ "$status" -eq 0 ]

  # Assert dirs and files were created
  [ -d "test_vault" ]
  [ -f "test_vault/Dockerfile" ]
  [ -f "test_vault/docker-compose.yml" ]
  [ -f "test_vault/backup.sh" ]
  [ -f "test_vault/restore.sh" ]
  [ -f "test_vault/backup-memory.sh" ]
  [ -f "test_vault/import.sh" ]
  [ -f "test_vault/.env" ]
  [ -f "test_vault/.dockerignore" ]
}

@test "Validates dynamic variable interpolation in Dockerfile" {
  export PROJ_NAME="dynamic_test"
  export USER_UID="2000"
  export PROJ_PORTS="5173"
  export CPUS="1.0"
  export MEM="2G"
  export APT_PKGS="htop"
  export CUSTOM_DNS=""
  export AUTO_BUILD="n"
  export SAVE_CONF="n"

  run ./${SCRIPT_NAME}

  [ "$status" -eq 0 ]
  cd dynamic_test

  # Check that node version and apt packages are injected correctly
  run grep "node:24.18.0-bookworm-slim" Dockerfile
  [ "$status" -eq 0 ]

  run grep "htop" Dockerfile
  [ "$status" -eq 0 ]
}

@test "Validates dynamic variables and blocks in docker-compose.yml" {
  export PROJ_NAME="compose_test"
  export USER_UID="1500"
  export PROJ_PORTS="9000"
  export CPUS="2.0"
  export MEM="4G"
  export APT_PKGS="vim"
  export CUSTOM_DNS="1.0.0.1"
  export AUTO_BUILD="n"
  export SAVE_CONF="n"

  run ./${SCRIPT_NAME}

  [ "$status" -eq 0 ]
  cd compose_test

  # Check container name and port bindings
  run grep "container_name: compose_test_container" docker-compose.yml
  [ "$status" -eq 0 ]

  # Verify specific content was injected into the generated files
  run grep "127.0.0.1:9000:9000" docker-compose.yml
  [ "$status" -eq 0 ]

  # Check tmpfs UID injection
  run grep "uid=1500,gid=1500" docker-compose.yml
  [ "$status" -eq 0 ]

  run grep "1.0.0.1" docker-compose.yml
  [ "$status" -eq 0 ]
}

@test "Validates utility scripts reference correct project name and UID" {
  export PROJ_NAME="script_test"
  export USER_UID="1750"
  export PROJ_PORTS="5173"
  export CPUS="1.0"
  export MEM="2G"
  export APT_PKGS="vim"
  export CUSTOM_DNS=""
  export AUTO_BUILD="n"
  export SAVE_CONF="n"

  run ./${SCRIPT_NAME}

  [ "$status" -eq 0 ]
  cd script_test

  # Check backup script references volume
  run grep "script_test_data" backup.sh
  [ "$status" -eq 0 ]

  # Check restore script references volume
  run grep "script_test_data" restore.sh
  [ "$status" -eq 0 ]

  # Check import script references custom UID for chown
  run grep "chown -R 1750:1750" import.sh
  [ "$status" -eq 0 ]
}

@test "Bypasses wizard when .harness-config exists and user confirms" {
  # Pre-seed a config file
  cat <<'EOF' > .harness-config
PROJ_NAME="preseeded_vault"
USER_UID="1000"
PROJ_PORTS="3000"
CPUS="1.0"
MEM="2G"
APT_PKGS="vim"
CUSTOM_DNS=""
NODE_VERSION="24.18.0"
AUTO_BUILD="n"
EOF

  # Pipe 'y' to confirm using the existing config
  run bash -c "echo 'y' | ./${SCRIPT_NAME}"
  
  [ "$status" -eq 0 ]
  [ -d "preseeded_vault" ]
  [ -f "preseeded_vault/docker-compose.yml" ]
}
