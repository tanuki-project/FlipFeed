//
//  Bookmark.h
//  tPortfolio
//
//  Created by Takahiro Sayama on 11/01/10.
//  Copyright 2011 tanuki-project. All rights reserved.
//

#import		<Foundation/Foundation.h>

#define DEFAULT_AUTOSCROLL_START_POSITION   3
#define DEFAULT_AUTOSCROLL_WIDTH            12
#define DEFAULT_AUTOSCROLL_TIMES            2
#define DEFAULT_AUTOSCROLL_SPEED            14
#define DEFAULT_AUTOSCROLL_INTERVAL         3.5

#define MIN_AUTOSCROLL_INTERVAL             1.0
#define MAX_AUTOSCROLL_INTERVAL             30.0
#define MIN_AUTOSCROLL_SPEED                4
#define MAX_AUTOSCROLL_SPEED                24

@interface Bookmark : NSObject {
    BOOL        enabled;
	NSString*	title;
	NSString*	url;
    NSInteger   startPosition;
    NSInteger   scrollWidth;
    NSInteger   scrollTimes;
    float       scrollInterval;
    NSString*   urlFilter;
    BOOL        disableJavaScript;
    NSString*   voice;
}

- (id)init;
- (id)initWithXmlElement:(NSXMLElement*)element;
- (void)setBookmark:(NSString*)newTitle :(NSString*)newUrl;
- (bool)isEqualBookmark:(Bookmark*)src :(Bookmark*)dst;
- (bool)isEqualToDomain:(NSString*)url;
- (int)buildXMLElement:(NSXMLElement*)element;

@property	(readwrite,copy)	NSString*		title;
@property	(readwrite,copy)	NSString*		url;
@property	(readwrite,copy)	NSString*		voice;
@property	(readwrite)         BOOL            enabled;
@property	(readwrite)         NSInteger       startPosition;
@property	(readwrite)         NSInteger       scrollWidth;
@property	(readwrite)         NSInteger       scrollTimes;
@property	(readwrite)         float           scrollInterval;
@property	(readwrite,copy)	NSString*		urlFilter;
@property	(readwrite)         BOOL            disableJavaScript;

@end
