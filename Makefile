BINARY := build/hermes
GOLANGCI_LINT ?= golangci-lint
PROTO_BREAKING_AGAINST ?= https://github.com/heliantheon/hermes.git\#tag=schema/v1.0.0,subdir=proto

.PHONY: build run test lint proto-lint proto-breaking generate check-generate fmt tidy clean

build:
	CGO_ENABLED=0 go build -o $(BINARY) .

run:
	go run ./main.go

test:
	go test ./...

lint:
	$(GOLANGCI_LINT) run ./...

proto-lint:
	cd proto && buf lint

proto-breaking:
	cd proto && buf breaking --against "$(PROTO_BREAKING_AGAINST)"

generate:
	cd proto && buf generate

check-generate: generate
	@git diff --exit-code -- internal/grpc/v1

fmt:
	go fmt ./...

tidy:
	go mod tidy

clean:
	rm -rf build
