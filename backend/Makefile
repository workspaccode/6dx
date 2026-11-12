# 6DX backend — local development helpers.
#
#   make run       foreground: go run ./cmd/api (Ctrl+C to stop)
#   make start     background: builds .run/6dx-api.exe, waits for /health
#   make stop      stops .run/api.pid, or a `go run` holding the port
#   make restart
#   make status    which process owns the port, and whether it is healthy
#   make logs      follow .run/api.log
#   make test      go vet + unit + integration suites
#   make fmt       gofmt the tree
#
# `make` is a convenience wrapper; the script works on its own too:
#   powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 start
#
# The listen address comes from ADDR in .env (default :8080). Override it for a
# one-off run with `$env:ADDR=':8099'; make start`.

SERVE := powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1

.PHONY: run start stop restart status logs test fmt tidy

run:
	$(SERVE) run

start:
	$(SERVE) start

stop:
	$(SERVE) stop

restart:
	$(SERVE) restart

status:
	$(SERVE) status

logs:
	$(SERVE) logs

test:
	go vet ./...
	go test ./...
	go test -tags=integration ./...

fmt:
	gofmt -w .

tidy:
	go mod tidy
