//
//  AppDelegate.m
//  GhostReader
//
//  Created by Takahiro Sayama on 2013/01/01.
//  Copyright (c) 2013年 tanuki-project. All rights reserved.
//

#import     "AppDelegate.h"
#include    "build.h"

NSString* const gReaderHomeUrlKey =             @"Home WebView URL";
NSString* const gReaderLastUrlKey =             @"Last WebView URL";
NSString* const gReaderBookmarkListKey =        @"Bookmark List";
NSString* const gReaderFeedListKey =            @"Feed List";
NSString* const gReaderLastFeedKey =            @"Last Feed URL";
NSString* const gReaderOrderFrontKey =          @"Order Front";
NSString* const gReaderRequestTimerKey =        @"URL Request Timer";
NSString* const gReaderScrollSpeedKey =         @"Scroll Speed";
NSString* const gReaderSpeechRateKey =          @"Speech Rate";
NSString* const gReaderAutopilotCountKey =      @"Autopilot Count";
NSString* const gReaderAutoStartKey =           @"Auto Start";
NSString* const gReaderEnableJavaScriptKey =    @"Enable JavaScript";
NSString* const gReaderEnableSoundKey =         @"Enable Sound";
NSString* const gReaderEnableSpeechKey =        @"Enable Speech";
NSString* const gReaderEnableRedirectKey =      @"Enable Redirect";
NSString* const gReaderShowReaderKey =          @"Show Reader";
NSString* const gReaderSkipBrowseKey =          @"Skip Browse";
NSString*       lang = nil;

BOOL    isLiteVresion = NO;

BOOL    isReloadRevalidatingCacheData = YES;
BOOL    enableSpeech = YES;
BOOL    enabelPreFetch = YES;
BOOL    enableJavaScript = YES;
BOOL    willTerminate = NO;
BOOL    skipBrowse = NO;

@implementation AppDelegate

+ (void)initialize
{
	// set default user preference values.
	NSMutableDictionary	*defaultValues = [NSMutableDictionary dictionary];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:gReaderAutoStartKey];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:gReaderOrderFrontKey];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:gReaderEnableJavaScriptKey];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:gReaderEnableSoundKey];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:gReaderEnableSpeechKey];
	[defaultValues setObject:[NSNumber numberWithBool:YES] forKey:gReaderEnableRedirectKey];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:gReaderShowReaderKey];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:gReaderSkipBrowseKey];
	[defaultValues setObject:[NSNumber numberWithFloat:DEFAULT_AUTOSCROLL_SPEED] forKey:gReaderScrollSpeedKey];
	[defaultValues setObject:[NSNumber numberWithFloat:DEFAULT_SPEECH_RATE] forKey:gReaderSpeechRateKey];
	[defaultValues setObject:[NSNumber numberWithFloat:DEFAULT_AUTOPILOT_COUNT] forKey:gReaderAutopilotCountKey];
	[defaultValues setObject:[NSNumber numberWithFloat:DEFAULT_URL_REQUEST_TIMER] forKey:gReaderRequestTimerKey];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
	NSLog(@"registreted defaults: %@", defaultValues);
}

- (id)init
{
    self = [super init];
    if (self) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self
			   selector:@selector(progressStarted:)
				   name:WebViewProgressStartedNotification
				 object:nil];
		[nc addObserver:self
			   selector:@selector(progressFinished:)
				   name:WebViewProgressFinishedNotification
				 object:nil];
		[nc addObserver:self selector:@selector(actionClose:)
				   name:NSWindowWillCloseNotification
				 object:window];
        [nc addObserver:self selector:@selector(actionSelected:)
                   name:NSTableViewSelectionDidChangeNotification
                 object:articleTableView];
        [nc addObserver:self selector:@selector(actionTerminate:)
                   name: NSApplicationWillTerminateNotification
                 object:window];
        bookmarks = nil;
        feeds = nil;
        lang = NSLocalizedString(@"LANG",@"en_US");
        [self loadBookmark];
        [self loadFeed];
        is_loading = NO;
        orderFront = YES;
        autoStartup = NO;
        enableSound = YES;
        enableRedirect = YES;
        scrollPage = NO;
        reader = [[RssReader alloc] init];
        [reader setParent:self];
        rssItems = [reader rssItems];
        target = nil;
        editing = nil;
        speechSynth = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
        [speechSynth setDelegate:self];
        urlRequestTimer = DEFAULT_URL_REQUEST_TIMER;
        reservedUrl = nil;
        voiceList = [[NSSpeechSynthesizer availableVoices] retain];
        defaultVoice = [[NSString alloc] initWithString:[speechSynth voice]];
        autopilotCount = DEFAULT_AUTOPILOT_COUNT;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"dealloc");
    [super dealloc];
}

- (void)actionClose:(NSNotification *)notification {
	NSLog(@"actionClose:Main");
    /*
    if ([reader crawling] == YES && [[reader window] viewsNeedDisplay] == YES) {
        [reader stopCrawling:YES];
        [self stopSpeech];
    }
    if (crawling == YES) {
        [self stopCrawling:YES];
        [self stopSpeech];
    }
    usleep(1000);
     */
}

- (void)actionTerminate:(NSNotification *)notification {
	NSLog(@"actionTerminate: %@", [notification object]);
    willTerminate = YES;
}

-(void)actionSelected:(NSNotification *)notification {
    NSLog(@"actionSelected:articleTableView: %@", notification);
    if ([notification object] != articleTableView) {
        return;
    }
    NSInteger row = [articleTableView selectedRow];
    if (row == -1) {
        return;
    }
    if (row != [[reader tableView] selectedRow]) {
        NSIndexSet* ixset = [NSIndexSet indexSetWithIndex:row];
        [[reader tableView] selectRowIndexes:ixset byExtendingSelection:NO];
        [[reader tableView] scrollRowToVisible:index];
    }
}

/*
- (BOOL) canBecomeKeyWindow
{
    return YES;
}

- (BOOL) canBecomeMainWindow
{
    return YES;
}

- (void) keyDown: (NSEvent *) event
{
    NSLog(@"KeyDown pressed[%d]", [event keyCode]);
}
*/

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [webView setFrameLoadDelegate:(id)self];
	[webView setDownloadDelegate:(id)self];
    [webView setPolicyDelegate:(id)self];
    WebFrame* mainFrame;
	NSURL* url = nil;
	NSString* urlKey = [defaults objectForKey:gReaderHomeUrlKey];
	if (urlKey == nil || [urlKey isEqualToString:@""] == YES) {
		urlKey = [defaults objectForKey:gReaderLastUrlKey];
	}
	if (urlKey) {
		url = [NSURL URLWithString:urlKey];
		NSLog(@"StartupUrl :%@", url);
	}
	if (url == nil) {
		url = [NSURL URLWithString:@"http://apple.com"];
	}
    orderFront = [defaults boolForKey:gReaderOrderFrontKey];
    enableJavaScript = [defaults boolForKey:gReaderEnableJavaScriptKey];
    enableSound = [defaults boolForKey:gReaderEnableSoundKey];
    enableSpeech = [defaults boolForKey:gReaderEnableSpeechKey];
    enableRedirect = [defaults boolForKey:gReaderEnableRedirectKey];
    urlRequestTimer = [defaults floatForKey:gReaderRequestTimerKey];
    scrollSpeed = [defaults floatForKey:gReaderScrollSpeedKey];
    speechRate = [defaults floatForKey:gReaderSpeechRateKey];
    autopilotCount = [defaults floatForKey:gReaderAutopilotCountKey];
    autoStartup = [defaults boolForKey:gReaderAutoStartKey];
    skipBrowse = [defaults boolForKey:gReaderSkipBrowseKey];
    [bookmarkController rearrangeObjects];
    [bookmarkTableView reloadData];
    [bookmarkTableView deselectAll:self];
    [bookmarkTableView setDoubleAction:@selector(openBookmark:)];
    [feedsController rearrangeObjects];
    [rssTableView reloadData];
    [rssTableView deselectAll:self];
    [rssTableView setDoubleAction:@selector(openFeed:)];
    [articleTableView reloadData];
    [articleTableView deselectAll:self];
    [articleTableView setDoubleAction:@selector(openArticle:)];
    [self localizeView];
    [[webView preferences] setJavaScriptEnabled:enableJavaScript];
    [[webView preferences] setCacheModel:WebCacheModelDocumentBrowser];
    if (skipBrowse == YES) {
        [modeButton setState:YES];
        [modeText setStringValue: @"SpeechOnly"];
    } else {
        [modeButton setState:NO];
        [modeText setStringValue: @"Browsing"];
    }
	NSURLRequest* urlRequest = [NSURLRequest requestWithURL:url];
	mainFrame = [webView mainFrame];
	[mainFrame loadRequest:urlRequest];
    [reader showWindow:self];
    //[[reader window] miniaturize:self];
    if ([defaults floatForKey:gReaderShowReaderKey] == NO) {
        [reader close];        
    }
    [[reader feedField] setStringValue:@""];
    [reader fetchAll:self];
    [self buildVoiceList];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	NSLog(@"validateMenuItem: %@", item);
    SEL action = [item action];
    if (action == @selector(showWindow:)) {
        if ([[self window] viewsNeedDisplay] == NO) {
            return NO;
        }
    } else if (action == @selector(showReader:)) {
        if ([reader isWindowLoaded] == NO) {
            return YES;
        }
        if ([[reader window] viewsNeedDisplay] == NO) {
            return NO;
        }
    } else if (action == @selector(goForwardAutoPilot:)) {
        if (crawling == YES || [reader crawling] == YES) {
            return NO;
        }
        if (crawlingTimerCmd == CRAWLING_TIMER_CMD_SKIP ||
            [reader crawlingTimerCmd] == CRAWLING_TIMER_CMD_SKIP) {
            return NO;
        }
    } else if (action == @selector(goBackAutopilot:)) {
        if (crawling == YES || [reader crawling] == YES) {
            return NO;
        }
    } else if (action == @selector(skipAutoPilot:)) {
        if (crawling == NO && [reader crawling] == NO) {
            return NO;
        }
    } else if (action == @selector(stopAutoPilot:)) {
        if (crawling == NO && [reader crawling] == NO) {
            return NO;
        }
    } else if (action == @selector(openFeed:)) {
        if ([rssTableView selectedRow] == -1) {
            return NO;
        }
    } else if (action == @selector(importFeeds:)) {
        if (isLiteVresion == YES) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication*)sender
{
	NSLog(@"applicationShouldOpenUntitledFile");
    [[self window] orderFront:self];
    return NO;
}

- (void)buildVoiceList
{
    [attrVoiceComboBox removeAllItems];
    [attrVoiceComboBox setTitleWithMnemonic:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")];
    [attrVoiceComboBox addItemWithObjectValue:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")];
    for (NSString* voice in voiceList) {
        NSDictionary* dict = [NSSpeechSynthesizer attributesForVoice:voice];
        NSString* voiceName = [dict objectForKey:NSVoiceName];
        NSString* voiceLocalId = [dict objectForKey:NSVoiceLocaleIdentifier];
        NSString *voiceItem;
        if (voiceLocalId && [voiceLocalId isEqualToString:@"en_US"] == NO) {
            voiceItem = [[NSString alloc] initWithFormat:@"%@ (%@)",voiceName,voiceLocalId];
        } else {
            voiceItem = [[NSString alloc] initWithFormat:@"%@",voiceName];
        }
        NSLog(@"voiceItem: %@",voiceItem);
        [attrVoiceComboBox addItemWithObjectValue:voiceItem];
        [voiceItem release];
    }
}

- (void)setVoice:(Bookmark*)bookmark
{
    NSLog(@"selectVoice: %@", [attrVoiceComboBox stringValue]);
    if ([[attrVoiceComboBox stringValue] isEqualToString:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")]) {
        [bookmark setVoice:nil];
    }
    for (NSString* voice in voiceList) {
        NSDictionary* dict = [NSSpeechSynthesizer attributesForVoice:voice];
        NSString* voiceName = [dict objectForKey:NSVoiceName];
        NSString* voiceLocalId = [dict objectForKey:NSVoiceLocaleIdentifier];
        NSString *voiceItem;
        if (voiceLocalId && [voiceLocalId isEqualToString:@"en_US"] == NO) {
            voiceItem = [[NSString alloc] initWithFormat:@"%@ (%@)",voiceName,voiceLocalId];
        } else {
            voiceItem = [[NSString alloc] initWithFormat:@"%@",voiceName];
        }
        if (voiceItem == nil) {
            continue;
        }
        NSLog(@"voiceItem: %@",voiceItem);
        if ([voiceItem isEqualToString:[attrVoiceComboBox stringValue]] == YES) {
            [bookmark setVoice:voice];
            [voiceItem release];
            break;
        }
        [voiceItem release];
    }
    return;
}

- (NSString*)voiceName:(NSString*)voice
{
	NSDictionary* dict = [NSSpeechSynthesizer attributesForVoice:voice];
	return [dict objectForKey:NSVoiceName];
}

- (NSString*)voiceLocaleIdentifier:(NSString*)voice
{
	NSDictionary* dict = [NSSpeechSynthesizer attributesForVoice:voice];
	return [dict objectForKey:NSVoiceLocaleIdentifier];
}

- (void)startSpeech:(NSString*)text :(NSString*)voice
{
    [self stopSpeech];
    if (voice) {
        [speechSynth setVoice:voice];
    } else {
        [speechSynth setVoice:defaultVoice];
    }
    [speechSynth setRate:speechRate];
    //[speechSynth setVolume:[volumeSlider doubleValue]];
    NSLog(@"startSpeech: rate=%f, volume=%f", [speechSynth rate], [speechSynth volume]);
    [speechSynth startSpeakingString:text];
}

- (void)stopSpeech
{
    if ([speechSynth isSpeaking]) {
        [speechSynth stopSpeaking];
    }
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender
        didFinishSpeaking:(BOOL)complete
{
    NSLog(@"didFinishSpeaking: complete = %d", complete);
    if ([reader crawling] == YES && [reader crawlingPaused] == NO && skipBrowse) {
        if (enableSound) {
            NSSound *sound = [NSSound soundNamed:@"Pop"];
            [sound play];
        }
        [reader continueCrawling];
    }
}

- (IBAction)speechArticle:(id)sender {
    if (crawling == YES || [reader crawling] == YES || [reader loading] == YES ||
        [[[tabView selectedTabViewItem] identifier] isEqualToString:@"bookmark"] == YES) {
        NSBeep();
        return;
    }
    [self openArticle:sender];
    [self speechArticle];
}

- (IBAction)changeMode:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([modeButton state] == YES) {
        [modeText setStringValue: @"SpeechOnly"];
        skipBrowse = YES;
    } else {
        skipBrowse = NO;
        [modeText setStringValue: @"Browsing"];
    }
    [defaults setBool:skipBrowse forKey:gReaderSkipBrowseKey];
}

- (void)speechArticle
{
    [self stopSpeech];
    //[reader clearTargetItem];
    //[reader buildSpeechText];
    NSInteger row = [[reader tableView] selectedRow];
    if (row != -1) {
        scrollPage = YES;
        [reader stopCrawling:NO];
        NSImage *template;
        template = [NSImage imageNamed:@"ImageStopSmall"];
        [forwardFeedButton setImage:template];
        template = [NSImage imageNamed:@"NSLeftFacingTriangleTemplate"];
        [backFeedButton setImage:template];
        [backFeedButton setEnabled:NO];
        [reader setForward:YES];
        [reader startCrawling:row:row];
    }
}

/*
- (BOOL)acceptsFirestResponder {
    NSLog(@"acceptsFirestResponder");
    return YES;
}
*/

/*
- (void)mouseDown:(NSEvent*)event
{
    NSLog(@"Mouse Down");
}
*/

/*
- (void)swipeWithEvent:(NSEvent *)event
{
    NSLog(@"swipeWithEvent:");
}
*/

- (IBAction)showWindow:(id)sender {
    NSLog(@"showWindow");
    [[self window] makeKeyAndOrderFront:nil];
}

- (IBAction)showAttrSheet:(id)sender {
    [atteAutoScrollTitle setStringValue:NSLocalizedString(@"AUTO_SCROLL_SETTING",@"Auto Scroll Setting")];
    [attrStartPositionLabel setStringValue:NSLocalizedString(@"AUTO_SCROLL_START",@"Start at (Line)")];
    [attrScrollWidthLabel setStringValue:NSLocalizedString(@"AUTO_SCROLL_WIDTH",@"Width (Line)")];
    [attrScrollIntervalLabel setStringValue:NSLocalizedString(@"AUTO_SCROLL_INTERVAL",@"Interval (Sec)")];
    [attrScrollTimesLabel setStringValue:NSLocalizedString(@"AUTO_SCROLL_TIMES",@"Times")];
    if (attrType == ATTR_TYPE_CREATE_BOOKMARK || attrType == ATTR_TYPE_CREATE_FEED) {
        [attrApplyButton setTitle:NSLocalizedString(@"ADD",@"Add")];
    } else {
        [attrApplyButton setTitle:NSLocalizedString(@"APPLY",@"Apply")];
    }
    [attrCancelButton setTitle:NSLocalizedString(@"CANCEL",@"Cancel")];
    [attrDisableJavaScript setTitle:NSLocalizedString(@"DISABLE_JAVASCRIPT", @"Disable JavaScript while Autopilot")];
    [attrFilterLabel setStringValue:NSLocalizedString(@"AUTO_SCROLL_FILTER",@"Keyword for URL Filtering:")];
    [attrFilterComment setStringValue:NSLocalizedString(@"AUTO_SCROLL_FILTER_DISC",@"(Matching by part of URL)")];
    /*
     "AUTO_SCROLL_FILTER" = "Keyword for URL Filtering:";
     "AUTO_SCROLL_FILTER_DISC" = "(Matching by part of URL)";
     */
    [NSApp beginSheet:attrSheet
       modalForWindow:[self window]
        modalDelegate:nil
       didEndSelector:NULL
          contextInfo:NULL];
}

- (IBAction)endAttrSheet:(id)sender {
    switch (attrType) {
        case ATTR_TYPE_CREATE_BOOKMARK:
            [self finishCreateBookmark:sender];
            break;
        case ATTR_TYPE_EDIT_BOOKMARK:
            [self finishEditBookmark:sender];
            break;
        case ATTR_TYPE_CREATE_FEED:
            [self finishCreateFeed:sender];
            break;
        case ATTR_TYPE_EDIT_FEED:
            [self finishEditFeed:sender];
            break;
    }
    [NSApp endSheet:attrSheet];
    [attrSheet orderOut:sender];
}

- (IBAction)cancelAttrSheet:(id)sender {
    [NSApp endSheet:attrSheet];
    [attrSheet orderOut:sender];
}

- (IBAction)resetAttrValue:(id)sender {
    [attrStartPositionField setIntegerValue:DEFAULT_AUTOSCROLL_START_POSITION];
    [attrScrollWidthField setIntegerValue:DEFAULT_AUTOSCROLL_WIDTH];
    [attrScrollTimesField setIntegerValue:DEFAULT_AUTOSCROLL_TIMES];
    [attrScrollIntervalField setFloatValue:DEFAULT_AUTOSCROLL_INTERVAL];
    [attrStartPositionStepper setIntegerValue:DEFAULT_AUTOSCROLL_START_POSITION];
    [attrScrollWidthStepper setIntegerValue:DEFAULT_AUTOSCROLL_WIDTH];
    [attrScrollTimesStepper setIntegerValue:DEFAULT_AUTOSCROLL_TIMES];
    [attrScrollIntervalStepper setFloatValue:DEFAULT_AUTOSCROLL_INTERVAL];
    [attrFilterField setStringValue:@""];
}

- (IBAction)changeAttrValue:(id)sender {
    [attrStartPositionField setIntegerValue:[attrStartPositionStepper intValue]];
    [attrScrollWidthField setIntegerValue:[attrScrollWidthStepper intValue]];
    [attrScrollTimesField setIntegerValue:[attrScrollTimesStepper intValue]];
    [attrScrollIntervalField setFloatValue:[attrScrollIntervalStepper floatValue]];
}

- (IBAction)showPreferenceSheet:(id)sender {
    
    [preferenceScrollSpeedLabel setStringValue:NSLocalizedString(@"AUTO_SCROLL_SPEED",@"Auto Scroll Speed")];
    [preferenceSpeechRateLabel setStringValue:NSLocalizedString(@"SPEECH_RATE",@"Speech Rate")];
    [preferenceCountLabel setStringValue:NSLocalizedString(@"AUTOPILOT_COUNT",@"Count of Autopilot for RSS Feeds")];
    [preferenceHomeUrlLabel setStringValue:NSLocalizedString(@"HOME_URL",@"Home Page:")];
    [preferenceRequestTimerLabel setStringValue:NSLocalizedString(@"URL_REQUEST_TIMER",@"URL Request Timer for Autopilot (sec) :")];
    [preferenceAutoStart setTitle:NSLocalizedString(@"AUTO_STARTUP",@"Auto Startup")];
    [preferenceOrderFront setTitle:NSLocalizedString(@"BRING_WINDOW_FRONT",@"Bring Window to Front")];
    [preferenceEnableSound setTitle:NSLocalizedString(@"ENABLE_SOUND",@"Enable Sound")];
    [preferenceEnableJavaScript setTitle:NSLocalizedString(@"ENABLE_JAVASCRIPT",@"Enable JavaScript")];
    [preferenceEnableSpeech setTitle:NSLocalizedString(@"ENABLE_SPEECH",@"Enable Speech")];
    [preferenceEnableRedirect setTitle:NSLocalizedString(@"ENABLE_REDIRECT",@"Redirect URL Request to RSS Reader")];
    [preferenceApplyButton setTitle:NSLocalizedString(@"APPLY",@"Apply")];
    [preferenceCancelButton setTitle:NSLocalizedString(@"CANCEL",@"Cancel")];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* urlKey = [defaults objectForKey:gReaderHomeUrlKey];
    [preferenceHomeUrlField setStringValue:@""];
	if (urlKey) {
        [preferenceHomeUrlField setStringValue:urlKey];
	}
    [preferenceAutoStart setState:autoStartup];
    [preferenceOrderFront setState:orderFront];
    [preferenceEnableJavaScript setState:enableJavaScript];
    [preferenceEnableSound setState:enableSound];
    [preferenceEnableSpeech setState:enableSpeech];
    [preferenceEnableRedirect setState:enableRedirect];
    [preferenceScrollSpeed setFloatValue:scrollSpeed];
    [preferenceSpeechRate setFloatValue:speechRate];
    [preferenceRequestTimerField setFloatValue:urlRequestTimer];
    [preferenceRequestTimerStepper setFloatValue:urlRequestTimer];
    NSInteger index = autopilotCount/DEFAULT_AUTOPILOT_COUNT_WIDTH;
    [preferenceSegmentCount setSelectedSegment:index];
    [NSApp beginSheet:preferenceSheet
       modalForWindow:[self window]
        modalDelegate:nil
       didEndSelector:NULL
          contextInfo:NULL];
}

- (IBAction)endPreferenceSheet:(id)sender {
    autoStartup = [preferenceAutoStart state];
    orderFront = [preferenceOrderFront state];
    enableJavaScript = [preferenceEnableJavaScript state];
    [[webView preferences] setJavaScriptEnabled:enableJavaScript];
    enableSound = [preferenceEnableSound state];
    enableSpeech = [preferenceEnableSpeech state];
    enableRedirect = [preferenceEnableRedirect state];
    if (scrollSpeed < MIN_AUTOSCROLL_SPEED) {
        scrollSpeed = MIN_AUTOSCROLL_SPEED;
    } else if (scrollSpeed > MAX_AUTOSCROLL_SPEED) {
        scrollSpeed = MAX_AUTOSCROLL_SPEED;
    }
    if (speechRate < MIN_SPEECH_RATE) {
        speechRate = MIN_SPEECH_RATE;
    } else if (speechRate > MAX_SPEECH_RATE) {
        speechRate = MAX_SPEECH_RATE;
    }
    scrollSpeed = [preferenceScrollSpeed floatValue];
    speechRate = [preferenceSpeechRate floatValue];
    autopilotCount = [preferenceSegmentCount selectedSegment]*DEFAULT_AUTOPILOT_COUNT_WIDTH;
    urlRequestTimer = [preferenceRequestTimerField floatValue];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[preferenceHomeUrlField stringValue] forKey:gReaderHomeUrlKey];
    [defaults setBool:autoStartup forKey:gReaderAutoStartKey];
    [defaults setBool:orderFront forKey:gReaderOrderFrontKey];
    [defaults setBool:enableJavaScript forKey:gReaderEnableJavaScriptKey];
    [defaults setBool:enableSound forKey:gReaderEnableSoundKey];
    [defaults setBool:enableSpeech forKey:gReaderEnableSpeechKey];
    [defaults setBool:enableRedirect forKey:gReaderEnableRedirectKey];
    [defaults setFloat:scrollSpeed forKey:gReaderScrollSpeedKey];
    [defaults setFloat:speechRate forKey:gReaderSpeechRateKey];
    [defaults setFloat:autopilotCount forKey:gReaderAutopilotCountKey];
    [defaults setFloat:urlRequestTimer forKey:gReaderRequestTimerKey];
    [NSApp endSheet:preferenceSheet];
    [preferenceSheet orderOut:sender];
}

- (IBAction)cancelPreferenceSheet:(id)sender {
    [NSApp endSheet:preferenceSheet];
    [preferenceSheet orderOut:sender];
}

- (IBAction)chengePreferenceValue:(id)sender {
    [preferenceRequestTimerField setFloatValue:[preferenceRequestTimerStepper floatValue]];
}

- (IBAction)changeBookmark:(id)sender {
    [self saveBookmark];
}

- (IBAction)changeFeed:(id)sender {
    [self saveFeed];
    [reader handleFeedChange:nil];
}

#pragma mark Notifiers

- (void)progressStarted:(NSNotification *)notification
{
    [webProgress setHidden:NO];
    [webProgressBg setHidden:NO];
	[webProgress startAnimation:self];
	// progressWebView = YES;
}

- (void)progressFinished:(NSNotification *)notification
{
	[webProgress stopAnimation:self];
    [webProgressBg setHidden:YES];
    [webProgress setHidden:YES];
    /*
	progressWebView = NO;
	if (progressConnection == NO) {
		[progress stopAnimation:self];
		[self enableUrlRequest:YES];
	}
     */
}

#pragma mark webView

- (void)webView:(WebView*)sender didStartProvisionalLoadForFrame:(WebFrame*)frame {
	if ([sender mainFrame] != frame) {
		return;
	}
	NSURLRequest *req = [[frame provisionalDataSource] request];
	NSString *url = [[req URL] absoluteString];
	NSLog(@"didStartProvisionalLoadForFrame: %@", url);
	[urlText setStringValue:url];
    if ((crawling == YES && crawlingPaused == NO) ||
        ([reader crawling] == YES && [reader crawlingPaused] == NO)) {
        if (orderFront == YES) {
            [[self window] orderFrontRegardless];
        }
    }
}

- (void)webView:(WebView*)sender didReceiveTitle: (NSString*)title forFrame:(WebFrame*)frame
{
	if (frame == [sender mainFrame]) {
		NSLog(@"didReceiveTitle: %@ %@", title, [webView mainFrameURL]);
		[titleText setStringValue:title];
		[urlText setStringValue:[webView mainFrameURL]];
        if (scrollTimer) {
            [self stopTimerScroll];
        }
        if (crawling == YES || ([reader crawling] == YES && skipBrowse == NO)) {
            [self stopSpeech];
        }
        [self progressStarted:nil];
	}
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
	if ([sender mainFrame] != frame) {
		return;
	}
	NSLog(@"didFinishLoadForFrame %@ %@", titleText, [webView mainFrameURL]);
    //NSLog(@"frameView origin = (%0.f,%0.f)", [[frame frameView] bounds].origin.x, [[frame frameView] bounds].origin.y);
 	[goBack setEnabled:[webView canGoBack]];
	[goForward setEnabled:[webView canGoForward]];
	[urlText setStringValue:[webView mainFrameURL]];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[urlText stringValue] forKey:gReaderLastUrlKey];
	if (crawling == YES && crawlingPaused == NO) {
        if (enableSound) {
            NSSound *sound = [NSSound soundNamed:@"Pop"];
            [sound play];
        }
        if ([target scrollTimes] == 0) {
            [self startTimerCrawling:CRAWLING_TIMER_CMD_CNT];
        } else {
            [self startTimerCrawling:CRAWLING_TIMER_CMD_SCROLL];
        }
        scrollWidth = DEFAULT_AUTOSCROLL_START_POSITION;
        scrollTimes = DEFAULT_AUTOSCROLL_TIMES;
        if (target) {
            scrollWidth = [target startPosition];
            scrollTimes = [target scrollTimes];
            if (enableSpeech) {
                [self startSpeech:[target title]:[target voice]];
            }
        }
        [self startTimerScroll:1/AUTOSCROLL_PAUSE_TIMER];
        if (enabelPreFetch == YES) {
            [self preFetchCrawling];
        }
	} else if ([reader crawling] == YES && [reader crawlingPaused] == NO && skipBrowse == NO) {
        if (enableSound) {
            NSSound *sound = [NSSound soundNamed:@"Pop"];
            [sound play];
        }
        if ([[reader targetItem] scrollTimes] == 0) {
            [reader startTimerCrawling:CRAWLING_TIMER_CMD_CNT];
        } else {
            [reader startTimerCrawling:CRAWLING_TIMER_CMD_SCROLL];
        }
        scrollWidth = DEFAULT_AUTOSCROLL_START_POSITION;
        scrollTimes = DEFAULT_AUTOSCROLL_TIMES;
        if ([reader targetItem]) {
            scrollWidth = [[reader targetItem] startPosition];
            scrollTimes = [[reader targetItem] scrollTimes];
            if (enableSpeech) {
                [reader buildSpeechText];
                [self startSpeech:[reader speechText]:[[reader targetItem] voice]];
            }
        }
        [self startTimerScroll:1/AUTOSCROLL_PAUSE_TIMER];
        if (enabelPreFetch == YES) {
            [reader preFetchCrawling];
        }
    }
    return;
}

- (IBAction)takeStringUrl:(id)sender
{
    if (sender != urlText) {
        return;
    }
	NSLog(@"takeStringUrl: %@", [urlText stringValue]);
	NSString* urlString = [urlText stringValue];
	NSURL* url;

	if (urlString == nil || [urlString isEqualToString:@""] == YES) {
		[[webView mainFrame] reload];
		return;
	}
    /*
    if ([[webView mainFrameURL] isEqualToString:[urlText stringValue]] == YES) {
        return;
    }
     */
    if (enableRedirect == YES) {
        if (crawling == YES || [reader crawling] == YES) {
            NSBeep();
            return;
        }
        NSURL* feedUrl = [NSURL URLWithString:urlString];
        if ([[feedUrl absoluteString] hasPrefix:@"feed://"] == YES ||
            [[feedUrl path] hasSuffix:@"/feed"] == YES ||
            [[feedUrl path] hasSuffix:@".rss"] == YES ||
            [[feedUrl path] hasSuffix:@".xml"] == YES ||
            [[feedUrl path] hasSuffix:@".rdf"] == YES) {
            NSLog(@"open feed request: %@", urlString);
            [[reader feedField] setStringValue:urlString];
            [reader showWindow:self];
            [reader fetch:self];
            [urlText setStringValue:[webView mainFrameURL]];
            return;
        }
    }
	if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
		url = [NSURL URLWithString:urlString];
    } else if ([urlString hasPrefix:@"feed:"] == YES) {
        NSRange range = [urlString rangeOfString:@"feed:"];
        NSMutableString* feed = [[NSMutableString alloc] initWithFormat:@"%@",urlString];
        [feed replaceCharactersInRange:range withString:@"http:"];
		url = [NSURL URLWithString:feed];
        [feed release];
	} else {
		NSRange range = [urlString rangeOfString:@"."];
		if (range.length == 0) {
			url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@.com", urlString]];
		} else {
			url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlString]];
		}
	}
	if (url) {
        // NSLog(@"URL scheme = %@ host = %@ path = %@", [url scheme],[url host],[url path]);
		NSURLRequest* urlRequest = [NSURLRequest requestWithURL:url];
		if (urlRequest) {
            NSLog(@"cash policy = %ld timeout interval = %f", (long)[urlRequest cachePolicy], [urlRequest timeoutInterval]);
			[[webView mainFrame] loadRequest:urlRequest];
		}
	}
}

- (WebView*)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	NSLog(@"createWebViewWithRequest: %@", request);
	NSURL *url = [[request URL] absoluteURL];
	[[NSWorkspace sharedWorkspace] openURL:url];
	return NULL;
}

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
decisionListener:(id)listener
{
	NSLog(@"decidePolicyForNewWindowAction: %@", request);
	NSURL *url = [[request URL] absoluteURL];
    /*
    if ([[url absoluteString] hasPrefix:@"feed://"] == YES ||
        [[url absoluteString] hasSuffix:@".rss"] == YES ||
        [[url absoluteString] hasSuffix:@".rdf"] == YES) {
        NSLog(@"open feed request: %@", [url absoluteString]);
    }
     */
	NSURLRequest* urlRequest = [ NSURLRequest requestWithURL:url ];
	if (urlRequest) {
		if ([webView isLoading]) {
			[webView stopLoading:self];
		}
		WebFrame* mainFrame = [webView mainFrame];
		[mainFrame loadRequest:urlRequest];
	}
}

- (void)webView:(WebView*)sender decidePolicyForNavigationAction:(NSDictionary *)info
        request:(NSURLRequest *)request
          frame:(WebFrame*)frame
decisionListener:(id<WebPolicyDecisionListener>)listener
{
	//NSLog(@"decidePolicyForNewWindowAction: %@", request);
    if (enableRedirect == YES && crawling == NO && [reader crawling] == NO) {
        NSURL *url = [[request URL] absoluteURL];
        if ([[url absoluteString] hasPrefix:@"feed://"] == YES ||
            [[url path] hasSuffix:@"/feed"] == YES ||
            [[url path] hasSuffix:@".rss"] == YES ||
            [[url path] hasSuffix:@".rdf"] == YES) {
            NSLog(@"open feed request: %@", [url absoluteString]);
            [ listener ignore];
            [[reader feedField] setStringValue:[url absoluteString]];
            [reader showWindow:self];
            [reader fetch:self];
            return;
        }
    }
    [ listener use ];
}

- (void)loadUrl:(NSString*)urlString
{
	WebFrame        *mainFrame;
	NSURL           *url;
    NSURLRequest    *urlRequest;
    
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
    if (isReloadRevalidatingCacheData == YES) {
        urlRequest = [ NSURLRequest requestWithURL:url
                                       cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                   timeoutInterval:60.0];
    } else {
        urlRequest = [ NSURLRequest requestWithURL:url ];
    }
	if (urlRequest) {
		if ([webView isLoading]) {
			[webView stopLoading:self];
		}
		mainFrame = [webView mainFrame];
		[mainFrame loadRequest:urlRequest];
	}
}

- (void)setJavaScriptEnabeled:(bool)enable {
    [[webView preferences] setJavaScriptEnabled:enable];
}

- (void)reserveLoadUrl:(NSString*)urlString
{
    reservedUrl = [urlString retain];
	reserveTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5
													  target:self
													selector:@selector(loadReservedUrl:)
													userInfo:nil
													 repeats:NO] retain];
}

- (void)loadReservedUrl:(NSTimer*) timer
{
    [self loadUrl:reservedUrl];
    [reservedUrl release];
    reservedUrl = nil;
    //[self setEnabeJavaScript:enableJavaScript];
}

- (void)preLoadUrl:(NSString*)urlString
{
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
    if (isReloadRevalidatingCacheData == YES) {
        urlRequest = [ NSURLRequest requestWithURL:url
                                       cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                   timeoutInterval:30.0];
    } else {
        urlRequest = [ NSURLRequest requestWithURL:url ];
    }
	if (urlRequest) {
		if ([backgroundWebView isLoading]) {
			[backgroundWebView stopLoading:self];
		}
		WebFrame    *mainFrame = [backgroundWebView mainFrame];
		[mainFrame loadRequest:urlRequest];
	}
}

- (void)loadCashedUrl
{
    NSURLRequest    *urlRequest;
	NSURL           *url;
    url = [NSURL URLWithString:[webView mainFrameURL]];
    urlRequest = [ NSURLRequest requestWithURL:url
                                   cachePolicy:NSURLRequestReturnCacheDataDontLoad
                               timeoutInterval:30.0];
    [[webView mainFrame] loadRequest:urlRequest];
}

- (void)enableUrlRequest:(bool)isEnable
{
	[urlText setEnabled:isEnable];
	[urlText setEditable:isEnable];
}

#pragma mark Auto Pilot

- (IBAction)crawlingBookmark:(id)sender {
    NSImage *template;
    scrollPage = NO;
    if (crawling == NO) {
        NSInteger	row = [bookmarkTableView selectedRow];
        [bookmarkTableView scrollRowToVisible:row];
        if (sender == forwardBookmarkButton || sender == menuGoForward) {
            if (row == -1) {
                row = 0;
            }
            for (; row < [bookmarks count]; row++) {
                Bookmark *item = [bookmarks objectAtIndex:row];
                if (item && [item enabled] == YES) {
                    break;
                }
            }
            if (row >= [bookmarks count]) {
                NSBeep();
                return;
            }
            [self startCrawling:row:[bookmarks count]-1];
            //[self startCrawling];
            if (crawling == NO) {
                return;
            }
            //template = [NSImage imageNamed:@"NSStopProgressTemplate"];
            template = [NSImage imageNamed:@"ImageStopSmall"];
            [forwardBookmarkButton setImage:template];
            [backBookmarkButton setEnabled:NO];
            forward = YES;
        } else {
            if (row == -1) {
                row = [rssItems count]-1;
            }
            for (; row >= 0; row--) {
                Bookmark *item = [bookmarks objectAtIndex:row];
                if (item && [item enabled] == YES) {
                    break;
                }
            }
            if (row < 0) {
                NSBeep();
                return;
            }
            [self startCrawling:row:0];
            //[self startCrawling];
            if (crawling == NO) {
                return;
            }
            //template = [NSImage imageNamed:@"NSStopProgressTemplate"];
            template = [NSImage imageNamed:@"ImageStopSmall"];
            [backBookmarkButton setImage:template];
            [forwardBookmarkButton setEnabled:NO];
            forward = NO;
        }
    } else {
        crawling = NO;
        template = [NSImage imageNamed:@"NSRightFacingTriangleTemplate"];
        [forwardBookmarkButton setImage:template];
        [forwardBookmarkButton setEnabled:YES];
        template = [NSImage imageNamed:@"NSLeftFacingTriangleTemplate"];
        [backBookmarkButton setImage:template];
        [backBookmarkButton setEnabled:YES];
    }
}

- (IBAction)skipBookmark:(id)sender {
    if (crawling == NO) {
        NSBeep();
        return;
    }
    if (crawlingTimerCmd == CRAWLING_TIMER_CMD_SKIP) {
        NSBeep();
        return;
    }
    if ([webView isLoading] == YES) {
        [webView stopLoading:self];
    }
    [self stopTimerScroll];
    [self stopTimerCrawling];
    [self startTimerCrawling:CRAWLING_TIMER_CMD_SKIP];
    return;
}

- (void)startCrawling:(NSInteger)indexFrom :(NSInteger)indexTo
{
    if ([rssItems count] == 0) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NO_CRAWLING_SITE",@"web site for autopilot not found.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
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
    [self stopCrawling:NO];
	crawling = YES;
	Bookmark* bookmark = [bookmarks objectAtIndex:crawlingIndex];
	if (bookmark) {
        [reader stopCrawling:NO];
        if (enableSound) {
            NSSound *sound = [NSSound soundNamed:@"Submarine"];
            [sound play];
        }
        if (target) {
            [target release];
            target = nil;
        }
        target = [bookmark retain];
        if ([target disableJavaScript] == YES) {
            [self setJavaScriptEnabeled:NO];
        } else {
            [self setJavaScriptEnabeled:enableJavaScript];
        }
        [self setBookmarkIndex:crawlingIndex];
		[self loadUrl:[bookmark url]];
		[self enableUrlRequest:NO];
		[self startTimerCrawling:CRAWLING_TIMER_CMD_CANCEL];
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
        [forwardBookmarkButton setImage:template];
        [forwardBookmarkButton setEnabled:YES];
        template = [NSImage imageNamed:@"NSLeftFacingTriangleTemplate"];
        [backBookmarkButton setImage:template];
        [backBookmarkButton setEnabled:YES];

		[self stopTimerCrawling];
        [self stopTimerScroll];
        [self setJavaScriptEnabeled:enableJavaScript];
		[self enableUrlRequest:YES];
		if (warn == YES) {
			NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"INFO",@"Info")
											 defaultButton:NSLocalizedString(@"OK",@"Ok")
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"CRAWLING_INTERRUPTED",@"autopilot is interrupted.")];
			[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		}
	}
}

- (void)continueCrawling
{
	NSLog(@"continueCrawling");
	if (crawling == NO) {
		return;
	}

    if (forward == YES) {
        crawlingIndex++;
        for (; crawlingIndex < [bookmarks count]; crawlingIndex++) {
            Bookmark *item = [bookmarks objectAtIndex:crawlingIndex];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if ([bookmarks count] <= crawlingIndex ||
            crawlingDst < crawlingIndex) {
            [self stopCrawling:NO];
            if (scrollPage == YES) {
                if (enableSound == YES) {
                    NSSound *sound = [NSSound soundNamed:@"Pop"];
                    [sound play];
                }
                [bookmarkTableView deselectAll:self];
                scrollPage = NO;
            } else {
                [self stopSpeech];
                if (enableSound) {
                    NSSound *sound = [NSSound soundNamed:@"CompleteAlarm"];
                    [sound play];
                }
            }
            return;
        }
    } else {
        crawlingIndex--;
        for (; crawlingIndex >= 0; crawlingIndex--) {
            Bookmark *item = [bookmarks objectAtIndex:crawlingIndex];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if (crawlingIndex < 0 ||
            crawlingIndex < crawlingDst) {
            [self stopCrawling:NO];
            if (scrollPage == YES) {
                if (enableSound == YES) {
                    NSSound *sound = [NSSound soundNamed:@"Pop"];
                    [sound play];
                }
                [bookmarkTableView deselectAll:self];
                scrollPage = NO;
            } else {
                [self stopSpeech];
                if (enableSound == YES) {
                    NSSound *sound = [NSSound soundNamed:@"CompleteAlarm"];
                    [sound play];
                }
            }
            return;
        }
    }
	Bookmark* bookmark = [bookmarks objectAtIndex:crawlingIndex];
	if (bookmark) {
        if (enableSound) {
            NSSound *sound = [NSSound soundNamed:@"Submarine"];
            [sound play];
        }
        if (target) {
            [target release];
            target = nil;
        }
        target = [bookmark retain];
        if ([target disableJavaScript] == YES) {
            [self setJavaScriptEnabeled:NO];
        } else {
            [self setJavaScriptEnabeled:enableJavaScript];
        }
        [self setBookmarkIndex:crawlingIndex];
		[self loadUrl:[bookmark url]];
		[self enableUrlRequest:NO];
        //[self enableWeb];
		[self startTimerCrawling:CRAWLING_TIMER_CMD_CANCEL];
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
        for (; index < [bookmarks count]; index++) {
            Bookmark *item = [bookmarks objectAtIndex:index];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if ([bookmarks count] <= index) {
            return;
        }
    } else {
        index--;
        for (; index >= 0; index--) {
            Bookmark *item = [bookmarks objectAtIndex:index];
            if (item && [item enabled] == YES) {
                break;
            }
        }
        if (index < 0) {
            return;
        }
    }
	Bookmark* bookmark = [bookmarks objectAtIndex:index];
	if (bookmark) {
		[self preLoadUrl:[bookmark url]];
	}
}

- (void)startTimerCrawling:(int)cmd {
	float timer;
    timer = DEFAULT_AUTOSCROLL_INTERVAL;
    if (target) {
        timer = [target scrollInterval];
    }
	if (crawlingTimer) {
		[self stopTimerCrawling];
	}
	crawlingTimerCmd = cmd;
	if (cmd == CRAWLING_TIMER_CMD_CANCEL) {
		timer = urlRequestTimer;
	}
    if ([webView isLoading] == YES) {
        timer += AUTOSCROLL_PAUSE_TIMER;
    }
    if (cmd == CRAWLING_TIMER_CMD_SKIP) {
        timer = AUTOSCROLL_PAUSE_TIMER;
    }
	crawlingTimer = [[NSTimer scheduledTimerWithTimeInterval:timer
													  target:self
													selector:@selector(checkTimerCrawling:)
													userInfo:nil
													 repeats:NO] retain];
	[self enableUrlRequest:YES];
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
			if (bookmarks == nil) {
				[self stopTimerCrawling];
				return;
			}
            if ([backgroundWebView isLoading] == YES) {
                [backgroundWebView stopLoading:self];
            }
			[self continueCrawling];
			break;
		case CRAWLING_TIMER_CMD_SCROLL:
            if (crawling == NO) {
                return;
            }
            scrollWidth = DEFAULT_AUTOSCROLL_WIDTH;
            if (target) {
                scrollWidth = [target scrollWidth];
            }
            [self startTimerScroll:scrollSpeed];
            scrollTimes--;
            if (scrollTimes <= 0) {
                [self startTimerCrawling:CRAWLING_TIMER_CMD_CNT];
            } else {
                [self startTimerCrawling:CRAWLING_TIMER_CMD_SCROLL];
            }
            break;
		case CRAWLING_TIMER_CMD_CANCEL:
			if ([webView isLoading] == YES) {
				[webView stopLoading:self];
			}
            if (enableSound) {
                NSSound *sound = [NSSound soundNamed:@"Pop"];
                [sound play];
            }
            if (crawling == YES && crawlingPaused == NO) {
                if ([target scrollTimes] == 0) {
                    [self startTimerCrawling:CRAWLING_TIMER_CMD_CNT];
                } else {
                    [self startTimerCrawling:CRAWLING_TIMER_CMD_SCROLL];
                }
                scrollWidth = DEFAULT_AUTOSCROLL_START_POSITION;
                scrollTimes = DEFAULT_AUTOSCROLL_TIMES;
                if (target) {
                    scrollWidth = [target startPosition];
                    scrollTimes = [target scrollTimes];
                    if (enableSpeech) {
                        [self startSpeech:[target title]:[target voice]];
                    }
                }
                [self startTimerScroll:1/AUTOSCROLL_PAUSE_TIMER];
                if (enabelPreFetch == YES) {
                    [self preFetchCrawling];
                }
            }
			break;
	}
}

#pragma mark Auto Scroll

- (void)startTimerScroll:(float)timer {
    float tv = 1/timer;
    if ([webView isLoading] == YES) {
        tv = 2/timer;
    }
	if (scrollTimer) {
		[self stopTimerScroll];
	}
    if (scrollWidth > 0) {
        scrollTimer = [[NSTimer scheduledTimerWithTimeInterval:tv
                                                        target:self
                                                      selector:@selector(checkTimerScroll:)
                                                      userInfo:nil
                                                       repeats:NO] retain];
    }
}

- (void)stopTimerScroll {
	if (scrollTimer) {
		[scrollTimer invalidate];
		[scrollTimer release];
		scrollTimer = nil;
	}
}

- (void)checkTimerScroll:(NSTimer*) timer {
    [ webView scrollLineDown:self];
    scrollWidth--;
    if (scrollWidth > 0) {
        if (crawling == YES || [reader crawling] == YES || scrollPage == YES) {
            [self startTimerScroll:scrollSpeed];
        }
    } else {
        [self stopTimerScroll];
    }
}

#pragma mark Bookmark

- (IBAction)createBookmark:(id)sender
{
	NSLog(@"createBookmark");
    if (isLiteVresion == YES) {
        if ([bookmarks count] >= LIMIT_BOOKMARKS_FOR_LITE_VER) {
            NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
                                             defaultButton:NSLocalizedString(@"OK",@"Ok")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"LIMIT_BOOKMARKS",@"In the lite version, You can register up to %d bookmarks."), LIMIT_BOOKMARKS_FOR_LITE_VER];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
            return;
        }
    }
    [attrTitleField setStringValue:[titleText stringValue]];
    [attrUrlField setStringValue:[urlText stringValue]];
    [self resetAttrValue:sender];
    attrType = ATTR_TYPE_CREATE_BOOKMARK;
    [attrFilterField setEnabled:NO];
    [attrFilterField setStringValue:@""];
    [attrDisableJavaScript setState:NO];
    [attrDisableJavaScript setEnabled:YES];
    [attrSheetTitle setStringValue:NSLocalizedString(@"DETAIL_BOOKMARK",@"Details of Bookmark")];
    [self showAttrSheet:sender];
    [attrVoiceComboBox setTitleWithMnemonic:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")];
}

- (IBAction)finishCreateBookmark:(id)sender
{
	NSLog(@"FinishCeateBookmark");
    for (Bookmark *item in bookmarks) {
        if ([[item url] isEqualToString:[attrUrlField stringValue]] == YES &&
            [[item title] isEqualToString:[attrTitleField stringValue]] == YES) {
            NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
                                             defaultButton:NSLocalizedString(@"OK",@"Ok")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"ALREDY_REGISTERED",@"Item is already registered.")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
            return;
        }
    }
	Bookmark *new = [bookmarkController newObject];
    [new setEnabled:YES];
    [new setTitle:[attrTitleField stringValue]];
    [new setUrl:[attrUrlField stringValue]];
    [self setVoice:new];
    [new setStartPosition:[attrStartPositionField integerValue]];
    [new setScrollWidth:[attrScrollWidthField integerValue]];
    [new setScrollTimes:[attrScrollTimesField integerValue]];
    [new setScrollInterval:[attrScrollIntervalField floatValue]];
    if ([new scrollInterval] < MIN_AUTOSCROLL_INTERVAL) {
        [new setScrollInterval:MIN_AUTOSCROLL_INTERVAL];
    }
    [new setDisableJavaScript:[attrDisableJavaScript state]];
    [new setUrlFilter:@""];
	[bookmarkController addObject:new];
	[bookmarkController rearrangeObjects];
	[new release];
    [self saveBookmark];
}

- (IBAction)removeBookmark:(id)sender
{
    if (crawling == YES) {
        NSBeep();
        return;
    }
	NSArray *selected = [bookmarkController selectedObjects];
    if ([selected count] == 0) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NOT_SELECTED",@"No item selected.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
    }
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"DELETE",@"Delete")
									 defaultButton:NSLocalizedString(@"DELETE",@"Delete")
								   alternateButton:NSLocalizedString(@"CANCEL",@"Cancel")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"SURE_DELETE",@"Do you really want to delete ?")];
	NSLog(@"Stating alert sheet");
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(alertEndedRemoveBookmark:code:context:) contextInfo:NULL];
}

- (void)alertEndedRemoveBookmark:(NSAlert*)alert
                            code:(int)choice
                         context:(void*)v
{
	NSLog(@"Alert sheet ended");
	if (choice == NSAlertDefaultReturn) {
		[bookmarkController remove:nil];
        [self saveBookmark];
	}
}

- (IBAction)editBookmark:(id)sender {
	NSArray *selected = [bookmarkController selectedObjects];
    if ([selected count] != 1) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NOT_SELECTED",@"No item selected.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
    }
    Bookmark *item = [selected objectAtIndex:0];
    if (item) {
        [attrTitleField setStringValue:[item title]];
        [attrUrlField setStringValue:[item url]];
        [attrStartPositionField setIntegerValue:[item startPosition]];
        [attrScrollWidthField setIntegerValue:[item scrollWidth]];
        [attrScrollTimesField setIntegerValue:[item scrollTimes]];
        [attrScrollIntervalField setFloatValue:[item scrollInterval]];
        [attrStartPositionStepper setIntegerValue:[item startPosition]];
        [attrScrollWidthStepper setIntegerValue:[item scrollWidth]];
        [attrScrollTimesStepper setIntegerValue:[item scrollTimes]];
        [attrScrollIntervalStepper setFloatValue:[item scrollInterval]];
        [attrFilterField setEnabled:NO];
        [attrDisableJavaScript setState:[item disableJavaScript]];
        [attrDisableJavaScript setEnabled:YES];
        [attrFilterField setStringValue:@""];
        attrType = ATTR_TYPE_EDIT_BOOKMARK;
        [attrSheetTitle setStringValue:NSLocalizedString(@"DETAIL_BOOKMARK",@"Details of Bookmark")];
        if ([item voice]) {
            //[attrVoiceComboBox setTitleWithMnemonic:[self voiceName:[item voice]]];
            NSDictionary* dict = [NSSpeechSynthesizer attributesForVoice:[item voice]];
            NSString* voiceName = [dict objectForKey:NSVoiceName];
            NSString* voiceLocalId = [dict objectForKey:NSVoiceLocaleIdentifier];
            NSString *voiceItem;
            if (voiceLocalId && [voiceLocalId isEqualToString:@"en_US"] == NO) {
                voiceItem = [[NSString alloc] initWithFormat:@"%@ (%@)",voiceName,voiceLocalId];
            } else {
                voiceItem = [[NSString alloc] initWithFormat:@"%@",voiceName];
            }
            [attrVoiceComboBox setTitleWithMnemonic:voiceItem];
            [voiceItem release];
        } else {
            [attrVoiceComboBox setTitleWithMnemonic:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")];
        }
        [self showAttrSheet:sender];
        editing = item;
    }
}

- (IBAction)finishEditBookmark:(id)sender {
	NSArray *selected = [bookmarkController selectedObjects];
    if ([selected count] != 1) {
        return;
    }
    Bookmark *item = editing;
    if (item) {
        [item setTitle:[attrTitleField stringValue]];
        [item setUrl:[attrUrlField stringValue]];
        [self setVoice:item];
        [item setStartPosition:[attrStartPositionField integerValue]];
        [item setScrollWidth:[attrScrollWidthField integerValue]];
        [item setScrollTimes:[attrScrollTimesField integerValue]];
        [item setScrollInterval:[attrScrollIntervalField floatValue]];
        if ([item scrollInterval] < MIN_AUTOSCROLL_INTERVAL) {
            [item setScrollInterval:MIN_AUTOSCROLL_INTERVAL];
        }
        [item setDisableJavaScript:[attrDisableJavaScript state]];
        [item setUrlFilter:@""];
        [self saveBookmark];
        [bookmarkController rearrangeObjects];
        [bookmarkTableView reloadData];
        editing = nil;
    }
}

- (IBAction)moveBookmark:(id)sender {
    int value = [bookmarkStepper intValue];
	[bookmarkTableView reloadData];
	[bookmarkController rearrangeObjects];
    long count = [bookmarks count];
    long index = [bookmarkTableView selectedRow];
    long newIndex = index;
    NSLog(@"moveBookmark: %d", value);
    [bookmarkStepper setIntValue:0];
    if (crawling == YES) {
        NSBeep();
        return;
    }
    if (index == -1) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NOT_SELECTED",@"No item selected.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        return;
    }
    if (count <= 1) {
        return;
    }
    if (value > 0) {
        // Up
        if (index == 0) {
            return;
        }
        [bookmarks exchangeObjectAtIndex:index withObjectAtIndex:index - 1];
        NSLog(@"exchangeObjectAtIndex: %ld %ld", index, index - 1);
        newIndex = index - 1;
    } else if (value < 0) {
        // Down
        if (index == (count - 1)) {
            return;
        }
        [bookmarks exchangeObjectAtIndex:index withObjectAtIndex:index + 1];
        NSLog(@"exchangeObjectAtIndex: %ld %ld", index, index + 1);
        newIndex = index + 1;
    }
    [bookmarkTableView reloadData];
	[bookmarkController rearrangeObjects];
    [bookmarkTableView scrollRowToVisible:newIndex];
    [self saveBookmark];
}

- (IBAction)openBookmark:(id)sender
{
	[bookmarkTableView reloadData];
	NSInteger	row = [bookmarkTableView clickedRow];
	if (row == -1) {
		row = [bookmarkTableView selectedRow];
	}
	NSLog(@"openBookmark: row=%ld", (long)row);
    if (crawling == YES) {
        NSBeep();
        return;
    }
	if (row == -1) {
        if (sender == webButton) {
            if ([webView isLoading] == YES) {
                NSBeep();
                return;
            }
            scrollPage = YES;
            [reader stopCrawling:NO];
            [self stopCrawling:NO];
            if (target) {
                [target release];
                target = nil;
            }
            if (enableSound == YES) {
                NSSound *sound = [NSSound soundNamed:@"Pop"];
                [sound play];
            }
            scrollPage = YES;
            scrollWidth = DEFAULT_AUTOSCROLL_WIDTH;
            [self startTimerScroll:1/AUTOSCROLL_PAUSE_TIMER];
        } else {
            NSBeep();
        }
		return;
	}
	if (row != [bookmarkTableView selectedRow]) {
        NSBeep();
		return;
	}
    Bookmark *item = [bookmarks objectAtIndex:row];
    if (item) {
        if (sender == webButton) {
            scrollPage = YES;
            [reader stopCrawling:NO];
            NSImage *template;
            template = [NSImage imageNamed:@"ImageStopSmall"];
            [forwardBookmarkButton setImage:template];
            template = [NSImage imageNamed:@"NSLeftFacingTriangleTemplate"];
            [backBookmarkButton setImage:template];
            [backBookmarkButton setEnabled:NO];
            forward = YES;
            [self startCrawling:row:row];
        } else {
            [self setJavaScriptEnabeled:enableJavaScript];
            [self loadUrl:[item url]];
            [bookmarkTableView deselectAll:sender];
        }
    } else {
        NSBeep();
    }
    return;
}

- (void)setBookmarkIndex:(NSInteger)index
{
    NSIndexSet* ixset = [NSIndexSet indexSetWithIndex:index];
    [bookmarkTableView selectRowIndexes:ixset byExtendingSelection:NO];
    [bookmarkTableView scrollRowToVisible:index];
}

#pragma mark RSS Feed

- (IBAction)createFeed:(id)sender
{
	NSLog(@"createFeed");
    if (isLiteVresion == YES) {
        if ([feeds count] >= LIMIT_FEEDS_FOR_LITE_VER) {
            NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
                                             defaultButton:NSLocalizedString(@"OK",@"Ok")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"LIMIT_FEEDS",@"In the lite version, You can register up to %d feeds."), LIMIT_FEEDS_FOR_LITE_VER];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
            return;
        }
    }
    [attrTitleField setStringValue:@""];
    if ([reader feedField]) {
        [attrUrlField setStringValue:[[reader feedField] stringValue]];
    } else {
        [attrUrlField setStringValue:@""];
    }
    if ([[attrUrlField stringValue] isEqualToString:@""] == NO && [reader window]) {
        [attrTitleField setStringValue:[[reader window] title]];
    }
    [self resetAttrValue:sender];
    [attrFilterField setEnabled:YES];
    [attrFilterField setStringValue:@""];
    [attrDisableJavaScript setEnabled:YES];
    [attrDisableJavaScript setState:NO];
    attrType = ATTR_TYPE_CREATE_FEED;
    [attrSheetTitle setStringValue:NSLocalizedString(@"DETAIL_FEED",@"Details of RSS Feed")];
    [self showAttrSheet:sender];
    [attrVoiceComboBox setTitleWithMnemonic:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")];
}

- (IBAction)finishCreateFeed:(id)sender
{
    for (Bookmark *item in feeds) {
        if ([[item url] isEqualToString:[attrUrlField stringValue]] == YES &&
            [[item title] isEqualToString:[attrTitleField stringValue]] == YES) {
            NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
                                             defaultButton:NSLocalizedString(@"OK",@"Ok")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"ALREDY_REGISTERED",@"Item is already registered.")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
            return;
        }
    }
	Bookmark *new = [feedsController newObject];
    [new setEnabled:YES];
    [new setTitle:[attrTitleField stringValue]];
    [new setUrl:[attrUrlField stringValue]];
    [self setVoice:new];
    [new setStartPosition:[attrStartPositionField integerValue]];
    [new setScrollWidth:[attrScrollWidthField integerValue]];
    [new setScrollTimes:[attrScrollTimesField integerValue]];
    [new setScrollInterval:[attrScrollIntervalField floatValue]];
    if ([new scrollInterval] < MIN_AUTOSCROLL_INTERVAL) {
        [new setScrollInterval:MIN_AUTOSCROLL_INTERVAL];
    }
    [new setDisableJavaScript:[attrDisableJavaScript state]];
    [new setUrlFilter:[attrFilterField stringValue]];
	[feedsController addObject:new];
	[feedsController rearrangeObjects];
	[new release];
    [self saveFeed];
    [reader handleFeedChange:nil];
}

- (IBAction)removeFeed:(id)sender
{
	NSLog(@"removeFeed");
    if ([reader loading] == YES) {
        NSBeep();
        return;
    }
	NSArray *selected = [feedsController selectedObjects];
    if ([selected count] == 0) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NOT_SELECTED",@"No item selected.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
    }
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"DELETE",@"Delete")
									 defaultButton:NSLocalizedString(@"DELETE",@"Delete")
								   alternateButton:NSLocalizedString(@"CANCEL",@"Cancel")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"SURE_DELETE",@"Do you really want to delete ?")];
	NSLog(@"Stating alert sheet");
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(alertEndedRemoveFeed:code:context:) contextInfo:NULL];
}

- (void)alertEndedRemoveFeed:(NSAlert*)alert
                        code:(int)choice
                     context:(void*)v
{
	NSLog(@"Alert sheet ended");
	if (choice == NSAlertDefaultReturn) {
		[feedsController remove:nil];
        [self saveFeed];
        [reader handleFeedChange:nil];
	}
}

- (IBAction)editFeed:(id)sender {
	NSArray *selected = [feedsController selectedObjects];
    if ([selected count] != 1) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NOT_SELECTED",@"No item selected.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		return;
    }
    Bookmark *item = [selected objectAtIndex:0];
    if (item) {
        [attrTitleField setStringValue:[item title]];
        [attrUrlField setStringValue:[item url]];
        [attrStartPositionField setIntegerValue:[item startPosition]];
        [attrScrollWidthField setIntegerValue:[item scrollWidth]];
        [attrScrollTimesField setIntegerValue:[item scrollTimes]];
        [attrScrollIntervalField setFloatValue:[item scrollInterval]];
        [attrStartPositionStepper setIntegerValue:[item startPosition]];
        [attrScrollWidthStepper setIntegerValue:[item scrollWidth]];
        [attrScrollTimesStepper setIntegerValue:[item scrollTimes]];
        [attrScrollIntervalStepper setFloatValue:[item scrollInterval]];
        [attrDisableJavaScript setEnabled:YES];
        [attrDisableJavaScript setState:[item disableJavaScript]];
        [attrFilterField setEnabled:YES];
        [attrFilterField setStringValue:[item urlFilter]];
        attrType = ATTR_TYPE_EDIT_FEED;
        [attrSheetTitle setStringValue:NSLocalizedString(@"DETAIL_FEED",@"Details of RSS Feed")];
        if ([item voice]) {
            //[attrVoiceComboBox setTitleWithMnemonic:[self voiceName:[item voice]]];
            NSDictionary* dict = [NSSpeechSynthesizer attributesForVoice:[item voice]];
            NSString* voiceName = [dict objectForKey:NSVoiceName];
            NSString* voiceLocalId = [dict objectForKey:NSVoiceLocaleIdentifier];
            NSString *voiceItem;
            if (voiceLocalId && [voiceLocalId isEqualToString:@"en_US"] == NO) {
                voiceItem = [[NSString alloc] initWithFormat:@"%@ (%@)",voiceName,voiceLocalId];
            } else {
                voiceItem = [[NSString alloc] initWithFormat:@"%@",voiceName];
            }
            [attrVoiceComboBox setTitleWithMnemonic:voiceItem];
            [voiceItem release];
        } else {
            [attrVoiceComboBox setTitleWithMnemonic:NSLocalizedString(@"DEFAULT_VOICE",@"Allow System Setting")];
        }
        [self showAttrSheet:sender];
        editing = item;
    }
}

- (IBAction)finishEditFeed:(id)sender {
	NSArray *selected = [feedsController selectedObjects];
    if ([selected count] != 1) {
        return;
    }
    Bookmark *item = editing;
    if (item) {
        [item setTitle:[attrTitleField stringValue]];
        [item setUrl:[attrUrlField stringValue]];
        [self setVoice:item];
        [item setStartPosition:[attrStartPositionField integerValue]];
        [item setScrollWidth:[attrScrollWidthField integerValue]];
        [item setScrollTimes:[attrScrollTimesField integerValue]];
        [item setScrollInterval:[attrScrollIntervalField floatValue]];
        [item setDisableJavaScript:[attrDisableJavaScript state]];
        [item setUrlFilter:[attrFilterField stringValue]];
        if ([item scrollInterval] < MIN_AUTOSCROLL_INTERVAL) {
            [item setScrollInterval:MIN_AUTOSCROLL_INTERVAL];
        }
        [feedsController rearrangeObjects];
        [rssTableView reloadData];
        [self saveFeed];
        [reader handleFeedChange:nil];
        editing = nil;
    }
}

- (IBAction)moveFeed:(id)sender {
    int value = [feedStepper intValue];
	[rssTableView reloadData];
	[feedsController rearrangeObjects];
    long count = [feeds count];
    long index = [rssTableView selectedRow];
    long newIndex = index;
    NSLog(@"moveFeed: %d", value);
    [feedStepper setIntValue:0];
    if ([reader loading] == YES) {
        NSBeep();
        return;
    }
    if (index == -1) {
		NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"ERROR",@"Error")
										 defaultButton:NSLocalizedString(@"OK",@"Ok")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"NOT_SELECTED",@"No item selected.")];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        return;
    }
    if (count <= 1) {
        return;
    }
    if (value > 0) {
        // Up
        if (index == 0) {
            return;
        }
        [feeds exchangeObjectAtIndex:index withObjectAtIndex:index - 1];
        NSLog(@"exchangeObjectAtIndex: %ld %ld", index, index - 1);
        newIndex = index - 1;
    } else if (value < 0) {
        // Down
        if (index == (count - 1)) {
            return;
        }
        [feeds exchangeObjectAtIndex:index withObjectAtIndex:index + 1];
        NSLog(@"exchangeObjectAtIndex: %ld %ld", index, index + 1);
        newIndex = index + 1;
    }
    [rssTableView reloadData];
	[feedsController rearrangeObjects];
    [rssTableView scrollRowToVisible:newIndex];
    [self saveFeed];
    [reader handleFeedChange:nil];
}

- (IBAction)openFeed:(id)sender
{
	[rssTableView reloadData];
    if (sender == rssButton || sender == menuLoadAllRSS) {
        if (autoStartup == YES) {
            [reader stopCrawling:NO];
        } else {
            [reader stopCrawling:YES];
        }
        if ([reader feedField]) {
            [[reader feedField] setStringValue:@""];
        }
        [reader fetchAll:sender];
        [rssTableView deselectAll:sender];
        return;
    }
	NSInteger	row = [rssTableView clickedRow];
	if (row == -1) {
		row = [rssTableView selectedRow];
	}
	NSLog(@"openFeed: row=%ld", (long)row);
	if (row == -1) {
        NSBeep();
		return;
	}
	if (row != [rssTableView selectedRow]) {
        NSBeep();
		return;
	}
    Bookmark *item = [feeds objectAtIndex:row];
    if (item) {
        if (autoStartup == YES) {
            [reader stopCrawling:NO];
        } else {
            [reader stopCrawling:YES];
        }
        if ([reader feedField]) {
            [[reader feedField] setStringValue:[item url]];
        }
        [reader clearTarget];
        [reader setTarget:item];
        [reader fetchRSS:self];
    } else {
        NSBeep();
    }
    return;
}

- (IBAction)openAllFeed:(id)sender
{
    [self openFeed:sender];
}

- (IBAction)openArticle:(id)sender
{
	[articleTableView reloadData];
	NSInteger	row = [articleTableView clickedRow];
	if (row == -1) {
		row = [articleTableView selectedRow];
	}
	NSLog(@"openArticle: row=%ld", (long)row);
	if (row == -1) {
        NSBeep();
		return;
	}
	if (row != [articleTableView selectedRow]) {
        NSBeep();
		return;
	}
    rssItem *item = [[reader rssItems] objectAtIndex:row];
    if (item) {
        if (skipBrowse == NO) {
            [reader stopCrawling:YES];
        }
        [urlText setStringValue:[item link]];
        [self setJavaScriptEnabeled:enableJavaScript];
        [self loadUrl:[item link]];
    }
    return;
}

- (IBAction)forwardFeed:(id)sender
{
    [reader crawlingRSS:sender];
}

- (IBAction)backFeed:(id)sender
{
    [reader crawlingRSS:sender];
}

- (IBAction)skipFeed:(id)sender
{
    if ([reader crawling] == NO) {
        NSBeep();
        return;
    }
    [reader skipCrawling];
    return;
}

- (IBAction)openSafari:(id)sender {
    NSURL* url = [NSURL URLWithString:[webView mainFrameURL]];
    NSWorkspace *workspace = [[[NSWorkspace alloc] init] autorelease];
    [workspace openURL:url];
}

- (IBAction)showReader:(id)sender {
    NSLog(@"showing %@", reader);
    [reader showWindow:nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:gReaderShowReaderKey];
}

- (IBAction)modifyArticle:(id)sender {
    [reader rearrengeArticle];
}

- (IBAction)goForwardAutoPilot:(id)sender {
    NSLog(@"goForwardAutoPilot: %@", [[tabView selectedTabViewItem] identifier]);
    if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"rss"]) {
        [self forwardFeed:sender];
    } else if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"bookmark"]) {
        [self crawlingBookmark:sender];
    }
}

- (IBAction)goBackAutoPilot:(id)sender {
    NSLog(@"goForwardAutoPilot: %@", [[tabView selectedTabViewItem] identifier]);
    if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"rss"]) {
        [self backFeed:sender];
    } else if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"bookmark"]) {
        [self crawlingBookmark:sender];
    }
}

- (IBAction)skipAutoPilot:(id)sender {
    if (crawling == YES) {
        [self skipBookmark:sender];
    }
    if ([reader crawling] == YES) {
        [self skipFeed:sender];
    }
}

- (IBAction)stopAutoPilot:(id)sender {
    if (crawling == YES) {
        [self stopCrawling:NO];
    }
    if ([reader crawling] == YES) {
        [reader stopCrawling:NO];
    }
}

- (IBAction)pageDown:(id)sender {
    [webView scrollPageDown:sender];
}

- (IBAction)pageUp:(id)sender {
    [webView scrollPageUp:sender];
}

- (IBAction)lineDown:(id)sender {
    [webView scrollLineDown:sender];
}

- (IBAction)lineUp:(id)sender {
    [webView scrollLineUp:sender];
}

- (IBAction)pageTop:(id)sender {
    [webView scrollToBeginningOfDocument:sender];
}

- (IBAction)pageEnd:(id)sender {
    [webView scrollToEndOfDocument:sender];
}

- (void)rearrangeArticle
{
    [articleController rearrangeObjects];
    [articleTableView reloadData];
}

- (void)rearrangeFeeds
{
    [feedsController rearrangeObjects];
    [rssTableView reloadData];
}

- (void)setArticleIndex:(NSInteger)index
{
    if (index == [articleTableView selectedRow]) {
        return;
    }
    NSIndexSet* ixset = [NSIndexSet indexSetWithIndex:index];
    [articleTableView selectRowIndexes:ixset byExtendingSelection:NO];
    [articleTableView scrollRowToVisible:index];
}

#pragma mark Archiver

- (void)loadBookmark
{
    BOOL    debug = NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *bookmarkAsData = [defaults objectForKey:gReaderBookmarkListKey];
	if (bookmarkAsData == nil || debug == YES) {
		bookmarks = [[NSMutableArray alloc] init];
        Bookmark *item = [[Bookmark alloc] init];
        [item setEnabled:YES];
        if ([lang isEqualToString:@"ja_JP"]) {
            [item setTitle:@"アップル - スタート"];
            [item setUrl:@"http://www.apple.com/jp/startpage/"];
        } else {
            [item setTitle:@"Apple - Start"];
            [item setUrl:@"http://www.apple.com/startpage/"];
        }
        [item setStartPosition:2];
        [bookmarks addObject:item];
        [item release];
        item = [[Bookmark alloc] init];
        [item setEnabled:YES];
        if ([lang isEqualToString:@"ja_JP"]) {
            [item setTitle:@"Google"];
            [item setUrl:@"http://www.google.co.jp"];
        } else {
            [item setTitle:@"Google"];
            [item setUrl:@"http://www.google.com/"];
        }
        [item setStartPosition:0];
        [item setScrollTimes:0];
        [bookmarks addObject:item];
        [item release];
        item = [[Bookmark alloc] init];
        [item setEnabled:YES];
        [item setTitle:@"Twitter"];
        [item setUrl:@"https://twitter.com/"];
        [bookmarks addObject:item];
        [item setStartPosition:0];
        [item setScrollTimes:8];
        [item release];
        [self saveBookmark];
		return;
	}
	bookmarks = [NSKeyedUnarchiver unarchiveObjectWithData:bookmarkAsData];
	if (bookmarks == nil) {
		bookmarks = [[NSMutableArray alloc] init];
	} else {
		[bookmarks retain];
	}
}

- (void)saveBookmark
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *bookmarkAsData = [NSKeyedArchiver archivedDataWithRootObject:bookmarks];
	[defaults setObject:bookmarkAsData forKey:gReaderBookmarkListKey];
}

- (void)loadFeed
{
    BOOL    debug = NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *bookmarkAsData = [defaults objectForKey:gReaderFeedListKey];
	if (bookmarkAsData == nil || debug == YES) {
		feeds = [[NSMutableArray alloc] init];
        Bookmark *item = [[Bookmark alloc] init];
        [item setEnabled:YES];
        if ([lang isEqualToString:@"ja_JP"]) {
            [item setTitle:@"アップル - ホットニュース"];
            [item setUrl:@"http://www.apple.com/jp/main/rss/hotnews/hotnews.rss"];
        } else {
            [item setTitle:@"Apple Hot News"];
            [item setUrl:@"feed://www.apple.com/main/rss/hotnews/hotnews.rss"];
        }
        [item setStartPosition:2];
        [feeds addObject:item];
        [item release];
        item = [[Bookmark alloc] init];
        [item setEnabled:YES];
        if ([lang isEqualToString:@"ja_JP"]) {
            [item setTitle:@"Reuters: トップニュース"];
            [item setUrl:@"feed://feeds.reuters.com/reuters/JPTopNews"];
        } else {
            [item setTitle:@"Reuters: Top News"];
            [item setUrl:@"feed://feeds.reuters.com/reuters/topNews"];
        }
        [item setStartPosition:5];
        [item setScrollTimes:3];
        [item setDisableJavaScript:YES];
        [feeds addObject:item];
        [item release];
		return;
	}
	feeds = [NSKeyedUnarchiver unarchiveObjectWithData:bookmarkAsData];
	if (feeds == nil) {
		feeds = [[NSMutableArray alloc] init];
	} else {
		[feeds retain];
	}
}

- (void)saveFeed
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *bookmarkAsData = [NSKeyedArchiver archivedDataWithRootObject:feeds];
	[defaults setObject:bookmarkAsData forKey:gReaderFeedListKey];
}

- (IBAction)importFeeds:(id)sender
{
	NSOpenPanel *opanel = [NSOpenPanel openPanel];
	NSInteger opRet;
	[opanel setAllowedFileTypes: [NSArray arrayWithObjects:@"xml",@"'XML'",nil]];
    opRet = [opanel runModal];
	if (opRet == NSOKButton){
        NSURL *dataURL = [opanel URL];
		NSLog(@"URL: %@",[dataURL path]);
        NSXMLDocument *doc;
        NSString *xmlString = [NSString stringWithContentsOfURL:dataURL encoding:NSUTF8StringEncoding error:nil];
        if (xmlString == nil) {
            return;
        }
        doc = [[NSXMLDocument alloc] initWithXMLString:xmlString
                                               options:NSXMLDocumentTidyXML
                                                 error:nil];
        if (doc == nil) {
            return;
        }
        NSLog(@"doc = %@", [doc XMLString]);
        [self importXML:doc];
        [doc release];
	}else{
		NSLog(@"Cansel");
	}
}

- (IBAction)exportFeeds:(id)sender
{
	NSSavePanel *spanel = [NSSavePanel savePanel];
	[spanel setAllowedFileTypes: [NSArray arrayWithObjects: @"xml",@"XML",nil]];
    if (isLiteVresion == YES) {
        [spanel setNameFieldStringValue:@"FlipFeed-Lite"];
    } else {
        [spanel setNameFieldStringValue:@"FlipFeed"];
    }
    [spanel beginSheetModalForWindow:window
                   completionHandler:^(NSInteger result) {
                       if (result == NSOKButton) {
                           NSLog(@"URL: %@",[[spanel URL] path]);
                           NSXMLElement *root;
                           NSXMLDocument *doc;
                           root = [[NSXMLElement alloc] initWithName:@"FlipFeed"];
                           if (root == nil) {
                               return;
                           }
                           doc = [[NSXMLDocument alloc] initWithRootElement:root];
                           if (doc == nil) {
                               [root release];
                               return;
                           }
                           [doc setCharacterEncoding:@"UTF-8"];
                           [doc setStandalone:YES];
                           [self exportXML:doc];
                           NSString *xmlString = [doc XMLStringWithOptions:NSXMLNodePrettyPrint];
                           NSLog(@"doc = %@", xmlString);
                           [xmlString writeToURL:[spanel URL] atomically:NO encoding:NSUTF8StringEncoding error:nil];
                           [doc release];
                           [root release];
                       }else{
                           NSLog(@"Cansel");
                       }
                   }
     ];
}


- (IBAction)initializeFeedsAndBookmarks:(id)sender
{
    if ([reader loading] == YES || [reader lastConnection] != nil) {
        NSBeep();
        return;
    }
    [reader stopCrawling:NO];
    [self stopCrawling:NO];
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"INITIALIZE",@"Initialize")
									 defaultButton:NSLocalizedString(@"INITIALIZE",@"Initialize")
								   alternateButton:NSLocalizedString(@"CANCEL",@"Cancel")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"SURE_INITIALIZE",@"Do you really want to initialize ?")];
	NSLog(@"Stating alert sheet");
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(alertEndedInitialize:code:context:) contextInfo:NULL];
}


- (void)alertEndedInitialize:(NSAlert*)alert
                        code:(int)choice
                     context:(void*)v
{
	NSLog(@"Alert sheet ended");
	if (choice == NSAlertDefaultReturn) {
        for (Bookmark* item in feeds) {
            [feedsController removeObject:item];
        }
        [feedsController rearrangeObjects];
        [self saveFeed];
        [reader handleFeedChange:nil];
        
        for (Bookmark* item in bookmarks) {
            [bookmarkController removeObject:item];
        }
        [bookmarkController rearrangeObjects];
        [self saveBookmark];
    }
}

- (void)importXML:(NSXMLDocument*)doc
{
    NSArray     *itemNodes;
	NSError     *error;
    itemNodes = [[doc nodesForXPath:@"//FlipFeed" error:&error] retain];
    if (itemNodes == nil) {
        return;
    }
    [itemNodes release];
    itemNodes = [[doc nodesForXPath:@"//Feed" error:&error] retain];
    if (itemNodes) {
        for (NSXMLElement* element in itemNodes) {
            Bookmark* item = [[Bookmark alloc] initWithXmlElement:element];
            if (element == nil) {
                continue;
            }
            [feedsController addObject:item];
            [item release];
        }
        [feedsController rearrangeObjects];
        [self saveFeed];
        [reader handleFeedChange:nil];
        [itemNodes release];
        [rssTableView deselectAll:self];
    }
    itemNodes = [[doc nodesForXPath:@"//Bookmark" error:&error] retain];
    if (itemNodes) {
        for (NSXMLElement* element in itemNodes) {
            Bookmark* item = [[Bookmark alloc] initWithXmlElement:element];
            if (element == nil) {
                continue;
            }
            [bookmarkController addObject:item];
            [item release];
        }
        [bookmarkController rearrangeObjects];
        [self saveBookmark];
        [itemNodes release];
        [bookmarkTableView deselectAll:self];
    }
}

- (void)exportXML:(NSXMLDocument*)doc
{
    NSXMLElement *root = [doc rootElement];
    if ([feeds count] > 0) {
        NSXMLElement* feedsRoot = [[NSXMLElement alloc] initWithName:@"Feeds"];
        [root addChild:feedsRoot];
        for (Bookmark *item in feeds) {
            NSXMLElement* feed = [[NSXMLElement alloc] initWithName:@"Feed"];
            if ([item buildXMLElement:feed] == -1) {
                [feed release];
                continue;
            }
            [feedsRoot addChild:feed];
            [feed release];
        }
        [feedsRoot release];
    }
    if ([bookmarks count] > 0) {
        NSXMLElement* bookmarksRoot = [[NSXMLElement alloc] initWithName:@"Bookmarks"];
        [root addChild:bookmarksRoot];
        for (Bookmark *item in bookmarks) {
            NSXMLElement* bookmark = [[NSXMLElement alloc] initWithName:@"Bookmark"];
            if ([item buildXMLElement:bookmark] == -1) {
                [bookmark release];
                continue;
            }
            [bookmarksRoot addChild:bookmark];
            [bookmark release];
        }
        [bookmarksRoot release];
    }
}

#pragma mark Localizer

- (void) localizeView
{
	// NSTableColumn *column = nil;
	NSString* lang = NSLocalizedString(@"LANG",LANG_EN_US);
	NSLog(@"localizeView: %@", lang);
	if ([lang isEqualToString:LANG_EN_US] == NO) {
        [menuAbout setTitle:NSLocalizedString(@"MEMU_ABOUT",@"About FlipFeed")];
        [menuPreference setTitle:NSLocalizedString(@"MENU_PREFERENCES",@"Preferences...")];
        [menuHide setTitle:NSLocalizedString(@"MENU_HIDE",@"Hide FlipFeed")];
        [menuHideOthers setTitle:NSLocalizedString(@"MENU_HIDE_OTHERS",@"Hide Others")];
        [menuShowAll setTitle:NSLocalizedString(@"MENU_SHOW_ALL",@"Show All")];
        [menuQuit setTitle:NSLocalizedString(@"MENU_QUIT",@"Quit FlipFeed")];
        [menuEdit setTitle:NSLocalizedString(@"MENU_EDIT",@"Edit")];
        [menuUndo setTitle:NSLocalizedString(@"MENU_UNDO",@"Undo")];
        [menuRedo setTitle:NSLocalizedString(@"MENU_REDO",@"Redo")];
        [menuCut setTitle:NSLocalizedString(@"MENU_CUT",@"Cut")];
        [menuCopy setTitle:NSLocalizedString(@"MENU_COPY",@"Copy")];
        [menuPaste setTitle:NSLocalizedString(@"MENU_PASTE",@"Paste")];
        [menuDelete setTitle:NSLocalizedString(@"MENU_DELETE",@"Delete")];
        [menuSpeech setTitle:NSLocalizedString(@"MENU_SPEECH",@"Speech Article")];
        [menuControls setTitle:NSLocalizedString(@"MENU_CONTROLS",@"Controls")];
        [menuAutoPilot setTitle:NSLocalizedString(@"MENU_AUTOPILOT",@"Autp Pilot")];
        [menuBrowser setTitle:NSLocalizedString(@"MENU_BROWSER",@"Browser")];
        [menuGoForward setTitle:NSLocalizedString(@"MENU_GO_FORWARD",@"Go Forward")];
        [menuGoForwardWeb setTitle:NSLocalizedString(@"MENU_GO_FORWARD",@"Go Forward")];
        [menuGoBack setTitle:NSLocalizedString(@"MENU_GO_BACK",@"Go Back")];
        [menuGoBackWeb setTitle:NSLocalizedString(@"MENU_GO_BACK",@"Go Back")];
        [menuReloadWeb setTitle:NSLocalizedString(@"MENU_RELOAD",@"Reload")];
        [menuSkip setTitle:NSLocalizedString(@"MENU_SKIP",@"Skip")];
        [menuStop setTitle:NSLocalizedString(@"MENU_STOP",@"Stop")];
        [menuStopWeb setTitle:NSLocalizedString(@"MENU_STOP",@"Stop")];
        [menuScroll setTitle:NSLocalizedString(@"MENU_SCROLL",@"Page Scroll")];
        [menuPageDown setTitle:NSLocalizedString(@"MENU_PAGE_DOWN",@"Page Down")];
        [menuPageUp setTitle:NSLocalizedString(@"MENU_PAGE_UP",@"Page Up")];
        [menuLineDown setTitle:NSLocalizedString(@"MENU_LINE_DOWN",@"Line Down")];
        [menuLineUp setTitle:NSLocalizedString(@"MENU_LINE_UP",@"Line Up")];
        [menuPageEnd setTitle:NSLocalizedString(@"MENU_PAGE_END",@"Page End")];
        [menuPageTop setTitle:NSLocalizedString(@"MENU_PAGE_TOP",@"Page Top")];
        [menuPageDown setTitle:NSLocalizedString(@"MENU_PAGE_DOWN",@"Page Down")];
        [menuPageUp setTitle:NSLocalizedString(@"MENU_PAGE_UP",@"Page Up")];
        [menuStandardSize setTitle:NSLocalizedString(@"MENU_STANDARD",@"Standerd Size")];
        [menuLager setTitle:NSLocalizedString(@"MENU_LARGER",@"Larger")];
        [menuSmaller setTitle:NSLocalizedString(@"MENU_SMALLER",@"Smaller")];
        [menuOpenSafati setTitle:NSLocalizedString(@"MENU_OPEN_SAFARI",@"Open Safari")];
        [menuLoadRss setTitle:NSLocalizedString(@"MENU_LOAD_RSS",@"Load RSS")];
        [menuLoadAllRSS setTitle:NSLocalizedString(@"MENU_LOAD_ALL_RSS",@"Load All RSS")];
        [menuFeedsAndBookmarks setTitle:NSLocalizedString(@"MENU_FEEDS_AND_BOOKMARKS",@"Feeds and Bookmarks")];
        [menuExport setTitle:NSLocalizedString(@"MENU_EXPORT",@"Export")];
        [menuImport setTitle:NSLocalizedString(@"MENU_IMPORT",@"Import")];
        [menuInitialize setTitle:NSLocalizedString(@"MENU_INITIALIZE",@"Initialize")];
        [menuWindow setTitle:NSLocalizedString(@"MENU_WINDOW",@"Window")];
        [menuMinimize setTitle:NSLocalizedString(@"MENU_MINIMIZE",@"Minimize")];
        [menuZoom setTitle:NSLocalizedString(@"MENU_ZOOM",@"Zoom")];
        [menuBringFront setTitle:NSLocalizedString(@"MENU_BRING_FRONT",@"Bring All to Front")];
        [menuShowWindow setTitle:NSLocalizedString(@"MENU_SHOW_WINDOW",@"Show Window")];
        [menuShowReader setTitle:NSLocalizedString(@"MENU_SHOW_READER",@"Show Reader")];
        [attrTitleLabel setStringValue:NSLocalizedString(@"LABEL_TITLE",@"TITLE:")];
        [attrVoiceLabel setStringValue:NSLocalizedString(@"LABEL_VOICE",@"VOICE:")];
    }
}

@synthesize     bookmarks;
@synthesize     feeds;
@synthesize     rssItems;
@synthesize     is_loading;
@synthesize     webView;
@synthesize     backgroundWebView;
@synthesize     speechSynth;
@synthesize     reader;
@synthesize     autoStartup;
@synthesize     enableSound;
@synthesize     enableRedirect;
@synthesize     orderFront;
@synthesize     crawling;
@synthesize     crawlingPaused;
@synthesize     scrollPage;
@synthesize     autopilotCount;
@synthesize     crawlingIndex;
@synthesize     crawlingTimerCmd;
@synthesize     scrollWidth;
@synthesize     scrollTimes;
@synthesize     scrollSpeed;
@synthesize     urlRequestTimer;
@synthesize     forwardFeedButton;
@synthesize     backFeedButton;
@synthesize     skipFeedButton;
@synthesize     modeButton;
@synthesize     articleTableView;
@synthesize     menuGoForward;
@synthesize     menuGoBack;
@synthesize     menuStop;
@synthesize     urlText;
@synthesize     window;

@end
