<h1 align="center">
    Code Vault
</h1>

<p align="center">
  <a href="https://github.com/farhanjiwani/code-vault/releases"><img alt="GitHub Release" src="https://img.shields.io/github/v/release/farhanjiwani/code-vault"></a> <a href="https://github.com/farhanjiwani/code-vault/commits/main/"><img alt="GitHub commits since latest release" src="https://img.shields.io/github/commits-since/farhanjiwani/code-vault/latest"></a>
  <br />
  <a href="https://github.com/farhanjiwani/code-vault/releases"><img alt="GitHub Downloads (specific asset, latest release)" src="https://img.shields.io/github/downloads/farhanjiwani/code-vault/latest/v1.2.0.zip"></a>
</p>

---

## Safe & Secure Claude Code Sandbox Environment

- Isolated Docker container to keep your OS and filesystem safe from malicious prompt injections which may occur during development.
- Uses named volume (rather than bind mount) for an air gap such that Claude cannot touch your file system's files.
- Lightweight.
- Easily clone the state of one container to new ones
- Not using Docker Desktop AI Sandbox due to it's _black box-iness_.

---

## Before You Begin...

> ⚠
> **Use at your own risk!**
> ⚠

I am not responsible for any harm or loss that occurs while using this script or the containers it has created. Use your own caution when dealing with AI tools such as Claude.

This script has been tested on (so far):

- [x] Windows (WSL)
- [x] Windows (Git BASH)
- [ ] Linux
- [ ] Mac

### UID Remapping

**For extra security,** to prevent "container scapes", make sure the UID for the user within the container (username: _node_), doesn't match the UID of the user running the container.

The default generated Dockerfile in this script maps user _node_ to UID 5001. Check what your UID is and change the UID for _node_ if it still matches.

```bash
# Outside of the container (WSL or Git BASH)
# Get your username
whoami

# Get your ID
id -u <YOUR_USERNAME>
# OR (Alternative method)
echo $UID
```

## Why Docker?

While alternatives like [Podman](https://podman.io) offer rootless security by default, **Code Vault** uses Docker for several key reasons:

- **WSL/Windows Stability:** Docker Desktop provides the most reliable bridge for volume mounting and networking on Windows hosts.
- **Ecosystem Compatibility:** Many AI agents and development tools expect a Docker-standard environment to function correctly.
- **Predictable Permissions:** The UID/GID mapping (UID 5001) implemented in this script provides a high level of isolation on the host without the complexity of Podman's sub-UID management.

In short: Docker allowed us to build a "Vault" that is secure without being impossible to use on a daily basis.

---

## How to Use

### Building & Starting the Sandbox Container

For Windows, install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) first.

#### Fast n' Easy Mode

- Run `setup-project.sh` in a new project directory and follow the instructions.
- **(Optional):** skip naming step by passing a project name as first argument.
    - `sh setup-project.sh <project_name>`
- **(Optional):** automatically build the container with `--build` (`-b`) as 2nd argument.
    - **(Windows)** Ensure the Docker Desktop is running.
    - `sh setup-project.sh <new_project_name> -b`
    - This will also automatically run `git init` and `npm init -y` from the `/app` directory inside the sandbox, as well as inject a Git-ignored `.env` file there.

#### Manual Mode

- Create project directory
- Copy included `Dockerfile` & `docker-compose.yml` to project directory
    - **SECURITY NOTE:** `tmpfs: /tmp` is required because the filesystem is read-only
    - If desired, update:
        - Node version (`Dockerfile`)
        - Container and named volume names (YML file)
            - **NOTE:** named volume name has 2 fields to update in the YML file
        - Exposed ports (YML file)
- Build & start the container

```bash
# Build (also run this if changes are made to the config)
docker compose up -d --build
```

### Inside the Sandbox

- Enter the sandbox with the `container_name` in the YML file
- Initialize npm project and Git
- If using **Claude Code (API key):**
    - A `.env` file should already exist. If not, copy the included `.env.example` to `/app/.env`
    - Add API key to `.env` file
        - The container will automatically use this key for all prompts.
- Run Claude
- If using **Claude Pro subscription:**
    - Log in with the `/login` command, if not prompted.
    - Go to magic login link provided in your external browser
    - Paste the generated string into the prompt
    - Since `/home/node` is a temporary memory-disk, you will have to log in each time

```bash
# Start the cached version of the container if not already started
docker compose up -d

# Enter the sandbox
docker exec -it [project_name]_container bash

# Init project (first time only)
npm init -y
git init

# Run Claude
claude
```

Everything will be safe in the `[project_name]_data` folder, even if the container is deleted, or Docker is updated, or your computer is turned off.

### Inspecting Code

Use the VSCode Dev Containers extension to edit, save, see Claude's changes in real-time:

- Install "Dev Containers" extension in VSCode
- Start the container
- Click `><` icon in VSCode (bottom-left corner)
- Select "Attach to Running Container..." and select the container
- VSCode will open a new window
    - Looks like local setup
    - But actually you're _inside_ the Docker volume

![Scene from Zoolander where they think the files they are looking for are physically within the computer's chassis](./docs/img/zoolander.gif)

### Stopping the Container

```bash
# Stop and keep container ready
docker compose stop
# OR...
# Stop and remove container
# (but keeps data thanks to named volume)
docker compose down
```

### Helpers

#### Included Aliases (within Code Vault)

| Alias    | Effect                                                                                            |
| :------- | :------------------------------------------------------------------------------------------------ |
| `la`     | Lists all files (including hidden ones) in long format (`-la`).                                   |
| `lsg`    | Lists files with directories shown first.                                                         |
| `..`     | Moves up one directory (`cd ..`).                                                                 |
| `...`    | Moves up two directories (`cd ../..`).                                                            |
| `gfp`    | Fetches all Git remotes and prunes any deleted branches.                                          |
| `gco`    | `git checkout`, e.g., `gco -b feat/new-fature`                                                    |
| `gs`     | `git status`                                                                                      |
| `ga`     | `git add`, e.g., `ga ./src`                                                                       |
| `gd`     | `git diff`                                                                                        |
| `gds`    | `git diff --staged`                                                                               |
| `gl`     | Shows a compact, graphical git log of all branches (`git log --oneline --graph --all`).           |
| `c-exit` | Creates `/app/.vault_memory` if needed, copies Claude’s memory files there, then exits the shell. |

To add/edit/remove, you can either edit the generated `Dockerfile` per project or update `script-setup.sh`. Search for `# Helpful aliases`. Rebuild the container in order to use your changes next time you use the container.

#### Alias Suggestions (for Host)

| Alias     | Command                                             | Purpose                                           |
| :-------- | :-------------------------------------------------- | :------------------------------------------------ |
| `c-up`    | `docker compose up -d`                              | Start container                                   |
| `c-down`  | `docker compose down`                               | Destroy container (Data/Memory is safe in Volume) |
| `c-enter` | `docker exec -it $(basename "$PWD")_container bash` | Jump in                                           |
| `c-logs`  | `docker compose logs -f`                            | View container logs                               |

#### Generated Scripts (for Host)

| Name          | Command               | Purpose                                  |
| :------------ | :-------------------- | :--------------------------------------- |
| Import        | `sh import.sh`        | Bulk import code from host to container  |
| Backup        | `sh backup.sh`        | Backup entire project volume (`.tar.gz`) |
| Backup Memory | `sh backup-memory.sh` | Snapshot Claude's memory to host         |

### 🧠 Migration & Memory Management

The Vault uses a "Warm Start" architecture to keep your AI's context persistent, even though the container's OS (`/home/node`) is reset every time you restart.

#### 1. The "Warm Start" Lifecycle

- **Startup:** The container automatically pulls your last saved `.claude` memory from the secure volume into the fast RAM disk.
- **Work:** You coding with Claude (everything happens in RAM).
- **Exit (`c-exit`):** **CRITICAL step.** Instead of typing `exit`, type `c-exit` inside the container. This syncs your RAM session back to the secure volume before closing.

#### 2. Backing up "The Brain" (Host Side)

To create a permanent, timestamped snapshot of Claude's memory on your Windows host (for long-term storage):

```bash
sh backup-memory.sh
```

- **Location:** `./memory_backup/YYYYMMDD_HHMMSS/`
- **Contains:** Global tool state (`.claude`) and project settings (`.claude.json`).

#### 3. Importing Existing Projects

If you have an existing project folder on Windows that you want to move into a Vault:

1. Run `setup-project.sh my-project -b` to create an empty Vault.
2. Copy your existing code files _into_ that new folder.
3. Run the import script:

```bash
# Handle the `docker cp` & permission fixes automatically
sh import.sh
```

### The "State Cloning" Workflow

Because of Named Volumes usage, the data is essentially a portable "brain" that can be plugged into any body (container) built.

1. Export the Source:
    - Run sh backup.sh in the project folder to create the .tar.gz file.
2. Create the Target:
    - Run ./setup-project.sh [new_project_name] -b to create a fresh, empty environment.
3. Transfer the "Brain":
    - Copy the backup file from the previous project folder into the new one.
4. Inject the State:
    - Run sh restore.sh inside the new project folder and select the copied backup file.

### Network Access

- Docker containers are isolated by default, but to see your project's dev server on other devices, use the `--host` flag from within the container.
    - Example 1 (Vite): `npm run dev -- --host 0.0.0.0`
    - Example 2 (Astro): `npm run dev -- --host`
- Find your computer's IP then navigate to it from any device on your network, including the port number.
    - Example: `http://192.168.1.22:5173`

### Backup/Restore Named Volume

> "Zip it up, and zip it _out!_"

- Use the generated backup and restore shell scripts or do it manually with the commands below.

```bash
# Backup
docker run --rm -v my_project_storage:/source -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz -C /source .

# Restore
docker compose stop
docker run --rm -v your_project_data:/dest -v $(pwd):/backup alpine sh -c "rm -rf /dest/* && tar xzf /backup/your_backup_file.tar.gz -C /dest"
docker compose up -d
```

## Troubleshooting

- Something stuck? Won't start after a restore?
  `docker compose logs -f` will help find exactly what the error could be
- Ensure you are using `docker compose` (no hyphen), as the docker-compose command is deprecated.
- If you encounter permission issues, ensure you haven't changed the `USER_UID` in the script to match your host UID, as this can cause mount conflicts in WSL

### `.bashrc`

The container uses a 'Hydration' system. To permanently change aliases or shell settings, you must update the `Dockerfile` and rebuild, as `/home/node` is a temporary memory-disk for security reasons.

### Reminders

- Always run the npm commands inside the container
- Check file permissions
    - If you get "Permission Denied", run the following:
    - `docker exec -u root [container_name] chown -R node:node /app`
    - `docker compose restart` (recommended after permissions changes)
- Don't forget the `--host` flag to see the server from outside of the container
- Use `git init` **immediately** so Claude can rely on it to see what got changed
- Clear out old, unused image layers once a month to save space:
    - `docker system prune`
    - **!! WARNING !!:** Using the `-a` flag will also delete your volumes!
- Clear the build cache: `docker builder prune -a`
- Clear orphaned networks: `docker network prune`
- Update digests and hashes every 6 months or so to known-good versions

---

## 🤝 Contributing & New Agents

Want to use a different AI agent (like Aider, OpenDevin, or Mentat) inside the Vault? I'd love to see your configurations!

If you've successfully adapted the `setup-project.sh` for another tool, please:

1. **Open an Issue** with the title `Agent: [Agent Name]`
2. **Share your Dockerfile snippet** and any specific `tmpfs` mounts required.

### Contribution Requirements:

To keep the "Vault" secure, all proposed agent configs must:

- Use a **non-root user** (mapped to something like a UID of 5001).
- Support a **read-only filesystem** (using `tmpfs` for caches).
- Stay **minimal** (based on `-slim` images where possible).
