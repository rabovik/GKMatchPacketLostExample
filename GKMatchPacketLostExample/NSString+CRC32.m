//
//  NSString+CRC32.m
//  GKMatchPacketLostExample
//
//  Created by Yan Rabovik on 20.06.13.
//  Copyright (c) 2013 Yan Rabovik. All rights reserved.
//

#import "NSString+CRC32.h"
#import <zlib.h>

@implementation NSString (CRC32)

-(unsigned long)crc32{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    return crc32(0, data.bytes, data.length);
}


@end
