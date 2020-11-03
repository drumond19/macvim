#import <QuartzCore/QuartzCore.h>
#import "MMTab.h"
#import "MMTabline.h"
#import "MMHoverButton.h"

@interface MMTab ()
@property (nonatomic) NSColor *fillColor;
@end

@implementation MMTab
{
    MMTabline __weak *_tabline;
    MMHoverButton *_closeButton;
    NSTextField *_titleLabel;
    NSShadow *_shadow;
}

+ (id)defaultAnimationForKey:(NSAnimatablePropertyKey)key
{
    if ([key isEqualToString:@"fillColor"]) return [CABasicAnimation new];
    return [super defaultAnimationForKey:key];
}

- (instancetype)initWithFrame:(NSRect)frameRect tabline:(MMTabline *)tabline
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _tabline = tabline;
        
        _closeButton = [MMHoverButton new];
        _closeButton.image = [NSImage imageNamed:@"CloseTabButton"];
        _closeButton.target = self;
        _closeButton.action = @selector(closeTab:);
        _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_closeButton];

        _titleLabel = [NSTextField new];
        _titleLabel.stringValue = @"[No Name]";
        _titleLabel.font = [NSFont systemFontOfSize:11];
        _titleLabel.textColor = NSColor.controlTextColor;
        _titleLabel.editable = NO;
        _titleLabel.selectable = NO;
        _titleLabel.bordered = NO;
        _titleLabel.bezeled = NO;
        _titleLabel.drawsBackground = NO;
        _titleLabel.cell.lineBreakMode = NSLineBreakByTruncatingTail;
        // Title can be compressed smaller than its contents. See centerConstraint
        // below where priority is set less than here for compression resistance.
        // This breaks centering and allows label to fill all available space.
        [_titleLabel setContentCompressionResistancePriority:NSLayoutPriorityFittingSizeCompression+2 forOrientation:NSLayoutConstraintOrientationHorizontal];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_titleLabel];
        
        NSDictionary *viewDict = NSDictionaryOfVariableBindings(_closeButton, _titleLabel);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-7-[_closeButton]-(>=5)-[_titleLabel]-(>=8)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:viewDict]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_titleLabel attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        NSLayoutConstraint *centerConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_titleLabel attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
        centerConstraint.priority = NSLayoutPriorityFittingSizeCompression+1;
        [self addConstraint:centerConstraint];

        _shadow = [NSShadow new];
        _shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.4];
        _shadow.shadowBlurRadius = 2;
        
        self.state = MMTabStateUnselected;
    }
    return self;
}

- (void)closeTab:(id)sender
{
    [_tabline closeTab:self force:NO layoutImmediately:NO];
}

- (NSString *)title
{
    return _titleLabel.stringValue;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.stringValue = title;
}

- (void)setCloseButtonHidden:(BOOL)closeButtonHidden
{
    _closeButtonHidden = closeButtonHidden;
    _closeButton.hidden = closeButtonHidden;
}

- (void)setFillColor:(NSColor *)fillColor
{
    _fillColor = fillColor;
    self.needsDisplay = YES;
}

- (void)setState:(MMTabState)state
{
    // Transitions to and from MMTabStateSelected
    // DO NOT animate so that UX feels snappier.
    if (state == MMTabStateSelected) {
        _closeButton.alphaValue = 1;
        _titleLabel.textColor = _tabline.tablineSelFgColor ?: NSColor.controlTextColor;
        _titleLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        self.fillColor = _tabline.tablineSelBgColor ?: [NSColor colorNamed:@"TablineSel"];
        self.shadow = _shadow;
    }
    else if (state == MMTabStateUnselected) {
        if (_state == MMTabStateSelected) {
            _closeButton.alphaValue = 0;
            _titleLabel.textColor = _tabline.tablineFgColor ?: NSColor.disabledControlTextColor;
            self.fillColor = _tabline.tablineBgColor ?: [NSColor colorNamed:@"Tabline"];
        } else {
            _closeButton.animator.alphaValue = 0;
            _titleLabel.animator.textColor = _tabline.tablineFgColor ?: NSColor.disabledControlTextColor;
            self.animator.fillColor = _tabline.tablineBgColor ?: [NSColor colorNamed:@"Tabline"];
        }
        _titleLabel.font = [NSFont systemFontOfSize:11];
        self.shadow = nil;
    }
    else { // state == MMTabStateUnselectedHover
        _closeButton.animator.alphaValue = 1;
        _titleLabel.animator.textColor = _tabline.tablineSelFgColor ?: NSColor.controlTextColor;
        _titleLabel.font = [NSFont systemFontOfSize:11];
        self.animator.fillColor = self.unselectedHoverColor;
        self.animator.shadow = _shadow;
    }
    _closeButton.fgColor = _tabline.tablineSelFgColor;
    _state = state;
}

- (NSColor *)unselectedHoverColor
{   // stackoverflow.com/a/52516863/111418
    NSColor *tablineSelBgColor = _tabline.tablineSelBgColor ?: [NSColor colorNamed:@"TablineSel"];
    NSColor *tablineBgColor = _tabline.tablineBgColor ?: [NSColor colorNamed:@"Tabline"];
    NSColor *c;
    NSAppearance *currentAppearance = NSAppearance.currentAppearance;
    NSAppearance.currentAppearance = self.effectiveAppearance;
    c = [tablineSelBgColor blendedColorWithFraction:0.6 ofColor:tablineBgColor];
    NSAppearance.currentAppearance = currentAppearance;
    return c;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self.fillColor set];
    NSBezierPath *p = [NSBezierPath new];
    [p moveToPoint:NSZeroPoint];
    [p lineToPoint:NSMakePoint(3.6, NSMaxY(self.bounds) - 2.5)];
    [p curveToPoint:NSMakePoint(6.5, NSMaxY(self.bounds)) controlPoint1:NSMakePoint(3.8, NSMaxY(self.bounds) - 1) controlPoint2:NSMakePoint(5.1, NSMaxY(self.bounds))];
    [p lineToPoint:NSMakePoint(NSMaxX(self.bounds) - 6.5, NSMaxY(self.bounds))];
    [p curveToPoint:NSMakePoint(NSMaxX(self.bounds) - 3.6, NSMaxY(self.bounds) - 2.5) controlPoint1:NSMakePoint(NSMaxX(self.bounds) - 5.1, NSMaxY(self.bounds)) controlPoint2:NSMakePoint(NSMaxX(self.bounds) - 3.8, NSMaxY(self.bounds) - 1)];
    [p lineToPoint:NSMakePoint(NSMaxX(self.bounds), 0)];
    [p closePath];
    [p fill];
}

@end
