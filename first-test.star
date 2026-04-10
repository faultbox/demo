# first-test.star — Your first Faultbox test (Chapters 2-3)
#
# Linux:  faultbox test first-test.star
# macOS:  make lima-run CMD="faultbox test first-test.star"

# Linux (native): BIN = "bin"
# macOS (Lima):   BIN = "bin/linux"
BIN = "bin/linux"

db = service("db", BIN + "/mock-db",
    interface("main", "tcp", 5432),
    healthcheck = tcp("localhost:5432"),
)

api = service("api", BIN + "/mock-api",
    interface("public", "http", 8080),
    env = {"PORT": "8080", "DB_ADDR": db.main.addr},
    depends_on = [db],
    healthcheck = http("localhost:8080/health"),
)

def test_ping():
    resp = db.main.send(data="PING")
    assert_eq(resp, "PONG")

def test_set_and_get():
    db.main.send(data="SET greeting hello")
    resp = db.main.send(data="GET greeting")
    assert_eq(resp, "hello")

def test_happy_path():
    resp = api.post(path="/data/mykey", body="myvalue")
    assert_eq(resp.status, 200)
    resp = api.get(path="/data/mykey")
    assert_eq(resp.status, 200)
    assert_eq(resp.body, "myvalue")

def test_write_failure():
    """DB writes fail — API should return 500."""
    def scenario():
        resp = api.post(path="/data/failkey", body="value")
        assert_true(resp.status >= 500, "expected 5xx on write failure")
    fault(db, write=deny("EIO", label="disk failure"), run=scenario)
