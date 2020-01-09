//
//  QYDragView.h
//  DSYMHelper
//
//  Created by 孟庆宇 on 2019/5/31.
//  Copyright © 2019 Damon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol QYDragViewDelegate <NSObject>
@optional
- (void)dragEnter;
- (void)dragExit;
- (void)dragFileComplete:(NSArray *)filepaths;

@end

@interface QYDragView : NSView

@property (nonatomic, weak) id <QYDragViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
