/*
 Copyright (c) 2014, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if !__has_feature(objc_arc)
#error XLFacility requires ARC
#endif

#import <objc/runtime.h>

#import "XLTCPClientLogger.h"
#import "XLFunctions.h"
#import "XLFacilityPrivate.h"

static void* _associatedObjectKey = &_associatedObjectKey;

@implementation GCDTCPClientConnection (XLTCPClientLogger)

- (XLTCPClientLogger*)logger {
  return objc_getAssociatedObject(self.peer, _associatedObjectKey);
}

@end

@implementation XLTCPClientLogger

+ (Class)clientClass {
  return [GCDTCPClient class];
}

+ (Class)connectionClass {
  return [GCDTCPClientConnection class];
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithHost:(NSString*)hostname port:(NSUInteger)port {
  XLOG_DEBUG_CHECK([[[self class] clientClass] isSubclassOfClass:[GCDTCPClient class]]);
  if ((self = [super init])) {
    _TCPClient = [[[[self class] clientClass] alloc] initWithConnectionClass:[[self class] connectionClass] host:hostname port:port];
    objc_setAssociatedObject(_TCPClient, _associatedObjectKey, self, OBJC_ASSOCIATION_ASSIGN);
    _sendTimeout = -1.0;
  }
  return self;
}

- (BOOL)open {
  return [_TCPClient start];
}

- (void)logRecord:(XLLogRecord*)record {
  NSData* data = XLConvertNSStringToUTF8String([self formatRecord:record]);
  if (_sendTimeout < 0.0) {
    [_TCPClient.connection writeDataAsynchronously:data completion:^(BOOL success) {
      if (!success) {
        [_TCPClient.connection close];
      }
    }];
  } else {
    if (![_TCPClient.connection writeData:data withTimeout:_sendTimeout]) {
      [_TCPClient.connection close];
    }
  }
}

- (void)close {
  [_TCPClient stop];
}

@end
