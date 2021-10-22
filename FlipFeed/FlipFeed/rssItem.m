//
//  rssItem.m
//  Reader
//
//  Created by Takahiro Sayama on 2012/08/28.
//
//

#import     "rssItem.h"
#include    "build.h"

@implementation rssItem

- (id)init
{
    self = [super init];
    if (self) {
        enabled = YES;
        title = nil;
        link = nil;
        pubDate = nil;
        feed = nil;
        date = nil;
        description = nil;
        enabled = YES;
        voice = nil;
        startPosition = DEFAULT_AUTOSCROLL_START_POSITION;
        scrollWidth = DEFAULT_AUTOSCROLL_WIDTH;
        scrollTimes = DEFAULT_AUTOSCROLL_TIMES;
        scrollInterval = DEFAULT_AUTOSCROLL_INTERVAL;
        disableJavaScript = NO;
    }
    return self;
}

- (void)dealloc
{
    if (title) {
        [title release];
    }
    if (link) {
        [link release];
    }
    if (pubDate) {
        [pubDate release];
    }
    if (feed) {
        [feed release];
    }
    if (date) {
        [date release];
    }
    if (description) {
        [description release];
    }
	[super dealloc];
}

- (void)readItem:(NSXMLElement*)element;
{
    NSDateFormatter *formatter;
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:usLocale];
    boolean_t   logging = YES;
    boolean_t   getTitle = NO;
    boolean_t   getUrl = NO;

    NSArray* children = [element children];
    for (NSXMLNode* node in children) {
        if (logging) {
            NSLog(@"node: %@ = %@, %@", [node name], [node stringValue], [node XMLString]);
        }
        if ([[node name] isEqualToString:@"title"] && getTitle == NO) {
            [self setTitle:[node stringValue]];
            if ([title hasPrefix:@"\n"] == YES) {
                [self removeLF];
            }
            if (logging) {
                NSLog(@"title = %@",[self title]);
            }
            getTitle = YES;
        } else if ([[node name] isEqualToString:@"link"] && getUrl == NO) {
            if ([[node stringValue] hasPrefix:@"http://"] || [[node stringValue] hasPrefix:@"https://"]) {
                [self setLink:[node stringValue]];
                if (logging) {
                    NSLog(@"link = %@",[self link]);
                }
                getUrl = YES;
            } else {
                if ([node XMLString]) {
                    NSString *subString;
                    NSString *href;
                    NSRange range = [[node XMLString] rangeOfString:@"href=\""];
                    if (range.length > 0) {
                        subString = [[node XMLString] substringFromIndex:range.location+range.length];
                        range = [subString rangeOfString:@"\""];
                        if (range.length > 0) {
                            href = [subString substringToIndex:range.location];
                            if (href) {
                                [self setLink:href];
                                getUrl = YES;
                            }
                        }
                    }
                    if (logging) {
                        NSLog(@"%@",[node XMLString]);
                        NSLog(@"link = %@",[self link]);
                    }
                }
            }
        } else if ([[node name] isEqualToString:@"id"] && getUrl == NO &&
                   ([[node stringValue] hasPrefix:@"http://"] || [[node stringValue] hasPrefix:@"https://"])) {
            [self setLink:[node stringValue]];
            if (logging) {
                NSLog(@"id = %@",[self link]);
            }
        } else if (date == nil && [[node name] isEqualToString:@"pubDate"]) {
            [self setPubDate:[node stringValue]];
            if (logging) {
                NSLog(@"pubDate = %@",[self pubDate]);
            }
            [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZZZ"];
            date = [[formatter dateFromString:pubDate] retain];
            if (date == nil) {
                [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
                date = [[formatter dateFromString:pubDate] retain];
            }
            if (date == nil) {
                if ([pubDate length] >= 25) {
                    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"];
                    date = [[formatter dateFromString:[pubDate substringToIndex:25]] retain];
                }
            }
            if (logging) {
                NSLog(@"Date = %@", date);
            }
        } else if (date == nil && [[node name] isEqualToString:@"updated"]) {
            [self setPubDate:[node stringValue]];
            [self removeT];
            if (logging) {
                NSLog(@"updates = %@",[self pubDate]);
            }
            [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ssZZZZ"];
            date = [[formatter dateFromString:pubDate] retain];
            if (date == nil) {
                [self transZ];
                date = [[formatter dateFromString:pubDate] retain];
            }
            if (date == nil) {
                if ([pubDate length] >= 19) {
                    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    date = [[formatter dateFromString:[pubDate substringToIndex:19]] retain];
                }
            }
            if (logging) {
                NSLog(@"Date = %@", date);
            }
        } else if (date == nil && [[node name] isEqualToString:@"dc:date"]) {
            [self setPubDate:[node stringValue]];
            [self removeT];
            if (logging) {
                NSLog(@"updates = %@",[self pubDate]);
            }
            [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ssZZZZ"];
            date = [[formatter dateFromString:pubDate] retain];
            if (date == nil) {
                [formatter setDateFormat:@"EEE, dd MM yyyy HH:mm:ssZZZZ"];
                date = [[formatter dateFromString:pubDate] retain];
            }
            if (date == nil) {
                [self transZ];
                [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ssZZZZ"];
                date = [[formatter dateFromString:pubDate] retain];
            }
            if (date == nil) {
                if ([pubDate length] >= 19) {
                    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    date = [[formatter dateFromString:[pubDate substringToIndex:19]] retain];
                }
            }
            if (logging) {
                NSLog(@"Date = %@", date);
            }
        } else if (description == nil &&
                   ([[node name] isEqualToString:@"description"] ||
                    [[node name] isEqualToString:@"content"])) {
            NSLog(@"%@ = %@",[node name], [node stringValue]);
            [self setDescription:[node stringValue]];
        } else {
            //NSLog(@"%@ = %@",[node name], [node stringValue]);
        }
    }

    if (date) {
        NSString* str;
        NSTimeZone* tz = [NSTimeZone localTimeZone];
        [date dateByAddingTimeInterval:[tz secondsFromGMT]];
        [formatter setDateFormat:@"yyyy/MM/dd HH:mm"];
        str = [[formatter stringFromDate:date] retain];
        [pubDate release];
        pubDate = str;
    }

    [usLocale release];
    [formatter release];
}

- (void)removeLF
{
	NSRange range = [title rangeOfString:@"\n"];
	if (range.length > 0) {
		NSString*  newTitle = [title stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        while ([newTitle hasPrefix:@" "] == YES) {
            NSString* substr = [newTitle substringFromIndex:1];
            newTitle = substr;
        }
        [self setTitle:newTitle];
	}
}

- (void)removeT
{
    NSRange scope = NSMakeRange(10, [pubDate length]-10);
    if ([pubDate length] <= 10) {
        return;
    }
	NSRange range = [pubDate rangeOfString:@"T" options:NSBackwardsSearch range:scope];
	if (range.length > 0) {
        // NSLog(@"range: %ld %ld", range.length, range.location);
		NSString*  newDate = [pubDate stringByReplacingOccurrencesOfString :@"T" withString:@" " options:nil range:range];
        [self setPubDate:newDate];
	}
}

- (void)transZ
{
    if ([pubDate length] == 25) {
        NSString *s1 = [pubDate substringToIndex:22];
        NSString *s2 = [pubDate substringFromIndex:23];
        NSString *newDate = [NSString stringWithFormat:@"%@%@", s1, s2];
        [self setPubDate:newDate];
    }
}

- (bool)isFilterMatched:(NSString*)keyword
{
    if (keyword == nil || link == nil) {
        return NO;
    }
    NSRange range = [link rangeOfString:keyword];
    // NSLog(@"range = %ld,%ld", range.location, range.length);
    if (range.location != NSNotFound && range.length == [keyword length]) {
        return YES;
    }
    return NO;
}

@synthesize     title;
@synthesize     link;
@synthesize     pubDate;
@synthesize     feed;
@synthesize     voice;
@synthesize     date;
@synthesize     description;
@synthesize     enabled;
@synthesize     startPosition;
@synthesize     scrollWidth;
@synthesize     scrollTimes;
@synthesize     scrollInterval;
@synthesize     disableJavaScript;

@end

@implementation rssChannel
- (id)init
{
    self = [super init];
    if (self) {
        rss_version = nil;
        title = nil;
        link = nil;
        description = nil;
        lastBuildDate = nil;
    }
    return self;
}

- (void)dealloc
{
    if (rss_version) {
        [rss_version release];
    }
    if (title) {
        [title release];
    }
    if (link) {
        [link release];
    }
    if (description) {
        [description release];
    }
    if (lastBuildDate) {
        [lastBuildDate release];
    }
	[super dealloc];
}

- (void)readChannel:(NSXMLDocument*)doc
{
    NSArray		*itemNodes = nil;
	NSError     *error;
    boolean_t   logging = NO;
    
    itemNodes = [[doc nodesForXPath:@"//channel/title" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        [self setTitle:[[itemNodes objectAtIndex:0] stringValue]];
        if ([title hasPrefix:@"\n"] == YES) {
            [self removeLF];
        }
        if (logging == YES) {
            NSLog(@"channel/title = %@",[self title]);
        }
    }
    [itemNodes release];
    itemNodes = [[doc nodesForXPath:@"//channel/link" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        [self setLink:[[itemNodes objectAtIndex:0] stringValue]];
        if (logging == YES) {
            NSLog(@"channel/link = %@",[self link]);
        }
    }
    [itemNodes release];
    itemNodes = [[doc nodesForXPath:@"//channel/lastBuildDate" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        [self setLastBuildDate:[[itemNodes objectAtIndex:0] stringValue]];
        if (logging == YES) {
            NSLog(@"channel/lastBuildDate = %@",[self lastBuildDate]);
        }
    }
    [itemNodes release];
    return;
}

- (void)readFeed:(NSXMLDocument*)doc
{
    NSArray		*itemNodes = nil;
	NSError     *error;
    boolean_t   logging = NO;
    
    itemNodes = [[doc nodesForXPath:@"//feed/title" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        [self setTitle:[[itemNodes objectAtIndex:0] stringValue]];
        if ([title hasPrefix:@"\n"] == YES) {
            [self removeLF];
        }
        if (logging == YES) {
            NSLog(@"feed/title = %@",[self title]);
        }
    }
    [itemNodes release];
    itemNodes = [[doc nodesForXPath:@"//feed/id" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        [self setLink:[[itemNodes objectAtIndex:0] stringValue]];
        if (logging == YES) {
            NSLog(@"feed/id = %@",[self link]);
        }
    }
    [itemNodes release];
    itemNodes = [[doc nodesForXPath:@"//feed/updated" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        [self setLastBuildDate:[[itemNodes objectAtIndex:0] stringValue]];
        if (logging == YES) {
            NSLog(@"feed/updated = %@",[self lastBuildDate]);
        }
    }
    [itemNodes release];
    return;
}

- (void)removeLF
{
	NSRange range = [title rangeOfString:@"\n"];
	if (range.length > 0) {
		NSString*  newTitle = [title stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        while ([newTitle hasPrefix:@" "] == YES) {
            NSString* substr = [newTitle substringFromIndex:1];
            newTitle = substr;
        }
        [self setTitle:newTitle];
	}
}

@synthesize     rss_version;
@synthesize     title;
@synthesize     link;
@synthesize     description;
@synthesize     lastBuildDate;

@end
