//  trash.m
//
//  Created by Ali Rantakari
//  http://hasseg.org/trash
//

/*
The MIT License

Copyright (c) 2010 Ali Rantakari, adapted for Python bindings in 2016 by
Michael Herrmann.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


#include <AppKit/AppKit.h>
#include <ScriptingBridge/ScriptingBridge.h>
#import <libgen.h>
#import "Finder.h"

// (Apple reserves OSStatus values outside the range 1000-9999 inclusive)
#define kHGAppleScriptError         9999
#define kHGNotAllFilesTrashedError  9998

static FinderApplication *getFinderApp()
{
    static FinderApplication *cached = nil;
    if (cached != nil)
        return cached;
    cached = [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
    return cached;
}

// return absolute path for file *without* following possible
// leaf symlink
static NSString *getAbsolutePath(NSString *filePath)
{
    NSString *parentDirPath = nil;
    if (![filePath hasPrefix:@"/"]) // relative path
    {
        NSString *currentPath = [NSString stringWithUTF8String:getcwd(NULL,0)];
        parentDirPath = [[currentPath stringByAppendingPathComponent:[filePath stringByDeletingLastPathComponent]] stringByStandardizingPath];
    }
    else // already absolute -- we just want to standardize without following possible leaf symlink
        parentDirPath = [[filePath stringByDeletingLastPathComponent] stringByStandardizingPath];

    return [parentDirPath stringByAppendingPathComponent:[filePath lastPathComponent]];
}


static ProcessSerialNumber getFinderPSN()
{
    ProcessSerialNumber psn = {0, 0};

    NSEnumerator *appsEnumerator = [[[NSWorkspace sharedWorkspace] launchedApplications] objectEnumerator];
    NSDictionary *appInfoDict = nil;
    while ((appInfoDict = [appsEnumerator nextObject]))
    {
        if ([[appInfoDict objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:@"com.apple.finder"])
        {
            psn.highLongOfPSN = [[appInfoDict objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
            psn.lowLongOfPSN  = [[appInfoDict objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];
            break;
        }
    }

    return psn;
}


static OSStatus askFinderToMoveFilesToTrash(NSArray *filePaths, BOOL bringFinderToFront)
{
    // Here we manually send Finder the Apple Event that tells it
    // to trash the specified files all at once. This is roughly
    // equivalent to the following AppleScript:
    //
    //   tell application "Finder" to delete every item of
    //     {(POSIX file "/path/one"), (POSIX file "/path/two")}
    //
    // First of all, this doesn't seem to be possible with the
    // Scripting Bridge (the -delete method is only available
    // for individual items there, and we don't want to loop
    // through items, calling that method for each one because
    // then Finder would prompt for authentication separately
    // for each one).
    //
    // The second approach I took was to construct an AppleScript
    // string that looked like the example above, but this
    // seemed a bit volatile. 'has' suggested in a comment on
    // my blog that I could do something like this instead,
    // and I thought it was a good idea. Seems to work just
    // fine and this is noticeably faster this way than generating
    // and executing some AppleScript was. I also don't have
    // to worry about input sanitization anymore.
    //

    // generate list descriptor containting the file URLs
    NSAppleEventDescriptor *urlListDescr = [NSAppleEventDescriptor listDescriptor];
    NSInteger i = 1;
    for (NSString *filePath in filePaths)
    {
        NSURL *url = [NSURL fileURLWithPath:getAbsolutePath(filePath)];
        NSAppleEventDescriptor *descr = [NSAppleEventDescriptor
            descriptorWithDescriptorType:'furl'
            data:[[url absoluteString] dataUsingEncoding:NSUTF8StringEncoding]
            ];
        [urlListDescr insertDescriptor:descr atIndex:i++];
    }

    // generate the 'top-level' "delete" descriptor
    ProcessSerialNumber finderPSN = getFinderPSN();
    NSAppleEventDescriptor *targetDesc = [NSAppleEventDescriptor
        descriptorWithDescriptorType:'psn '
        bytes:&finderPSN
        length:sizeof(finderPSN)
        ];
    NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor
        appleEventWithEventClass:'core'
        eventID:'delo'
        targetDescriptor:targetDesc
        returnID:kAutoGenerateReturnID
        transactionID:kAnyTransactionID
        ];

    // add the list of file URLs as argument
    [descriptor setDescriptor:urlListDescr forKeyword:'----'];

    if (bringFinderToFront)
        [getFinderApp() activate];

    // send the Apple Event synchronously
    AppleEvent replyEvent;
    OSStatus sendErr = AESendMessage([descriptor aeDesc], &replyEvent, kAEWaitReply, kAEDefaultTimeout);
    if (sendErr != noErr)
        return sendErr;

    // check reply in order to determine return value
    AEDesc replyAEDesc;
    OSStatus getReplyErr = AEGetParamDesc(&replyEvent, keyDirectObject, typeWildCard, &replyAEDesc);
    if (getReplyErr != noErr)
        return getReplyErr;

    NSAppleEventDescriptor *replyDesc = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&replyAEDesc] autorelease];
    if ([replyDesc numberOfItems] == 0
        || ([filePaths count] > 1 && ([replyDesc descriptorType] != typeAEList || [replyDesc numberOfItems] != (NSInteger)[filePaths count])))
        return kHGNotAllFilesTrashedError;

    return noErr;
}


static FSRef getFSRef(NSString *filePath)
{
    FSRef fsRef;
    FSPathMakeRefWithOptions(
        (const UInt8 *)[filePath fileSystemRepresentation],
        kFSPathMakeRefDoNotFollowLeafSymlink,
        &fsRef,
        NULL // Boolean *isDirectory
        );
    return fsRef;
}

int moveFilesToTrash(int argc, char *files[])
{
    NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];

    int exitValue = 0;

    // Always separate restricted and other items and call askFinderToMoveFilesToTrash() for
    // both groups separately because if the user cancels the authentication any files listed
    // after the first restricted item are not trashed at all
    NSMutableArray *nonRestrictedPathsForFinder = [NSMutableArray arrayWithCapacity:argc];
    NSMutableArray *restrictedPathsForFinder = [NSMutableArray arrayWithCapacity:argc];
    int i;
    for (i = 0; i < argc; i++)
    {
        // Note: don't standardize the path! we don't want to expand leaf symlinks.
        NSString *path = [[NSString stringWithUTF8String:files[i]] stringByExpandingTildeInPath];
        if (path == nil)
        {
            exitValue = 1;
            break;
        }

        if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            exitValue = 2;
            break;
        }

        FSRef fsRef = getFSRef(path);

        // get file info
        FSCatalogInfo catInfo;
        OSErr getCatalogStatus = FSGetCatalogInfo(
            &fsRef,
            kFSCatInfoUserPrivs|kFSCatInfoPermissions,
            &catInfo,
            NULL, // HFSUniStr255 *outName
            NULL, // FSSpecPtr fsSpec
            NULL // FSRef *parentRef
            );
        if (getCatalogStatus != noErr)
        {
            exitValue = 3;
            continue;
        }

        BOOL deletable = ((catInfo.userPrivileges & kioACUserNoMakeChangesMask) == 0);

        if (!deletable)
            [restrictedPathsForFinder addObject:path];
        else
            [nonRestrictedPathsForFinder addObject:path];
    }


    if ([nonRestrictedPathsForFinder count] > 0)
    {
        OSStatus status = askFinderToMoveFilesToTrash(nonRestrictedPathsForFinder, NO);
        if (status != noErr)
            exitValue = 4;
    }

    if ([restrictedPathsForFinder count] > 0)
    {
        OSStatus status = askFinderToMoveFilesToTrash(restrictedPathsForFinder, YES);
        if (status != noErr)
            exitValue = 5;
    }

    [autoReleasePool release];
    return exitValue;
}