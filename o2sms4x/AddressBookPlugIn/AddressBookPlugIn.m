
#import "AddressBookPlugIn.h"

@implementation AddressBookPlugIn

#pragma mark *** WidgetPlugin methods ***

// initWithWebView is called as the Dashboard widget and its WebView
// are initialized, which is when the widget plug-in is loaded
// This is just an object initializer; DO NOT use the passed WebView
// to manipulate WebScriptObjects or anything in the WebView's hierarchy
- (id) initWithWebView:(WebView*)webView {
    self = [super init];
    return self;
}

#pragma mark *** WebScripting methods ***

// windowScriptObjectAvailable passes the JavaScript window object referring
// to the plug-in's parent window (in this case, the Dashboard widget)
// We use that to register our plug-in as a var of the window object;
// This allows the plug-in to be referenced from JavaScript via 
// window.<plugInName>, or just <plugInName>
- (void) windowScriptObjectAvailable:(WebScriptObject*)webScriptObject {
    [webScriptObject setValue:self forKey:@"AddressBookPlugIn"];
}

// Prevent direct key access from JavaScript
// Write accessor methods and expose those if necessary
+ (BOOL) isKeyExcludedFromWebScript:(const char*)key {
	return YES;
}

// Used for convenience of WebScripting names below
NSString * const kWebSelectorPrefix = @"web_";

// This is where prefixing our JavaScript methods with web_ pays off:
// instead of a huge if/else trail to decide which methods to exclude,
// just check the selector names for kWebSelectorPrefix
+ (BOOL) isSelectorExcludedFromWebScript:(SEL)aSelector {
	return !([NSStringFromSelector(aSelector) hasPrefix:kWebSelectorPrefix]);
}

+ (NSString *) webScriptNameForSelector:(SEL)aSelector {
	NSString*	selName = NSStringFromSelector(aSelector);

	if ([selName hasPrefix:kWebSelectorPrefix] && ([selName length] > [kWebSelectorPrefix length])) {
		return [[[selName substringFromIndex:[kWebSelectorPrefix length]] componentsSeparatedByString: @":"] objectAtIndex: 0];
	}
	return nil;
}

- (NSArray *) web_peopleWithMobiles {
	return [self stringResultsForPeople:[self peopleWithMobiles2]];
}

- (NSArray *) peopleWithMobiles2 {
	return [[ABAddressBook sharedAddressBook] people];
}

#pragma mark *** Utility methods ***


// Condense useful info into string arrays for transmission across ObjC-JS bridge
- (NSArray *) stringResultsForPeople:(NSArray *) people {
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[people count]];
	ABPerson *currPerson = nil;
	NSEnumerator *peopleEnumerator = [people objectEnumerator];
	while (currPerson = [peopleEnumerator nextObject]) {
		NSString *firstName = [currPerson valueForProperty:kABFirstNameProperty];
		NSString *lastName = [currPerson valueForProperty:kABLastNameProperty];
		
		ABMutableMultiValue *aPhoneList = [[currPerson valueForProperty:kABPhoneProperty] mutableCopy];
		
		int hasMob = 0;
		NSString *aPhone = @"";
		
		for (int i = 0; i < [aPhoneList count]; i++)
		{
			NSString *label = [aPhoneList labelAtIndex:i];
			
			if ([label isEqualToString:kABPhoneMobileLabel])
			{
				hasMob = 1;
				aPhone = [aPhoneList valueAtIndex:i];
			}
		}
		
		if (hasMob == 0)
		{
			continue;
		}
		
		NSMutableArray *personDetails = [NSMutableArray arrayWithCapacity:2];
		[personDetails addObject:(firstName ? firstName : @"")];
		[personDetails addObject:(lastName ? lastName : @"")];
		[personDetails addObject:(aPhone ? aPhone : @"")];
		[personDetails addObject:[currPerson uniqueId]];
		[results addObject:personDetails];
	}
	
	return results;
}

@end