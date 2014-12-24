//
//  WiFriedX - Controls AWDL interface to help reduce interference
//  WiFriedApp.h - Manages UI
//
//  Copyright (c) 2014 Mario Ciabarra. All rights reserved
//  MIT License
//
#import "WiFriedXAppController.h"
#import "WiFriedManager.h"

#import "../WiFriedX_private.h"


@implementation WiFriedXAppController

- (void) awakeFromNib
{
    if (![[WiFriedManager sharedInstance] hasAWDL])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"AWDL Not Supported on this Mac"];
        [alert setInformativeText:@"WiFriedX helps reduce WiFi interference from AWDL. Your Mac does not support AWDL. \nNothing to do."];
        [alert runModal];
        exit(0);
    }
    if (![[[NSBundle mainBundle] bundlePath] hasPrefix: @"/Applications"])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"Run in Applications Folder"];
        [alert setInformativeText:@"Please drag WiFriedX into the Applications Folder.\nBy doing so, WiFriedX can be sure to clean up correctly on uninstall."];
        [alert runModal];
        exit(0);
    }
    if (![[WiFriedManager sharedInstance] configureHelper])
    {
        NSLog(@"No helper - exiting");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"Could Not Authorize Helper"];
        [alert setInformativeText:@"WiFriedX requires installation of a helper to bring the AWDL interface up and down. Exiting."];
        [alert runModal];
        exit(-1);
    }
    
    [[WiFriedManager sharedInstance] setDelegate: self];
    
    [self createStatusBar];
    [self interfaceChanged];
    [NSApp activateIgnoringOtherApps:YES];
}


- (void) createStatusBar
{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:25.0];
    [statusItem setHighlightMode:YES];

    menu = [[NSMenu alloc] init];

    awdlItem = [[NSMenuItem alloc] initWithTitle:@"Disable AWDL/AirDrop" action:@selector(toggleEnable:) keyEquivalent:@"E"];
    launchOnStart = [[NSMenuItem alloc] initWithTitle:@"Launch On Start" action:@selector(toggleLaunch:) keyEquivalent:@""];
    NSMenuItem* aboutItem = [[NSMenuItem alloc] initWithTitle:@"WiFriedX 1.2 by @mariociabarra" action:@selector(openURL) keyEquivalent:@""];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit_application) keyEquivalent:@"Q"];

    if ([[WiFriedManager sharedInstance] isLaunchAtStartup])
        [launchOnStart setState:NSOnState];

    [menu addItem:awdlItem];
    [menu addItem:launchOnStart];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:aboutItem];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:quit];

    [statusItem setMenu:menu];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
}

- (void) openURL
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"https://www.twitter.com/mariociabarra"]];
}

- (void) interfaceChanged
{
    bool preferenceAWDLEnabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"WiFriedX_Enable_AWDL"] boolValue];
    awdlEnabled = [[WiFriedManager sharedInstance] isAWDLUp];

    if (preferenceAWDLEnabled != awdlEnabled)
        [[WiFriedManager sharedInstance] sendAWDLChangeToDaemon:preferenceAWDLEnabled];
    [self updateStatus];
}
     
- (void) updateStatus
{
    static NSImage *OKImage;
    static NSImage *FriedImage;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OKImage = [NSImage imageNamed:@"wifried-osx-ok"];
        [OKImage setTemplate:YES];
        
        FriedImage = [NSImage imageNamed:@"wifried-osx-fried"];
        [FriedImage setTemplate:YES];
    });
    
    if (!awdlEnabled)
    {
        [statusItem setImage:OKImage];
        [awdlItem setState:NSOnState];
    }
    else
    {
        [statusItem setImage:FriedImage];
        [awdlItem setState:NSOffState];
    }
}


- (void) toggleLaunch:(NSMenuItem*)sender
{
    bool setEnabled = ![sender state];
    [launchOnStart setState: setEnabled ? NSOnState : NSOffState];
    [[WiFriedManager sharedInstance] setLaunchAtLogin:setEnabled];
}

- (void) toggleEnable:(NSMenuItem*)sender
{
    [[WiFriedManager sharedInstance] sendAWDLChangeToDaemon:(bool)[sender state]];
    [[NSUserDefaults standardUserDefaults] setBool:(bool)[sender state] forKey:@"WiFriedX_Enable_AWDL"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) quit_application
{
    exit(0);
}

@end
