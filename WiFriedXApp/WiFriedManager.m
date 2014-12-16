//
//  WiFriedX - Controls AWDL interface to help reduce interference
//  WiFriedManager.m - Communication with Daemon, Callbacks for interface change, Install of priviledged Helper
//
//  Copyright (c) 2014 Mario Ciabarra. All rights reserved
//  MIT License
//

#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <Foundation/Foundation.h>

#import "WiFriedManager.h"
#import "../WiFriedX_private.h"

#define JOB_LABEL @"com.mariociabarra.WiFriedXHelper"
#define AWDL_INTERFACE_KEY @"State:/Network/Interface/awdl0/Link"

@implementation WiFriedManager

static WiFriedManager* sharedManager = nil;

+ (WiFriedManager*) sharedInstance
{
    if (sharedManager == nil)
         sharedManager = [[WiFriedManager alloc] init];
    return sharedManager;
}

static void callback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info)
{
    [[WiFriedManager sharedInstance].delegate interfaceChanged];
}

- (WiFriedManager*) init
{
    self = [super init];
    SCDynamicStoreContext context = {0, (__bridge void*)self, CFRetain, CFRelease, CFCopyDescription};
    dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, CFSTR("com.mariociabarra.WiFriedX"), callback, &context);
    if(dynamicStore)
    {
        if(SCDynamicStoreSetDispatchQueue(dynamicStore, dispatch_get_main_queue()))
            if(SCDynamicStoreSetNotificationKeys(dynamicStore, (__bridge CFArrayRef)[NSArray arrayWithObject:AWDL_INTERFACE_KEY], NULL))
                NSLog(@"Initialization of SCDynamicStore succeeded");
    }
    // set defaults for first launch
    if (dynamicStore && ![[NSUserDefaults standardUserDefaults] objectForKey:@"WiFriedX_DID_INIT"])
    {
        [self setLaunchAtLogin: true];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"WiFriedX_Enable_AWDL"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"WiFriedX_DID_INIT"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    return self;
}

- (BOOL) isAWDLUp
{
    bool isUp = true;
    if (dynamicStore)
    {
        NSDictionary* awdlDict = (__bridge NSDictionary*) SCDynamicStoreCopyValue(dynamicStore, (__bridge CFStringRef) AWDL_INTERFACE_KEY);
        if (awdlDict)
        {
            isUp = [awdlDict[@"Active"] boolValue];
            CFRelease((__bridge CFDictionaryRef) awdlDict);
        }
    }
    return isUp;
}


- (BOOL) hasAWDL
{
    bool hasAWDL = false;
    if (dynamicStore)
    {
        NSDictionary* awdlDict = (__bridge NSDictionary*) SCDynamicStoreCopyValue(dynamicStore, (__bridge CFStringRef) AWDL_INTERFACE_KEY);
        if (awdlDict)
        {
            if (awdlDict[@"Active"])
                 hasAWDL = true;
            CFRelease((__bridge CFDictionaryRef) awdlDict);
        }
    }
    return hasAWDL;
}


// MIT license from http://bdunagan.com/2010/09/25/cocoa-tip-enabling-launch-on-startup/
- (BOOL)isLaunchAtStartup
{
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self createItemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);
    
    return isInList;
}

- (LSSharedFileListItemRef)createItemRefInLoginItems
{
    LSSharedFileListItemRef itemRef = nil;
    CFURLRef itemUrl = nil;
    
    // Get the app's URL.
    NSURL *appUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef != nil)
    {
        // Iterate over the LoginItems.
        NSArray *loginItems = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
        if (loginItems)
        {
            for (NSUInteger currentIndex = 0; currentIndex < [loginItems count]; currentIndex++)
            {
                // Get the current LoginItem and resolve its URL.
                LSSharedFileListItemRef currentItemRef = (__bridge LSSharedFileListItemRef)[loginItems objectAtIndex:currentIndex];
                if (LSSharedFileListItemResolve(currentItemRef, 0, &itemUrl, NULL) == noErr)
                {
                    // Compare the URLs for the current LoginItem and the app.
                    if ([(__bridge NSURL *) itemUrl isEqual:appUrl])
                    {
                        // Save the LoginItem reference.
                        itemRef = currentItemRef;
                        CFRetain(itemRef);
                        break;
                    }
                }
            }
            CFRelease((__bridge CFArrayRef)loginItems);
        }
        
        CFRelease(loginItemsRef);
    }
    
    return itemRef;
}

- (void) setLaunchAtLogin:(BOOL) launch
{
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef != nil)
    {
        if (launch)
        {
            // Add the app to the LoginItems list.
            CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
            LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
            if (itemRef) CFRelease(itemRef);
            NSLog(@"Inserted Launch Item");
        }
        else
        {
            // Remove the app from the LoginItems list.
            LSSharedFileListItemRef itemRef = [self createItemRefInLoginItems];
            if (itemRef)
            {
                LSSharedFileListItemRemove(loginItemsRef,itemRef);
                CFRelease(itemRef);
                NSLog(@"Removed Launch Item");
            }
        }
        CFRelease(loginItemsRef);
    }

}


// From Apple SMBless demo
- (BOOL) configureHelper
{
    bool success = false;
    NSError *error = nil;
    if ([self needsBlessing])
    {
        OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &self->_authRef);
        if (status != errAuthorizationSuccess)
        {
            NSLog(@"Auth Create Failed! %@ / %d", [error domain], (int) [error code]);
        }
        else if (![self blessHelperWithLabel])
        {
            NSLog(@"Did not get authorization! %@ / %d", [error domain], (int) [error code]);
        }
        else
            success = true;
    }
    else
        success = true;
    return success;
}

- (BOOL) needsBlessing
{
    BOOL needsBlessing = true;
    NSDictionary* installedHelperJobData  = (__bridge NSDictionary*)SMJobCopyDictionary( kSMDomainSystemLaunchd, (__bridge CFStringRef)JOB_LABEL );
    NSLog(@"installedHelperJobData: %@", installedHelperJobData);
    if (installedHelperJobData)
    {
        NSString*       installedPath           = [[installedHelperJobData objectForKey:@"ProgramArguments"] objectAtIndex:0];
        NSURL*          installedPathURL        = [NSURL fileURLWithPath:installedPath];
        
        NSDictionary*   installedInfoPlist      = (__bridge NSDictionary*)CFBundleCopyInfoDictionaryForURL( (__bridge CFURLRef)installedPathURL );
        if (installedInfoPlist)
        {
            NSString*       installedBundleVersion  = [installedInfoPlist objectForKey:@"CFBundleVersion"];
            float       installedVersion        = [installedBundleVersion floatValue];
            CFRelease((__bridge CFDictionaryRef) installedInfoPlist);
            
            NSBundle*       appBundle       = [NSBundle mainBundle];
            NSURL*          appBundleURL    = [appBundle bundleURL];
            NSURL*          currentHelperToolURL    = [appBundleURL URLByAppendingPathComponent:@"Contents/Library/LaunchServices/com.mariociabarra.WiFriedXHelper"];
            NSDictionary*   currentInfoPlist        = (__bridge NSDictionary*)CFBundleCopyInfoDictionaryForURL( (__bridge CFURLRef)currentHelperToolURL );
            if (currentInfoPlist)
            {
                NSString*       currentBundleVersion    = [currentInfoPlist objectForKey:@"CFBundleVersion"];
                float       currentVersion          = [currentBundleVersion floatValue];
                
                NSLog(@"Installed Version: %f vs current: %f", installedVersion, currentVersion);
                if (currentVersion == installedVersion)
                    needsBlessing = false;
                CFRelease((__bridge CFDictionaryRef) currentInfoPlist);
            }
        }
        CFRelease((__bridge CFDictionaryRef) installedHelperJobData);
    }
    return needsBlessing;
}

- (BOOL)blessHelperWithLabel
{
    BOOL result = NO;
    NSError * error = nil;
    
    AuthorizationItem authItem		= { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights	= { 1, &authItem };
    AuthorizationFlags flags		=	kAuthorizationFlagDefaults				|
    kAuthorizationFlagInteractionAllowed	|
    kAuthorizationFlagPreAuthorize			|
    kAuthorizationFlagExtendRights;
    
    
    /* Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCopyRights(self->_authRef, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess)
    {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Copy rights failed: %@ / %d", [error domain], (int) [error code]);
    }
    else
    {
        CFErrorRef  cfError;
        
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        result = (BOOL) SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)JOB_LABEL, self->_authRef, &cfError);
        NSLog(@"Result of JobBless: %d", result);
        if (!result)
        {
            error = CFBridgingRelease(cfError);
            NSLog(@"Could not perform JobBless: %@", error.localizedDescription);
        }
    }
    
    return result;
}

- (int) sendAWDLChangeToDaemon: (bool) up
{
    // write to daemon
    struct sockaddr_un addr;
    int fd;
    
    if ( (fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1)
    {
        NSLog(@"send: socket error");
        return -1;
    }
    
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path)-1);
    
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) == -1)
    {
        NSLog(@"send: socket connect error");
        return -1;
    }
    
    struct WiFriedXRequest wiFriedXRequest;
    wiFriedXRequest.magic = kWiFriedXMagic;
    wiFriedXRequest.up = up;
    ssize_t writeLength = write(fd, &wiFriedXRequest, sizeof(wiFriedXRequest));
    if (writeLength != sizeof(wiFriedXRequest))
    {
        if (writeLength > 0)
            NSLog(@"send: partial write: %zd", writeLength);
        else
        {
            NSLog(@"send: write error");
        }
    }
    else
        NSLog(@"send: Sent command to daemon");
    close(fd);
    return 0;
}

@end
