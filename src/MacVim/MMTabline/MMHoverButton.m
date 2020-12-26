#import "MMHoverButton.h"

@implementation MMHoverButton
{
    NSTrackingArea *_trackingArea;
    NSBox *_circle;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.buttonType = NSButtonTypeMomentaryChange;
        self.bordered = NO;
        self.imagePosition = NSImageOnly;
        
        // This view will fade in/out when hovered.
        _circle = [NSBox new];
        _circle.boxType = NSBoxCustom;
        _circle.borderWidth = 0;
        _circle.alphaValue = 0.16;
        _circle.fillColor = NSColor.clearColor;
        _circle.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _circle.frame = self.bounds;
        [self addSubview:_circle positioned:NSWindowBelow relativeTo:nil];
    }
    return self;
}

- (void)setFgColor:(NSColor *)color
{
    _fgColor = color;
    self.image = super.image;
}

- (void)setImage:(NSImage *)image
{
    _circle.cornerRadius = image.size.width / 2.0;
    NSColor *fillColor = self.fgColor ?: NSColor.controlTextColor;
    super.image = [NSImage imageWithSize:image.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [image drawInRect:dstRect];
        [fillColor set];
        NSRectFillUsingOperation(dstRect, NSCompositingOperationSourceAtop);
        return YES;
    }];
    self.alternateImage = [NSImage imageWithSize:image.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [[fillColor colorWithAlphaComponent:0.2] set];
        [[NSBezierPath bezierPathWithOvalInRect:dstRect] fill];
        [super.image drawInRect:dstRect];
        return YES;
    }];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self evaluateHover];
}

- (void)updateTrackingAreas
{
    [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
    [self evaluateHover];
    [super updateTrackingAreas];
}

- (void)evaluateHover
{
    NSPoint mouseLocation = [self.window mouseLocationOutsideOfEventStream];
    mouseLocation = [self convertPoint:mouseLocation fromView:nil];
    if (NSPointInRect(mouseLocation, self.bounds)) {
        if (self.enabled) _circle.animator.fillColor = self.fgColor ?: NSColor.controlTextColor;
        else _circle.animator.fillColor = NSColor.clearColor;
    } else {
        _circle.animator.fillColor = NSColor.clearColor;
    }
}

- (void)mouseEntered:(NSEvent *)event
{
    if (self.enabled) _circle.animator.fillColor = self.fgColor ?: NSColor.controlTextColor;
}

- (void)mouseExited:(NSEvent *)event
{
    _circle.animator.fillColor = NSColor.clearColor;
}

@end
