//
//  RHEAEntityResolver.h
//  Rhea
//
//  Created by Tim Johnsen on 8/5/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RHEAEntityResolver : NSObject

+ (nullable id)resolveEntity:(const id)entity;
+ (id)resolvePasteboard:(NSPasteboard *)pasteboard;

@end

NS_ASSUME_NONNULL_END
