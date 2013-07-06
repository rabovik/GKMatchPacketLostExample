//
//  RSAppDelegate.h
//  GKMatchPacketLostExample
//
//  Created by Yan Rabovik on 18.06.13.
//  Copyright (c) 2013 Yan Rabovik. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RSViewController;

@interface RSAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) RSViewController *viewController;

@end
