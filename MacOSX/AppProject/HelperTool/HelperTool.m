/*
 File: HelperTool.m
 Abstract: The main object in the helper tool.
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

#import "HelperTool.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>

@interface HelperTool () <NSXPCListenerDelegate, HelperToolProtocol>

@property (atomic, strong, readwrite) NSXPCListener *    listener;

@end

@implementation HelperTool

- (id)init
{
    self = [super init];
    if (self != nil) {
        // Set up our XPC listener to handle requests on our Mach service.
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        self->_listener.delegate = self;
    }
    return self;
}

- (void)run
{
    // Tell the XPC listener to start processing requests.
    
    [self.listener resume];
    
    // Run the run loop forever.
    
    [[NSRunLoop currentRunLoop] run];
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
// Called by our XPC listener when a new connection comes in.  We configure the connection
// with our protocol and ourselves as the main object.
{
    assert(listener == self.listener);
#pragma unused(listener)
    assert(newConnection != nil);
    
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    
    return YES;
}

- (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
// Check that the client denoted by authData is allowed to run the specified command.
// authData is expected to be an NSData with an AuthorizationExternalForm embedded inside.
{
#pragma unused(authData)
    NSError *                   error;
    OSStatus                    err;
    OSStatus                    junk;
    AuthorizationRef            authRef;
    
    assert(command != nil);
    
    authRef = NULL;
    
    // First check that authData looks reasonable.
    
    error = nil;
    if ( (authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    // Create an authorization ref from that the external form data contained within.
    
    if (error == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        // Authorize the right associated with the command.
        
        if (err == errAuthorizationSuccess) {
            AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights   = { 1, &oneRight };
            
            oneRight.name = [[Common authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &rights,
                                          NULL,
                                          kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                                          NULL
                                          );
        }
        if (err != errAuthorizationSuccess) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
        }
    }
    
    if (authRef != NULL) {
        junk = AuthorizationFree(authRef, 0);
        assert(junk == errAuthorizationSuccess);
    }
    
    return error;
}



#pragma mark * HelperToolProtocol implementation

// IMPORTANT: NSXPCConnection can call these methods on any thread.  It turns out that our
// implementation of these methods is thread safe but if that's not the case for your code
// you have to implement your own protection (for example, having your own serial queue and
// dispatching over to it).

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *))reply
// Part of the HelperToolProtocol.  Not used by the standard app (it's part of the sandboxed
// XPC service support).  Called by the XPC service to get an endpoint for our listener.  It then
// passes this endpoint to the app so that the sandboxed app can talk us directly.
{
    reply([self.listener endpoint]);
}

- (void)isDevicePaired:(NSString *)deviceUUID authorization:(NSData *)authData withReply:(void(^)(BOOL  exist))reply
// Part of the HelperToolProtocol.  Returns the version number of the tool.  Note that never
// requires authorization.
{
    // We specifically don't check for authorization here.  Everyone is always allowed to get
    // the version of the helper tool.
    BOOL isPaired = NO;
    NSError *   error;
    if (error == nil) {
        error = [self checkAuthorization:authData command:_cmd];
    }
    if (error == nil) {
        NSString* filePath = [[@"/var/db/lockdown/" stringByAppendingString:deviceUUID] stringByAppendingString:@".plist"];
        isPaired =[[NSFileManager defaultManager] fileExistsAtPath:filePath];
    }
    reply(isPaired);
    
}



- (void)readDevicesPaired:(NSData *)authData withReply:(void(^)(NSError * error, NSArray * devices))reply
// Part of the HelperToolProtocol.  Gets the current license key from the defaults database.
{
    
    NSError *   error;
    NSDictionary *mainDictionary = nil;
    NSString *fileNameWithoutExt ;
    NSMutableArray *arrayDevices = [[NSMutableArray alloc]init];
    NSString  *destination_path = @"/var/db/lockdown/";
    NSMutableDictionary *dictionaryAux;
    NSArray *plistFiles ;
    error = [self checkAuthorization:authData command:_cmd];
    
    if (error == nil) {
        NSArray * directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: destination_path error:nil];
        plistFiles = [directoryContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.plist'"]];
        for(NSString* file in plistFiles){
            fileNameWithoutExt = [file stringByDeletingPathExtension];
            if ([self validateUDID:fileNameWithoutExt]) {
                mainDictionary = [[NSDictionary alloc] initWithContentsOfFile: [destination_path stringByAppendingString:file]];
                if(mainDictionary != nil){
                    dictionaryAux = [[NSMutableDictionary alloc] init];
                    [dictionaryAux setValue:fileNameWithoutExt forKey:@"udid"];
                    [dictionaryAux setValue:[mainDictionary valueForKey:@"WiFiMACAddress"] forKey:@"WiFiMACAddress"];
                    [dictionaryAux setValue:[self getMacBluetooth:[mainDictionary valueForKey:@"WiFiMACAddress"]] forKey:@"BluetoothMAC"];
                    [dictionaryAux setValue:[mainDictionary valueForKey:@"HostID"] forKey:@"HostID"];
                    [arrayDevices addObject:dictionaryAux];
                }
            }
        }
        
    }
    
    reply(error, [NSArray arrayWithArray:arrayDevices]);
}

- (void)deletePairDeviceFile:(NSString *)deviceUUID authorization:(NSData *)authData withReply:(void(^)(NSError * error))reply
// Part of the HelperToolProtocol.  Saves the license key to the defaults database.
{
    NSError *   error;
    
    error = nil;
    error = [self checkAuthorization:authData command:_cmd];
    if (error == nil && [self validateUDID:deviceUUID]) {
        
        //RemoveFile
        NSString* filePath = [[@"/var/db/lockdown/" stringByAppendingString:deviceUUID] stringByAppendingString:@".plist"];
        if( [[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    }
    reply(error);
}

-(BOOL) validateUDID:(NSString*)deviceUDID{
    
    NSString *expression = @"^([0-9a-fA-F]{40})$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:expression options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSArray *matches = [regex matchesInString:deviceUDID
                                      options:0
                                        range:NSMakeRange(0, [deviceUDID length])];
    return (matches.count == 1);
}


-(NSString*) getMacBluetooth:(NSString*) wifiHexValue{
    unsigned result = 0;
    NSString *code = [wifiHexValue substringFromIndex: [wifiHexValue length] - 2];
    NSScanner *scanner = [NSScanner scannerWithString:code];
    [scanner setScanLocation:0];
    [scanner scanHexInt:&result];
    result++;
    return [[wifiHexValue substringToIndex:[wifiHexValue length] - 2] stringByAppendingString: [NSString stringWithFormat:@"%lx",(unsigned long)result]];
    
}
@end
