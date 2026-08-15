PROJECT := Conjuror.xcodeproj
SCHEME := Conjuror
DERIVED_DATA_PATH := .derivedData
XCODEBUILD := xcodebuild
ARCH := $(shell uname -m)
XCODEBUILD_ARGS := -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA_PATH) -destination 'platform=macOS,arch=$(ARCH)'
SWIFT_FORMAT := swift format
SWIFT_SOURCES := Conjuror ConjurorTests
ARCHIVE_PATH ?= $(DERIVED_DATA_PATH)/Archives/Conjuror.xcarchive
EXPORT_PATH ?= $(DERIVED_DATA_PATH)/Export
NOTARIZATION_PATH ?= $(DERIVED_DATA_PATH)/Notarization
NOTARY_PROFILE ?= conjuror-notary
DIRECT_EXPORT_OPTIONS := export.plist
EXPORTED_APP := $(EXPORT_PATH)/Conjuror.app
NOTARIZATION_ARCHIVE := $(NOTARIZATION_PATH)/Conjuror.zip

.PHONY: all build test archive notarize export generate-emoji format lint clean

all: build

build:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) build

test:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) test

archive:
	rm -rf "$(ARCHIVE_PATH)"
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=macOS' -archivePath "$(ARCHIVE_PATH)" archive

notarize: export
	rm -rf "$(NOTARIZATION_PATH)"
	mkdir -p "$(NOTARIZATION_PATH)"
	ditto -c -k --keepParent "$(EXPORTED_APP)" "$(NOTARIZATION_ARCHIVE)"
	xcrun notarytool submit "$(NOTARIZATION_ARCHIVE)" \
		--keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(EXPORTED_APP)"
	xcrun stapler validate "$(EXPORTED_APP)"

export:
	@test -d "$(ARCHIVE_PATH)" || (echo "Missing archive; run 'make archive' first" >&2; exit 1)
	rm -rf "$(EXPORT_PATH)"
	$(XCODEBUILD) -exportArchive -archivePath "$(ARCHIVE_PATH)" \
		-exportPath "$(EXPORT_PATH)" -exportOptionsPlist "$(DIRECT_EXPORT_OPTIONS)" \
		-allowProvisioningUpdates

generate-emoji:
	node scripts/generate_emoji.js

format:
	$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive $(SWIFT_SOURCES)

lint:
	$(SWIFT_FORMAT) lint --configuration .swift-format --parallel --recursive --strict $(SWIFT_SOURCES)

clean:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) clean
