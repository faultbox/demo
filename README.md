# Faultbox Demo

Demo services for the [Faultbox tutorial](https://faultbox.io/docs).

## What's inside

| Service | Description | Used in |
|---------|-------------|---------|
| `target/` | Minimal binary (write + HTTP) | Chapter 1 |
| `mock-db/` | TCP key-value store | Chapters 2-3 |
| `mock-api/` | HTTP API wrapping mock-db | Chapters 2-3 |
| `inventory-svc/` | TCP service with WAL | Chapters 4-6 |
| `order-svc/` | HTTP API calling inventory | Chapters 4-6 |

## Quick start

### 1. Install Faultbox

```bash
curl -fsSL https://faultbox.io/install.sh | sh
```

### 2. Clone this repo

```bash
git clone https://github.com/faultbox/demo.git
cd demo
```

### 3. Build and run

**Linux (native):**

```bash
make build
faultbox test first-test.star
faultbox test demo.star
```

**macOS (via Lima VM):**

```bash
brew install lima               # if not installed
make lima-create                # one-time VM setup (~3 min)
make lima-build                 # cross-compile + install faultbox in VM
make lima-test                  # run demo.star inside VM
```

Or run any command inside the VM:

```bash
make lima-run CMD="faultbox test first-test.star"
make lima-run CMD="faultbox run --fault 'write=EIO:100%' bin/linux/target"
```

## Specs

| File | Services | What it tests |
|------|----------|---------------|
| `first-test.star` | mock-db, mock-api | Ping, set/get, happy path, write fault |
| `demo.star` | inventory-svc, order-svc | Happy path, slow writes, unreachable, fsync, disk full |

## Lima VM

The Lima VM provides a Linux kernel with seccomp-notify support.
Your Mac's home directory is mounted at `/host-home/` — binaries
built on macOS (cross-compiled) are accessible inside the VM.

| Command | Description |
|---------|-------------|
| `make lima-create` | Create and start the VM (one-time) |
| `make lima-start` | Start a stopped VM |
| `make lima-stop` | Stop the VM |
| `make lima-build` | Cross-compile binaries + install faultbox |
| `make lima-test` | Run demo.star inside the VM |
| `make lima-run CMD="..."` | Run any command inside the VM |

## Tutorial

Follow the [full tutorial](https://faultbox.io/docs/tutorial/00-prelude/00-setup)
starting from Chapter 0.
