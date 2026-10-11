#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static inline CGFloat PLClamp(CGFloat x, CGFloat a, CGFloat b) { return MAX(a,MIN(b,x)); }
static inline CGFloat PLDistance(CGPoint a, CGPoint b) { return hypot(a.x-b.x,a.y-b.y); }
static inline CGPoint PLPlus(CGPoint a, CGPoint b, CGFloat s) { return CGPointMake(a.x+b.x*s,a.y+b.y*s); }
static inline CGPoint PLUnit(CGPoint a, CGPoint b) {
    CGFloat l = MAX(0.001,PLDistance(a,b));
    return CGPointMake((b.x-a.x)/l,(b.y-a.y)/l);
}

@interface PLGuide : UIView
@property(nonatomic) CGPoint cue, objectBall;
@property(nonatomic) BOOL aimVisible, bankVisible, pocketVisible;
@property(nonatomic) CGFloat lineFactor, ballRadius, inset;
@property(nonatomic) NSInteger chosenPocket;
@end

@implementation PLGuide
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor; self.userInteractionEnabled=NO;
        self.opaque=NO; self.contentMode=UIViewContentModeRedraw;
        self.aimVisible=YES; self.bankVisible=YES; self.pocketVisible=NO;
        self.lineFactor=1.0; self.ballRadius=10.0; self.inset=42.0;
    }
    return self;
}
- (void)line:(CGContextRef)c from:(CGPoint)a to:(CGPoint)b color:(UIColor*)color width:(CGFloat)width dash:(BOOL)dash {
    CGContextSetStrokeColorWithColor(c,color.CGColor);
    CGContextSetLineWidth(c,width);
    CGFloat marks[] = {9,6}; CGContextSetLineDash(c,0,dash?marks:NULL,dash?2:0);
    CGContextMoveToPoint(c,a.x,a.y); CGContextAddLineToPoint(c,b.x,b.y);
    CGContextStrokePath(c);
}
- (void)dot:(CGContextRef)c at:(CGPoint)p radius:(CGFloat)r color:(UIColor*)color {
    CGContextSetFillColorWithColor(c,color.CGColor);
    CGContextFillEllipseInRect(c,CGRectMake(p.x-r,p.y-r,r*2,r*2));
}
- (CGPoint)pocketAt:(NSInteger)i rect:(CGRect)r {
    CGPoint ps[]={ {CGRectGetMinX(r),CGRectGetMinY(r)}, {CGRectGetMidX(r),CGRectGetMinY(r)},
        {CGRectGetMaxX(r),CGRectGetMinY(r)}, {CGRectGetMinX(r),CGRectGetMaxY(r)},
        {CGRectGetMidX(r),CGRectGetMaxY(r)}, {CGRectGetMaxX(r),CGRectGetMaxY(r)} };
    return ps[((i%6)+6)%6];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();
    if(!c) return;
    CGContextSaveGState(c);
    CGRect table=CGRectInset(self.bounds,self.inset,self.inset*0.8);
    if (table.size.width<50 || table.size.height<50) { CGContextRestoreGState(c);return; }

    if(self.pocketVisible) {
        CGPoint pocket=[self pocketAt:self.chosenPocket rect:table];
        CGPoint direction=PLUnit(self.objectBall,pocket);
        CGPoint ghost=PLPlus(self.objectBall,direction,-2.0*self.ballRadius);
        UIColor *cyan=[UIColor colorWithRed:.22 green:.96 blue:.91 alpha:.96];
        UIColor *yellow=[UIColor colorWithRed:1 green:.80 blue:.24 alpha:.99];
        [self line:c from:self.cue to:ghost color:cyan width:3.5 dash:YES];
        [self line:c from:self.objectBall to:pocket color:yellow width:2.6 dash:YES];
        [self dot:c at:ghost radius:self.ballRadius color:[UIColor colorWithRed:.22 green:.96 blue:.91 alpha:.26]];
        [self dot:c at:pocket radius:9 color:yellow];
        [self line:c from:CGPointMake(pocket.x-13,pocket.y) to:CGPointMake(pocket.x+13,pocket.y) color:yellow width:1 dash:NO];
        [self line:c from:CGPointMake(pocket.x,pocket.y-13) to:CGPointMake(pocket.x,pocket.y+13) color:yellow width:1 dash:NO];
    } else if(self.aimVisible) {
        CGPoint dir=PLUnit(self.cue,self.objectBall);
        CGFloat length=hypot(self.bounds.size.width,self.bounds.size.height)*self.lineFactor;
        CGPoint end=PLPlus(self.cue,dir,length);
        [self line:c from:self.cue to:end color:[UIColor colorWithRed:.16 green:.93 blue:1 alpha:.97] width:3.0 dash:YES];
        if(self.bankVisible) {
            CGPoint cur=self.cue;
            CGPoint d=dir;
            UIColor *gold=[UIColor colorWithRed:1 green:.70 blue:.24 alpha:.84];
            for(int bounce=0;bounce<2;bounce++) {
                CGFloat tx=INFINITY,ty=INFINITY;
                if(fabs(d.x)>0.0001) tx=((d.x>0 ? CGRectGetMaxX(table):CGRectGetMinX(table))-cur.x)/d.x;
                if(fabs(d.y)>0.0001) ty=((d.y>0 ? CGRectGetMaxY(table):CGRectGetMinY(table))-cur.y)/d.y;
                tx=tx>0.0001?tx:INFINITY;ty=ty>0.0001?ty:INFINITY;
                CGFloat t=MIN(tx,ty);
                if(!isfinite(t))break;
                CGPoint wall=PLPlus(cur,d,t);
                if (bounce==0) [self line:c from:cur to:wall color:gold width:2 dash:YES];
                if(tx<ty) d.x=-d.x; else d.y=-d.y;
                CGFloat t2=MIN(200.0,length*.33);
                CGPoint after=PLPlus(wall,d,t2);
                [self line:c from:wall to:after color:gold width:2 dash:YES];
                cur=PLPlus(wall,d,.8);
            }
        }
    }
    CGContextRestoreGState(c);
}
@end

@interface PLWindow : UIWindow @end
@interface PLController : UIViewController
@property(nonatomic,strong) PLGuide *guide;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIButton *launcher,*cueHandle,*targetHandle,*pocketButton,*autoPocketButton;
@property(nonatomic,strong) UISwitch *aimSwitch,*bankSwitch,*pocketSwitch,*handlesSwitch;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic) CGPoint cueNorm,targetNorm;
@property(nonatomic) BOOL panelShown,handlesShown;
@property(nonatomic) NSInteger pocket;
@end

@implementation PLController
- (UIColor*)purple {return [UIColor colorWithRed:.42 green:.26 blue:.95 alpha:1];}
- (UIColor*)cyan {return [UIColor colorWithRed:.22 green:.96 blue:.91 alpha:1];}
- (UILabel*)label:(NSString*)text y:(CGFloat)y size:(CGFloat)size color:(UIColor*)color {
    UILabel *l=[[UILabel alloc]initWithFrame:CGRectMake(18,y,305,25)];
    l.text=text; l.textColor=color; l.font=[UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    l.adjustsFontSizeToFitWidth=YES;
    return l;
}
- (UIButton*)button:(NSString*)title rect:(CGRect)rect selector:(SEL)selector {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    b.frame=rect;b.layer.cornerRadius=10;
    b.backgroundColor=[self purple];
    b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [b setTitle:title forState:UIControlStateNormal];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];return b;
}
- (UISwitch*)setting:(NSString*)title y:(CGFloat)y sel:(SEL)action on:(BOOL)on {
    UILabel *l=[self label:title y:y size:13 color:UIColor.whiteColor];
    l.frame=CGRectMake(18,y,229,28);[self.panel addSubview:l];
    UISwitch *s=[[UISwitch alloc]initWithFrame:CGRectMake(270,y,48,31)];
    s.on=on;s.onTintColor=[self cyan];s.transform=CGAffineTransformMakeScale(.80,.80);
    [s addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:s];return s;
}
- (UIButton*)handle:(NSString*)name background:(UIColor*)color {
    UIButton *v=[UIButton buttonWithType:UIButtonTypeSystem];
    v.frame=CGRectMake(0,0,44,44);
    v.backgroundColor=[color colorWithAlphaComponent:.89];v.layer.cornerRadius=22;
    v.layer.borderWidth=2;v.layer.borderColor=UIColor.whiteColor.CGColor;
    v.layer.shadowColor=color.CGColor;v.layer.shadowOpacity=.85;v.layer.shadowRadius=8;
    [v setTitle:name forState:UIControlStateNormal];
    [v setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    v.titleLabel.font=[UIFont boldSystemFontOfSize:16];
    UIPanGestureRecognizer *drag=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(dragMarker:)];
    [v addGestureRecognizer:drag]; return v;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.clearColor;
    self.cueNorm=CGPointMake(.31,.60);self.targetNorm=CGPointMake(.57,.50);
    self.handlesShown=YES;
    self.guide=[[PLGuide alloc]initWithFrame:self.view.bounds];
    self.guide.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.guide];
    self.cueHandle=[self handle:@"C" background:[UIColor whiteColor]];
    self.targetHandle=[self handle:@"O" background:[UIColor colorWithRed:1 green:.78 blue:.19 alpha:1]];
    [self.view addSubview:self.cueHandle];[self.view addSubview:self.targetHandle];
    self.launcher=[self button:@"PL +" rect:CGRectMake(8,8,62,42) selector:@selector(toggle)];
    self.launcher.layer.shadowOpacity=.8;self.launcher.layer.shadowRadius=10;
    self.launcher.layer.shadowColor=[self purple].CGColor;
    [self.view addSubview:self.launcher];

    self.panel=[[UIView alloc]initWithFrame:CGRectMake(8,55,345,352)];
    self.panel.backgroundColor=[UIColor colorWithRed:.057 green:.067 blue:.125 alpha:.975];
    self.panel.layer.cornerRadius=19;
    self.panel.layer.borderWidth=1.5;
    self.panel.layer.borderColor=[self purple].CGColor;
    self.panel.layer.shadowColor=[self purple].CGColor;self.panel.layer.shadowOpacity=.6;
    self.panel.layer.shadowRadius=12;
    [self.panel addSubview:[self label:@"POOL LAB  •  NEO" y:10 size:20 color:[self cyan]]];
    [self.panel addSubview:[self label:@"LIVE OVERLAY  /  OHNE KEY" y:37 size:10 color:[UIColor colorWithWhite:.7 alpha:1]]];
    UIView *rule=[[UIView alloc]initWithFrame:CGRectMake(16,67,312,1)];
    rule.backgroundColor=[self purple];[self.panel addSubview:rule];
    self.aimSwitch=[self setting:@"EXTENDED AIM LINE" y:79 sel:@selector(updated) on:YES];
    self.bankSwitch=[self setting:@"BANK SHOT GUIDE" y:116 sel:@selector(updated) on:YES];
    self.pocketSwitch=[self setting:@"GHOST BALL / POCKET" y:153 sel:@selector(updated) on:NO];
    self.handlesSwitch=[self setting:@"MARKER ANZEIGEN" y:190 sel:@selector(updated) on:YES];
    self.autoPocketButton=[self button:@"BESTE TASCHE" rect:CGRectMake(17,235,148,40) selector:@selector(recommendPocket)];
    self.autoPocketButton.backgroundColor=[self purple];
    [self.panel addSubview:self.autoPocketButton];
    self.pocketButton=[self button:@"WEITER  →" rect:CGRectMake(173,235,154,40) selector:@selector(nextPocket)];
    self.pocketButton.backgroundColor=[UIColor colorWithRed:.13 green:.25 blue:.32 alpha:1];
    [self.panel addSubview:self.pocketButton];
    self.status=[self label:@"C = Spielball  •  O = Objektball" y:283 size:12 color:[self cyan]];
    [self.panel addSubview:self.status];
    UILabel *footer=[self label:@"Manuelle Ausrichtung • keine Ballerkennung" y:312 size:10 color:[UIColor colorWithWhite:.64 alpha:1]];
    [self.panel addSubview:footer];
    self.panel.hidden=YES;[self.view addSubview:self.panel];
    [self updated];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;
    CGRect sf=self.view.safeAreaInsets.top>0?CGRectMake(10,MAX(6,self.view.safeAreaInsets.top),62,42):CGRectMake(10,7,62,42);
    self.launcher.frame=sf;
    CGFloat px=MAX(5,MIN(80,w-350));
    CGFloat py=CGRectGetMaxY(sf)+5;
    if(h<py+352) py=MAX(2,h-355);
    self.panel.frame=CGRectMake(px,py,MIN(345,w-10),MIN(352,h-4));
    self.cueHandle.center=CGPointMake(w*self.cueNorm.x,h*self.cueNorm.y);
    self.targetHandle.center=CGPointMake(w*self.targetNorm.x,h*self.targetNorm.y);
    [self refreshGuide];
}
- (void)dragMarker:(UIPanGestureRecognizer*)gesture {
    UIView *marker=gesture.view;CGPoint delta=[gesture translationInView:self.view];
    CGFloat w=MAX(self.view.bounds.size.width,1),h=MAX(self.view.bounds.size.height,1);
    CGPoint p=CGPointMake(PLClamp(marker.center.x+delta.x,20,w-20),PLClamp(marker.center.y+delta.y,20,h-20));
    marker.center=p;
    if(marker==self.cueHandle) self.cueNorm=CGPointMake(p.x/w,p.y/h);
    else self.targetNorm=CGPointMake(p.x/w,p.y/h);
    [gesture setTranslation:CGPointZero inView:self.view];
    [self refreshGuide];
}
- (void)refreshGuide {
    self.guide.cue=self.cueHandle.center;
    self.guide.objectBall=self.targetHandle.center;
    self.guide.chosenPocket=self.pocket;
    [self.guide setNeedsDisplay];
    if (self.status) {
        CGPoint p = [self.guide pocketAt:self.pocket rect:CGRectInset(self.guide.bounds,self.guide.inset,self.guide.inset*0.8)];
        CGPoint dir=PLUnit(self.targetHandle.center,p);
        CGPoint ghost=PLPlus(self.targetHandle.center,dir,-2.0*self.guide.ballRadius);
        CGPoint v=PLUnit(self.cueHandle.center,ghost);
        CGFloat angle=atan2(v.y,v.x)*180.0/M_PI;
        self.status.text=[NSString stringWithFormat:@"Tasche %ld  ·  Zielwinkel %.0f°",(long)(self.pocket+1),angle];
    }
}
- (void)toggle { self.panel.hidden=!self.panel.hidden; self.panelShown=!self.panel.hidden; }
- (void)nextPocket {self.pocket=(self.pocket+1)%6; [self refreshGuide];}
- (void)recommendPocket {
    // Real calculation from manually positioned markers. No access to live game ball state.
    CGRect table=CGRectInset(self.guide.bounds,self.guide.inset,self.guide.inset*0.8);
    CGFloat best=CGFLOAT_MAX;
    NSInteger bestIndex=0;
    CGPoint cue=self.cueHandle.center, ball=self.targetHandle.center;
    CGPoint approach=PLUnit(cue,ball);
    for(NSInteger idx=0;idx<6;idx++){
        CGPoint pocket=[self.guide pocketAt:idx rect:table];
        CGFloat run=PLDistance(ball,pocket);
        if(run<self.guide.ballRadius*3.0) continue;
        CGPoint toward=PLUnit(ball,pocket);
        CGPoint ghost=PLPlus(ball,toward,-self.guide.ballRadius*2.0);
        CGPoint shot=PLUnit(cue,ghost);
        CGFloat cosine=PLClamp(shot.x*toward.x+shot.y*toward.y,-1,1);
        // Prefer a realistic cut angle; discourage long runs and out-of-table ghost positions.
        CGFloat cut=acos(cosine);
        CGFloat cueTravel=PLDistance(cue,ghost);
        BOOL ghostInside=CGRectContainsPoint(CGRectInset(table,6,6),ghost);
        CGFloat score=3.2*cut + .002*run + .001*cueTravel + (ghostInside?0:5);
        if (shot.x*approach.x+shot.y*approach.y < .1) score+=3;
        if (score<best) {best=score;bestIndex=idx;}
    }
    self.pocket=bestIndex;
    self.pocketSwitch.on=YES;
    [self updated];
}
- (void)updated {
    self.guide.aimVisible=self.aimSwitch.on;
    self.guide.bankVisible=self.bankSwitch.on;
    self.guide.pocketVisible=self.pocketSwitch.on;
    BOOL markers=self.handlesSwitch.on;
    self.cueHandle.hidden=!markers;
    self.targetHandle.hidden=!markers;
    self.pocketButton.enabled=self.pocketSwitch.on;
    self.pocketButton.alpha=self.pocketSwitch.on?1:.4;
    self.autoPocketButton.enabled=YES;
    [self refreshGuide];
}
@end

@implementation PLWindow
- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)ev {
    UIView *v=[super hitTest:p withEvent:ev];
    if(!v || v==self || v==self.rootViewController.view) return nil;
    return v;
}
@end

static PLWindow *PLSharedWindow=nil;
static void PLInstall(void) {
    if (PLSharedWindow || ![NSThread isMainThread]) return;
    UIApplication *app=[UIApplication sharedApplication];
    UIWindowScene *foreground=nil;
    if (@available(iOS 13.0,*)) {
        for (UIScene *scene in app.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState==UISceneActivationStateForegroundActive) {
                foreground=(UIWindowScene*)scene;break;
            }
        }
        if(!foreground) return;
        PLSharedWindow=[[PLWindow alloc]initWithWindowScene:foreground];
    } else {
        PLSharedWindow=[[PLWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
    }
    PLSharedWindow.backgroundColor=UIColor.clearColor;
    PLSharedWindow.windowLevel=UIWindowLevelAlert+15;
    PLSharedWindow.rootViewController=[PLController new];
    PLSharedWindow.hidden=NO;
}
__attribute__((constructor)) static void PLBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ PLInstall(); }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ PLInstall(); });
    });
}
