#import <Cocoa/Cocoa.h>

// A tab with a close button and title.

typedef enum : NSUInteger {
    MMTabStateSelected,
    MMTabStateUnselected,
    MMTabStateUnselectedHover,
} MMTabState;

@class MMTabline;

@interface MMTab : NSView

@property (nonatomic, copy) NSString *title;
@property (nonatomic, getter=isCloseButtonHidden) BOOL closeButtonHidden;
@property (nonatomic) MMTabState state;

- (instancetype)initWithFrame:(NSRect)frameRect tabline:(MMTabline *)tabline;

@end
