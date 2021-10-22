//
//  rssItem.h
//  Reader
//
//  Created by Takahiro Sayama on 2012/08/28.
//
//

#import <Foundation/Foundation.h>
#import "Bookmark.h"

@interface rssItem : NSObject {
    BOOL        enabled;
    NSString*   title;
    NSString*   link;
    NSString*   pubDate;
    NSString*   feed;
    NSDate*     date;
    NSString*   description;
    NSString*   voice;
    NSInteger   startPosition;
    NSInteger   scrollWidth;
    NSInteger   scrollTimes;
    float       scrollInterval;
    BOOL        disableJavaScript;
}

- (void)readItem:(NSXMLElement*)element;
- (void)removeLF;
- (void)removeT;
- (void)transZ;
- (bool)isFilterMatched:(NSString*)keyword;

@property	(readwrite,copy)	NSString*   title;
@property	(readwrite,copy)	NSString*   link;
@property	(readwrite,copy)	NSString*   pubDate;
@property	(readwrite,copy)	NSString*   feed;
@property	(readwrite,copy)	NSString*   voice;
@property	(readwrite,copy)	NSDate*     date;
@property	(readwrite,copy)	NSString*   description;
@property	(readwrite)         BOOL        enabled;
@property	(readwrite)         NSInteger   startPosition;
@property	(readwrite)         NSInteger   scrollWidth;
@property	(readwrite)         NSInteger   scrollTimes;
@property	(readwrite)         float       scrollInterval;
@property	(readwrite)         BOOL        disableJavaScript;

@end

@interface rssChannel : NSObject {
    NSString*   rss_version;
    NSString*   title;
    NSString*   link;
    NSString*   description;
    NSString*   lastBuildDate;
}

- (void)readChannel:(NSXMLDocument*)doc;
- (void)readFeed:(NSXMLDocument*)doc;
- (void)removeLF;

@property	(readwrite,copy)	NSString*   rss_version;
@property	(readwrite,copy)	NSString*   title;
@property	(readwrite,copy)	NSString*   link;
@property	(readwrite,copy)	NSString*   description;
@property	(readwrite,copy)	NSString*   lastBuildDate;

@end