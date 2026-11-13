// RarQuickAction.m — Automator action used by the "Extract RAR" and
// "Compress to RAR" Quick Actions.
//
// It runs rartool.sh with the selected Finder items and passes rar's
// percentage to Automator's progressValue, which is what the ⚙️ gear in the
// menu bar shows ("45% completed"). Clicking the gear's ✕ calls -stop, which
// sends SIGTERM to rartool.sh; the script then stops rar and removes any
// half-finished output.
//
// Parameter "mode" (set in each workflow): "extract", "compress" or "probe"
// ("probe" just finishes, so install.sh can check the action is allowed to run).
//
// Build: action/build.sh

#import <Automator/Automator.h>
#include <signal.h>

@interface RarQuickAction : AMBundleAction
@end

@implementation RarQuickAction {
  NSTask *_task;
  NSTimer *_timer;
  NSString *_progressFile;
  id _input;
  BOOL _finished;
}

- (void)runAsynchronouslyWithInput:(id)input {
  _input = input;
  NSString *mode = [[self parameters] objectForKey:@"mode"] ?: @"extract";
  if ([mode isEqualToString:@"probe"]) {
    [self finishWithError:nil];
    return;
  }

  NSMutableArray<NSString *> *paths = [NSMutableArray array];
  NSArray *items = [input isKindOfClass:[NSArray class]] ? input : (input ? @[ input ] : @[]);
  for (id item in items) {
    if ([item isKindOfClass:[NSURL class]]) [paths addObject:[(NSURL *)item path]];
    else if ([item isKindOfClass:[NSString class]]) [paths addObject:item];
  }

  NSString *tool = [NSHomeDirectory()
      stringByAppendingPathComponent:@"Library/Application Support/RarQuickActions/rartool.sh"];
  _progressFile = [NSTemporaryDirectory()
      stringByAppendingPathComponent:[NSString stringWithFormat:@"rarqa-progress-%@", [NSUUID UUID].UUIDString]];

  NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy];
  env[@"RQA_PROGRESS_FILE"] = _progressFile;

  _task = [[NSTask alloc] init];
  _task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
  _task.arguments = [@[ tool, mode ] arrayByAddingObjectsFromArray:paths];
  _task.environment = env;
  _task.standardInput = [NSFileHandle fileHandleWithNullDevice];
  _task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
  _task.standardError = [NSFileHandle fileHandleWithNullDevice];

  __weak RarQuickAction *weakSelf = self;
  _task.terminationHandler = ^(NSTask *t) {
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf finishWithError:nil]; });
  };

  NSError *err = nil;
  if (![_task launchAndReturnError:&err]) {
    [self finishWithError:err];
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    RarQuickAction *s = weakSelf;
    if (!s || s->_finished) return;
    s->_timer = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *timer) {
      [weakSelf readProgress];
    }];
  });
}

// rartool.sh writes a whole number 0–100 to the progress file.
- (void)readProgress {
  NSString *s = [NSString stringWithContentsOfFile:_progressFile encoding:NSUTF8StringEncoding error:nil];
  if (s.length == 0) return;
  double pct = [s doubleValue];
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  self.progressValue = pct / 100.0;
}

- (void)finishWithError:(NSError *)error {
  if (_finished) return;
  _finished = YES;
  [_timer invalidate];
  _timer = nil;
  if (_progressFile) [[NSFileManager defaultManager] removeItemAtPath:_progressFile error:nil];
  self.output = _input;
  [self finishRunningWithError:error];
}

// The gear's ✕ (or Automator's Stop button).
- (void)stop {
  if (_task.running) kill(_task.processIdentifier, SIGTERM);
  [super stop];
}

@end
