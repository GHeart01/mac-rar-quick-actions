// progress.js — small floating progress window for the RAR Quick Actions.
//
//   osascript -l JavaScript progress.js <title> <status-file> <cancel-file>
//
// rartool.sh writes "<percent>\t<detail>" to <status-file> while rar runs.
// The window polls it, and closes as soon as the file says "done" or
// disappears. Clicking Cancel creates <cancel-file>; rartool.sh then stops rar.

ObjC.import('Cocoa');

function run(argv) {
  const title = argv[0] || 'RAR';
  const statusPath = argv[1];
  const cancelPath = argv[2];

  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory); // no Dock icon

  const W = 440, H = 118;
  const win = $.NSPanel.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(0, 0, W, H),
    $.NSWindowStyleMaskTitled | $.NSWindowStyleMaskUtilityWindow,
    $.NSBackingStoreBuffered, false);
  win.title = title;
  win.level = $.NSFloatingWindowLevel;
  win.releasedWhenClosed = false;
  win.hidesOnDeactivate = false;
  win.collectionBehavior = $.NSWindowCollectionBehaviorCanJoinAllSpaces;

  const view = win.contentView;

  const detail = $.NSTextField.labelWithString('Starting…');
  detail.frame = $.NSMakeRect(20, H - 38, W - 40, 18);
  detail.lineBreakMode = $.NSLineBreakByTruncatingMiddle;
  view.addSubview(detail);

  const bar = $.NSProgressIndicator.alloc.initWithFrame($.NSMakeRect(20, H - 66, W - 40, 20));
  bar.indeterminate = false;
  bar.minValue = 0;
  bar.maxValue = 100;
  bar.doubleValue = 0;
  view.addSubview(bar);

  const pct = $.NSTextField.labelWithString('0%');
  pct.frame = $.NSMakeRect(20, 16, 200, 18);
  pct.font = $.NSFont.monospacedDigitSystemFontOfSizeWeight(13, $.NSFontWeightMedium);
  view.addSubview(pct);

  let cancelled = false;

  ObjC.registerSubclass({
    name: 'RQAProgressController',
    methods: {
      'cancel:': {
        types: ['void', ['id']],
        implementation: function () {
          if (cancelled) return;
          cancelled = true;
          $(cancelPath).writeToFileAtomicallyEncodingError('1', true, $.NSUTF8StringEncoding, null);
          detail.stringValue = 'Cancelling…';
          button.enabled = false;
        },
      },
      'tick:': {
        types: ['void', ['id']],
        implementation: function () {
          const s = $.NSString.stringWithContentsOfFileEncodingError(statusPath, $.NSUTF8StringEncoding, null);
          if (s.isNil()) { app.terminate(null); return; }   // rartool.sh cleaned up
          const text = s.js.trim();
          if (text === 'done') { app.terminate(null); return; }
          const tab = text.indexOf('\t');
          const n = parseInt(tab >= 0 ? text.slice(0, tab) : text, 10);
          if (!isNaN(n)) {
            if (bar.indeterminate) { bar.stopAnimation(null); bar.indeterminate = false; }
            bar.doubleValue = n;
            pct.stringValue = n + '%';
          } else if (!bar.indeterminate) {
            // Percentage unknown (e.g. the unar fallback): show a spinner bar.
            bar.indeterminate = true;
            bar.startAnimation(null);
            pct.stringValue = '';
          }
          if (!cancelled && tab >= 0 && text.slice(tab + 1)) detail.stringValue = text.slice(tab + 1);
        },
      },
    },
  });

  const ctl = $.RQAProgressController.alloc.init;

  const button = $.NSButton.buttonWithTitleTargetAction('Cancel', ctl, 'cancel:');
  button.frame = $.NSMakeRect(W - 20 - 96, 10, 96, 30);
  button.keyEquivalent = '\x1b'; // Esc
  view.addSubview(button);

  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(0.2, ctl, 'tick:', $(), true);

  win.center;
  win.makeKeyAndOrderFront(null);
  win.orderFrontRegardless;
  app.activateIgnoringOtherApps(true);
  app.run;
}
