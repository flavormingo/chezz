.PHONY: bootstrap generate open nnue test build clean

XCODEGEN := $(shell command -v xcodegen 2>/dev/null)
SIM ?= platform=iOS Simulator,name=iPhone 16 Pro

bootstrap:
	@if [ -z "$(XCODEGEN)" ]; then echo "→ Installing XcodeGen…"; brew install xcodegen; fi
	@$(MAKE) generate
	@echo "→ Fetching Stockfish neural nets (needed for AI + Review)…"
	@./scripts/fetch-nnue.sh || echo "⚠️  NNUE fetch failed — run ./scripts/fetch-nnue.sh later."
	@$(MAKE) open

generate:
	xcodegen generate

open:
	open chezz.xcodeproj

nnue:
	./scripts/fetch-nnue.sh

build: generate
	xcodebuild -project chezz.xcodeproj -scheme chezz \
		-destination '$(SIM)' -derivedDataPath DerivedData \
		CODE_SIGNING_ALLOWED=NO build

# serial: the engine-heavy tests contend with each other under parallel runs.
test: generate
	xcodebuild -project chezz.xcodeproj -scheme chezz \
		-destination '$(SIM)' CODE_SIGNING_ALLOWED=NO \
		-parallel-testing-enabled NO test

clean:
	rm -rf chezz.xcodeproj DerivedData
