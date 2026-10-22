// Shows a little window and records the next shortcut you press.
// Prints it in macOS notation (@ = ⌘, ~ = ⌥, ^ = ⌃, $ = ⇧), e.g. "@~^l".
// Prints nothing if you cancel (Esc or close the window) or after 60 seconds.
//
//   osascript -l JavaScript record-shortcut.js
//   osascript -l JavaScript record-shortcut.js --self-test   # fakes a ⌃⇧K press

ObjC.import('Cocoa');

const CMD = 1 << 20, OPT = 1 << 19, CTRL = 1 << 18, SHIFT = 1 << 17;
// JXA hands enum constants back as strings (and NSEventMaskAny overflows), so use plain numbers
const ESC = 53, KEY_DOWN = 10, ANY_EVENT = Number.MAX_SAFE_INTEGER;

function run(argv) {
  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyRegular);

  const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(0, 0, 380, 130), $.NSWindowStyleMaskTitled | $.NSWindowStyleMaskClosable,
    $.NSBackingStoreBuffered, false);
  win.title = 'Open in Linear';
  win.releasedWhenClosed = false;

  const label = $.NSTextField.wrappingLabelWithString('');
  label.frame = $.NSMakeRect(20, 20, 340, 90);
  label.alignment = $.NSTextAlignmentCenter;
  label.font = $.NSFont.systemFontOfSize(15);
  const say = (text) => { label.stringValue = text; };
  say('Press the shortcut you want to use\n(a modifier like ⌘ ⌥ ⌃ ⇧, plus a letter or number)\n\nEsc to cancel');
  win.contentView.addSubview(label);

  app.finishLaunching;

  win.center;
  win.makeKeyAndOrderFront(null);
  app.activateIgnoringOtherApps(true);

  if (argv[0] === '--self-test') {
    app.postEventAtStart($.NSEvent.keyEventWithTypeLocationModifierFlagsTimestampWindowNumberContextCharactersCharactersIgnoringModifiersIsARepeatKeyCode(
      KEY_DOWN, $.NSZeroPoint, CTRL | SHIFT, 0, win.windowNumber, null, '\x0b', 'K', false, 40), true);
  }

  const deadline = Date.now() + 60000;
  let result = '';

  while (Date.now() < deadline && win.isVisible) {
    const event = app.nextEventMatchingMaskUntilDateInModeDequeue(
      ANY_EVENT, $.NSDate.dateWithTimeIntervalSinceNow(0.1), $.NSDefaultRunLoopMode, true);
    if (event.isNil()) continue;

    if (Number(event.type) !== KEY_DOWN) {
      app.sendEvent(event);
      continue;
    }
    if (Number(event.keyCode) === ESC) break;

    const flags = Number(event.modifierFlags);
    const key = baseKey(event);
    let mods = '';
    if (flags & CMD) mods += '@';
    if (flags & OPT) mods += '~';
    if (flags & CTRL) mods += '^';
    if (flags & SHIFT) mods += '$';

    if (!/^[a-z0-9]$/.test(key)) {
      say('Use a letter or number for the key\n\nEsc to cancel');
    } else if (!mods) {
      say('Hold at least one modifier (⌘ ⌥ ⌃ ⇧) too\n\nEsc to cancel');
    } else {
      result = mods + key;
      break;
    }
  }

  win.close;
  return result;
}

// The key without modifiers applied, so ⌥K gives "k" rather than "˚"
function baseKey(event) {
  let chars = '';
  if (event.respondsToSelector('charactersByApplyingModifiers:')) {
    chars = ObjC.unwrap(event.charactersByApplyingModifiers(0)) || '';
  }
  if (!chars) chars = ObjC.unwrap(event.charactersIgnoringModifiers) || '';
  return chars.toLowerCase();
}
