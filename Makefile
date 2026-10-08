APP := build/Waddle On.app
CONFIG ?= release
VERSION := 26.10.0
BIN_DIR ?= .build/$(CONFIG)
SWIFT_FLAGS ?=

.PHONY: app run install test clean
app:
	swift build -c $(CONFIG) $(SWIFT_FLAGS)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	cp Support/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp "$(BIN_DIR)/WaddleOn" "$(APP)/Contents/MacOS/WaddleOn"
	cp -R "$(BIN_DIR)/WaddleOn_WaddleOn.bundle" "$(APP)/Contents/Resources/"
	codesign --force --deep --sign - "$(APP)"

run: app
	open "$(APP)"

install: app
	ditto "$(APP)" "/Applications/Waddle On.app"

test:
	swift test

clean:
	swift package clean

.PHONY: dmg
dmg:
	$(MAKE) app CONFIG=release SWIFT_FLAGS="--arch arm64 --arch x86_64" BIN_DIR=".build/apple/Products/Release"
	rm -rf build/dmg
	mkdir -p build/dmg
	ditto "$(APP)" "build/dmg/Waddle On.app"
	ln -sfn /Applications build/dmg/Applications
	hdiutil create -volname "Waddle On" -srcfolder build/dmg -ov -format UDZO "build/Waddle-On.dmg"
