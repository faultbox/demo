# demo.star — Order + Inventory system
#
# order-svc (HTTP) → inventory-svc (TCP + WAL)
#
# Linux:  faultbox test demo.star
# macOS:  make lima-test

# --- Binary paths ---
# Linux (native): BIN = "bin"
# macOS (Lima):   BIN = "bin/linux"
BIN = "bin/linux"

# --- Topology ---

inventory = service("inventory",
    BIN + "/inventory-svc",
    interface("main", "tcp", 5432),
    env = {"PORT": "5432", "WAL_PATH": "/tmp/inventory.wal"},
    healthcheck = tcp("localhost:5432"),
)

orders = service("orders",
    BIN + "/order-svc",
    interface("public", "http", 8080),
    env = {"PORT": "8080", "INVENTORY_ADDR": inventory.main.addr},
    depends_on = [inventory],
    healthcheck = http("localhost:8080/health"),
)

# --- Tests ---

def test_happy_path():
    """Place an order — stock reserved, WAL written."""
    resp = orders.get(path="/inventory/widget")
    assert_eq(resp.status, 200)
    assert_true("100" in resp.body, "expected 100 widgets in stock")

    resp = orders.post(path="/orders", body='{"sku":"widget","qty":1}')
    assert_eq(resp.status, 200)
    assert_true("confirmed" in resp.body, "expected confirmed order")

    resp = orders.get(path="/inventory/widget")
    assert_eq(resp.status, 200)
    assert_true("99" in resp.body, "expected 99 widgets after reservation")

def test_inventory_slow():
    """Inventory writes delayed 500ms — order still succeeds but slow."""
    def scenario():
        resp = orders.post(path="/orders", body='{"sku":"gadget","qty":1}')
        assert_eq(resp.status, 200)
        assert_true(resp.duration_ms > 400, "expected delay > 400ms")
    fault(inventory, write=delay("500ms"), run=scenario)

def test_inventory_unreachable():
    """Order service can't connect to inventory — returns 503."""
    def scenario():
        resp = orders.post(path="/orders", body='{"sku":"widget","qty":1}')
        assert_eq(resp.status, 503)
    fault(orders, connect=deny("ECONNREFUSED"), run=scenario)

def test_wal_fsync_failure():
    """WAL fsync fails — reservation should fail."""
    def scenario():
        resp = orders.post(path="/orders", body='{"sku":"gizmo","qty":1}')
        assert_true(resp.status != 200, "expected failure on fsync deny")
    fault(inventory, fsync=deny("EIO"), run=scenario)

def test_disk_full():
    """WAL write fails with ENOSPC."""
    def scenario():
        resp = orders.post(path="/orders", body='{"sku":"widget","qty":1}')
        assert_true(resp.status != 200, "expected failure on disk full")
    fault(inventory, write=deny("ENOSPC"), run=scenario)

scenario(test_happy_path)
