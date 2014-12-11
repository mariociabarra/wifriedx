//
//  WiFriedX - Controls AWDL interface to help reduce interference
//  WiFriedApp.h - Manages UI
//
//  Copyright (c) 2014 Mario Ciabarra. All rights reserved
//  MIT License
//

#import <Cocoa/Cocoa.h>
#import "WiFriedManager.h"

@interface WiFriedXAppController : NSObject <NSApplicationDelegate>
{
    NSStatusItem *statusItem;
    NSMenuItem *awdlItem;
    NSMenu* menu;
    NSMenuItem* launchOnStart;

    bool awdlEnabled;
}

- (void) interfaceChanged;

@property (atomic, strong) NSWindow* window;

@end
