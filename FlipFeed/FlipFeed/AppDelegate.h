//
//  AppDelegate.h
//  GhostReader
//
//  Created by Takahiro Sayama on 2013/01/01.
//  Copyright (c) 2013年 tanuki-project. All rights reserved.
//

#import     <Cocoa/Cocoa.h>
#import		<WebKit/WebKit.h>
#import     "Bookmark.h"
#import     "rssItem.h"
#import     "RssReader.h"

@class  RssReader;

#define	CRAWLING_TIMER_CMD_CNT			0
#define	CRAWLING_TIMER_CMD_CANCEL		1
#define	CRAWLING_TIMER_CMD_SCROLL		2
#define	CRAWLING_TIMER_CMD_SKIP         3

#define DEFAULT_URL_REQUEST_TIMER       20.0
#define AUTOSCROLL_PAUSE_TIMER          0.50
#define DEFAULT_AUTOPILOT_COUNT         0
#define DEFAULT_AUTOPILOT_COUNT_WIDTH   25
#define DEFAULT_SPEECH_RATE             180.0
#define MAX_SPEECH_RATE                 320.0
#define MIN_SPEECH_RATE                 120.0

#define ATTR_TYPE_CREATE_BOOKMARK       1
#define ATTR_TYPE_CREATE_FEED           2
#define ATTR_TYPE_EDIT_BOOKMARK         3
#define ATTR_TYPE_EDIT_FEED             4

#define LIMIT_FEEDS_FOR_LITE_VER        10
#define LIMIT_BOOKMARKS_FOR_LITE_VER    20

#define LANG_DE_DE          @"de_DE"
#define LANG_EN_US          @"en_US"
#define LANG_ES_ES          @"es_ES"
#define LANG_FR_FR          @"fr_FR"
#define LANG_IT_IT          @"it_IT"
#define LANG_JA_JP          @"ja_JP"
#define LANG_PT_PT          @"pt_PT"

@interface AppDelegate : NSObject <NSApplicationDelegate,NSSpeechSynthesizerDelegate> {
    NSMutableArray                  *bookmarks;
    NSMutableArray                  *feeds;
    NSMutableArray                  *rssItems;
    BOOL                            is_loading;
    BOOL                            crawling;
	BOOL                            crawlingPaused;
    BOOL                            forward;
    BOOL                            scrollPage;
    BOOL                            orderFront;
    BOOL                            autoStartup;
    BOOL                            enableSound;
    BOOL                            enableRedirect;
    Bookmark                        *target;
    Bookmark                        *editing;
    RssReader                       *reader;
    NSInteger                       autopilotCount;
	NSInteger                       crawlingIndex;
	NSInteger                       crawlingDst;
	NSTimer*                        crawlingTimer;
	NSInteger                       crawlingTimerCmd;
	NSTimer*                        scrollTimer;
    NSInteger                       scrollWidth;
    NSInteger                       scrollTimes;
    NSInteger                       attrType;
    float                           scrollSpeed;
    float                           speechRate;
    float                           urlRequestTimer;
    NSString                        *reservedUrl;
	NSTimer*                        reserveTimer;
    NSSpeechSynthesizer             *speechSynth;
    NSString                        *defaultVoice;
    NSArray                         *voiceList;
    IBOutlet NSTextField            *urlText;
    IBOutlet NSTextField            *titleText;
    IBOutlet WebView                *webView;
    IBOutlet WebView                *backgroundWebView;
    IBOutlet NSProgressIndicator    *webProgress;
    IBOutlet NSButton               *webProgressBg;
	IBOutlet NSButton				*goForward;
	IBOutlet NSButton				*goBack;
    IBOutlet NSTabView              *tabView;
    IBOutlet NSTableView            *bookmarkTableView;
    IBOutlet NSTableView            *rssTableView;
    IBOutlet NSTableView            *articleTableView;
    IBOutlet NSArrayController      *bookmarkController;
    IBOutlet NSArrayController      *feedsController;
    IBOutlet NSArrayController      *articleController;
    IBOutlet NSButton               *addBookmarkButton;
    IBOutlet NSButton               *deleteBookmarkButton;
    IBOutlet NSButton               *forwardBookmarkButton;
    IBOutlet NSButton               *backBookmarkButton;
    IBOutlet NSButton               *skipBookmarkButton;
    IBOutlet NSStepper              *bookmarkStepper;
    IBOutlet NSButton               *addFeedButton;
    IBOutlet NSButton               *deleteFeedButton;
    IBOutlet NSButton               *forwardFeedButton;
    IBOutlet NSButton               *backFeedButton;
    IBOutlet NSButton               *skipFeedButton;
    IBOutlet NSStepper              *feedStepper;
    IBOutlet NSButton               *rssButton;
    IBOutlet NSButton               *webButton;
    IBOutlet NSWindow               *attrSheet;
    IBOutlet NSButton               *modeButton;
    IBOutlet NSTextField            *modeText;
    IBOutlet NSTextField            *attrSheetTitle;
    IBOutlet NSTextField            *attrTitleField;
    IBOutlet NSTextField            *attrTitleLabel;
    IBOutlet NSTextField            *atteAutoScrollTitle;
    IBOutlet NSTextField            *attrUrlField;
    IBOutlet NSComboBoxCell         *attrVoiceComboBox;
    IBOutlet NSTextField            *attrStartPositionField;
    IBOutlet NSTextField            *attrVoiceLabel;
    IBOutlet NSTextField            *attrScrollWidthField;
    IBOutlet NSTextField            *attrScrollIntervalField;
    IBOutlet NSTextField            *attrScrollTimesField;
    IBOutlet NSTextField            *attrFilterField;
    IBOutlet NSStepper              *attrStartPositionStepper;
    IBOutlet NSStepper              *attrScrollWidthStepper;
    IBOutlet NSStepper              *attrScrollIntervalStepper;
    IBOutlet NSStepper              *attrScrollTimesStepper;
    IBOutlet NSTextField            *attrStartPositionLabel;
    IBOutlet NSTextField            *attrScrollWidthLabel;
    IBOutlet NSTextField            *attrScrollIntervalLabel;
    IBOutlet NSTextField            *attrScrollTimesLabel;
    IBOutlet NSTextField            *attrFilterLabel;
    IBOutlet NSButton               *attrDisableJavaScript;
    IBOutlet NSTextField            *attrFilterComment;
    IBOutlet NSButton               *attrApplyButton;
    IBOutlet NSButton               *attrCancelButton;
    IBOutlet NSWindow               *preferenceSheet;
    IBOutlet NSTextField            *preferenceHomeUrlField;
    IBOutlet NSTextField            *preferenceRequestTimerField;
    IBOutlet NSStepper              *preferenceRequestTimerStepper;
    IBOutlet NSButton               *preferenceAutoStart;
    IBOutlet NSButton               *preferenceOrderFront;
    IBOutlet NSButton               *preferenceEnableJavaScript;
    IBOutlet NSButton               *preferenceEnableSound;
    IBOutlet NSButton               *preferenceEnableSpeech;
    IBOutlet NSButton               *preferenceEnableRedirect;
    IBOutlet NSSlider               *preferenceScrollSpeed;
    IBOutlet NSSlider               *preferenceSpeechRate;
    IBOutlet NSTextField            *preferenceScrollSpeedLabel;
    IBOutlet NSTextField            *preferenceSpeechRateLabel;
    IBOutlet NSTextField            *preferenceHomeUrlLabel;
    IBOutlet NSSegmentedControl     *preferenceSegmentCount;
    IBOutlet NSTextField            *preferenceCountLabel;
    IBOutlet NSTextField            *preferenceRequestTimerLabel;
    IBOutlet NSButton               *preferenceApplyButton;
    IBOutlet NSButton               *preferenceCancelButton;
    IBOutlet NSWindow               *window;
    IBOutlet NSMenuItem             *menuAbout;
    IBOutlet NSMenuItem             *menuPreference;
    IBOutlet NSMenuItem             *menuHide;
    IBOutlet NSMenuItem             *menuHideOthers;
    IBOutlet NSMenuItem             *menuShowAll;
    IBOutlet NSMenuItem             *menuQuit;
    IBOutlet NSMenu                 *menuEdit;
    IBOutlet NSMenuItem             *menuUndo;
    IBOutlet NSMenuItem             *menuRedo;
    IBOutlet NSMenuItem             *menuCut;
    IBOutlet NSMenuItem             *menuCopy;
    IBOutlet NSMenuItem             *menuPaste;
    IBOutlet NSMenuItem             *menuDelete;
    IBOutlet NSMenuItem             *menuSpeech;
    IBOutlet NSMenu                 *menuControls;
    IBOutlet NSMenuItem             *menuAutoPilot;
    IBOutlet NSMenuItem             *menuGoForward;
    IBOutlet NSMenuItem             *menuGoBack;
    IBOutlet NSMenuItem             *menuSkip;
    IBOutlet NSMenuItem             *menuStop;
    IBOutlet NSMenuItem             *menuBrowser;
    IBOutlet NSMenuItem             *menuGoForwardWeb;
    IBOutlet NSMenuItem             *menuGoBackWeb;
    IBOutlet NSMenuItem             *menuStopWeb;
    IBOutlet NSMenuItem             *menuReloadWeb;
    IBOutlet NSMenuItem             *menuScroll;
    IBOutlet NSMenuItem             *menuPageDown;
    IBOutlet NSMenuItem             *menuPageUp;
    IBOutlet NSMenuItem             *menuPageTop;
    IBOutlet NSMenuItem             *menuPageEnd;
    IBOutlet NSMenuItem             *menuLineDown;
    IBOutlet NSMenuItem             *menuLineUp;
    IBOutlet NSMenuItem             *menuStandardSize;
    IBOutlet NSMenuItem             *menuLager;
    IBOutlet NSMenuItem             *menuSmaller;
    IBOutlet NSMenuItem             *menuOpenSafati;
    IBOutlet NSMenuItem             *menuLoadRss;
    IBOutlet NSMenuItem             *menuLoadAllRSS;
    IBOutlet NSMenuItem             *menuFeedsAndBookmarks;
    IBOutlet NSMenuItem             *menuImport;
    IBOutlet NSMenuItem             *menuExport;
    IBOutlet NSMenuItem             *menuInitialize;
    IBOutlet NSMenu                 *menuWindow;
    IBOutlet NSMenuItem             *menuMinimize;
    IBOutlet NSMenuItem             *menuZoom;
    IBOutlet NSMenuItem             *menuBringFront;
    IBOutlet NSMenuItem             *menuShowWindow;
    IBOutlet NSMenuItem             *menuShowReader;
    NSButtonCell *openSafari;
}

- (IBAction)showWindow:(id)sender;
- (IBAction)takeStringUrl:(id)sender;
- (IBAction)createBookmark:(id)sender;
- (IBAction)removeBookmark:(id)sender;
- (IBAction)editBookmark:(id)sender;
- (IBAction)moveBookmark:(id)sender;
- (IBAction)openBookmark:(id)sender;
- (IBAction)crawlingBookmark:(id)sender;
- (IBAction)skipBookmark:(id)sender;
- (IBAction)createFeed:(id)sender;
- (IBAction)removeFeed:(id)sender;
- (IBAction)editFeed:(id)sender;
- (IBAction)moveFeed:(id)sender;
- (IBAction)openFeed:(id)sender;
- (IBAction)openAllFeed:(id)sender;
- (IBAction)openArticle:(id)sender;
- (IBAction)forwardFeed:(id)sender;
- (IBAction)backFeed:(id)sender;
- (IBAction)skipFeed:(id)sender;
- (IBAction)openSafari:(id)sender;
- (IBAction)showAttrSheet:(id)sender;
- (IBAction)endAttrSheet:(id)sender;
- (IBAction)cancelAttrSheet:(id)sender;
- (IBAction)resetAttrValue:(id)sender;
- (IBAction)changeAttrValue:(id)sender;
- (IBAction)showPreferenceSheet:(id)sender;
- (IBAction)endPreferenceSheet:(id)sender;
- (IBAction)cancelPreferenceSheet:(id)sender;
- (IBAction)chengePreferenceValue:(id)sender;
- (IBAction)changeBookmark:(id)sender;
- (IBAction)changeFeed:(id)sender;
- (IBAction)showReader:(id)sender;
- (IBAction)modifyArticle:(id)sender;
- (IBAction)goForwardAutoPilot:(id)sender;
- (IBAction)goBackAutoPilot:(id)sender;
- (IBAction)skipAutoPilot:(id)sender;
- (IBAction)stopAutoPilot:(id)sender;
- (IBAction)pageDown:(id)sender;
- (IBAction)pageUp:(id)sender;
- (IBAction)pageTop:(id)sender;
- (IBAction)pageEnd:(id)sender;
- (IBAction)lineDown:(id)sender;
- (IBAction)lineUp:(id)sender;
- (IBAction)exportFeeds:(id)sender;
- (IBAction)importFeeds:(id)sender;
- (IBAction)initializeFeedsAndBookmarks:(id)sender;
- (IBAction)speechArticle:(id)sender;
- (IBAction)changeMode:(id)sender;

- (void)buildVoiceList;
- (void)setVoice:(Bookmark*)bookmark;
- (void)startSpeech:(NSString*)text :(NSString*)voice;
- (void)stopSpeech;
- (void)speechArticle;
- (void)loadUrl:(NSString*)urlString;
- (void)setJavaScriptEnabeled:(bool)enable;
- (void)reserveLoadUrl:(NSString*)urlString;
- (void)preLoadUrl:(NSString*)urlString;
- (void)loadCashedUrl;
- (void)enableUrlRequest:(bool)isEnable;
- (void)startCrawling:(NSInteger)indexFrom :(NSInteger)indexTo;
- (void)stopCrawling:(bool)warn;
- (void)startTimerCrawling:(int)cmd;
- (void)stopTimerCrawling;
- (void)checkTimerCrawling:(NSTimer*)timer;
- (void)startTimerScroll:(float)timer;
- (void)stopTimerScroll;
- (void)checkTimerScroll:(NSTimer*)timer;
- (void)rearrangeArticle;
- (void)rearrangeFeeds;
- (void)setArticleIndex:(NSInteger)index;
- (void)setBookmarkIndex:(NSInteger)index;
- (void)loadBookmark;
- (void)saveBookmark;
- (void)loadFeed;
- (void)saveFeed;
- (void)importXML:(NSXMLDocument*)doc;
- (void)exportXML:(NSXMLDocument*)doc;

@property   (readwrite,retain)  NSMutableArray      *bookmarks;
@property   (readwrite,retain)  NSMutableArray      *feeds;
@property   (readwrite,retain)  NSMutableArray      *rssItems;
@property	(readwrite)         BOOL                is_loading;
@property	(readwrite,retain)	WebView             *webView;
@property	(readwrite,retain)	WebView             *backgroundWebView;
@property	(readwrite,retain)	NSSpeechSynthesizer *speechSynth;
@property	(assign)            RssReader           *reader;
@property	(readwrite)         BOOL                autoStartup;
@property	(readwrite)         BOOL                enableSound;
@property	(readwrite)         BOOL                enableRedirect;
@property	(readwrite)         BOOL                orderFront;
@property	(readwrite)         BOOL                crawling;
@property	(readwrite)         BOOL                crawlingPaused;
@property	(readwrite)         BOOL                scrollPage;
@property	(readwrite)         NSInteger           autopilotCount;
@property	(readwrite)         NSInteger           crawlingIndex;
@property	(readwrite)         NSInteger           crawlingTimerCmd;
@property	(readwrite)         NSInteger           scrollWidth;
@property	(readwrite)         NSInteger           scrollTimes;
@property	(readwrite)         float               scrollSpeed;
@property	(readwrite)         float               urlRequestTimer;
@property   (assign)            NSButton            *forwardFeedButton;
@property   (assign)            NSButton            *backFeedButton;
@property   (assign)            NSButton            *skipFeedButton;
@property   (assign)            NSButton            *modeButton;
@property   (assign)            NSMenuItem          *menuGoForward;
@property   (assign)            NSMenuItem          *menuGoBack;
@property   (assign)            NSMenuItem          *menuStop;
@property   (assign)            NSTableView         *articleTableView;
@property   (assign)            NSTextField         *urlText;
@property   (assign)            NSWindow            *window;

@end
