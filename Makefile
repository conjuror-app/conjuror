PROJECT := Conjuror.xcodeproj
SCHEME := Conjuror
DERIVED_DATA_PATH := .derivedData
XCODEBUILD := xcodebuild
XCODEBUILD_ARGS := -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA_PATH)

.PHONY: all build test clean

all: build

build:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) build

test:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) test

clean:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) clean
