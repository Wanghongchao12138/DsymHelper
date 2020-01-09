//
//  QYDragView.m
//  DSYMHelper
//
//  Created by 孟庆宇 on 2019/5/31.
//  Copyright © 2019 Damon. All rights reserved.
//

#import "QYDragView.h"

@implementation QYDragView

- (void)awakeFromNib
{
    [super awakeFromNib];
    // 设置支持的文件类型
    [self registerForDraggedTypes:@[NSPasteboardTypePDF, NSPasteboardTypePNG, NSPasteboardTypeURL, NSPasteboardTypeFileURL]];
}

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//    
//    // Drawing code here.
//    
//    self.layer.backgroundColor = [NSColor yellowColor].CGColor;
//    [self setNeedsDisplay:YES];
//}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(dragEnter)]) {
        [self.delegate dragEnter];
    }
    
    return NSDragOperationGeneric;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(dragExit)]) {
        [self.delegate dragExit];
    }
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    // 获取所有的路径
    NSArray *arr =  [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    if (self.delegate && arr.count > 0 && [self.delegate respondsToSelector:@selector(dragFileComplete:)]) {
        [self.delegate dragFileComplete:arr];
    }
    return YES;
}

@end
