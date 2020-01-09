//
//  ViewController.m
//  DSYMHelper
//
//  Created by 孟庆宇 on 2019/5/31.
//  Copyright © 2019 Damon. All rights reserved.
//

#import "ViewController.h"
#import "QYDragView.h"
#import "ArchiveInfo.h"
#import "UUIDInfo.h"

@interface ViewController()<QYDragViewDelegate,NSTableViewDelegate, NSTableViewDataSource,NSTextFieldDelegate>

/**
 *  显示 archive 文件的 tableView
 */
@property (weak) IBOutlet NSTableView *archiveFilesTableView;

@property (weak) IBOutlet QYDragView *dragView;

@property (weak) IBOutlet NSButton *armv7Button;
@property (weak) IBOutlet NSButton *arm64Button;

@property (weak) IBOutlet NSTextField *uuidLabel;
@property (weak) IBOutlet NSTextField *baseAddressTextField;
@property (weak) IBOutlet NSTextField *crashAddressTextField;
@property (weak) IBOutlet NSTextView *crashCodeTextView;

/**
 *  archive 文件信息数组
 */
@property (strong) NSMutableArray *archiveFilesInfo;

/**
 *  选中的 archive 文件信息
 */
@property (strong) ArchiveInfo *selectedArchiveInfo;

/**
 * 选中的 UUID 信息
 */
@property (strong) UUIDInfo *selectedUUIDInfo;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.dragView.delegate = self;
    
    self.archiveFilesTableView.dataSource = self;
    self.archiveFilesTableView.delegate = self;
}

- (IBAction)addFile:(NSButton *)sender {
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setPrompt: @"打开"];
    [openPanel setCanChooseDirectories:YES]; //设置允许打开文件夹
    [openPanel setAllowsMultipleSelection:YES]; // 会否允许打开多个目录
    [openPanel setCanChooseFiles:YES];  //设置允许打开文件
    [openPanel setCanCreateDirectories:YES]; // 允许新建文件夹
    [openPanel setCanDownloadUbiquitousContents:NO]; //是否处理还未下载成功的文档
    [openPanel setCanResolveUbiquitousConflicts:NO]; //是否处理有冲突的文档
    openPanel.allowedFileTypes = [NSArray arrayWithObjects: @"dSYM", nil]; //设置允许打开的文件类型
    __weak __typeof(self)weakSelf = self;
    [openPanel beginSheetModalForWindow:[NSApplication sharedApplication].keyWindow completionHandler:^(NSModalResponse result) {
        
        NSArray *filePaths = [openPanel URLs];
        NSMutableArray *fileAry = [NSMutableArray array];
        for (NSURL *item in filePaths) {
            NSString *filePathStr = [item.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            if (filePathStr) {
                [fileAry addObject:filePathStr];
            }
        }
        if (fileAry.count > 0) {
            [weakSelf dealFiles:fileAry];
        }
    }];
}

- (IBAction)cpuTypeTap:(NSButton *)sender {
    
    if (self.selectedArchiveInfo == nil) {
        self.arm64Button.state = NSControlStateValueOff;
        self.armv7Button.state = NSControlStateValueOff;
        return ;
    }
    
    if (sender == self.armv7Button) {
        self.arm64Button.state = NSControlStateValueOff;
        
        _selectedUUIDInfo = _selectedArchiveInfo.uuidInfos.firstObject;
    }else if (sender == self.arm64Button) {
        self.armv7Button.state = NSControlStateValueOff;
        
        _selectedUUIDInfo = _selectedArchiveInfo.uuidInfos.lastObject;
    }
    
    self.uuidLabel.stringValue = _selectedUUIDInfo.uuid;
}

- (void)dealFiles:(NSArray *)filePaths
{
    self.archiveFilesInfo = [NSMutableArray arrayWithCapacity:1];
    for(NSString *filePath in filePaths){
        ArchiveInfo *archiveInfo = [[ArchiveInfo alloc] init];

        NSString *fileName = filePath.lastPathComponent;
        if([fileName hasSuffix:@".dSYM"]){
            archiveInfo.dSYMFilePath = filePath;
            archiveInfo.dSYMFileName = fileName;
            archiveInfo.archiveFileType = ArchiveFileTypeDSYM;
            [self formatDSYM:archiveInfo];
            
            [self frameworkNameDSYM:archiveInfo];

        }
        else{
            continue;
        }

        [self.archiveFilesInfo addObject:archiveInfo];
    }
    
    [self.archiveFilesTableView reloadData];
    _selectedArchiveInfo= _archiveFilesInfo.firstObject;
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
    [self.archiveFilesTableView selectRowIndexes:indexSet byExtendingSelection:NO];
    
    [self cpuTypeTap:self.arm64Button];
    self.arm64Button.state = NSControlStateValueOn;
}

/**
 * 根据 dSYM 文件获取 framework name。
 * @param archiveInfo ArchiveInfo
 */
- (void)frameworkNameDSYM:(ArchiveInfo *)archiveInfo{
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *fileList =  [fileManager contentsOfDirectoryAtPath:archiveInfo.dSYMFilePath error:&error];
    if ([fileList containsObject:@"Contents"]) {
        NSArray *contentsList =  [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents",archiveInfo.dSYMFilePath] error:&error];
        if ([contentsList containsObject:@"Resources"]) {
            NSArray *resourcesList =  [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents/Resources",archiveInfo.dSYMFilePath] error:&error];
            if ([resourcesList containsObject:@"DWARF"]) {
                NSArray *DWARFList =  [fileManager contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents/Resources/DWARF",archiveInfo.dSYMFilePath] error:&error];
                archiveInfo.frameworkName = DWARFList.firstObject;
            }
        }
    }
}

/**
 * 根据 dSYM 文件获取 UUIDS。
 * @param archiveInfo ArchiveInfo
 */
- (void)formatDSYM:(ArchiveInfo *)archiveInfo{
    //匹配 () 里面内容
    NSString *pattern = @"(?<=\\()[^}]*(?=\\))";
    NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSString *commandString = [NSString stringWithFormat:@"dwarfdump --uuid \"%@\"",archiveInfo.dSYMFilePath];
    NSString *uuidsString = [self runCommand:commandString];
    NSArray *uuids = [uuidsString componentsSeparatedByString:@"\n"];
    
    NSMutableArray *uuidInfos = [NSMutableArray arrayWithCapacity:1];
    for(NSString *uuidString in uuids){
        NSArray* match = [reg matchesInString:uuidString options:NSMatchingReportCompletion range:NSMakeRange(0, [uuidString length])];
        if (match.count == 0) {
            continue;
        }
        for (NSTextCheckingResult *result in match) {
            NSRange range = [result range];
            UUIDInfo *uuidInfo = [[UUIDInfo alloc] init];
            uuidInfo.arch = [uuidString substringWithRange:range];
            uuidInfo.uuid = [uuidString substringWithRange:NSMakeRange(6, range.location-6-2)];
            uuidInfo.executableFilePath = [uuidString substringWithRange:NSMakeRange(range.location+range.length+2, [uuidString length]-(range.location+range.length+2))];
            [uuidInfos addObject:uuidInfo];
        }
        archiveInfo.uuidInfos = uuidInfos;
    }
}

- (NSString *)runCommand:(NSString *)commandToRun
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    NSArray *arguments = @[@"-c",
                           [NSString stringWithFormat:@"%@", commandToRun]];
    //    NSLog(@"run command:%@", commandToRun);
    [task setArguments:arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}


/**
 * 重置之前显示的信息
 */
- (void)resetPreInformation {
    
    self.arm64Button.state = NSControlStateValueOff;
    self.armv7Button.state = NSControlStateValueOff;
    
    self.uuidLabel.stringValue = @"armv7";
    self.selectedUUIDInfo = nil;
    
    self.baseAddressTextField.stringValue = @"";
    self.crashAddressTextField.stringValue = @"";
    
    self.crashCodeTextView.string = @"";
}

#pragma mark - QYDragViewDelegate

- (void)dragFileComplete:(NSArray *)filepaths
{
    if (filepaths.count > 0) {
        [self dealFiles:filepaths];
    }
    
}

- (void)dragExit
{
    
}

#pragma mark - NSTableViewDataSources
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
    return [_archiveFilesInfo count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    
    ArchiveInfo *archiveInfo= _archiveFilesInfo[row];
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc]init];
        cell.identifier = identifier;
    }
    if(archiveInfo.archiveFileType == ArchiveFileTypeXCARCHIVE){
        cell.textField.stringValue = archiveInfo.archiveFileName;
    }else if(archiveInfo.archiveFileType == ArchiveFileTypeDSYM){
        cell.textField.stringValue = archiveInfo.dSYMFileName;
    }
    
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification{
    NSInteger row = [notification.object selectedRow];
    _selectedArchiveInfo= _archiveFilesInfo[row];
    
    [self resetPreInformation];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if (self.baseAddressTextField.stringValue.length > 0 && self.crashAddressTextField.stringValue.length > 0) {
        
        [self crashDetailBaseAddress:self.baseAddressTextField.stringValue crashAddress:self.crashAddressTextField.stringValue];
    }
}

- (void)crashDetailBaseAddress:(NSString *)baseAddress crashAddress:(NSString *)crashAddress
{
    NSString *cpuType = @"";
    if (self.arm64Button.state == NSControlStateValueOn) {
        cpuType = @"arm64";
    }else{
        cpuType = @"armv7";
    }
    
    NSArray *crashAry = [crashAddress componentsSeparatedByString:@","];
    
    NSMutableString *crashDetailStr = [NSMutableString string];
    for (NSString *crashAddr in crashAry) {
        if ([crashAddr isEqualToString:@""]) {
            continue ;
        }
        NSString *commandString = [NSString stringWithFormat:@"atos -o \"%@/Contents/Resources/DWARF/%@\" -arch %@ -l %@ %@",self.selectedArchiveInfo.dSYMFilePath,self.selectedArchiveInfo.frameworkName,cpuType,self.baseAddressTextField.stringValue,crashAddr];
        NSString *crashString = [self runCommand:commandString];
        
        [crashDetailStr appendFormat:@"%@\n%@\n",crashAddr,crashString];
    }
    
    self.crashCodeTextView.string = crashDetailStr;
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
