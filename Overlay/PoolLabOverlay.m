#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface PLPassWindow : UIWindow
@end

@interface PLGuideView : UIView
@property(nonatomic) CGPoint start;
@property(nonatomic) CGPoint aim;
@property(nonatomic) BOOL visibleLine;
@property(nonatomic) BOOL wallPreview;
@property(nonatomic) CGFloat extension;
@end

@implementation PLGuideView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.extension = 1.0;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    if (!self.visibleLine) return;
    CGFloat dx = self.aim.x - self.start.x, dy = self.aim.y - self.start.y;
    CGFloat l = hypot(dx, dy);
    if (l < 2) return;
    dx /= l; dy /= l;
    CGFloat rayLength = hypot(self.bounds.size.width, self.bounds.size.height) * self.extension;
    CGPoint end = CGPointMake(self.start.x + dx * rayLength, self.start.y + dy * rayLength);

    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);
    CGContextSetLineWidth(c, 2.5);
    CGContextSetStrokeColorWithColor(c, [UIColor colorWithRed:0.15 green:0.97 blue:0.95 alpha:0.92].CGColor);
    CGFloat dashes[] = {11, 7};
    CGContextSetLineDash(c, 0, dashes, 2);
    CGContextMoveToPoint(c, self.start.x, self.start.y);
    CGContextAddLineToPoint(c, end.x, end.y);
    CGContextStrokePath(c);

    if (self.wallPreview) {
        // Schematic reflection at a manually estimated rectangular play area.
        CGRect area = CGRectInset(self.bounds, 26, 28);
        CGFloat tx = INFINITY, ty = INFINITY;
        if (fabs(dx) > .0001) tx = (dx > 0 ? CGRectGetMaxX(area)-self.aim.x : CGRectGetMinX(area)-self.aim.x)/dx;
        if (fabs(dy) > .0001) ty = (dy > 0 ? CGRectGetMaxY(area)-self.aim.y : CGRectGetMinY(area)-self.aim.y)/dy;
        CGFloat t = fmin(tx > 0 ? tx : INFINITY, ty > 0 ? ty : INFINITY);
        if (isfinite(t)) {
            CGPoint wall = CGPointMake(self.aim.x+dx*t, self.aim.y+dy*t);
            if (tx < ty) dx = -dx; else dy = -dy;
            CGContextSetStrokeColorWithColor(c, [UIColor colorWithRed:1 green:.78 blue:.28 alpha:.85].CGColor);
            CGContextMoveToPoint(c, wall.x, wall.y);
            CGContextAddLineToPoint(c, wall.x+dx*150, wall.y+dy*150);
            CGContextStrokePath(c);
        }
    }
    CGContextRestoreGState(c);
}
@end

@interface PLOverlayController : UIViewController
@property(nonatomic,strong) PLGuideView *guide;
@property(nonatomic,strong) UIButton *menuButton;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIView *handleA;
@property(nonatomic,strong) UIView *handleB;
@property(nonatomic,strong) UISwitch *guideSwitch;
@property(nonatomic,strong) UISwitch *wallSwitch;
@property(nonatomic) CGPoint normalizedA;
@property(nonatomic) CGPoint normalizedB;
@property(nonatomic) BOOL panelOpened;
@end

@implementation PLOverlayController
- (UILabel *)label:(NSString*)text frame:(CGRect)frame size:(CGFloat)size {
    UILabel *label=[[UILabel alloc]initWithFrame:frame];
    label.text=text; label.textColor=UIColor.whiteColor;
    label.font=[UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    return label;
}
- (UISwitch *)addSwitch:(NSString*)text atY:(CGFloat)y action:(SEL)action initial:(BOOL)on {
    [self.panel addSubview:[self label:text frame:CGRectMake(15,y,195,31) size:13]];
    UISwitch *s=[[UISwitch alloc] initWithFrame:CGRectMake(216,y,47,31)];
    s.transform=CGAffineTransformMakeScale(.8,.8);
    s.onTintColor=[UIColor colorWithRed:.37 green:.84 blue:.89 alpha:1];
    s.on=on;
    [s addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:s]; return s;
}
- (UIView *)makeHandle:(NSString*)letter {
    UIView *v=[[UIView alloc]initWithFrame:CGRectMake(0,0,42,42)];
    v.backgroundColor=[UIColor colorWithRed:.16 green:.78 blue:.88 alpha:.77];
    v.layer.cornerRadius=21; v.layer.borderColor=UIColor.whiteColor.CGColor; v.layer.borderWidth=2;
    UILabel *t=[self label:letter frame:v.bounds size:15]; t.textAlignment=NSTextAlignmentCenter;
    [v addSubview:t]; t.userInteractionEnabled=NO;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panHandle:)];
    [v addGestureRecognizer:pan]; return v;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.clearColor;
    self.normalizedA=CGPointMake(.30,.64);
    self.normalizedB=CGPointMake(.54,.50);
    self.guide=[[PLGuideView alloc]initWithFrame:self.view.bounds];
    self.guide.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.guide.visibleLine=YES;
    [self.view addSubview:self.guide];

    self.handleA=[self makeHandle:@"A"];
    self.handleB=[self makeHandle:@"B"];
    [self.view addSubview:self.handleA]; [self.view addSubview:self.handleB];

    self.menuButton=[UIButton buttonWithType:UIButtonTypeSystem];
    self.menuButton.frame=CGRectMake(12,15,58,38);
    self.menuButton.layer.cornerRadius=14;
    self.menuButton.backgroundColor=[UIColor colorWithRed:.35 green:.25 blue:.77 alpha:.92];
    [self.menuButton setTitle:@"PL" forState:UIControlStateNormal];
    [self.menuButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.menuButton.titleLabel.font=[UIFont boldSystemFontOfSize:16];
    [self.menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.menuButton];

    self.panel=[[UIView alloc]initWithFrame:CGRectMake(12,59,286,188)];
    self.panel.backgroundColor=[UIColor colorWithRed:.065 green:.07 blue:.14 alpha:.96];
    self.panel.layer.cornerRadius=16;
    self.panel.layer.borderColor=[UIColor colorWithRed:.4 green:.44 blue:.75 alpha:1].CGColor;
    self.panel.layer.borderWidth=1;
    self.panel.hidden=YES;
    [self.panel addSubview:[self label:@"POOL LAB  •  Overlay" frame:CGRectMake(16,9,250,26) size:16]];
    self.guideSwitch=[self addSwitch:@"Manuelle Ziellinie" atY:42 action:@selector(updateSwitches) initial:YES];
    self.wallSwitch=[self addSwitch:@"Banden-Vorschau" atY:80 action:@selector(updateSwitches) initial:NO];
    UILabel *info=[[UILabel alloc]initWithFrame:CGRectMake(15,121,255,56)];
    info.text=@"A und B verschieben, um die Linie auszurichten.\nKeine automatische Ballerkennung.";
    info.textColor=[UIColor colorWithWhite:.75 alpha:1];
    info.numberOfLines=2;
    info.font=[UIFont systemFontOfSize:11];
    [self.panel addSubview:info]; [self.view addSubview:self.panel];
    [self updateSwitches];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w=self.view.bounds.size.width, h=self.view.bounds.size.height;
    self.menuButton.frame=CGRectMake(12,MAX(8,self.view.safeAreaInsets.top+3),58,38);
    CGFloat panelY=CGRectGetMaxY(self.menuButton.frame)+5;
    self.panel.frame=CGRectMake(12,panelY,MIN(286,w-24),188);
    if (h < panelY+188) self.panel.frame=CGRectMake(80,8,MIN(286,w-92),188);
    self.handleA.center=CGPointMake(w*self.normalizedA.x,h*self.normalizedA.y);
    self.handleB.center=CGPointMake(w*self.normalizedB.x,h*self.normalizedB.y);
    [self redraw];
}
- (void)panHandle:(UIPanGestureRecognizer *)pan {
    UIView *v=pan.view;
    CGPoint d=[pan translationInView:self.view];
    CGPoint center=CGPointMake(v.center.x+d.x,v.center.y+d.y);
    CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;
    center.x=MAX(22,MIN(w-22,center.x));
    center.y=MAX(22,MIN(h-22,center.y));
    if(v==self.handleA) self.normalizedA=CGPointMake(center.x/w,center.y/h);
    else self.normalizedB=CGPointMake(center.x/w,center.y/h);
    v.center=center;
    [pan setTranslation:CGPointZero inView:self.view];
    [self redraw];
}
- (void)redraw {
    self.guide.start=self.handleA.center;
    self.guide.aim=self.handleB.center;
    [self.guide setNeedsDisplay];
}
- (void)toggleMenu {
    self.panelOpened=!self.panelOpened;
    self.panel.hidden=!self.panelOpened;
}
- (void)updateSwitches {
    BOOL enabled=self.guideSwitch.on;
    self.handleA.hidden=!enabled;
    self.handleB.hidden=!enabled;
    self.guide.visibleLine=enabled;
    self.guide.wallPreview=self.wallSwitch.on;
    [self redraw];
}
@end

@implementation PLPassWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *target=[super hitTest:point withEvent:event];
    if (!target || target==self || target==self.rootViewController.view) return nil;
    return target;
}
@end

static PLPassWindow *poolLabWindow=nil;
static void PLInstall(void) {
    if (poolLabWindow || ![NSThread isMainThread]) return;
    UIApplication *app=UIApplication.sharedApplication;
    UIWindowScene *scene=nil;
    if (@available(iOS 13.0,*)) {
        for (UIScene *candidate in app.connectedScenes) {
            if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive) {
                scene=(UIWindowScene*)candidate; break;
            }
        }
        if (!scene) return;
        poolLabWindow=[[PLPassWindow alloc]initWithWindowScene:scene];
    } else {
        poolLabWindow=[[PLPassWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
    }
    poolLabWindow.backgroundColor=UIColor.clearColor;
    poolLabWindow.windowLevel=UIWindowLevelAlert+20;
    poolLabWindow.rootViewController=[PLOverlayController new];
    poolLabWindow.hidden=NO;
}
__attribute__((constructor)) static void PLStartup(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            PLInstall();
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)),dispatch_get_main_queue(), ^{
            PLInstall();
        });
    });
}
