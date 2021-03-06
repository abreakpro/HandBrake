/**
 * @file
 * Implementation of class HBPreferencesController.
 */

#import "HBPreferencesController.h"

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_ADVANCED    @"TOOLBAR_ADVANCED"

/**
 * This class controls the preferences window of HandBrake. Default values for
 * all preferences and user defaults are specified in class method
 * @c registerUserDefaults. The preferences window is loaded from
 * Preferences.nib file when HBPreferencesController is initialized.
 *
 * All preferences are bound to user defaults in Interface Builder, therefore
 * no getter/setter code is needed in this file (unless more complicated
 * preference settings are added that cannot be handled with Cocoa bindings).
 */

@interface HBPreferencesController () <NSTokenFieldDelegate>
{
    IBOutlet NSView         * fGeneralView, * fAdvancedView;
    IBOutlet NSTextField    * fSendEncodeToAppField;
}

/* Manage the send encode to xxx.app windows and field */
- (IBAction) browseSendToApp: (id) sender;

- (void) setPrefView: (id) sender;
- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image;

@property (unsafe_unretained) IBOutlet NSTokenField *formatTokenField;
@property (unsafe_unretained) IBOutlet NSTokenField *builtInTokenField;
@property (nonatomic, readonly, strong) NSArray *buildInFormatTokens;
@property (nonatomic, strong) NSArray *matches;

@end

@implementation HBPreferencesController

/**
 * +[HBPreferencesController registerUserDefaults]
 *
 * Registers default values to user defaults. This is called immediately
 * when HandBrake starts, from [HBController init].
 */
+ (void)registerUserDefaults
{
    NSString *desktopDirectory = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
    NSURL *desktopURL = [NSURL fileURLWithPath:desktopDirectory isDirectory:YES];

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"HBShowOpenPanelAtLaunch":         @YES,
        @"DefaultMpegExtension":            @"Auto",
        @"UseDvdNav":                       @"YES",
        // Archive the URL because they aren't supported in plist.
        @"HBLastDestinationDirectory":      [NSKeyedArchiver archivedDataWithRootObject:desktopURL],
        @"HBLastSourceDirectory":           [NSKeyedArchiver archivedDataWithRootObject:desktopURL],
        @"DefaultAutoNaming":               @NO,
        @"HBAlertWhenDone":                 @(HBDoneActionNotification),
        @"HBResetWhenDoneOnLaunch":         @NO,
        @"HBAlertWhenDoneSound":            @YES,
        @"LoggingLevel":                    @"1",
        @"HBClearOldLogs":                  @YES,
        @"EncodeLogLocation":               @"NO",
        @"MinTitleScanSeconds":             @"10",
        @"PreviewsNumber":                  @"10",
        @"HBx264CqSliderFractional":        @2,
        @"HBShowAdvancedTab":               @NO,
        @"HBAutoNamingFormat":              @[@"{Source}", @" ", @"{Title}"],
        @"HBQueuePauseIfLowSpace":          @YES,
        @"HBQueueMinFreeSpace":             @"2"
        }];

    // Overwrite the update check interval because previous versions
    // could be set to a dayly check.
    NSUInteger week = 60 * 60 * 24 * 7;
    [[NSUserDefaults standardUserDefaults] setObject:@(week) forKey:@"SUScheduledCheckInterval"];
}

/**
 * -[HBPreferencesController init]
 *
 * Initializes the preferences controller by loading Preferences.nib file.
 *
 */
- (instancetype)init
{
    self = [super initWithWindowNibName:@"Preferences"];
    return self;
}

- (void)showWindow:(id)sender
{
    if (!self.window.isVisible)
    {
        [self.window center];
    }

    [super showWindow:sender];
}

/**
 *
 * Called after all the outlets in the nib file have been attached. Sets up the
 * toolbar and shows the "General" pane.
 *
 */
- (void)windowDidLoad
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: @"Preferences Toolbar"];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [toolbar setSizeMode: NSToolbarSizeModeRegular];
    [[self window] setToolbar: toolbar];

    // Format token field initialization
    [self.formatTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"%%"]];
    [self.formatTokenField setCompletionDelay:0.2];

    _buildInFormatTokens = @[@"{Source}", @"{Title}", @"{Date}", @"{Time}", @"{Creation-Date}", @"{Creation-Time}", @"{Chapters}", @"{Quality/Bitrate}"];
    [self.builtInTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"%%"]];
    [self.builtInTokenField setStringValue:[self.buildInFormatTokens componentsJoinedByString:@"%%"]];

    [toolbar setSelectedItemIdentifier: TOOLBAR_GENERAL];
    [self setPrefView:nil];
}

- (NSToolbarItem *)toolbar: (NSToolbar *)toolbar
     itemForItemIdentifier: (NSString *)ident
 willBeInsertedIntoToolbar: (BOOL)flag
{
    if ( [ident isEqualToString:TOOLBAR_GENERAL] )
    {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"General", @"Preferences General Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
    }
    else if ( [ident isEqualToString:TOOLBAR_ADVANCED] )
    {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Advanced", @"Preferences Advanced Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNameAdvanced]];
    }

    return nil;
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarDefaultItemIdentifiers: toolbar];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarAllowedItemIdentifiers: toolbar];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return @[TOOLBAR_GENERAL, TOOLBAR_ADVANCED];
}

/* Manage the send encode to xxx.app windows and field */
/*Opens the app browse window*/
- (IBAction) browseSendToApp: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowedFileTypes:@[@"app"]];
    [panel setMessage:NSLocalizedString(@"Select the desired external application", @"Preferences -> send to app destination open panel")];

    NSString *sendToAppDirectory;
	if ([[NSUserDefaults standardUserDefaults] stringForKey:@"LastSendToAppDirectory"])
	{
		sendToAppDirectory = [[NSUserDefaults standardUserDefaults] stringForKey:@"LastSendToAppDirectory"];
	}
	else
	{
		sendToAppDirectory = @"/Applications";
	}
    [panel setDirectoryURL:[NSURL fileURLWithPath:sendToAppDirectory]];

    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK)
        {
            NSURL *sendToAppURL = [panel URL];
            NSURL *sendToAppDirectoryURL = [sendToAppURL URLByDeletingLastPathComponent];
            [[NSUserDefaults standardUserDefaults] setObject:[sendToAppDirectoryURL path] forKey:@"LastSendToAppDirectory"];

            // We set the name of the app to send to in the display field
            NSString *sendToAppName = [[sendToAppURL lastPathComponent] stringByDeletingPathExtension];
            [self->fSendEncodeToAppField setStringValue:sendToAppName];

            [[NSUserDefaults standardUserDefaults] setObject:self->fSendEncodeToAppField.stringValue forKey:@"HBSendToApp"];
        }
    }];
}

#pragma mark - Format Token Field Delegate

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0 && [representedObject length] > 1)
    {
        return [self localizedStringForToken:representedObject];
    }

    return representedObject;
}

- (NSString *)localizedStringForToken:(NSString *)tokenString
{
    if ([tokenString isEqualToString:@"{Source}"])
    {
        return NSLocalizedString(@"Source", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Title}"])
    {
        return NSLocalizedString(@"Title", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Date}"])
    {
        return NSLocalizedString(@"Date", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Time}"])
    {
        return NSLocalizedString(@"Time", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Creation-Date}"])
    {
        return NSLocalizedString(@"Creation-Date", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Creation-Time}"])
    {
        return NSLocalizedString(@"Creation-Time", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Chapters}"])
    {
        return NSLocalizedString(@"Chapters", "Preferences -> Output Name Token");
    }
    else if ([tokenString isEqualToString:@"{Quality/Bitrate}"])
    {
        return NSLocalizedString(@"Quality/Bitrate", "Preferences -> Output Name Token");
    }

    return tokenString;
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0)
    {
        return NSTokenStyleRounded;
    }
    else
    {
        return NSTokenStyleNone;
    }
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
    return editingString;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex
    indexOfSelectedItem:(NSInteger *)selectedIndex
{
    self.matches = [self.buildInFormatTokens filteredArrayUsingPredicate:
                    [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", substring]];
    return self.matches;
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject
{
    if ([representedObject rangeOfString: @"{"].location == 0)
    {
        return [NSString stringWithFormat:@"%%%@%%", representedObject];
    }
    else
    {
        return representedObject;
    }
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    return tokens;
}

- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard
{
    NSString *format = [objects componentsJoinedByString:@"%%"];
    [pboard setString:format forType:NSPasteboardTypeString];

    return YES;
}


#pragma mark - Private methods

- (void) setPrefView: (id) sender
{
    NSView *view = fGeneralView;
    if (sender)
    {
        NSString *identifier = [sender itemIdentifier];
        if([identifier isEqualToString:TOOLBAR_ADVANCED])
        {
            view = fAdvancedView;
        }
    }

    NSWindow *window =  self.window;
    if (window.contentView == view)
    {
        return;
    }

    window.contentView = view;

    if (window.isVisible)
    {
            view.hidden = YES;

            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.allowsImplicitAnimation = YES;
                [window layoutIfNeeded];

            } completionHandler:^{
                view.hidden = NO;
            }];
    }

    // set title label
    if (sender)
    {
        window.title = [sender label];
    }
    else
    {
        NSToolbar *toolbar = window.toolbar;
        NSString *itemIdentifier = toolbar.selectedItemIdentifier;
        for (NSToolbarItem *item in toolbar.items)
        {
            if ([item.itemIdentifier isEqualToString:itemIdentifier])
            {
                window.title = item.label;
                break;
            }
        }
    }
}

/**
 * -[HBPreferencesController(Private) toolbarItemWithIdentifier:label:image:]
 *
 * Shared code for creating the NSToolbarItems for the Preferences toolbar.
 *
 */
- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    [item setLabel:label];
    [item setImage:image];
    [item setAction:@selector(setPrefView:)];
    [item setAutovalidates:NO];
    return item;
}

@end
