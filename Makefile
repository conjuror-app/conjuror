PROJECT := Conjuror.xcodeproj
SCHEME := Conjuror
DERIVED_DATA_PATH := .derivedData
XCODEBUILD := xcodebuild
ARCH := $(shell uname -m)
XCODEBUILD_ARGS := -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA_PATH) -destination 'platform=macOS,arch=$(ARCH)'
SWIFT_FORMAT := swift format
SWIFT_SOURCES := Conjuror ConjurorTests

.PHONY: all build test generate-emoji format lint clean

all: build

build:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) build

test:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) test

generate-emoji:
	node scripts/generate_emoji.js

format:
	$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive $(SWIFT_SOURCES)

lint:
	$(SWIFT_FORMAT) lint --configuration .swift-format --parallel --recursive --strict $(SWIFT_SOURCES)

clean:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) clean
