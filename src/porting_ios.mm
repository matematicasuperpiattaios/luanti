// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2025 SFENCE <sfence.software@gmail.com>

#include "porting_ios.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

namespace porting
{

std::string getAppleDocumentsDirectory() {
    @autoreleasepool {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        return std::string([[paths firstObject] UTF8String]);
    }
}

std::string getAppleLibraryDirectory() {
    @autoreleasepool {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        return std::string([[paths firstObject] UTF8String]);
    }
}

std::string getAppleCacheDirectory()
{
    @autoreleasepool {
        NSURL *url = [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:nil];

        return std::string([[url path] UTF8String]);
    }
}

bool openURLApple(const std::string &url) {
    @autoreleasepool {
        NSString *urlStr = [NSString stringWithUTF8String:url.c_str()];
        NSURL *nsurl = urlStr ? [NSURL URLWithString:urlStr] : nil;
        if (nsurl == nil)
            return false;

        // -openURL: must run on the main thread; dispatch there unconditionally.
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:nsurl
                                               options:@{}
                                     completionHandler:nil];
        });
        return true;
    }
}

// namespace porting
}
