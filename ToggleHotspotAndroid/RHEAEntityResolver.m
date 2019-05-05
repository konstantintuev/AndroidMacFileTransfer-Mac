//
//  RHEAEntityResolver.m
//  Rhea
//
//  Created by Tim Johnsen on 8/5/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "RHEAEntityResolver.h"

@implementation RHEAEntityResolver

+ (id)resolveEntity:(id)entity
{
    id result = nil;
    if ([entity isKindOfClass:[NSString class]]) {
        NSURL *const url = [NSURL URLWithString:[(NSString *)entity stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        if (url.scheme.length > 0) { // -URLWithString: parses file paths successfully, check the scheme to ensure it's not just a path.
            result = [self resolveURL:url];
        } else {
            result = [self resolvePath:entity];
        }
    } else if ([entity isKindOfClass:[NSURL class]]) {
        result = [self resolveURL:entity];
    }
    return result;
}

+ (id)resolvePasteboard:(NSPasteboard *)pasteboard
{
    // http://stackoverflow.com/a/423702/3943258

    id resolvedEntity = nil;

    NSArray *const paths = [pasteboard propertyListForType:NSFilenamesPboardType];
    NSArray *const urls = [pasteboard propertyListForType:NSURLPboardType];
    NSString *const string = [pasteboard stringForType:NSStringPboardType];

    if (paths.count > 0) {
        if (paths.count == 1) {
            resolvedEntity = [RHEAEntityResolver resolveEntity:[paths firstObject]];
        }
    } else if (urls.count > 0) {
        const id object = [urls firstObject];
        NSURL *url = nil;
        if ([object isKindOfClass:[NSURL class]]) {
            url = object;
        } else if ([object isKindOfClass:[NSString class]]) {
            url = [NSURL URLWithString:object];
        }
        if (url) {
            resolvedEntity = [RHEAEntityResolver resolveEntity:url];
        }
    } else if (string) {
        resolvedEntity = [RHEAEntityResolver resolveEntity:string];
    }

    return resolvedEntity;
}

+ (id)resolvePath:(NSString *const)path
{
    id result = nil;
    NSString *const extension = [[NSURL fileURLWithPath:path] pathExtension];
    if ([extension isEqualToString:@"webloc"]) {
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:path] options:0 format:nil error:nil];
        NSURL *const url = [NSURL URLWithString:plist[@"URL"]];
        result = [self resolveURL:url];
    } else {
        BOOL isDirectory = NO;
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
        if (fileExists && !isDirectory) {
            result = path;
        }
    }
    return result;
}

+ (id)resolveURL:(NSURL *const)url
{
    id result = nil;
    if ([url.scheme isEqualToString:@"file"]) {
        result = [self resolvePath:url.path];
    } else {
        result = url;
    }
    return result;
}


@end
