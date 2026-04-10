.PHONY: build build-linux clean lima-create lima-start lima-stop lima-build lima-test

BIN := bin
LIMA_VM := faultbox-dev

# ─── Build (native) ──────────────────────────────────────────

build:
	@mkdir -p $(BIN)
	go build -o $(BIN)/target         ./target/
	go build -o $(BIN)/mock-db        ./mock-db/
	go build -o $(BIN)/mock-api       ./mock-api/
	go build -o $(BIN)/inventory-svc  ./inventory-svc/
	go build -o $(BIN)/order-svc      ./order-svc/
	@echo "Built: $(BIN)/"

clean:
	rm -rf $(BIN)

# ─── Cross-compile for Lima VM (macOS → linux/arm64) ─────────

LINUX_BIN := $(BIN)/linux

build-linux:
	@mkdir -p $(LINUX_BIN)
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o $(LINUX_BIN)/target         ./target/
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o $(LINUX_BIN)/mock-db        ./mock-db/
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o $(LINUX_BIN)/mock-api       ./mock-api/
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o $(LINUX_BIN)/inventory-svc  ./inventory-svc/
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o $(LINUX_BIN)/order-svc      ./order-svc/
	@echo "Built: $(LINUX_BIN)/"

# ─── Lima VM management (macOS) ──────────────────────────────

lima-create:
	@echo "Creating Lima VM '$(LIMA_VM)'..."
	limactl create --name=$(LIMA_VM) lima/faultbox-dev.yaml --tty=false
	limactl start $(LIMA_VM)
	@echo "VM ready. Run: make lima-build"

lima-start:
	limactl start $(LIMA_VM)

lima-stop:
	limactl stop $(LIMA_VM)

# Build demo binaries + install faultbox inside Lima
lima-build: build-linux
	@echo "Installing faultbox in Lima VM..."
	limactl shell $(LIMA_VM) -- sudo bash -c '\
		export PATH=/usr/local/bin:$$PATH; \
		if ! command -v faultbox >/dev/null 2>&1; then \
			curl -fsSL https://faultbox.io/install.sh | FAULTBOX_DIR=/usr/local/bin sh; \
		else \
			echo "faultbox already installed: $$(faultbox --version)"; \
		fi'
	@echo "Ready. Run: make lima-test"

# Run tutorial tests inside Lima
lima-test:
	limactl shell --workdir /host-home/$${PWD\#$$HOME/} $(LIMA_VM) -- \
		faultbox test demo.star

# Run a command inside Lima (usage: make lima-run CMD="faultbox --help")
lima-run:
	limactl shell --workdir /host-home/$${PWD\#$$HOME/} $(LIMA_VM) -- $(CMD)
