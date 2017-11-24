//
//  UnpairDeviceWindowController.m
//  iDevicePaired
//
//  Created by Rodol on 29/3/17.
//
//

#import "UnpairDeviceWindowController.h"
#import "AppDelegate.h"

@interface UnpairDeviceWindowController ()

@end

@implementation UnpairDeviceWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (instancetype)init
{
    return [self initWithWindowNibName:@"UnpairDeviceWindowController" owner:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];

}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self];
}

-(IBAction)AcceptButtonAction:(id)sender
{
#pragma unused(sender)
    
    [APPDELEGATE deletePairDeviceFileAction];
    [self CloseButtonAction:nil];
    
}
- (IBAction)CloseButtonAction:(id)sender {
#pragma unused(sender)
    [APPDELEGATE resetDeviceUUID];
    [self close];
    
}

-(void)windowWillClose:(NSNotification *)notification
{
#pragma unused(notification)
    [[NSApplication sharedApplication] stopModal];
}
@end
