//
//  WindowManagerController.m
//  SecureUnplug
//
//  Created by Rodol on 24/3/17.
//  Copyright © 2017 ElevenPaths. All rights reserved.
//

#import "WindowManagerController.h"
#import "AppDelegate.h"

@interface WindowManagerController ()
@end

@implementation WindowManagerController


- (void)windowDidLoad {
    [super windowDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    _needUpdate = NO;
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (instancetype)init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowFocus:) name:NSWindowDidBecomeMainNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowFocus:) name:NSWindowDidUpdateNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
    return [self initWithWindowNibName:@"WindowManager" owner:self];
    
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeMainNotification object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidUpdateNotification object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self];
}
-(void)windowWillClose:(NSNotification *)notification
{
#pragma unused(notification)
    [APPDELEGATE setShowWindowManager:YES];
}
- (IBAction)refreshButtonAction:(id)sender {
#pragma unused(sender)
    _needUpdate = YES;
    [self windowFocus:nil];
}

-(void)windowFocus:(NSNotification *)notification
{
#pragma unused(notification)
    if(_needUpdate){
        [APPDELEGATE setShowWindowManager:NO];
        [APPDELEGATE readDevicesPaired:nil];
        _needUpdate=NO;
        
    }
}
- (IBAction)CloseButtonAction:(id)sender {
#pragma unused(sender)
    [self close];
}

-(void)showWindow
{
    [self.tableView reloadData];
    [self showWindow:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
     [self windowFocus:nil];
}


-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
#pragma unused(tableView)
    return (NSInteger)[[APPDELEGATE devicesArray] count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex{
#pragma unused(tableView)
    NSString *aString;
    if(![[tableColumn identifier] isEqualToString:@"Remove"]){
        aString = [(NSDictionary*)[[APPDELEGATE devicesArray] objectAtIndex:(NSUInteger)rowIndex] objectForKey:[tableColumn identifier]];
        return aString;
    }
    else
    {
        return [NSImage imageNamed:@"Logo"];
    }
}


- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
#pragma unused(tableView)
    if([cell isKindOfClass:[NSImageCell class]] && [[tableColumn identifier] isEqualToString:@"Remove"])
    {
        [APPDELEGATE setDeviceUUID: [(NSDictionary*)[[APPDELEGATE devicesArray] objectAtIndex:(NSUInteger)row] objectForKey:@"udid"]];
        [APPDELEGATE showUnpairWindow];
        _needUpdate = YES;
    }
    
    return YES;
}

@end
