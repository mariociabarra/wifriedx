//
//  WiFriedXHelper.m
//  WiFriedX - Controls AWDL interface to help reduce interference
//
//  The priviledged Helper brings up/down awdl0 interface.
//  As Apple does not provide a way to remove Helpers when the App is deleted,
//  this uninstalls itself when main App not detected (on reboot).
//
//  Copyright (c) 2014 Mario Ciabarra. All rights reserved
//  MIT License
//

#include <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/task.h>

#include <sys/sysctl.h>
#include <signal.h>

#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <launch.h>

#include <sys/socket.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <netinet/in.h>

#include "../WiFriedX_private.h"

bool setAWDLIFUp(bool up);
void SocketAcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info);
void selfDestructIfNeeded();



bool setAWDLIFUp(bool up)
{
    static int sockfd = -1;
    struct ifreq ifr;
    
    if (sockfd)
        sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    
    if (sockfd < 0)
    {
        NSLog(@"WiFriedX: Could not create socket");
        return false;
    }
    
    ifr.ifr_addr.sa_family = AF_INET;
    strncpy(ifr.ifr_name, "awdl0", sizeof (ifr.ifr_name));
    
    if (ioctl(sockfd, SIOCGIFFLAGS, &ifr) < 0)
    {
        NSLog(@"WiFriedX: Error getting IFFLAGS from awdl0");
        return false;
    }
    
    short flags = ifr.ifr_flags;
    if (up)
        flags |= IFF_UP;
    else
        flags &= ~IFF_UP;
    
    ifr.ifr_flags = flags;
    
    int result = ioctl(sockfd, SIOCSIFFLAGS, &ifr);
    NSLog(@"WiFriedX Change AWDL interface %s (%d)", up ? "up" : "down", result);
    return (result == 0);
}


static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void* data, void *info)
{
    CFIndex length = CFDataGetLength((CFDataRef)data);
    struct WiFriedXRequest* wifriedXRequest;
    if (length == sizeof(struct WiFriedXRequest))
    {
        wifriedXRequest = (struct WiFriedXRequest *) CFDataGetBytePtr((CFDataRef)data);
        if (wifriedXRequest->magic == kWiFriedXMagic)
        {
            setAWDLIFUp(wifriedXRequest->up);
        }
        else
            NSLog(@"****** DATA ERROR");
    }
}


void SocketAcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    NSLog(@"Incoming connection");
    
    CFSocketNativeHandle csock = *(CFSocketNativeHandle *)data;
    CFSocketRef sn = CFSocketCreateWithNative(NULL, csock, kCFSocketDataCallBack, SocketReadCallback, NULL);
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, sn, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);
    CFRelease(sn);
}


void selfDestructIfNeeded()
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/WiFriedX.app"])
    {
        // Remove launchdaemon and helper
        // The login item might still exist. As I run as root, I don't know which user has is set, and it could be multiple.
        // but it's just ends up being an entry in the shared loginitems.plist and a checkbox in the login items that a user can clean by deleting under Preferences -> User Accounts -> Login Items
        NSLog(@"Removing helper as no /Applications/WiFriedX.app");
        NSError* error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:@"/Library/PrivilegedHelperTools/com.mariociabarra.WiFriedXHelper" error:&error];
        if (error)
            NSLog(@"Error removing helper: %@", error);
        [[NSFileManager defaultManager] moveItemAtPath:@"/Library/LaunchDaemons/com.mariociabarra.WiFriedXHelper.plist" toPath:@"/tmp/com.mariociabarra.WiFriedXHelper.plist" error:&error];
        if (error)
            NSLog(@"Error moving helper launchd plist: %@", error);
        
        system("launchctl unload /tmp/com.mariociabarra.WiFriedXHelper.plist");
        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/com.mariociabarra.WiFriedXHelper.plist" error:&error];
        
        if (error)
            NSLog(@"Error deleting helper launchd plist: %@", error);
        exit(0);
    }
}

int main(int argc, char** argv)
{
    NSLog(@"Initializing...");
    
    selfDestructIfNeeded();
    
    int sock;
    CFSocketRef listenerCF;
    
    launch_data_t checkin_request, launch_dict;
    
    checkin_request = launch_data_new_string(LAUNCH_KEY_CHECKIN);
    launch_dict = launch_msg(checkin_request);
    launch_data_free(checkin_request);
    
    if(launch_dict == NULL)
    {
        NSLog(@"launchd checkin failed!");
        exit(1);
    }
    
    launch_data_t socketsDict = launch_data_dict_lookup(launch_dict,LAUNCH_JOBKEY_SOCKETS);
    if (socketsDict == NULL)
    {
        NSLog(@"No socket dict!");
        exit(1);
    }
    
    launch_data_t fdArray = launch_data_dict_lookup(socketsDict, "ListenerSocket");
    if (fdArray == NULL)
    {
        NSLog(@"No socket data!");
        exit(1);
    }
    launch_data_t  fdData = launch_data_array_get_index(fdArray, 0);
    if (fdData == NULL)
    {
        NSLog(@"No socket data array!");
        exit(1);
    }
    
    sock = launch_data_get_fd(fdData);
    
    launch_data_free(launch_dict);
    
    if (sock >= 0)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3 * 60), dispatch_get_main_queue(), ^{
            // No reason to stick around ever
            NSLog(@"Exiting.");
            exit(0);
        });
        listenerCF = CFSocketCreateWithNative(NULL, (CFSocketNativeHandle) sock, kCFSocketAcceptCallBack, SocketAcceptCallback, NULL);
        CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, listenerCF, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
        NSLog(@"Listening...");
        CFRunLoopRun();
        CFSocketInvalidate(listenerCF);
        CFRelease(listenerCF);
    }
    else
    {
        NSLog(@"Invalid socket from launchd");
    }
    return 0;
}

