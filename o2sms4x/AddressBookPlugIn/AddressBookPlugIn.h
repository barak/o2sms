#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <AddressBook/AddressBook.h>

enum {
	kDaysInWeek = 7,
	kSecondsInDay = 86400
};

@interface AddressBookPlugIn : NSObject {
}

- (NSArray *) peopleWithMobiles2;

// JavaScript-ready methods
- (NSArray *) web_peopleWithMobiles;

// converts Cocoa results to JavaScript-readable results
- (NSArray *) stringResultsForPeople:(NSArray *) people;

@end

