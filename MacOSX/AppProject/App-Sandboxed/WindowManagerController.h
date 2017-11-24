//
//  WindowManagerController.h
//  SecureUnplug
//
//  Created by Rodol on 24/3/17.
//  Copyright © 2017 ElevenPaths. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WindowManagerController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSApplicationDelegate>

@property(weak,nonatomic)IBOutlet NSTableView* tableView;
@property(nonatomic) BOOL needUpdate;
- (void)showWindow;
@end
