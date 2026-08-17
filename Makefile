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
BUILDS_PATH ?= builds
NOTARY_PROFILE ?= conjuror-notary
DIRECT_EXPORT_OPTIONS := export.plist
EXPORTED_APP := $(EXPORT_PATH)/Conjuror.app
ARCHIVED_DSYM := $(ARCHIVE_PATH)/dSYMs/Conjuror.app.dSYM
NOTARIZATION_ARCHIVE := $(NOTARIZATION_PATH)/Conjuror.zip

.PHONY: all build test archive notarize export zip generate-emoji format lint clean

all: build

build:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) build

test:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) test

archive:
	rm -rf "$(ARCHIVE_PATH)"
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=macOS' -archivePath "$(ARCHIVE_PATH)" \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym archive
	@test -d "$(ARCHIVE_PATH)/dSYMs/Conjuror.app.dSYM" || \
		(echo "Archive is missing Conjuror.app.dSYM" >&2; exit 1)

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

zip:
	@test -d "$(EXPORTED_APP)" || (echo "Missing exported app; run 'make notarize' first" >&2; exit 1)
	@test -d "$(ARCHIVED_DSYM)" || (echo "Missing dSYM; run 'make archive' first" >&2; exit 1)
	xcrun stapler validate "$(EXPORTED_APP)"
	@version=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(EXPORTED_APP)/Contents/Info.plist"); \
	build=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(EXPORTED_APP)/Contents/Info.plist"); \
	output="$(BUILDS_PATH)/conjuror-$$version-$$build.zip"; \
	symbols="$(BUILDS_PATH)/conjuror-$$version-$$build.dSYM.zip"; \
	mkdir -p "$(BUILDS_PATH)"; \
	rm -f "$$output" "$$symbols"; \
	ditto -c -k --keepParent "$(EXPORTED_APP)" "$$output"; \
	ditto -c -k --keepParent "$(ARCHIVED_DSYM)" "$$symbols"; \
	echo "Created $$output"; \
	echo "Created $$symbols"

generate-emoji:
	node scripts/generate_emoji.js

format:
	$(SWIFT_FORMAT) format --configuration .swift-format --in-place --parallel --recursive $(SWIFT_SOURCES)

lint:
	$(SWIFT_FORMAT) lint --configuration .swift-format --parallel --recursive --strict $(SWIFT_SOURCES)

clean:
	$(XCODEBUILD) $(XCODEBUILD_ARGS) clean
