APP := build/Waddle On.app
CONFIG ?= release

.PHONY: app run install test clean
app:
	swift build -c $(CONFIG)
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	cp Support/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp ".build/$(CONFIG)/WaddleOn" "$(APP)/Contents/MacOS/WaddleOn"
	cp -R ".build/$(CONFIG)/WaddleOn_WaddleOn.bundle" "$(APP)/Contents/Resources/"
	codesign --force --deep --sign - "$(APP)"

run: app
	open "$(APP)"

install: app
	ditto "$(APP)" "/Applications/Waddle On.app"

test:
	swift test

clean:
	swift package clean
