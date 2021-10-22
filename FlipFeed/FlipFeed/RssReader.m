//
//  RssReader.m
//  TanukiPortfolio
//
//  Created by Takahiro Sayama on 2012/09/01.
//  Copyright (c) 2012年 tanuki-project. All rights reserved.
//

#import     "RssReader.h"
#include    "build.h"

extern  NSString* gReaderFeedListKey;
extern  NSString* gReaderLastFeedKey;
extern  NSString* gReaderShowReaderKey;

extern BOOL     isLiteVresion;

Boolean         enableTimer = YES;

extern BOOL     enableSpeech;
extern BOOL     enabelPreFetch;
extern BOOL     enableJavaScript;
extern BOOL     willTerminate;
extern bool     skipBrowse;

Boolean         disableWindowDidLoaded = YES;

@interface RssReader ()

@end

@implementation RssReader

- (id)init
{
	NSLog(@"init RssReader");
	if (self) {
        self = [super initWithWindowNibName:@"RssReader"];
        channel = [[rssChannel alloc] init];
        rssItems = [[NSMutableArray alloc] init];
        lastFeed = nil;
        cachePolicy = NSURLRequestReturnCacheDataElseLoad;
        fetchIndex = 0;
        loading = NO;
        documentTitle = nil;
        documentUrl = nil;
        documentContent = nil;
        documentData = nil;
        lastConnection = nil;
        nextConnection = nil;
        crawling = NO;
        crawlingPaused = NO;
        crawlingIndex = 0;
        crawlingDst = 0;
        crawlingTimer = nil;
        target = nil;
        targetItem = nil;
        columnHidden = YES;
        isWindowLoaded = NO;
        speechText = nil;
        oneShotTimer = nil;
	}
    return self;
}

- (void)dealloc
{
	NSLog(@"dealloc RssReader");
    [rssItems removeAllObjects];
    [self stopCrawling:NO];
	[super dealloc];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    if (disableWindowDidLoaded == YES) {
        [self initializeReader];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    if (disableWindowDidLoaded == YES) {
        return;
    }
    [tableView setDoubleAction:@selector(actionDoubleClick:)];
    [tableView setAction:@selector(actionClick:)];

	NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(actionSelected:)
               name:NSTableViewSelectionDidChangeNotification
             object:[self tableView]];
    [nc addObserver:self selector:@selector(readerClose:)
               name:NSWindowWillCloseNotification
             object:[self window]];
    [self localizeView];
    [self handleFeedChange:nil];
    [tableView setTarget:self];
    [tableView reloadData];
    cachePolicy = NSURLRequestReloadRevalidatingCacheData;
    NSTableColumn *column = [tableView tableColumnWithIdentifier:@"Feed"];
    [column setHidden:columnHidden];
    return;
}

- (void)initializeReader
{
    [tableView setDoubleAction:@selector(actionDoubleClick:)];
    [tableView setAction:@selector(actionClick:)];
    
    NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(actionSelected:)
               name:NSTableViewSelectionDidChangeNotification
             object:[self tableView]];
    [nc addObserver:self selector:@selector(readerClose:)
               name:NSWindowWillCloseNotification
             object:win];
    [self localizeView];
    [self handleFeedChange:nil];
    [tableView setTarget:self];
    [tableView reloadData];
    cachePolicy = NSURLRequestReloadRevalidatingCacheData;
    NSTableColumn *column = [tableView tableColumnWithIdentifier:@"Feed"];
    [column setHidden:columnHidden];
    return;
}

- (void)readerClose:(NSNotification *)notification {
	NSLog(@"readerClose:");
    if (willTerminate == YES) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:gReaderShowReaderKey];
}

- (void)actionSelected:(NSNotification *)notification {
    if ([notification object] != tableView) {
        return;
    }
    showSelectedCount = SHOW_RETRY_CONT;
	if (oneShotTimer) {
		[oneShotTimer invalidate];
		[oneShotTimer release];
		oneShotTimer = nil;
	}
	oneShotTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
													  target:self
													selector:@selector(showSelectedRow:)
													userInfo:nil
													 repeats:NO] retain];
    //[self showSelectedRow];
}

- (void)showSelectedRow:(NSTimer*)timer
{
    NSInteger row = [tableView selectedRow];
    if (row == -1) {
        [textView setString:@""];
        [linkField setStringValue:@""];
        return;
    }
    NSLog(@"actionSelected: %ld", (long)row);
    rssItem *item = [rssItems objectAtIndex:row];
    if (item && [item description]) {
        NSData *data = [[item description] dataUsingEncoding:NSUTF16StringEncoding];
        NSDictionary *dic = [[NSDictionary alloc] init];
        NSAttributedString *as = [[NSAttributedString alloc] initWithHTML:data options:dic documentAttributes:nil];
        if (as) {
            [[textView textStorage] setAttributedString:as];
            NSFont *font = [NSFont systemFontOfSize:15];
            [[textView textStorage] setFont:font];
            // NSLog(@"font = %@", [[textView textStorage]font]);
            [as release];
        } else {
            [textView setString:[item description]];
        }
        [linkField setStringValue:[item link]];
        [dic release];
    } else {
        [textView setString:@""];
        [linkField setStringValue:@""];
    }
    [parent setArticleIndex:row];
    if (showSelectedCount > 0) {
        showSelectedCount--;
        if (oneShotTimer) {
            [oneShotTimer invalidate];
            [oneShotTimer release];
            oneShotTimer = nil;
        }
        oneShotTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
                                                         target:self
                                                       selector:@selector(showSelectedRow:)
                                                       userInfo:nil
                                                        repeats:NO] retain];
    }
}

- (IBAction)fetch:(id)sender
{
    if ([[feedField stringValue] hasPrefix:@"http://"] == NO &&
        [[feedField stringValue] hasPrefix:@"https://"] == NO &&
        [[feedField stringValue] hasPrefix:@"feed://"] == NO) {
        return;
    }
    NSLog(@"fetch: %@", [feedField stringValue]);
    if ([lastFeed isEqualToString:[feedField stringValue]] == YES) {
        return;
    }
    if (loading == YES) {
        return;
    }
    if (target) {
        [target release];
    }
    target = nil;
    for (Bookmark *item in [parent feeds]) {
        if ([feedField stringValue] && [[feedField stringValue] isEqualToString:[item url]] == YES) {
            target = [item retain];
        }
    }
    if ([parent enableSound] == YES) {
        NSSound *sound = [NSSound soundNamed:@"Pop"];
        [sound play];
    }
    [self stopCrawling:YES];
    [self fetchRSS:sender];
    return;
}

- (IBAction)fetchRSS:(id)sender
{
    [rssItems removeAllObjects];
    [rssArray rearrangeObjects];
    [tableView reloadData];
    [parent rearrangeArticle];
    [linkButton setHidden:YES];
    [progress setHidden:NO];
    [progress startAnimation:nil];
    [rssItems removeAllObjects];
    [rssArray rearrangeObjects];
    [tableView reloadData];
    [parent rearrangeArticle];
    [feedField setEnabled:NO];
    [forwardButton setEnabled:NO];
    [[parent forwardFeedButton] setEnabled:NO];
    [backButton setEnabled:NO];
    [[parent backFeedButton] setEnabled:NO];
    [[parent skipFeedButton] setEnabled:NO];
    loading = NO;
    NSTableColumn *column = [tableView tableColumnWithIdentifier:@"Feed"];
    [column setHidden:YES];
    columnHidden = YES;
    [self startRssConnection:self];
    return;
}

- (IBAction)fetchAll:(id)sender
{
    if ([[parent feeds] count] == 0) {
        return;
    }
    for (fetchIndex = 0; fetchIndex < [[parent feeds] count]; fetchIndex++) {
        Bookmark *item = [[parent feeds] objectAtIndex:fetchIndex];
        if ([item enabled] == YES) {
            break;
        }
    }
    if (fetchIndex >= [[parent feeds] count]) {
        if (sender != parent) {
            NSBeep();
        }
        return;
    }
    if (loading == YES) {
        loading = NO;
        return;
    }
    [self stopCrawling:YES];
    [linkButton setEnabled:NO];
    [linkButton setHidden:YES];
    [progress setHidden:NO];
    [progress startAnimation:nil];
    [rssItems removeAllObjects];
    [rssArray rearrangeObjects];
    [tableView reloadData];
    [parent rearrangeArticle];
    [feedField setEnabled:NO];
    [forwardButton setEnabled:NO];
    [[parent forwardFeedButton] setEnabled:NO];
    [backButton setEnabled:NO];
    [[parent backFeedButton] setEnabled:NO];
    [[parent skipFeedButton] setEnabled:NO];
    loading = YES;
    NSTableColumn *column = [tableView tableColumnWithIdentifier:@"Feed"];
    [column setHidden:NO];
    columnHidden = NO;

    if (target) {
        [target release];
        target = nil;
    }
    Bookmark* feed = [[parent feeds] objectAtIndex:fetchIndex];
    if (feed) {
        target = [feed retain];
        [feedField setStringValue:[feed url]];
        [self startRssConnection:self];
    }
    fetchIndex++;
    for (; fetchIndex < [[parent feeds] count]; fetchIndex++) {
        Bookmark *item = [[parent feeds] objectAtIndex:fetchIndex];
        if ([item enabled] == YES) {
            break;
        }
    }
}

- (void)getFeed:(NSData*)urlData
{
	NSXMLDocument		*doc = nil;
	NSError             *error;
    boolean_t           bFeed;
    if (urlData == nil) {
        return;
    }
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
                                     defaultButton:NSLocalizedString(@"OK",@"Ok")
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"PARSE_RSS_FAILED", @"Failed to parse RSS.")];

	doc = [[NSXMLDocument alloc] initWithData:urlData
									  options:NSXMLDocumentTidyXML
										error:&error];
	if (!doc) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
	}

    NSArray* itemNodes = nil;
    itemNodes = [[doc nodesForXPath:@"//feed" error:&error] retain];
    if (itemNodes && [itemNodes count] > 0) {
        bFeed = YES;
    } else {
        bFeed = NO;
    }
    if (itemNodes) {
        [itemNodes release];
    }
    if (bFeed == NO) {
        itemNodes = [[doc nodesForXPath:@"//channel" error:&error] retain];
        if (itemNodes == nil) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
            [doc release];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
            return;
        }
        if ([itemNodes count] == 0) {
            [itemNodes release];
            [doc release];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
            //[feedField setStringValue:@""];
            if ([parent enableRedirect] == YES) {
                [parent setEnableRedirect:NO];
                [parent loadUrl:[feedField stringValue]];
                [parent setEnableRedirect:YES];
            } else {
                [parent loadUrl:[feedField stringValue]];
            }
            return;
        }
        [itemNodes release];
    }
    if (bFeed) {
        [channel readFeed:doc];
    } else {
        [channel readChannel:doc];
    }
    [win setTitle:[channel title]];

    if (bFeed) {
        itemNodes = [[doc nodesForXPath:@"//entry" error:&error] retain];
    } else {
        itemNodes = [[doc nodesForXPath:@"//item" error:&error] retain];
    }
	if (itemNodes == nil) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
        [doc release];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
	}
    [itemNodes release];
    
    for (NSXMLElement* element in itemNodes) {
        if ([element kind] != NSXMLElementKind) {
            continue;
        }
        rssItem* item = [[rssItem alloc] init];
        [item readItem:element];
        if ([item link] && [[item link] isEqualToString:@""] == NO) {
            [item setFeed:[channel title]];
            if (target) {
                if ([target voice]) {
                    [item setVoice:[target voice]];
                }
                [item setStartPosition:[target startPosition]];
                [item setScrollWidth:[target scrollWidth]];
                [item setScrollTimes:[target scrollTimes]];
                [item setScrollInterval:[target scrollInterval]];
                [item setDisableJavaScript:[target disableJavaScript]];
                if ([target urlFilter] && [[target urlFilter] isEqualToString:@""] == NO) {
                    if ([item isFilterMatched:[target urlFilter]] == NO) {
                        [item setEnabled:NO];
                    }
                }
                /*
                if ([target isEqualToDomain:[item link]] == NO) {
                    [item setEnabled:NO];
                }
                 */
            }
            [rssItems addObject:item];
        }
        [item release];
    }
    if ([rssItems count] > 0) {
        [linkButton setEnabled:YES];
    }
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[feedField stringValue] forKey:gReaderLastFeedKey];
    if (lastFeed) {
        [lastFeed release];
        lastFeed = nil;
    }
    if (feedField) {
        lastFeed = [[NSString alloc] initWithString:[feedField stringValue]];
    } else if (target) {
        lastFeed = [[NSString alloc] initWithString:[target url]];
    }
	NSLog(@"tableView = %@", tableView);
    //NSLog(@"%@",[feedTitle title]);
    
    // Sort Items
    NSSortDescriptor	*descriptor;
    NSMutableArray		*sortDescriptors = [[NSMutableArray alloc] init];
    descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO selector:@selector(compare:)];
    [sortDescriptors addObject:descriptor];
    [rssItems sortUsingDescriptors:sortDescriptors];
    [descriptor release];
    [sortDescriptors release];

    [rssArray rearrangeObjects];
	[tableView reloadData];
    [parent rearrangeArticle];
    [doc release];
    return;
}

- (IBAction)openItem:(id)sender
{
	NSInteger	row = [tableView selectedRow];
	//if (row == -1) {
    //    row = [tableView selectedRow];
    //}
	NSLog(@"openItem: row=%lu", (long)row);
	if (row == -1) {
        [linkButton setState:NO];
		return;
	}
    [tableView scrollRowToVisible:row];
    [rssItems sortUsingDescriptors:[tableView sortDescriptors]];
    [rssArray rearrangeObjects];
	[tableView reloadData];
    [parent rearrangeArticle];
    rssItem* item = [rssItems objectAtIndex:row];
	NSString	*urlString = [item link];
    if ([urlString hasPrefix:@"http://"] == NO &&
        [urlString hasPrefix:@"https://"] == NO) {
        [linkButton setState:NO];
        return;
    }
    // Show link on builtin browser
    if (skipBrowse == YES) {
        [[parent urlText] setStringValue:urlString];
        [parent setJavaScriptEnabeled:enableJavaScript];
        [parent loadUrl:urlString];
        [linkButton setState:NO];
        if ([parent orderFront] == YES) {
            [[parent window] orderFront:self];
        }
        return;
    }
    [self stopCrawling:YES];
    /*
    if ([parent enableSound] == YES) {
        NSSound *sound = [NSSound soundNamed:@"Submarine"];
        [sound play];
    }
     */
    [self clearTargetItem];
    targetItem = [item retain];
    [[parent urlText] setStringValue:urlString];
    [parent setJavaScriptEnabeled:enableJavaScript];
    [parent loadUrl:urlString];
    [[parent window] orderFront:self];
    [[self window] orderFront:self];
    [linkButton setState:NO];
    return;
}

- (IBAction)selectBookmark:(id)sender
{
	NSInteger selected = [comboBoxBookmark indexOfSelectedItem];
	NSLog(@"selectBookmark: %ld: %@", (long)selected, [comboBoxBookmark stringValue]);
	Bookmark* bookmark = nil;
	NSString* title = [channel title];
	NSString* url = [feedField stringValue];
	int	index = 0;
    // NSSound *sound = [NSSound soundNamed:@"Pop"];
	if (selected == 0) {
		// find duplicate entry
		for (bookmark in [parent feeds]) {
			index++;
			if ([[bookmark url] isEqualToString:url] &&
				[[bookmark title] isEqualToString:title]) {
				if (selected == 0) {
					NSLog(@"Duplicate bookmark: %@", title);
					selected = index;
				}
			}
		}
	}
	switch (selected) {
		case 0:
			// insert object
            if ([url isEqualToString:@""] == YES) {
                break;
            }
            if (isLiteVresion == YES) {
                if ([[parent feeds] count] >= LIMIT_FEEDS_FOR_LITE_VER) {
                    NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
                                                     defaultButton:NSLocalizedString(@"OK",@"Ok")
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:NSLocalizedString(@"LIMIT_FEEDS",@"In the lite version, You can register up to %d feeds."), LIMIT_FEEDS_FOR_LITE_VER];
                    [alert beginSheetModalForWindow:win modalDelegate:self didEndSelector:nil contextInfo:nil];
                    break;
                }
            }
			bookmark = [[Bookmark alloc] init];
			if (bookmark == nil) {
				break;
			}
			[bookmark setBookmark:title:url];
            [bookmark setUrlFilter:@""];
			[[parent feeds] addObject:bookmark];
            [comboBoxBookmark addItemWithObjectValue:title];
			NSLog(@"Add Bookmark : %d %@ %@ %@", (int)[[parent feeds] count], bookmark, [bookmark title], [bookmark url]);
			[bookmark release];
			//[sound play];
            [parent saveFeed];
            [parent rearrangeFeeds];
			break;
		default:
			bookmark = [[parent feeds] objectAtIndex:selected-1];
			if (bookmark == nil) {
				NSLog(@"Bookmark is nil %ld/%d", (long)selected, (int)[[parent feeds] count]);
				break;
			}
			[bookmark retain];
			NSLog(@"Jump Bookmark %@ %@ %@", bookmark, [bookmark title], [bookmark url]);
            [self stopCrawling:YES];
            [feedField setStringValue:[bookmark url]];
			//[sound play];
            if (target) {
                [target release];
                target = nil;
            }
            target = [bookmark retain];
            [self fetchRSS:self];
			[bookmark release];
			break;
	}
	[comboBoxBookmark setTitleWithMnemonic:NSLocalizedString(@"RSS_FEED",@"RSS Feed")];
    return;
}

- (void)actionDoubleClick:(id)sender
{
    if (sender != tableView) {
        return;
    }
    if ([rssItems count] == 0) {
        return;
    }
    NSLog(@"actionDoubleClick %lu", (long)[tableView clickedRow]);
    if ([tableView selectedRow] == [tableView clickedRow]) {
        [self openItem:self];
    }
    return;
}

- (void)actionClick:(id)sender
{
    if (sender != tableView) {
        return;
    }
    if ([rssItems count] == 0) {
        return;
    }
    NSLog(@"actionClick %lu", (long)[tableView clickedRow]);
    [rssItems sortUsingDescriptors:[tableView sortDescriptors]];
    [rssArray rearrangeObjects];
    [tableView reloadData];
    [parent rearrangeArticle];
}

- (void)rearrengeArticle {
    [rssArray rearrangeObjects];
    [tableView reloadData];
}

- (IBAction)modifyArticle:(id)sender {
    [parent rearrangeArticle];
}

- (IBAction)speechArticle:(id)sender {
    if ([parent crawling ] == YES || crawling == YES || loading == YES) {
        NSBeep();
        return;
    }
    [parent openArticle:sender];
    [parent speechArticle];
}

- (void)handleFeedChange:(NSNotification*)note
{
	NSLog(@"Received notification: %@", note);
	[comboBoxBookmark removeAllItems];
    /*
	NSString* lang = NSLocalizedString(@"LANG",@"en_US");
	if ([lang isEqualToString:@"ja_JP"]) {
		[comboBoxBookmark addItemWithObjectValue:@"フィードを追加する"];
	} else {
		[comboBoxBookmark addItemWithObjectValue:@"Add Feed"];
	}
     */
    [comboBoxBookmark addItemWithObjectValue:NSLocalizedString(@"ADD_FEED",@"Add Feed")];
    for (Bookmark* bookmark in [parent feeds]) {
        //NSLog(@"bookmark %@ %@", [bookmark title], [bookmark url]);
        NSString* title = [bookmark title];
        [comboBoxBookmark addItemWithObjectValue:title];
    }
}

- (void)setFontColor:(NSColor*)color
{
	NSTableColumn *column = nil;
	NSLog(@"setFontColor");
	
	// set font color of tableView
	column = [tableView  tableColumnWithIdentifier:@"Date"];
	[(id)[column dataCell] setTextColor:color];
	column = [tableView  tableColumnWithIdentifier:@"Feed"];
	[(id)[column dataCell] setTextColor:color];
	column = [tableView  tableColumnWithIdentifier:@"Title"];
	[(id)[column dataCell] setTextColor:color];
	//[tableView reloadData];
}


#pragma mark HTTP Conection

- (IBAction)startRssConnection:(id)sender
{
	NSString *input;
    if (target == nil) {
        if ([[feedField stringValue] hasPrefix:@"http://"] == NO &&
            [[feedField stringValue] hasPrefix:@"https://"] == NO &&
            [[feedField stringValue] hasPrefix:@"feed://"] == NO) {
            return;
        }
        input = [feedField stringValue];
    } else {
        input = [target url];
    }
	NSString *searchString = [input stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSLog(@"searchString = %@", searchString);
    
	NSMutableString *urlString = [NSMutableString stringWithFormat: @"%@", searchString];
    if ([urlString hasPrefix:@"feed:"] == YES) {
        NSRange range = [urlString rangeOfString:@"feed:"];
        [urlString replaceCharactersInRange:range withString:@"http:"];
    }
	NSURL *url = [NSURL URLWithString:urlString];
	NSLog(@"url = %@", url);
	NSURLRequest* urlRequest = [NSURLRequest requestWithURL:url];
    [self startConnection:urlRequest];
}

- (IBAction)crawlingRSS:(id)sender {
    NSImage *template;
    if (crawling == NO) {
        NSInteger	row = [tableView selectedRow];
        if (sender == [parent forwardFeedButton] || sender == [parent backFeedButton] ||
            sender == [parent menuGoForward] || sender == [parent menuGoBack]) {
            row = [[parent articleTableView] selectedRow];
        }
        [tableView scrollRowToVisible:row];
        [rssItems sortUsingDescriptors:[tableView sortDescriptors]];
        [rssArray rearrangeObjects];
        [tableView reloadData];
        [parent rearrangeArticle];
        if (sender == forwardButton || sender == [parent forwardFeedButton] ||
            sender == [parent menuGoForward]) {
            if (row == -1) {
                row = 0;
            }
            for (; row < [rssItems count]; row++) {
                rssItem *item = [rssItems objectAtIndex:row];
                if (item && [item enabled] == YES) {
                    break;
                }
            }
            if (row >= [rssItems count]) {
                NSBeep();
                return;
            }
            [self startCrawling:row:[rssItems count]-1];
            if (crawling == NO) {
                return;
            }
            //template = [NSImage imageNamed:@"NSStopProgressTemplate"];
            template = [NSImage imageNamed:@"ImageStopSmall"];
            [forwardButton setImage:template];
            [[parent forwardFeedButton] setImage:template];
            [backButton setEnabled:NO];
            [[parent backFeedButton] setEnabled:NO];
            [[parent modeButton] setEnabled:NO];
            forward = YES;
        } else {
            if (row == -1) {
                row = [rssItems count]-1;
            }
            for (; row >= 0; row--) {
                rssItem *item = [rssItems objectAtIndex:row];
                if (item && [item enabled] == YES) {
                    break;
                }
            }
            if (row < 0) {
                NSBeep();
                return;
            }
            [self startCrawling:row:0];
            if (crawling == NO) {
                return;
            }
            //template = [NSImage imageNamed:@"NSStopProgressTemplate"];
            template = [NSImage imageNamed:@"ImageStopSmall"];
            [backButton setImage:template];
            [[parent backFeedButton] setImage:template];
            [forwardButton setEnabled:NO];
            [[parent forwardFeedButton] setEnabled:NO];
            [[parent modeButton] setEnabled:NO];
            forward = NO;
        }
    } else {
        crawling = NO;
        template = [NSImage imageNamed:@"NSRightFacingTriangleTemplate"];
        [forwardButton setImage:template];
        [[parent forwardFeedButton] setImage:template];
        [forwardButton setEnabled:YES];
        [[parent forwardFeedButton] setEnabled:YES];
        template = [NSImage imageNamed:@"NSLeftFacingTriangleTemplate"];
        [backButton setImage:template];
        [[parent backFeedButton] setImage:template];
        [backButton setEnabled:YES];
        [[parent backFeedButton] setEnabled:YES];
        [[parent skipFeedButton] setEnabled:YES];
        [[parent modeButton] setEnabled:YES];
        if ([[parent speechSynth] isSpeaking] == YES) {
            [[parent speechSynth] stopSpeaking];            
        }
    }
}

- (void)startConnection:(NSURLRequest*)req
{
    NSLog(@"RSSReader: startConnection");
	NSString *url = [[req URL] absoluteString];
	if (documentUrl) {
		[documentUrl release];
	}
	if (lastConnection) {
		[lastConnection cancel];
	}
	documentUrl = [url retain];
	lastConnection = [NSURLConnection connectionWithRequest:req delegate:self];
}

- (void)preLoadUrl:(NSString*)urlString
{
    NSLog(@"RSSReader: preLoadUrl");
    NSURLRequest    *urlRequest;
	NSURL           *url;
	if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
		url = [NSURL URLWithString:urlString];
    } else if ([urlString hasPrefix:@"feed:"] == YES) {
        NSRange range = [urlString rangeOfString:@"feed:"];
        NSMutableString* feed = [[NSMutableString alloc] initWithFormat:@"%@",urlString];
        [feed replaceCharactersInRange:range withString:@"http:"];
		url = [NSURL URLWithString:feed];
        [feed release];
	} else {
		url = [NSURL URLWithString:urlString];
    }
    urlRequest = [ NSURLRequest requestWithURL:url
                                   cachePolicy:NSURLRequestReloadRevalidatingCacheData
                               timeoutInterval:30.0];
	if (urlRequest) {
        if (nextConnection) {
            [nextConnection cancel];
        }
        nextConnection = [NSURLConnection connectionWithRequest:urlRequest delegate:self];
	}
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    if (connection == nextConnection) {
        return;
    }
	NSLog(@"RSSReader: didReceiveResponse");
	if (documentData) {
		[documentData release];
	}
    NSLog( @"size = %llu", [response expectedContentLength]);
    NSLog(@"%@", [response MIMEType]);
    //NSLog(@"%@", [response textEncodingName]);
	documentData = [[NSMutableData alloc] init];
	[self purgeDocumentData];
}

- (void)connection:(NSURLConnection*)connection
	didReceiveData:(NSData*)data
{
    if (connection == nextConnection) {
        return;
    }
	NSLog(@"RSSReader: didReceiveData: %ld", (long)[data length]);
	if (documentData) {
		[documentData appendData:data];
	}
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == nextConnection) {
        nextConnection = nil;
        return;
    }
	NSLog(@"RSSReader: didFailWithError: %@", error);
	if (lastConnection == connection) {
		lastConnection = nil;
	}
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
									 defaultButton:NSLocalizedString(@"OK",@"Ok")
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"CONNECTION_FAILED", @"Failed to connect server: %@"), [error localizedDescription]];
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    [self completeRSSConnection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection == nextConnection) {
        nextConnection = nil;
        return;
    }
	NSLog(@"RSSReader: didFinishLoading");
	NSString *htmlString = [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding];
	if (htmlString == nil) {
		htmlString = [[NSString alloc] initWithData:documentData encoding:NSShiftJISStringEncoding];
	}
	if (htmlString == nil) {
		htmlString = [[NSString alloc] initWithData:documentData encoding:NSJapaneseEUCStringEncoding];
	}
	[self purgeDocumentData];
	documentContent = [htmlString retain];
	if (lastConnection == connection) {
		lastConnection = nil;
	}
    [self getFeed:documentData];
    [self completeRSSConnection];
    return;
}

- (void)completeRSSConnection
{
    if (fetchIndex >= [[parent feeds] count] || loading == NO) {
        if (loading) {
            [feedField setStringValue:@""];
        }
        NSTableColumn *column = [tableView tableColumnWithIdentifier:@"Feed"];
        if (loading == YES) {
            [column setHidden:NO];
            columnHidden = NO;
        } else {
            [column setHidden:YES];
            columnHidden = YES;
        }
        [feedField setEnabled:YES];
        [forwardButton setEnabled:YES];
        [[parent forwardFeedButton] setEnabled:YES];
        [backButton setEnabled:YES];
        [[parent backFeedButton] setEnabled:YES];
        [[parent skipFeedButton] setEnabled:YES];
        [[parent modeButton] setEnabled:YES];
        [progress stopAnimation:nil];
        [progress setHidden:YES];
        [linkButton setHidden:NO];
        [linkButton setState:NO];
        if (loading == YES && [rssItems count] > 0) {
            [win setTitle:@"RSS Reader"];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:@"" forKey:gReaderLastFeedKey];
            if (lastFeed) {
                [lastFeed release];
            }
            lastFeed = [[NSString alloc] initWithString:@""];
        }
        loading = NO;
        
        // Sort Items
        NSSortDescriptor	*descriptor;
        NSMutableArray		*sortDescriptors = [[NSMutableArray alloc] init];
        descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO selector:@selector(compare:)];
        [sortDescriptors addObject:descriptor];
        [rssItems sortUsingDescriptors:sortDescriptors];
        [descriptor release];
        [sortDescriptors release];
        if ([tableView selectedRow] == -1) {
            NSIndexSet* ixset = [NSIndexSet indexSetWithIndex:0];
            [tableView selectRowIndexes:ixset byExtendingSelection:NO];
            [tableView scrollRowToVisible:0];
            [parent setArticleIndex:0];
        } else {
            [tableView scrollRowToVisible:[tableView selectedRow]];
        }
        if (enabelPreFetch) {
            [self preFetchCrawling];
        }
        if ([parent autoStartup] == YES) {
            [self crawlingRSS:forwardButton];
        }
    } else {
        Bookmark* feed = [[parent feeds] objectAtIndex:fetchIndex];
        if (feed) {
            target = [feed retain];
            [feedField setStringValue:[feed url]];
            [self startRssConnection:self];
            fetchIndex++;
            for (; fetchIndex < [[parent feeds] count]; fetchIndex++) {
                Bookmark *item = [[parent feeds] objectAtIndex:fetchIndex];
                if ([item enabled] == YES) {
                    break;
                }
            }
        }
    }
}

- (void)purgeDocumentData
{
	if (documentContent) {
		[documentContent release];
		documentContent = nil;
	}
}

#pragma mark Auto Pilot

- (void)startCrawling:(NSInteger)indexFrom :(NSInteger)indexTo
{
	NSLog(@"startCrawling");
    if ([rssItems count] == 0) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NO_CRAWLING_SITE",@"web site for autopilot not found.")];
		[alert beginSheetModalForWindow:win modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
    }
    if (indexFrom  < 0 || indexTo < 0  || indexFrom > [rssItems count]) {
        return;
    }
    if (indexTo > indexFrom) {
        if (indexTo >= [rssItems count]) {
            indexTo = [rssItems count] - 1;
        }
    }
    crawlingDst = indexTo;
	crawlingIndex = indexFrom;
    crawlingCount = 0;
    [parent stopCrawling:NO];
	crawling = YES;
    rssItem *item = [rssItems objectAtIndex:indexFrom];
    if (item) {
        [parent stopCrawling:NO];
		NSIndexSet* ixset = [NSIndexSet indexSetWithIndex:indexFrom];
		[tableView selectRowIndexes:ixset byExtendingSelection:NO];
		[tableView scrollRowToVisible:indexFrom];
        [parent setArticleIndex:indexFrom];
        if (skipBrowse == YES) {
            [self stopTimerCrawling];
            [self clearTargetItem];
            targetItem = [item retain];
            [self showWindow:self];
            [self buildSpeechText];
            [parent startSpeech:speechText:[targetItem voice]];
            if (enabelPreFetch) {
                [self preFetchCrawling];
            }
        } else {
            if ([parent enableSound] == YES) {
                NSSound *sound = [NSSound soundNamed:@"Submarine"];
                [sound play];
            }
            [self clearTargetItem];
            targetItem = [item retain];
            if ([item disableJavaScript] == YES) {
                [parent setJavaScriptEnabeled:NO];
            } else {
                [parent setJavaScriptEnabeled:enableJavaScript];
            }
            [[parent urlText] setStringValue:[item link]];
            [parent loadUrl:[item link]];
            [parent enableUrlRequest:NO];
            //[parent enableWeb];
            [self startTimerCrawling:CRAWLING_TIMER_CMD_CANCEL];
        }
    }
}

- (void)stopCrawling:(bool)warn
{
	NSLog(@"stopCrawling");
	if (crawling == YES) {
        NSImage *template;
		crawling = NO;
		crawlingIndex = 0;
        template = [NSImage imageNamed:@"NSRightFacingTriangleTemplate"];
        [forwardButton setImage:template];
        [[parent forwardFeedButton] setImage:template];
        [forwardButton setEnabled:YES];
        [[parent forwardFeedButton] setEnabled:YES];
        template = [NSImage imageNamed:@"NSLeftFacingTriangleTemplate"];
        [backButton setImage:template];
        [[parent backFeedButton] setImage:template];
        [backButton setEnabled:YES];
        [[parent backFeedButton] setEnabled:YES];
        [[parent modeButton] setEnabled:YES];
		[self stopTimerCrawling];
        [parent stopTimerScroll];
        [parent setJavaScriptEnabeled:enableJavaScript];
		[parent enableUrlRequest:YES];
		if (warn == YES) {
			NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"INFO",@"Info")
											 defaultButton:NSLocalizedString(@"OK",@"Ok")
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"CRAWLING_INTERRUPTED",@"autopilot is interrupted.")];
			[alert beginSheetModalForWindow:[parent window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		}
	}
}

- (void)skipCrawling
{
	if (crawling == NO) {
        NSBeep();
        return;
    }
    if (crawlingTimerCmd == CRAWLING_TIMER_CMD_SKIP) {
        NSBeep();
        return;
    }
    if (skipBrowse == YES) {
        if ([[parent speechSynth] isSpeaking] == NO) {
            NSBeep();
        } else {
            [[parent speechSynth] stopSpeaking];
        }
        return;
    }
    if ([[parent webView] isLoading] == YES) {
        [[parent webView] stopLoading:self];
    }
    [parent stopTimerScroll];
    [self stopTimerCrawling];
    [self startTimerCrawling:CRAWLING_TIMER_CMD_SKIP];
    return;
}

- (void)continueCrawling
{
	NSLog(@"continueCrawling");
	if (crawling == NO) {
		return;
	}

    if ([parent autopilotCount] > 0) {
        crawlingCount++;
        if (crawlingCount >= [parent autopilotCount]) {
            [self stopCrawling:NO];
            [parent stopSpeech];
            if ([parent enableSound] == YES) {
                NSSound *sound = [NSSound soundNamed:@"CompleteAlarm"];
                [sound play];
            }
            return;
        }
    }

    if (forward == YES) {
        crawlingIndex++;
        for (; crawlingIndex < [rssItems count]; crawlingIndex++) {
            rssItem *item = [rssItems objectAtIndex:crawlingIndex];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if ([rssItems count] <= crawlingIndex ||
            crawlingDst < crawlingIndex) {
            [self stopCrawling:NO];
            if ([parent scrollPage] == YES) {
                [parent setScrollPage:NO];
            } else {
                [parent stopSpeech];
                if ([parent enableSound] == YES) {
                    NSSound *sound = [NSSound soundNamed:@"CompleteAlarm"];
                    [sound play];
                }
            }
            return;
        }

    } else {
        crawlingIndex--;
        for (; crawlingIndex >= 0; crawlingIndex--) {
            rssItem *item = [rssItems objectAtIndex:crawlingIndex];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if (crawlingIndex < 0 ||
            crawlingIndex < crawlingDst) {
            [self stopCrawling:NO];
            if ([parent scrollPage] == YES) {
                [parent setScrollPage:NO];
            } else {
                [parent stopSpeech];
                if ([parent enableSound] == YES) {
                    NSSound *sound = [NSSound soundNamed:@"CompleteAlarm"];
                    [sound play];
                }
            }
            return;
        }
    }
	rssItem* item = [rssItems objectAtIndex:crawlingIndex];
	if (item) {
		NSIndexSet* ixset = [NSIndexSet indexSetWithIndex:crawlingIndex];
		[tableView selectRowIndexes:ixset byExtendingSelection:NO];
		[tableView scrollRowToVisible:crawlingIndex];
        [parent setArticleIndex:crawlingIndex];
        if (skipBrowse) {
            [self stopTimerCrawling];
            [self clearTargetItem];
            targetItem = [item retain];
            if ([parent orderFront] == YES) {
                [self showWindow:self];
            }
            [self buildSpeechText];
            [parent startSpeech:speechText:[targetItem voice]];
            if (enabelPreFetch) {
                [self preFetchCrawling];
            }
        } else {
            if ([parent enableSound] == YES) {
                NSSound *sound = [NSSound soundNamed:@"Submarine"];
                [sound play];
            }
            [self clearTargetItem];
            targetItem = [item retain];
            if ([item disableJavaScript] == YES) {
                [parent setJavaScriptEnabeled:NO];
            } else {
                [parent setJavaScriptEnabeled:enableJavaScript];
            }
            [[parent urlText] setStringValue:[item link]];
            [parent loadUrl:[item link]];
            [parent enableUrlRequest:NO];
            //[parent enableWeb];
            [self startTimerCrawling:CRAWLING_TIMER_CMD_CANCEL];
        }
	}
}

- (void)preFetchCrawling
{
	NSLog(@"preFetchCrawling");
	if (crawling == NO) {
		return;
	}
    NSInteger index = crawlingIndex;
    if (forward == YES) {
        index++;
        for (; index < [rssItems count]; index++) {
            rssItem *item = [rssItems objectAtIndex:index];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if ([rssItems count] <= index) {
            return;
        }
        
    } else {
        index--;
        for (; index >= 0; index--) {
            rssItem *item = [rssItems objectAtIndex:index];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if (index < 0) {
            return;
        }
    }
	rssItem* item = [rssItems objectAtIndex:index];
	if (item) {
		//[parent preLoadUrl:[item link]];
        [self preLoadUrl:[item link]];
	}
}

- (void)pauseCrawling:(bool)pause {
	if (crawling == NO) {
		crawlingPaused = NO;
		return;
	}
	if (pause == YES) {
		[self stopTimerCrawling];
	} else {
		[self continueCrawling];
	}
	crawlingPaused = pause;
}

- (void)clearTarget {
    if (target) {
        [target release];
        target = nil;
    }
}

- (void)clearTargetItem {
    if (targetItem) {
        [targetItem release];
        targetItem = nil;
    }
}

- (void)startTimerCrawling:(int)cmd {
	float timer = DEFAULT_AUTOSCROLL_INTERVAL;
    if (targetItem) {
        timer = [targetItem scrollInterval];
    }
	if (crawlingTimer) {
		[self stopTimerCrawling];
	}
	crawlingTimerCmd = cmd;
	if (cmd == CRAWLING_TIMER_CMD_CANCEL) {
		timer = [parent urlRequestTimer];
	}
    if ([[parent webView] isLoading] == YES) {
        timer += AUTOSCROLL_PAUSE_TIMER;
    }
	if (cmd == CRAWLING_TIMER_CMD_CNT) {
        if (enableSpeech && [[parent speechSynth] isSpeaking]) {
            timer += DEFAULT_AUTOSCROLL_INTERVAL;
        }
    } else if (cmd == CRAWLING_TIMER_CMD_SKIP) {
        timer = AUTOSCROLL_PAUSE_TIMER;
    }
	crawlingTimer = [[NSTimer scheduledTimerWithTimeInterval:timer
													  target:self
													selector:@selector(checkTimerCrawling:)
													userInfo:nil
													 repeats:NO] retain];
	[parent enableUrlRequest:YES];
}

- (void)stopTimerCrawling {
	if (crawlingTimer) {
		[crawlingTimer invalidate];
		[crawlingTimer release];
		crawlingTimer = nil;
	}
}

- (void)checkTimerCrawling:(NSTimer*) timer {
	switch (crawlingTimerCmd) {
		case CRAWLING_TIMER_CMD_CNT:
		case CRAWLING_TIMER_CMD_SKIP:
			if (rssItems == nil) {
				[self stopTimerCrawling];
				return;
			}
            if ([[parent backgroundWebView] isLoading] == YES) {
                [[parent backgroundWebView] stopLoading:self];
            }
			[self continueCrawling];
            //[[parent webView] scrollLineDown:self];
            //[parent setScrollCount:WEB_AUTOSCROLL_COUNT];
            //[parent startTimerScroll:AUTOSCROLL_TIMER];
			break;
		case CRAWLING_TIMER_CMD_SCROLL:
            //[[parent webView] scrollLineDown:self];
            if (crawling == NO) {
                return;
            }
            [parent setScrollWidth:DEFAULT_AUTOSCROLL_WIDTH];
            if (targetItem) {
                [parent setScrollWidth:[targetItem scrollWidth]];
            }
            [parent startTimerScroll:[parent scrollSpeed]];
            [parent setScrollTimes:[parent scrollTimes] - 1];
            if ([parent scrollTimes] <= 0) {
                [self startTimerCrawling:CRAWLING_TIMER_CMD_CNT];
            } else {
                [self startTimerCrawling:CRAWLING_TIMER_CMD_SCROLL];
            }
            break;
		case CRAWLING_TIMER_CMD_CANCEL:
			if ([[parent webView] isLoading] == YES) {
				[[parent webView] stopLoading:parent];
                //[parent loadCashedUrl];
                //NSLog(@"loadCashedUrl");
			}
            if ([parent enableSound] == YES) {
                NSSound *sound = [NSSound soundNamed:@"Pop"];
                [sound play];
            }
            if (crawling == YES && crawlingPaused == NO) {
                if ([targetItem scrollTimes] == 0) {
                    [self startTimerCrawling:CRAWLING_TIMER_CMD_CNT];
                } else {
                    [self startTimerCrawling:CRAWLING_TIMER_CMD_SCROLL];
                }
                [parent setScrollWidth:DEFAULT_AUTOSCROLL_START_POSITION];
                [parent setScrollTimes:DEFAULT_AUTOSCROLL_TIMES];
                if (targetItem) {
                    [parent setScrollWidth:[targetItem startPosition]];
                    [parent setScrollTimes:[targetItem scrollTimes]];
                    if (enableSpeech) {
                        [self buildSpeechText];
                        [parent startSpeech:speechText:[targetItem voice]];
                    }
                }
                [parent startTimerScroll:1/AUTOSCROLL_PAUSE_TIMER];
                if (enabelPreFetch) {
                    [self preFetchCrawling];
                }
            }
			break;
	}
}

- (void)buildSpeechText
{
    NSDictionary *dic = [[NSDictionary alloc] init];
    if (speechText) {
        [speechText release];
        speechText = nil;
    }
    if (targetItem == nil) {
        targetItem = [rssItems objectAtIndex:[tableView selectedRow]];
        NSData *data = [[targetItem description] dataUsingEncoding:NSUTF16StringEncoding];
        NSAttributedString *as = [[NSAttributedString alloc] initWithHTML:data options:dic documentAttributes:nil];
        if (as) {
            speechText = [[NSString alloc] initWithFormat:@"%@ \n %@", [targetItem title], [as string]];
            [as release];
        }
        targetItem = nil;
        [dic release];
        return;
    }
    if ([targetItem description] == nil) {
        speechText = [[NSString alloc] initWithFormat:@"%@", [targetItem title]];
        [dic release];
        return;
    }
    NSData *data = [[targetItem description] dataUsingEncoding:NSUTF16StringEncoding];
    NSAttributedString *as = [[NSAttributedString alloc] initWithHTML:data options:dic documentAttributes:nil];
    if (as) {
        speechText = [[NSString alloc] initWithFormat:@"%@ \n %@", [targetItem title], [as string]];
        [as release];
    } else {
        speechText = [[NSString alloc] initWithFormat:@"%@", [targetItem title]];
    }
    [dic release];
}

#pragma mark Localizer

- (void) localizeView
{
	NSTableColumn *column = nil;
	NSString* lang = NSLocalizedString(@"LANG",LANG_EN_US);
	NSLog(@"localizeView: %@", lang);
	if ([lang isEqualToString:LANG_JA_JP]) {
		[comboBoxBookmark removeAllItems];
		[comboBoxBookmark setTitleWithMnemonic:@"RSSフィード"];
		[comboBoxBookmark addItemWithObjectValue:@"フィードを追加する"];
		column = [tableView  tableColumnWithIdentifier:@"Date"];
		[[column headerCell] setStringValue:@"日付"];
		column = [tableView  tableColumnWithIdentifier:@"Feed"];
		[[column headerCell] setStringValue:@"フィード"];
		column = [tableView  tableColumnWithIdentifier:@"Title"];
		[[column headerCell] setStringValue:@"タイトル"];
	}
}

@synthesize     rssItems;
@synthesize     tableView;
@synthesize     parent;
@synthesize     feedField;
@synthesize     loading;
@synthesize     crawlingTimerCmd;
@synthesize     crawling;
@synthesize     crawlingPaused;
@synthesize     forward;
@synthesize     target;
@synthesize     targetItem;
@synthesize     speechText;
@synthesize     lastConnection;
@synthesize     isWindowLoaded;

@end
