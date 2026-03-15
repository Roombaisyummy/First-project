#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#include <spawn.h>

extern char **environ;

@interface SatellaRootListController : PSListController
@end

@implementation SatellaRootListController

- (BOOL)runCommand:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments {
    pid_t pid = 0;
    NSMutableArray<NSString *> *argvStrings = [NSMutableArray arrayWithObject:launchPath];
    [argvStrings addObjectsFromArray:arguments];

    char *argv[argvStrings.count + 1];
    for (NSUInteger i = 0; i < argvStrings.count; i++) {
        argv[i] = (char *)argvStrings[i].UTF8String;
    }
    argv[argvStrings.count] = NULL;

    int status = posix_spawn(&pid, launchPath.UTF8String, NULL, NULL, argv, environ);
    return status == 0;
}

- (void)presentResultWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (void)openGitHub {
    NSURL *url = [NSURL URLWithString:@"https://github.com/Paisseon/Satella"];
    if (url != nil) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)clearLogs {
    NSString *logPath = @"/var/jb/var/mobile/Library/Logs/SatellaJailed.log";
    NSError *error = nil;
    [@"" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:&error];

    NSString *title = (error == nil) ? @"Success" : @"Error";
    NSString *message = (error == nil) ? @"Logs cleared." : [NSString stringWithFormat:@"Failed to clear logs: %@", error.localizedDescription];
    [self presentResultWithTitle:title message:message];
}

- (void)restartTargetApps {
    BOOL gilded = [self runCommand:@"/var/jb/usr/bin/killall" arguments:@[@"-9", @"Gilded"]];
    BOOL sentinel = [self runCommand:@"/var/jb/usr/bin/killall" arguments:@[@"-9", @"Sentinel"]];

    NSString *message = (gilded || sentinel)
        ? @"Killed Gilded/Sentinel. Reopen the app to apply Satella changes."
        : @"Could not kill Gilded or Sentinel. If they were not running, just reopen them manually.";
    [self presentResultWithTitle:@"Target Apps" message:message];
}

- (void)respringDevice {
    BOOL ok = [self runCommand:@"/var/jb/usr/bin/sbreload" arguments:@[]];
    if (!ok) {
        ok = [self runCommand:@"/bin/launchctl" arguments:@[@"reboot", @"userspace"]];
    }

    NSString *message = ok
        ? @"Respring requested."
        : @"Could not trigger a respring automatically.";
    [self presentResultWithTitle:ok ? @"Respring" : @"Error" message:message];
}

@end
