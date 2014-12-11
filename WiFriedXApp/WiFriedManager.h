//
//  WiFriedX - Controls AWDL interface to help reduce interference
//  WiFriedManager.h - Communication with Daemon, Callbacks for interface change, Install of priviledged Helper
//
//  Copyright (c) 2014 Mario Ciabarra. All rights reserved
//  MIT License
//



#import <Cocoa/Cocoa.h>
#include <SystemConfiguration/SystemConfiguration.h>

@protocol WiFriedInterfaceListener
- (void) interfaceChanged;
@end

@interface WiFriedManager : NSObject
{
    AuthorizationRef        _authRef;
    SCDynamicStoreRef dynamicStore;
}

- (BOOL) configureHelper;
+ (WiFriedManager*) sharedInstance;
- (int) sendAWDLChangeToDaemon: (bool) up;
- (void) setLaunchAtLogin:(BOOL) launch;
- (BOOL)isLaunchAtStartup;
- (BOOL) isAWDLUp;
- (BOOL) hasAWDL;

@property (atomic, retain) id <WiFriedInterfaceListener> delegate;

@end
