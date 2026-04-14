Immutable infrastructure
- Immutable infrastructure is a paradigm in which servers are never modified after they are deployed. If a change is needed, a new server is provisioned with the updated configuration, and the old server is decommissioned.
- It provides stability, efficiency, and fidelity to your applications through automation and the use of successful patterns from programming.
- This approach leads to more predictable and reliable deployments, as the environment remains consistent and eliminates configuration drift.
- No rigorous or standardized definition of immutable infrastructure exists yet, but the basic idea is that you create and operate your infrastructure using the programming concept of immutability: once you instantiate something, you never change it. Instead, you replace it with another instance to make changes or ensure proper behavior.
- This approach is often implemented using infrastructure as code (IaC) tools, which allow you to define and manage your infrastructure in a declarative manner. With IaC, you can version control your infrastructure configurations, making it easier to track changes and roll back if necessary.
- There are a variety of reasons artisanally maintained infrastructure composed of traditional, long-lived (and therefore mutable) components is insufficient to the task of operating modern, distributed services in the cloud.
    - Increasing operational complexity
    - Slower deployments, more failures
    - Identifying errors and threats in order to mitigate harm
    - Fire drills
- The benefits of immutable infrastructure are manifold if applied appropriately to your application and have fully automated deployment and recovery methods for your infrastructure.
    - Simplifying operations
    - Continuous deployments, fewer failures
    - Reduces errors and threats
    - No problem with cloud reboot
- Tools like Docker and Kubernetes facilitate immutable infrastructure by allowing developers to package applications and their dependencies into containers that can be easily deployed and scaled.
- These tools also support the principles of immutability by enabling the creation of disposable, stateless components that can be replaced rather than modified.

12 Factor App
- The 12-factor app methodology is a set of best practices for building modern, cloud-native applications. It emphasizes the importance of treating your application as a single unit that can be easily deployed and scaled.
- Some key principles include:
    - Codebase: One codebase tracked in version control, many deploys.
    - Dependencies: Explicitly declare and isolate dependencies.
    - Config: Store configuration in the environment.
    - Backing services: Treat backing services as attached resources.
    - Build, release, run: Strictly separate build and run stages.
    - Processes: Execute the app as one or more stateless processes.
    - Port binding: Export services via port binding.
    - Concurrency: Scale out via the process model.
    - Disposability: Maximize robustness with fast startup and graceful shutdown.
    - Dev/prod parity: Keep development, staging, and production as similar as possible.
    - Logs: Treat logs as event streams.
    - Admin processes: Run admin/management tasks as one-off processes.
- The 12-factor app methodology is closely aligned with the principles of immutable infrastructure, as both approaches emphasize the importance of automation, consistency, and reproducibility in the deployment and management of applications.
- Both methodologies advocate for treating infrastructure and applications as disposable, allowing for easier updates and rollbacks.

Container Lifetime & Persisting Data
- Containers are usually immutable and ephemeral, meaning that any data created inside a container is lost when the container is stopped or destroyed.
- Immutable infrastructure: only re-deploy containers, never change them.
- Docker gives features to ensure a separation of concerns between the application and its data (persisting data).
- By default all files created inside a container are stored on a writable container layer that sits on top of the read-only, immutable image layers.
- Data written to the container layer doesn't persist when the container is destroyed. This means that it can be difficult to get the data out of the container if another process needs it.
- The writable layer is unique per container. You can't easily extract the data from the writeable layer to the host, or to another container.
- Docker supports the following types of storage mounts for storing data outside of the writable layer of the container:
    - Volume mounts
    - Bind mounts
    - tmpfs mounts
    - Named pipes
- No matter which type of mount you choose to use, the data looks the same from within the container. It is exposed as either a directory or an individual file in the container's filesystem.

Volume mounts
- Volumes are persistent storage mechanisms managed by the Docker daemon. They retain data even after the containers using them are removed. Volume data is stored on the filesystem on the host, but in order to interact with the data in the volume, you must mount the volume to a container. Directly accessing or interacting with the volume data is unsupported, undefined behavior, and may result in the volume or its data breaking in unexpected ways.
- Volumes are ideal for performance-critical data processing and long-term storage needs. Since the storage location is managed on the daemon host, volumes provide the same raw file performance as accessing the host filesystem directly.
- You need to remove volumes manually when they are no longer needed, as they persist beyond the lifecycle of individual containers.

Commands
- docker container run [OPTIONS] IMAGE [COMMAND] [ARG...]
    - -v <volume>:<container_path> (Mount a volume into the container)
- docker volume COMMAND
    - ls (List all volumes)
    - create [OPTIONS] [VOLUME] (Create a new volume)
    Required to do this before docker run to use custom drivers and labels
        - --driver DRIVER (Specify volume options and labels)
        - -o <opt> (Set an option for the volume driver)
        - --label <key=value> (Set a label or metadata on the volume)
    - rm [VOLUME] (Remove a volume)
    - inspect [VOLUME] (Display detailed information about a volume)
    - prune (Remove all unused local volumes)
- On dockerfile
    - VOLUME [DIRECTORY] (It creates a mount point with the specified path and marks it as holding externally mounted volumes)

Bind mounts
- Bind mounts create a direct link between a host system path and a container, allowing access to files or directories stored anywhere on the host. Since they aren't isolated by Docker, both non-Docker processes on the host and container processes can modify the mounted files simultaneously.
- Use bind mounts when you need to be able to access files from both the container and the host.

Commands
- docker container run [OPTIONS] IMAGE [COMMAND] [ARG...]
    - -v <host_path>:<container_path> (Mount a host path into the container)

tmpfs mounts
- A tmpfs mount stores files directly in the host machine's memory, ensuring the data is not written to disk. This storage is ephemeral: the data is lost when the container is stopped or restarted, or when the host is rebooted. tmpfs mounts do not persist data either on the Docker host or within the container's filesystem.
- These mounts are suitable for scenarios requiring temporary, in-memory storage, such as caching intermediate data, handling sensitive information like credentials, or reducing disk I/O. Use tmpfs mounts only when the data does not need to persist beyond the current container session.

Named pipes
- Named pipes can be used for communication between the Docker host and a container. Common use case is to run a third-party tool inside of a container and connect to the Docker Engine API using a named pipe.

How file permissions work across multiple containers accessing the same volume or bind-mount

At some point you'll have file permissions problems with container apps not having the permissions they need. Maybe you want multiple containers to access the same volume(s). Or maybe you're bind-mounting existing files into a container.

Note that the below info is about pure Linux hosts, like production server setups. If you're using Docker Desktop locally, it will translate permissions from your host (macOS & Windows) into the container (Linux) automatically, but when working on pure Linux servers with just dockerd, no translation is made.

How file permissions work across multiple containers accessing the same volume or bind-mount
- File ownership between containers and the host are just numbers. They stay consistent no matter how you run them. Sometimes you see friendly user names in commands like ls but those are just name-to-number aliases that you'll see in `/etc/passwd` and `/etc/group`.
- Your host has those files, and usually, your containers will have their own. They are usually different. These files are really just for humans to see friendly names. The Linux Kernel only cares about IDs, which are attached to each file and directory in the file system itself, and those IDs are the same no matter which process accesses them.
- When a container is just accessing its own files, this isn't usually an issue.
- But for multiple containers accessing the same volume or bind-mount, problems can arise in two ways:

1. Problem one: The `/etc/passwd` is different across containers. Creating a named user in one container and running as that user may use ID 700, but that same name in another container with a different `/etc/passwd` may use a different ID for that same username. That's why I only care about IDs when trying to sync up permissions. You'll see this confusion if you're running a container on a Linux VM and it had a volume or bind-mount. If you do an ls on those files from the host, it may show them owned by ubuntu or node or systemd, etc. Then if you run ls inside the container, it may show a different friendly username. The IDs are the same in both cases, but the host will have a different passwd file than the container, and show you different friendly names. Different names are fine, because it's only ID that counts. Two processes trying to access the same file must have a matching user ID or group ID.

2. Problem two: Your two containers are running as different users. Maybe the user/group IDs and/or the USER statement in your Dockerfiles are different, and the two containers are technically running under different IDs. Different apps will end up running as different IDs. For example, the node base image creates a user called node with ID of 1000, but the NGINX image creates an nginx user as ID 101. Also, some apps spin-off sub-processes as different users. NGINX starts its main process (PID 1) as root (ID 0) but spawns sub-processes as the nginx user (ID 101), which keeps it more secure.

So for troubleshooting, this is what I do:
1. Use the command ps aux in each container to see a list of processes and usernames. The process needs a matching user ID or group ID to access the files in question.

2. Find the UID/GID in each containers `/etc/passwd` and `/etc/group` to translate names to numbers. You'll likely find there a miss-match, where one containers process originally wrote the files with its UID/GID and the other containers process is running as a different UID/GID.

3. Figure out a way to ensure both containers are running with either a matching user ID or group ID. This is often easier to manage in your own custom app (when using a language base image like python or node) rather than trying to change a 3rd party app's container (like nginx or postgres)... but it all depends. This may mean creating a new user in one Dockerfile and setting the startup user with USER. (explain about USER) The node default image has a good example of the commands for creating a user and group with hard-coded IDs:

RUN groupadd --gid 1000 node \\
        && useradd --uid 1000 --gid node --shell /bin/bash --create-home node
USER 1000:1000

- When setting a Dockerfile's USER, use numbers, which work better in Kubernetes than using names.
- If ps doesn't work in your container, you may need to install it. In debian-based images with apt, you can add it with apt-get update && apt-get install procps