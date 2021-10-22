//
//  RssReader.h
//  TanukiPortfolio
//
//  Created by Takahiro Sayama on 2012/09/01.
//  Copyright (c) 2012年 tanuki-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "rssItem.h"
#import "Bookmark.h"

@class AppDelegate;

#define SHOW_RETRY_CONT     2

@interface RssReader : NSWindowController {
    Bookmark                        *target;
    rssItem                         *targetItem;
    AppDelegate                     *parent;
    rssChannel                      *channel;
    NSMutableArray                  *rssItems;
    NSString                        *lastFeed;
    NSInteger                       cachePolicy;
    NSInteger                       fetchIndex;
    Boolean                         loading;
	NSString                        *documentTitle;
	NSString                        *documentUrl;
	NSMutableData                   *documentData;
	NSString                        *documentContent;
    NSURLConnection*                lastConnection;
    NSURLConnection*                nextConnection;
    bool                            crawling;
	bool                            crawlingPaused;
    bool                            forward;
    bool                            columnHidden;
    bool                            isWindowLoaded;
    NSInteger                       crawlingCount;
	NSInteger                       crawlingIndex;
	NSInteger                       crawlingDst;
	NSTimer*                        crawlingTimer;
    NSString*                       speechText;
    NSTimer*                        oneShotTimer;
    NSInteger                       showSelectedCount;
	int                             crawlingTimerCmd;
    IBOutlet NSArrayController      *rssArray;
    IBOutlet NSTextField            *feedField;
    IBOutlet NSButton               *forwardButton;
    IBOutlet NSButton               *backButton;
    IBOutlet NSButton               *linkButton;
    IBOutlet NSProgressIndicator    *progress;
	IBOutlet NSTableView            *tableView;
    IBOutlet NSComboBox             *comboBoxBookmark;
    IBOutlet NSWindow               *win;
    IBOutlet NSTextView             *textView;
    IBOutlet NSTextField            *linkField;
}

- (IBAction)selectBookmark:(id)sender;
- (IBAction)fetch:(id)sender;
- (IBAction)fetchAll:(id)sender;
- (IBAction)fetchRSS:(id)sender;
- (IBAction)openItem:(id)sender;
- (IBAction)startRssConnection:(id)sender;
- (IBAction)crawlingRSS:(id)sender;
- (IBAction)modifyArticle:(id)sender;
- (IBAction)speechArticle:(id)sender;

- (void)showSelectedRow:(NSTimer*)timer;
- (void)getFeed:(NSData*)urlData;
- (void)handleFeedChange:(NSNotification*)note;
- (void)rearrengeArticle;
- (void)actionDoubleClick:(id)sender;
- (void)startConnection:(NSURLRequest*)req;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data;
- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)startCrawling:(NSInteger)indexFrom :(NSInteger)indexTo;
- (void)stopCrawling:(bool)warn;
- (void)skipCrawling;
- (void)continueCrawling;
- (void)preFetchCrawling;
- (void)pauseCrawling:(bool)pause;
- (void)startTimerCrawling:(int)cmd;
- (void)stopTimerCrawling;
- (void)checkTimerCrawling:(NSTimer*) timer;
- (void)clearTarget;
- (void)clearTargetItem;
- (void)buildSpeechText;
- (void)localizeView;
- (void)actionSelected:(NSNotification *)notification;

@property   (readwrite,retain)	NSMutableArray  *rssItems;
@property   (readwrite,assign)	NSTableView     *tableView;
@property   (readwrite,assign)  AppDelegate     *parent;
@property   (readwrite,assign)  NSTextField     *feedField;
@property	(readwrite)			Boolean			loading;
@property	(readwrite)			int             crawlingTimerCmd;
@property	(readwrite)			bool			crawling;
@property	(readwrite)			bool			crawlingPaused;
@property	(readwrite)			bool			forward;
@property	(readwrite)			bool			isWindowLoaded;
@property	(readwrite,retain)  Bookmark        *target;
@property	(readwrite,retain)  rssItem         *targetItem;
@property	(readwrite,retain)  NSString        *speechText;
@property	(readwrite,retain)  NSURLConnection *lastConnection;

@end
