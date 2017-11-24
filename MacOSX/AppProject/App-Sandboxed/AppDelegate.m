/*
 File: AppDelegate.m
 Abstract: Main app controller.
 Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "AppDelegate.h"

#import "XPCService.h"
#import "HelperTool.h"

#include <ServiceManagement/ServiceManagement.h>
#include <IOKit/usb/IOUSBLib.h>

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/hid/IOHIDKeys.h>
#include "UnpairDeviceWindowController.h"
#include "WindowManagerController.h"

//#define DEBUG

#ifdef DEBUG
#define DebugLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define DebugLog(...)
#endif


@interface AppDelegate () {
    AuthorizationRef    _authRef;
}

// for IB


@property (nonatomic, strong) UnpairDeviceWindowController *unPairWindowController;
@property (nonatomic, strong) WindowManagerController *ViewManagerController;

// private stuff

@property (atomic, copy,   readwrite) NSData *                  authorization;
@property (atomic, strong, readwrite) NSXPCConnection *         helperToolConnection;
@property (atomic, strong, readwrite) NSXPCConnection *         xpcServiceConnection;


@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;

@end

@implementation AppDelegate

NSString* deviceConnectedNotification;
NSString* deviceDiconnectedNotification;
NSString* deviceUUID;
NSArray * iDevices;

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
#pragma unused(note)
    iDevices  = @[ @"iPhone", @"iPad", @"iPod" ];
    OSStatus                    err;
    AuthorizationExternalForm   extForm;
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if(args.count>1){
        if([args[1] isEqualToString:@"installDaemon"]){
            [self installAction:nil];
        }
    }
    _showWindowManager = YES;
    [AppDelegate listenForUSBEvents];
    [self setupStatusItem];
    
    // Create our connection to the authorization system.
    //
    // If we can't create an authorization reference then the app is not going to be able
    // to do anything requiring authorization.  Generally this only happens when you launch
    // the app in some wacky, and typically unsupported, way.  In the debug build we flag that
    // with an assert.  In the release build we continue with self->_authRef as NULL, which will
    // cause all authorized operations to fail.
    
    err = AuthorizationCreate(NULL, NULL, 0, &self->_authRef);
    if (err == errAuthorizationSuccess) {
        err = AuthorizationMakeExternalForm(self->_authRef, &extForm);
    }
    if (err == errAuthorizationSuccess) {
        self.authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
    }
    assert(err == errAuthorizationSuccess);
    
    // If we successfully connected to Authorization Services, get our XPC service to add
    // definitions for our default rights (unless they're already in the database).
    
    if (self->_authRef) {
        [self connectToXPCService];
        [[self.xpcServiceConnection remoteObjectProxy] setupAuthorizationRights];
    }
    
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
#pragma unused(sender)
    return NO;
}

- (void)setupStatusItem
{
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageNamed:@"StatusItem-Image"];
    
    [self updateStatusItemMenu];
}

- (void)updateStatusItemMenu
{
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Open Device Paired Tool Manager" action:@selector(readDevicesPaired:) keyEquivalent:@""];
    if(![self isDaemonInstalled]){
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Install Helper Tool" action:@selector(installAction:) keyEquivalent:@""];
    }
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"More Tools of ElevenPaths..." action:@selector(openElevenPathsWeb:) keyEquivalent:@""];
    
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    
    self.statusItem.menu = menu;
}

- (void)showManager
{
    if (!self.ViewManagerController) {
        self.ViewManagerController = [[WindowManagerController alloc] init];
    }
    [self updateManager];
}

-(void)updateManager{
    if (self.ViewManagerController) {
        [self.ViewManagerController showWindow];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
}
- (void)logText:(NSString *)text
// Logs the specified text to the log view.
{
    // any thread
    assert(text != nil);
    
    //Comment #define DEBUG line, when compile to production
    DebugLog(@"%@", text);
}

- (void)logWithFormat:(NSString *)format, ...
// Logs the formatted text to the log view.
{
    va_list ap;
    
    // any thread
    assert(format != nil);
    
    va_start(ap, format);
    [self logText:[[NSString alloc] initWithFormat:format arguments:ap]];
    va_end(ap);
}

- (void)logError:(NSError *)error
// Logs the error to the log view.
{
    // any thread
    assert(error != nil);
    [self logWithFormat:@"error %@ / %d\n", [error domain], (int) [error code]];
}

- (void)connectToXPCService
// Ensures that we're connected to our XPC service.
{
    assert([NSThread isMainThread]);
    if (self.xpcServiceConnection == nil) {
        self.xpcServiceConnection = [[NSXPCConnection alloc] initWithServiceName:kXPCServiceName];
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCServiceProtocol)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        // We can ignore the retain cycle warning because a) the retain taken by the
        // invalidation handler block is released by us setting it to nil when the block
        // actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
        // will be released when that operation completes and the operation itself is deallocated
        // (notably self does not have a reference to the NSBlockOperation).
        self.xpcServiceConnection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            self.xpcServiceConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.xpcServiceConnection = nil;
                [self logText:@"connection invalidated\n"];
            }];
        };
#pragma clang diagnostic pop
        [self.xpcServiceConnection resume];
    }
}

- (void)connectToHelperToolEndpoint:(NSXPCListenerEndpoint *)endpoint
// Ensures that we're connected to our helper tool.
{
    assert([NSThread isMainThread]);
    if (self.helperToolConnection == nil) {
        self.helperToolConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
        self.helperToolConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        self.helperToolConnection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            //
            // We can ignore the retain cycle warning for the reasons discussed in -connectToXPCService.
            self.helperToolConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.helperToolConnection = nil;
                [self logText:@"connection invalidated\n"];
            }];
        };
#pragma clang diagnostic pop
        [self.helperToolConnection resume];
    }
}

- (void)connectAndExecuteCommandBlock:(void(^)(NSError *))commandBlock
// Connects to the helper tool and then executes the supplied command block on the
// main thread, passing it an error indicating if the connection was successful.
{
    assert([NSThread isMainThread]);
    if (self.helperToolConnection != nil) {
        // The helper tool connection is already in place, so we can just call the
        // command block directly.
        commandBlock(nil);
    } else {
        // There's no helper tool connection in place.  Create on XPC service and ask
        // it to give us an endpoint for the helper tool.
        [self connectToXPCService];
        [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                commandBlock(proxyError);
            }];
        }] connectWithEndpointAndAuthorizationReply:^(NSXPCListenerEndpoint * connectReplyEndpoint, NSData * connectReplyAuthorization) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (connectReplyEndpoint == nil) {
                    commandBlock([NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTTY userInfo:nil]);
                } else {
                    // The XPC service gave us an endpoint for the helper tool.  Create a connection from that.
                    // Also, save the authorization information returned by the helper tool so that the command
                    // block can send requests that act like they're coming from the XPC service (which is allowed
                    // to use authorization services) and not the app (which isn't, 'cause it's sandboxed).
                    //
                    // It's important to realize that self.helperToolConnection could be non-nil here because some
                    // other command has connected ahead of us.  That's OK though, -connectToHelperToolEndpoint:
                    // will just ignore the new endpoint and keep using the helper tool connection that's in place.
                    [self connectToHelperToolEndpoint:connectReplyEndpoint];
                    self.authorization = connectReplyAuthorization;
                    commandBlock(nil);
                }
            }];
        }];
    }
}

#pragma mark * Need Security

- (void)installAction:(id)sender
{
#pragma unused(sender)
    [self connectToXPCService];
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [self logError:proxyError];
    }] installHelperToolWithReply:^(NSError * replyError) {
        if (replyError == nil) {
            [self logWithFormat:@"success\n"];
        } else {
            [self logError:replyError];
        }
    }];
    
}

- (void)openElevenPathsWeb:(id)sender
{
#pragma unused(sender)
    NSURL *URL = [NSURL URLWithString:@"https://www.elevenpaths.com/es/labsp/herramientas/index.html"];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (void)checkDevicePaired
{
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            [self logError:connectError];
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                [self logError:proxyError];
            }] isDevicePaired:deviceUUID authorization:self.authorization withReply:^(BOOL exist) {
                
                if(exist)
                {
                    [self logWithFormat:@"Device exist\n"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [APPDELEGATE showUnpairWindow];
                        
                    });
                }
                else
                {
                    [self logWithFormat:@"Device does not exist\n"];
                }
            }];
        }
    }];
    
}

- (void)readDevicesPaired:(id)sender
{
#pragma unused(sender)
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            [self logError:connectError];
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                [self logError:proxyError];
            }] readDevicesPaired:self.authorization withReply:^(NSError * commandError, NSArray * devices) {
                if (commandError != nil) {
                    [self logError:commandError];
                } else {
                    [self logWithFormat:@"devices = %@\n", devices];
                    _devicesArray =[devices copy];
                    if(_showWindowManager){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [APPDELEGATE showManager];
                            _showWindowManager = NO;
                        });
                    }else{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [APPDELEGATE updateManager];
                        });
                    }
                }
            }];
        }
    }];
}

- (void) deletePairDeviceFileAction
{
    
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            [self logError:connectError];
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                [self logError:proxyError];
            }] deletePairDeviceFile:deviceUUID authorization:self.authorization withReply:^(NSError *error) {
                if (error != nil) {
                    [self logError:error];
                } else {
                    [self logWithFormat:@"success\n"];
                    if ([APPDELEGATE ViewManagerController]) {
                        [[APPDELEGATE ViewManagerController] setNeedUpdate:YES];
                    }
                }
            }];
        }
    }];
}



+ (void)listenForUSBEvents
{
    io_iterator_t  portIterator = 0;
    CFMutableDictionaryRef  matchingDict = IOServiceMatching( kIOUSBDeviceClassName );
    IONotificationPortRef  notifyPort = IONotificationPortCreate( kIOMasterPortDefault );
    CFRunLoopSourceRef  runLoopSource = IONotificationPortGetRunLoopSource( notifyPort );
    CFRunLoopRef  runLoop = CFRunLoopGetCurrent();
    
    CFRunLoopAddSource( runLoop, runLoopSource, kCFRunLoopDefaultMode);
    CFRetain( matchingDict );
    
    kern_return_t  returnCode = IOServiceAddMatchingNotification( notifyPort, kIOMatchedNotification, matchingDict, DeviceConnected, NULL, &portIterator );
    
    if ( returnCode == 0 )
    {
        DeviceConnected( nil, portIterator );
    }
    
    returnCode = IOServiceAddMatchingNotification( notifyPort, kIOTerminatedNotification, matchingDict, DeviceDisconnected, NULL, &portIterator );
    
    if ( returnCode == 0 )
    {
        DeviceDisconnected( nil, portIterator );
    }
}

#pragma mark USBConnection
void DeviceConnected( void *refCon, io_iterator_t iterator )
{
#pragma unused(refCon)
    kern_return_t  returnCode = KERN_FAILURE;
    io_object_t  usbDevice;
    while ( ( usbDevice = IOIteratorNext( iterator ) ) )
    {
        io_name_t name;
        
        
        returnCode = IORegistryEntryGetName( usbDevice, name );
        
        if ( returnCode != KERN_SUCCESS )
        {
            return;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:deviceConnectedNotification object:nil userInfo:nil];
        if ([iDevices containsObject: [NSString stringWithFormat:@"%s", name]] ){
            if ([APPDELEGATE ViewManagerController]){
                [[APPDELEGATE ViewManagerController] setNeedUpdate:YES];
            }
        }
    }
}

void DeviceDisconnected( void *refCon, io_iterator_t iterator )
{
#pragma unused(refCon)
    kern_return_t    returnCode = KERN_FAILURE;
    io_object_t      usbDevice;
    io_struct_inband_t devnode;
    char * USBserialNumber = "USB Serial Number";
    unsigned int len = 256;
    
    while ( ( usbDevice = IOIteratorNext( iterator ) ) )
    {
        io_name_t name;
        
        deviceDiconnectedNotification = [NSString stringWithUTF8String:name];
        IORegistryEntryGetProperty(usbDevice, USBserialNumber, devnode, &len);
        deviceUUID = [NSString stringWithUTF8String:devnode];
        returnCode = IOObjectRelease( usbDevice );
        
        if ( returnCode != kIOReturnSuccess )
        {
            NSLog( @"Couldn't release raw device object: %08x.", returnCode );
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:deviceDiconnectedNotification object:nil userInfo:nil];
    if(deviceUUID.length>0 ){
        [APPDELEGATE checkDevicePaired];
        
    }
    
}


-(void)resetDeviceUUID
{
    deviceUUID = @"";
}

- (void)setDeviceUUID:(NSString*) udid{
    deviceUUID = udid;
}
- (void)showUnpairWindow
{
    
    if (!self.unPairWindowController) {
        self.unPairWindowController = [[UnpairDeviceWindowController alloc] init];
    }
    
    
    [self.unPairWindowController showWindow:nil];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] runModalForWindow:[self.unPairWindowController window]];
    
}


-(BOOL)isDaemonInstalled
{
    return  ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/LaunchDaemons/com.11paths.iDevicePaired.HelperTool.plist"] &&
             [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/PrivilegedHelperTools/com.11paths.iDevicePaired.HelperTool"]);
}





@end
