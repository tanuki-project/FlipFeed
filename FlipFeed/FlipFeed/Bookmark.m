//
//  Bookmark.m
//  tPortfolio
//
//  Created by Takahiro Sayama on 11/01/10.
//  Copyright 2011 tanuki-project. All rights reserved.
//

#import		"Bookmark.h"
#include    "build.h"

@implementation Bookmark

- (id)init
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
	title = nil;
	url = nil;
    enabled = YES;
    startPosition = DEFAULT_AUTOSCROLL_START_POSITION;
    scrollWidth = DEFAULT_AUTOSCROLL_WIDTH;
    scrollTimes = DEFAULT_AUTOSCROLL_TIMES;
    scrollInterval = DEFAULT_AUTOSCROLL_INTERVAL;
    urlFilter = @"";
    disableJavaScript = NO;
    voice = nil;
	return self;
}

- (id)initWithXmlElement:(NSXMLElement*)element
{
    Bookmark* new = [[Bookmark alloc] init];
    if (new) {
        NSArray* children = [element children];
        for (NSXMLNode* node in children) {
            NSLog(@"%@ = %@", [node name], [node stringValue]);
            if ([[node name] isEqualToString:@"title"]) {
                [new setTitle:[node stringValue]];
            } else if ([[node name] isEqualToString:@"link"]) {
                [new setUrl:[node stringValue]];
            } else if ([[node name] isEqualToString:@"voice"]) {
                [new setVoice:[node stringValue]];
            } else if ([[node name] isEqualToString:@"enabled"]) {
                if ([[node stringValue] isEqualToString:@"yes"]) {
                    [new setEnabled:YES];
                } else {
                    [new setEnabled:NO];
                }
            } else if ([[node name] isEqualToString:@"disableJavaScript"]) {
                if ([[node stringValue] isEqualToString:@"yes"]) {
                    [new setDisableJavaScript:YES];
                } else {
                    [new setDisableJavaScript:NO];
                }
            } else if ([[node name] isEqualToString:@"filter"]) {
                [new setUrlFilter:[node stringValue]];
            } else if ([[node name] isEqualToString:@"startPosition"]) {
                [new setStartPosition:[[node stringValue] integerValue]];
            } else if ([[node name] isEqualToString:@"scrollWidth"]) {
                [new setScrollWidth:[[node stringValue] integerValue]];
            } else if ([[node name] isEqualToString:@"scrollTimes"]) {
                [new setScrollTimes:[[node stringValue] integerValue]];
            } else if ([[node name] isEqualToString:@"scrollInterval"]) {
                [new setScrollInterval:[[node stringValue] floatValue]];
            }
        }
        if ([new title] == nil || [new url] == nil) {
            [new release];
            return nil;
        }
    }
    return new;
}

- (void)dealloc
{
	if (title) {
		[title release];
	}
	if (url) {
		[url release];
	}
    if (voice) {
        [voice release];
    }
	[super dealloc];
}

- (void)setBookmark:(NSString*)newTitle :(NSString*)newUrl
{
	if (title) {
		[title release];
	}
	if (url) {
		[url release];
	}
	if (newTitle) {
		title = [newTitle retain];
	} else {
		title = nil;
	}
	url = [newUrl retain];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	// NSLog(@"encodeWithCoder @% @%", title, url);
	[coder encodeObject:title forKey:@"title"];
	[coder encodeObject:url forKey:@"url"];
    if (voice != nil) {
        [coder encodeObject:voice forKey:@"voice"];
    }
	[coder encodeBool:enabled forKey:@"enabled"];
	[coder encodeInteger:startPosition forKey:@"startPosition"];
	[coder encodeInteger:scrollWidth forKey:@"scrollWidth"];
	[coder encodeInteger:scrollTimes forKey:@"scrollTimes"];
	[coder encodeFloat:scrollInterval forKey:@"scrollInterval"];
	[coder encodeObject:urlFilter forKey:@"urlFilter"];
	[coder encodeBool:disableJavaScript forKey:@"disableJavaScript"];
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	title = [[coder decodeObjectForKey:@"title"] retain];
    if (title == nil) {
        title = @"";
    }
	url = [[coder decodeObjectForKey:@"url"] retain];
    if (url == nil) {
        url = @"";
    }
	voice = [[coder decodeObjectForKey:@"voice"] retain];
    enabled = [coder decodeBoolForKey:@"enabled"];
    startPosition = [coder decodeIntegerForKey:@"startPosition"];
    if (startPosition < 0) {
        startPosition = DEFAULT_AUTOSCROLL_START_POSITION;
    }
    scrollWidth = [coder decodeIntegerForKey:@"scrollWidth"];
    if (scrollWidth < 0) {
        scrollWidth = DEFAULT_AUTOSCROLL_WIDTH;
    }
    scrollTimes = [coder decodeIntegerForKey:@"scrollTimes"];
    if (scrollTimes < 0) {
        scrollTimes = DEFAULT_AUTOSCROLL_TIMES;
    }
    scrollInterval = [coder decodeFloatForKey:@"scrollInterval"];
    if (scrollInterval < 0) {
        scrollInterval = DEFAULT_AUTOSCROLL_INTERVAL;
    }
	urlFilter = [[coder decodeObjectForKey:@"urlFilter"] retain];
    if (urlFilter == nil) {
        urlFilter = @"";
    }
    disableJavaScript = [coder decodeBoolForKey:@"disableJavaScript"];
	// NSLog(@"initWithCoder @% @%", title, url);
	return self;
}

- (int)buildXMLElement:(NSXMLElement*)element {
    if (element == nil) {
        return -1;
    }
    NSXMLElement* value;
    value = [[NSXMLElement alloc] initWithName:@"title"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue:title];
    [element addChild:value];
    [value release];
    value = [[NSXMLElement alloc] initWithName:@"link"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue:url];
    [element addChild:value];
    [value release];
    if (voice) {
        value = [[NSXMLElement alloc] initWithName:@"voice"];
        if (value == nil) {
            return -1;
        }
        [value setStringValue:voice];
        [element addChild:value];
        [value release];
    }
    value = [[NSXMLElement alloc] initWithName:@"enabled"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue:enabled ? @"yes" : @"no"];
    [element addChild:value];
    [value release];
    value = [[NSXMLElement alloc] initWithName:@"disableJavaScript"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue:disableJavaScript ? @"yes" : @"no"];
    [element addChild:value];
    [value release];
    if (urlFilter && [urlFilter length] > 0) {
        value = [[NSXMLElement alloc] initWithName:@"filter"];
        if (value == nil) {
            return -1;
        }
        [value setStringValue:urlFilter];
        [element addChild:value];
        [value release];
    }
    value = [[NSXMLElement alloc] initWithName:@"startPosition"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue: [NSString stringWithFormat:@"%ld",(long)startPosition]];
    [element addChild:value];
    [value release];
    value = [[NSXMLElement alloc] initWithName:@"scrollWidth"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue: [NSString stringWithFormat:@"%ld",(long)scrollWidth]];
    [element addChild:value];
    [value release];
    value = [[NSXMLElement alloc] initWithName:@"scrollTimes"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue: [NSString stringWithFormat:@"%ld",(long)scrollTimes]];
    [element addChild:value];
    [value release];
    value = [[NSXMLElement alloc] initWithName:@"scrollInterval"];
    if (value == nil) {
        return -1;
    }
    [value setStringValue: [NSString stringWithFormat:@"%0.1f",scrollInterval]];
    [element addChild:value];
    [value release];
    return 0;
}

- (bool)isEqualBookmark:(Bookmark*)src :(Bookmark*)dst
{
	if ([[src url] isEqualToString:[dst url]] &&
		[[src title] isEqualToString:[dst title]]) {
		return YES;
	}
	return NO;
}

- (bool)isEqualToDomain:(NSString*)urlString
{
    if (url == nil || [url isEqualToString:@""] == YES ||
        urlString == nil || [url isEqualToString:@""]) {
        return NO;
    }
    NSURL *bookmarkUrl = [NSURL URLWithString:url];
    NSURL *feedUrl = [NSURL URLWithString:urlString];
    if ([[bookmarkUrl host] isEqualToString:[feedUrl host]] == YES) {
        return YES;
    }
    /*
    NSMutableString *domain = [[NSMutableString alloc] initWithString:@""];
    NSArray *tokens = [[feedUrl host] componentsSeparatedByString:@"."];
    NSInteger i = [tokens count] - 3;
    if (i < 0) {
        i = 0;
    }
    for ( ; i < [tokens count]; i++) {
        if ([domain length] > 0) {
            [domain appendString:@"."];
        }
        [domain appendString:[tokens objectAtIndex:i]];
    }
    NSLog(@"domain = %@", domain);
    NSRange range = [url rangeOfString:domain];
    NSLog(@"range = %ld,%ld", range.location, range.length);
    [domain release];
    if (range.location > 0 && range.length > 0) {
        return YES;
    }
     */
    return NO;
}

@synthesize		title;
@synthesize		url;
@synthesize     voice;
@synthesize     enabled;
@synthesize     startPosition;
@synthesize     scrollWidth;
@synthesize     scrollTimes;
@synthesize     scrollInterval;
@synthesize     urlFilter;
@synthesize     disableJavaScript;

@end
