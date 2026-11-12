#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include "PIDefines.h"
#include "PIFilter.h"
#include <vector>
#include <dlfcn.h>
#include <atomic>
#include <memory>
#include "PendingResult.h"
#include "Upscale.h"
// Reset only when the user double-clicks the slider thumb.
@interface DefaultValueSlider : NSSlider
@property double defaultValue;
@end
@implementation DefaultValueSlider
- (void)mouseDown:(NSEvent *)event {
    if (!self.enabled) return;
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSSliderCell *cell = (NSSliderCell *)self.cell;
    if (event.clickCount == 2 && NSPointInRect(point, [cell knobRectFlipped:self.isFlipped])) {
        self.doubleValue = self.defaultValue;
        [self sendAction:self.action to:self.target];
        self.needsDisplay = YES;
        return;
    }
    [super mouseDown:event];
}
@end
PendingResult pendingResult;
using Bytes=std::vector<uint8_t>;
using Completion=void(*)(void*,const uint8_t*,size_t,const char*);
using Process=void(*)(const uint8_t*,size_t,int32_t,int32_t,int32_t,const char*,const char*,void*,Completion);
#include "Localization.h"
#include "PIProperties.h"
static void ReadPhotoshopLocale(FilterRecord*f){
 SetDLSSLocale(nil);
 if(!f||!f->propertyProcs||!f->propertyProcs->getPropertyProc||!f->handleProcs)return;
 auto*h=f->handleProcs;if(!h->lockProc||!h->unlockProc||!h->getSizeProc||!h->disposeProc)return;
 Handle value=nullptr;intptr_t simple=0;
 OSErr error=f->propertyProcs->getPropertyProc('8BIM',propLocale,0,&simple,&value);
 if(!error&&value){int32 n=h->getSizeProc(value);const void*bytes=h->lockProc(value,false);if(bytes){if(n>0&&n<128)SetDLSSLocale([[NSString alloc]initWithBytes:bytes length:n encoding:NSUTF8StringEncoding]);h->unlockProc(value);}}
 if(value)h->disposeProc(value);
}

static NSImage *picture(const Bytes&b,int w,int h){NSBitmapImageRep*r=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w*4 bitsPerPixel:32];memcpy(r.bitmapData,b.data(),b.size());NSImage*i=[[NSImage alloc]initWithSize:NSMakeSize(w,h)];[i addRepresentation:r];return i;}
@interface Preview:NSView
@property NSImage *before,*after;
@property double zoom,split;
@property NSPoint offset,lastPoint;
@property BOOL original,comparison,draggingDivider;
@end
@implementation Preview
-(BOOL)isFlipped{return YES;}
-(BOOL)wantsDefaultClipping{return YES;}
-(CGFloat)dividerX{CGFloat w=NSWidth(self.bounds),margin=MIN(20.,w/2);return MAX(margin,MIN(w-margin,w*self.split));}
-(void)moveDividerToX:(CGFloat)x{CGFloat w=NSWidth(self.bounds);if(w<=0)return;CGFloat margin=MIN(20.,w/2);self.split=MAX(margin,MIN(w-margin,x))/w;self.needsDisplay=YES;[self.window invalidateCursorRectsForView:self];}

-(void)drawRect:(NSRect)dirty{NSRectClip(self.bounds);[[NSColor colorWithWhite:.08 alpha:1]setFill];NSRectFill(self.bounds);NSImage*i=self.original?self.before:(self.after?:self.before);if(!i)return;double z=self.zoom?:MIN(self.bounds.size.width/i.size.width,self.bounds.size.height/i.size.height);NSRect r=NSMakeRect((self.bounds.size.width-i.size.width*z)/2+self.offset.x,(self.bounds.size.height-i.size.height*z)/2+self.offset.y,i.size.width*z,i.size.height*z);NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationHigh;[i drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];if(self.comparison&&self.after&&!self.original){[NSGraphicsContext saveGraphicsState];NSRectClip(NSMakeRect(0,0,[self dividerX],self.bounds.size.height));[self.before drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];[NSGraphicsContext restoreGraphicsState];[[NSColor whiteColor]setFill];CGFloat x=[self dividerX];NSRectFill(NSMakeRect(x-1,0,2,self.bounds.size.height));
NSRect grip=NSMakeRect(x-16,NSMidY(self.bounds)-22,32,44);
[[NSColor colorWithWhite:.12 alpha:.9]setFill];NSBezierPath*handle=[NSBezierPath bezierPathWithRoundedRect:grip xRadius:10 yRadius:10];[handle fill];[[NSColor whiteColor]setStroke];handle.lineWidth=1.5;[handle stroke];
[@"↔" drawInRect:NSInsetRect(grip,4,11) withAttributes:@{NSFontAttributeName:[NSFont boldSystemFontOfSize:18],NSForegroundColorAttributeName:NSColor.whiteColor}];}}
-(BOOL)hitsDivider:(NSPoint)p{return self.comparison&&self.after&&!self.original&&(fabs(p.x-[self dividerX])<=8||NSPointInRect(p,NSMakeRect([self dividerX]-20,NSMidY(self.bounds)-26,40,52)));}
-(void)mouseDown:(NSEvent*)e{self.lastPoint=[self convertPoint:e.locationInWindow fromView:nil];self.draggingDivider=[self hitsDivider:self.lastPoint];if(self.draggingDivider)[NSCursor.resizeLeftRightCursor push];else [NSCursor.closedHandCursor push];}
-(void)mouseDragged:(NSEvent*)e{NSPoint q=[self convertPoint:e.locationInWindow fromView:nil];if(self.draggingDivider){[self moveDividerToX:q.x];}else{self.offset=NSMakePoint(self.offset.x+q.x-self.lastPoint.x,self.offset.y+q.y-self.lastPoint.y);self.needsDisplay=YES;}self.lastPoint=q;}
-(void)mouseUp:(NSEvent*)e{self.draggingDivider=NO;[NSCursor pop];[self.window invalidateCursorRectsForView:self];}
-(void)resetCursorRects{[self addCursorRect:self.bounds cursor:NSCursor.openHandCursor];if(self.comparison&&self.after&&!self.original){[self addCursorRect:NSMakeRect([self dividerX]-8,0,16,NSHeight(self.bounds)) cursor:NSCursor.resizeLeftRightCursor];[self addCursorRect:NSMakeRect([self dividerX]-20,NSMidY(self.bounds)-26,40,52) cursor:NSCursor.resizeLeftRightCursor];}}
-(void)scrollWheel:(NSEvent*)e{if(!self.before)return;double z=self.zoom?:MIN(self.bounds.size.width/self.before.size.width,self.bounds.size.height/self.before.size.height);self.zoom=MAX(.01,MIN(8,z*exp(-e.scrollingDeltaY*.01)));self.needsDisplay=YES;}
@end
@interface Panel:NSObject<NSWindowDelegate>{ @public Bytes input,output; int width,height; int requestedScale; bool upscaleEligible; Process process; NSString*resources; }
@property NSWindow*window;
@property NSView*processingOverlay;
@property NSProgressIndicator*processingSpinner;
@property NSTextField*processingLabel;
@property Preview*view;
@property NSPopUpButton*profile,*quality,*zoomMenu,*presets,*upscale;
@property NSMutableArray<NSSlider*>*sliders;
@property NSButton*skin,*automatic,*apply,*run,*cancel,*stop;
@property NSTextField*status,*presetName;
@property BOOL busy,accepted,cancelRequested,closeRequested;
@end
static NSButton*button(NSString*t,id target,SEL action,NSRect r,NSView*parent){NSButton*b=[NSButton buttonWithTitle:t target:target action:action];b.frame=r;[parent addSubview:b];return b;}
@implementation Panel
-(NSDictionary*)settings{NSArray*s=self.sliders;return @{ @"profile":@[@"off",@"natural",@"standard",@"cinematic",@"neutral"][self.profile.indexOfSelectedItem],@"processingLongEdge":@[@320,@384,@512,@640,@768,@960,@1280,@1920][self.quality.indexOfSelectedItem],@"intensity":@([s[0]doubleValue]),@"tone":@([s[1]doubleValue]),@"structure":@([s[2]doubleValue]),@"temporal":@NO,@"upscale":@(self.upscale.indexOfSelectedItem==1?2:1),@"advanced":@{@"colour":@([s[3]doubleValue]),@"detail":@([s[4]doubleValue]),@"radius":@([s[5]doubleValue]),@"skin":@([s[6]doubleValue]),@"automaticStructure":@([s[7]doubleValue]),@"skinEnabled":@(self.skin.state==NSControlStateValueOn)}};}
-(void)remember{[[NSUserDefaults standardUserDefaults]setObject:@{@"automatic":@(self.automatic.state==NSControlStateValueOn)} forKey:@"com.local.dlss5.native.lastSession"];}
-(void)restore{NSDictionary*d=[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"com.local.dlss5.native.lastSession"];if(!d)return;if([d[@"automatic"]isKindOfClass:[NSNumber class]])self.automatic.state=[d[@"automatic"]boolValue]?NSControlStateValueOn:NSControlStateValueOff;}
-(void)changed:(id)sender{[self remember];self.apply.enabled=NO;[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(render:) object:nil];if(self.automatic.state==NSControlStateValueOn)[self performSelector:@selector(render:) withObject:nil afterDelay:.6 inModes:@[NSModalPanelRunLoopMode,NSDefaultRunLoopMode]];}
-(void)toggleOriginal:(id)s{self.view.original=!self.view.original;self.view.needsDisplay=YES;}
-(void)toggleSplit:(id)s{self.view.comparison=!self.view.comparison;self.view.needsDisplay=YES;}
-(void)zoom:(id)s{double values[]={0,.25,.5,1,1.5,2,4};self.view.zoom=values[self.zoomMenu.indexOfSelectedItem];self.view.offset=NSZeroPoint;self.view.needsDisplay=YES;}
-(void)zoomIn:(id)s{[self zoomFactor:1.25];}
-(void)zoomOut:(id)s{[self zoomFactor:.8];}
-(void)zoomFactor:(double)f{double z=self.view.zoom?:MIN(self.view.bounds.size.width/self.view.before.size.width,self.view.bounds.size.height/self.view.before.size.height);self.view.zoom=MAX(.01,MIN(8,z*f));self.view.needsDisplay=YES;[self.zoomMenu setTitle:[NSString stringWithFormat:@"%.0f%%",self.view.zoom*100]];}
-(void)reset:(id)s{[self.upscale selectItemAtIndex:0];[self.profile selectItemAtIndex:0];[self.quality selectItemAtIndex:2];for(int i=0;i<8;i++)self.sliders[i].doubleValue=i==5?4:1;self.skin.state=NSControlStateValueOff;[self changed:nil];}
-(void)savePreset:(id)s{NSString*n=self.presetName.stringValue;if(!n.length)return;NSMutableDictionary*d=[[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"com.local.dlss5.native.presets"]mutableCopy]?:[NSMutableDictionary dictionary];d[n]=self.settings;[[NSUserDefaults standardUserDefaults]setObject:d forKey:@"com.local.dlss5.native.presets"];[self refresh];}
-(void)refresh{[self.presets removeAllItems];[self.presets addItemsWithTitles:[[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"com.local.dlss5.native.presets"].allKeys sortedArrayUsingSelector:@selector(compare:)]];}
-(void)loadPreset:(id)s{NSDictionary*d=[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"com.local.dlss5.native.presets"][self.presets.titleOfSelectedItem];if(!d)return;[self loadSettings:d];[self changed:nil];}
-(void)loadSettings:(NSDictionary*)d{[self.upscale selectItemAtIndex:upscaleEligible&&[d[@"upscale"]intValue]==2?1:0];if(![d isKindOfClass:[NSDictionary class]])return;NSUInteger p=[@[@"off",@"natural",@"standard",@"cinematic",@"neutral"]indexOfObject:d[@"profile"]];if(p<5)[self.profile selectItemAtIndex:p];NSNumber*edge=d[@"processingLongEdge"];if([edge intValue]==1024)edge=@960;else if([edge intValue]==1536)edge=@1280;NSUInteger q=[@[@320,@384,@512,@640,@768,@960,@1280,@1920]indexOfObject:edge];if(q<8)[self.quality selectItemAtIndex:q];NSArray*a=@[d[@"intensity"]?:@1,d[@"tone"]?:@1,d[@"structure"]?:@1,d[@"advanced"][@"colour"]?:@1,d[@"advanced"][@"detail"]?:@1,d[@"advanced"][@"radius"]?:@4,d[@"advanced"][@"skin"]?:@1,d[@"advanced"][@"automaticStructure"]?:@1];for(int i=0;i<8;i++)self.sliders[i].doubleValue=[a[i]doubleValue];self.skin.state=[d[@"advanced"][@"skinEnabled"]boolValue];}
-(void)deletePreset:(id)s{NSString*n=self.presets.titleOfSelectedItem;if(!n)return;NSMutableDictionary*d=[[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"com.local.dlss5.native.presets"]mutableCopy];[d removeObjectForKey:n];[[NSUserDefaults standardUserDefaults]setObject:d forKey:@"com.local.dlss5.native.presets"];[self refresh];}
-(void)showProcessing{
 if(!self.processingOverlay){
  self.processingOverlay=[[NSView alloc]initWithFrame:self.view.frame];self.processingOverlay.wantsLayer=YES;self.processingOverlay.layer.backgroundColor=[[NSColor blackColor]colorWithAlphaComponent:.48].CGColor;
  CGFloat w=NSWidth(self.view.frame),h=NSHeight(self.view.frame);
  NSView*card=[[NSView alloc]initWithFrame:NSMakeRect((w-300)/2,(h-130)/2,300,130)];card.wantsLayer=YES;card.layer.backgroundColor=[NSColor colorWithWhite:.12 alpha:.96].CGColor;card.layer.cornerRadius=16;[self.processingOverlay addSubview:card];
  self.processingSpinner=[[NSProgressIndicator alloc]initWithFrame:NSMakeRect(132,72,36,36)];self.processingSpinner.style=NSProgressIndicatorStyleSpinning;self.processingSpinner.indeterminate=YES;self.processingSpinner.controlSize=NSControlSizeRegular;self.processingSpinner.usesThreadedAnimation=YES;[card addSubview:self.processingSpinner];
  self.processingLabel=[NSTextField labelWithString:@""];self.processingLabel.frame=NSMakeRect(12,25,276,32);self.processingLabel.alignment=NSTextAlignmentCenter;self.processingLabel.font=[NSFont systemFontOfSize:14 weight:NSFontWeightMedium];[card addSubview:self.processingLabel];
  [self.window.contentView addSubview:self.processingOverlay];
 }
 self.processingLabel.stringValue=tr(@"Обрабатываем изображение…",@"Processing image…");self.processingOverlay.hidden=NO;[self.processingSpinner startAnimation:nil];[self.processingOverlay displayIfNeeded];
}
-(void)hideProcessing{[self.processingSpinner stopAnimation:nil];self.processingOverlay.hidden=YES;}
-(void)render:(id)s{if(self.busy)return;[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(render:) object:nil];[self remember];self.cancelRequested=NO;self.closeRequested=NO;requestedScale=self.upscale.indexOfSelectedItem==1?2:1;
if(self.profile.indexOfSelectedItem==0&&requestedScale==1){output=input;self.view.before.size=NSMakeSize(width,height);self.view.after=nil;self.view.needsDisplay=YES;self.apply.enabled=NO;self.status.stringValue=tr(@"Обработка выключена",@"Processing is off");return;}
self.busy=YES;[self showProcessing];for(NSView*v in self.window.contentView.subviews)if([v isKindOfClass:[NSControl class]])((NSControl*)v).enabled=NO;self.apply.enabled=NO;self.run.enabled=NO;self.cancel.enabled=YES;self.stop.enabled=YES;self.status.stringValue=tr(@"Обработка…",@"Processing…");for(NSControl*c in self.sliders)c.enabled=NO;self.profile.enabled=self.quality.enabled=self.skin.enabled=self.automatic.enabled=NO;NSData*j=[NSJSONSerialization dataWithJSONObject:self.settings options:0 error:nil];NSString*json=[[NSString alloc]initWithData:j encoding:NSUTF8StringEncoding];void*ctx=(__bridge_retained void*)self;Process selectedProcess=self.profile.indexOfSelectedItem==0?+[](const uint8_t*b,size_t n,int32_t,int32_t,int32_t,const char*,const char*,void*c,Completion cb){cb(c,b,n,nullptr);}:process;
selectedProcess(input.data(),input.size(),width,height,4,json.UTF8String,resources.UTF8String,ctx,[](void*c,const uint8_t*b,size_t n,const char*error){Panel*p=(__bridge_transfer Panel*)c;auto result=std::make_shared<Bytes>();if(b)result->assign(b,b+n);__block NSString*err=error?[NSString stringWithUTF8String:error]:nil;
dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
if(!err&&p->requestedScale==2&&result->size()==p->input.size()&&!p.cancelRequested){try{NSString*model=[p->resources stringByAppendingPathComponent:@"Upscale/esrgan_x2.onnx"];*result=Upscale2(*result,p->width,p->height,model.fileSystemRepresentation,[p](int done,int total){dispatch_async(dispatch_get_main_queue(),^{p.processingLabel.stringValue=[NSString stringWithFormat:tr(@"Апскейл ×2: %d / %d",@"Upscaling ×2: %d / %d"),done,total];});return !p.cancelRequested;});}catch(const std::exception&e){err=[NSString stringWithUTF8String:e.what()];}}
dispatch_async(dispatch_get_main_queue(),^{p.busy=NO;[p hideProcessing];for(NSView*v in p.window.contentView.subviews)if([v isKindOfClass:[NSControl class]])((NSControl*)v).enabled=YES;p.apply.enabled=NO;p.stop.enabled=NO;p.run.enabled=p.cancel.enabled=YES;for(NSControl*x in p.sliders)x.enabled=YES;p.profile.enabled=p.quality.enabled=p.skin.enabled=p.automatic.enabled=YES;if(p.cancelRequested){p.status.stringValue=tr(@"Обработка прервана. Результат не применён.",@"Processing cancelled. Result discarded.");if(p.closeRequested)[NSApp stopModal];return;}if(err||result->size()!=p->input.size()*p->requestedScale*p->requestedScale){p.status.stringValue=err?:tr(@"Некорректный результат обработки",@"Invalid processing result");return;}p->output=std::move(*result);p.view.after=picture(p->output,p->width*p->requestedScale,p->height*p->requestedScale);p.view.before.size=NSMakeSize(p->width*p->requestedScale,p->height*p->requestedScale);p.view.original=NO;p.view.needsDisplay=YES;p.apply.enabled=YES;p.status.stringValue=p->requestedScale==2?[NSString stringWithFormat:tr(@"Готово: %d × %d → %d × %d",@"Ready: %d × %d → %d × %d"),p->width,p->height,p->width*2,p->height*2]:tr(@"Превью готово",@"Preview ready");});});});}
-(void)commit:(id)s{if(self.busy||!self.apply.enabled)return;self.accepted=YES;[NSApp stopModal];}
-(void)interrupt:(id)s{[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(render:) object:nil];if(!self.busy)return;self.cancelRequested=YES;self.processingLabel.stringValue=tr(@"Завершаем текущий проход…",@"Finishing current pass…");self.stop.enabled=NO;self.apply.enabled=NO;self.status.stringValue=tr(@"Прерывание… ждём завершения текущего прохода",@"Stopping… waiting for the current processing pass");}
-(void)close:(id)s{[self remember];if(self.busy){self.closeRequested=YES;[self interrupt:nil];}else [NSApp stopModal];}
-(BOOL)windowShouldClose:(id)s{[self close:nil];return NO;}
-(BOOL)show{self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1080,760) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];self.window.title=@"DLSS5 • Native";self.window.delegate=self;self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];NSView*c=self.window.contentView;self.view=[[Preview alloc]initWithFrame:NSMakeRect(58,108,690,636)];self.view.before=picture(input,width,height);self.view.split=.5;self.view.comparison=YES;self.view.wantsLayer=YES;self.view.layer.masksToBounds=YES;[c addSubview:self.view];button(@"◐",self,@selector(toggleOriginal:),NSMakeRect(8,690,42,40),c);button(@"◧",self,@selector(toggleSplit:),NSMakeRect(8,640,42,40),c);
button(@"+",self,@selector(zoomIn:),NSMakeRect(8,590,42,40),c);button(@"−",self,@selector(zoomOut:),NSMakeRect(8,540,42,40),c);self.zoomMenu=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(620,66,120,30)];[self.zoomMenu addItemsWithTitles:@[@"FIT",@"25%",@"50%",@"100%",@"150%",@"200%",@"400%"]];self.zoomMenu.target=self;self.zoomMenu.action=@selector(zoom:);[c addSubview:self.zoomMenu];
self.presets=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(770,705,190,28)];[c addSubview:self.presets];button(@"↵",self,@selector(loadPreset:),NSMakeRect(965,705,42,28),c);button(@"−",self,@selector(deletePreset:),NSMakeRect(1010,705,42,28),c);self.presetName=[[NSTextField alloc]initWithFrame:NSMakeRect(770,667,235,28)];self.presetName.placeholderString=tr(@"Название пресета",@"Preset name");[c addSubview:self.presetName];button(@"+",self,@selector(savePreset:),NSMakeRect(1010,667,42,28),c);[self refresh];
self.profile=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(770,620,280,30)];[self.profile addItemsWithTitles:@[tr(@"Выкл.",@"Off"),tr(@"Естественный",@"Natural"),tr(@"Стандартный",@"Standard"),tr(@"Кинематографический",@"Cinematic"),tr(@"Нейтральный",@"Neutral")]];self.profile.target=self;self.profile.action=@selector(changed:);[c addSubview:self.profile];self.sliders=[NSMutableArray array];NSArray*labels=@[tr(@"Сила эффекта",@"Strength"),tr(@"Локальный тон",@"Local tone"),tr(@"Структура",@"Structure"),tr(@"Исходный цвет",@"Original colour"),tr(@"Детали",@"Detail"),tr(@"Радиус деталей",@"Detail radius"),tr(@"Структура кожи",@"Skin texture"),tr(@"Структура маски",@"Mask structure")];for(int i=0;i<8;i++){double y=575-i*53;NSTextField*l=[NSTextField labelWithString:labels[i]];l.frame=NSMakeRect(775,y+19,270,22);[c addSubview:l];DefaultValueSlider*v=[DefaultValueSlider sliderWithValue:i==5?4:1 minValue:i==5?.5:0 maxValue:i==5?12:2 target:self action:@selector(changed:)];v.defaultValue=i==5?4:1;v.toolTip=tr(@"Двойной клик по бегунку — значение по умолчанию",@"Double-click the thumb to reset to default");v.frame=NSMakeRect(775,y,270,22);[c addSubview:v];[self.sliders addObject:v];}
self.skin=[NSButton checkboxWithTitle:tr(@"Коррекция кожи",@"Skin correction") target:self action:@selector(changed:)];self.skin.frame=NSMakeRect(775,155,275,25);[c addSubview:self.skin];self.quality=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(775,112,105,30)];[self.quality addItemsWithTitles:@[@"320 px",@"384 px",@"512 px",@"640 px",@"768 px",@"960 px",@"1280 px",@"1920 px"]];[self.quality selectItemAtIndex:2];self.quality.target=self;self.quality.action=@selector(changed:);[c addSubview:self.quality];self.upscale=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(890,112,160,30)];[self.upscale addItemsWithTitles:@[tr(@"Без апскейла",@"No upscale"),@"Real-ESRGAN ×2"]];self.upscale.target=self;self.upscale.action=@selector(changed:);[c addSubview:self.upscale];[[self.upscale itemAtIndex:1]setEnabled:upscaleEligible];self.upscale.autoenablesItems=NO;self.upscale.toolTip=tr(@"×2 увеличивает Image Size всего документа. Требуется слой во весь документ без выделения.",@"×2 doubles the document Image Size. Requires a full-canvas layer without selection.");self.automatic=[NSButton checkboxWithTitle:tr(@"Автоматически",@"Automatic") target:self action:@selector(changed:)];self.automatic.state=NSControlStateValueOn;self.automatic.frame=NSMakeRect(430,24,150,24);[c addSubview:self.automatic];button(tr(@"Сбросить",@"Reset"),self,@selector(reset:),NSMakeRect(12,18,95,36),c);self.status=[NSTextField labelWithString:tr(@"Выбранный слой • RGB 8 бит",@"Selected layer • RGB 8 bit")];self.status.frame=NSMakeRect(72,68,530,24);[c addSubview:self.status];self.cancel=button(tr(@"Отмена",@"Cancel"),self,@selector(close:),NSMakeRect(120,18,90,36),c);self.run=button(tr(@"Превью",@"Preview"),self,@selector(render:),NSMakeRect(585,18,110,36),c);self.apply=button(tr(@"Применить на новый слой",@"Apply to new layer"),self,@selector(commit:),NSMakeRect(785,18,280,36),c);self.stop=button(tr(@"Прервать обработку",@"Stop processing"),self,@selector(interrupt:),NSMakeRect(220,18,195,36),c);self.apply.bezelColor=NSColor.controlAccentColor;
self.automatic.toolTip=tr(@"Обновлять превью после изменения параметров",@"Update preview when settings change");
self.run.toolTip=tr(@"Обработать изображение для просмотра",@"Process the image for preview");
self.apply.toolTip=tr(@"Создать копию слоя и применить результат",@"Duplicate the layer and apply the result");
self.status.textColor=NSColor.secondaryLabelColor;self.status.lineBreakMode=NSLineBreakByTruncatingTail;
NSBox*divider=[NSBox new];divider.boxType=NSBoxSeparator;divider.frame=NSMakeRect(12,101,1053,1);[c addSubview:divider];
for(NSView*v in c.subviews){if([v isKindOfClass:[NSButton class]]){NSButton*b=(NSButton*)v;if([b.title isEqualToString:@"◐"])b.toolTip=tr(@"Показать оригинал / результат",@"Show original / result");if([b.title isEqualToString:@"◧"])b.toolTip=tr(@"Слайдер до и после",@"Before / after divider");}}
self.stop.enabled=NO;self.apply.enabled=NO;[self restore];[self.window center];[self.window makeKeyAndOrderFront:nil];if(self.automatic.state==NSControlStateValueOn)[self performSelector:@selector(render:) withObject:nil afterDelay:0 inModes:@[NSModalPanelRunLoopMode]];[NSApp runModalForWindow:self.window];[NSObject cancelPreviousPerformRequestsWithTarget:self];[self.window orderOut:nil];return self.accepted;}
@end
thread_local bool dlssLayerTransaction=false;
extern thread_local const char* dlssLaunchStage;
extern bool DLSSListenerReady();
static void*engine=nullptr;
extern "C" __attribute__((visibility("default"))) void PluginMain(int16 selector,FilterRecord*f,intptr_t*data,int16*result){@autoreleasepool{*result=0;try{if(selector==filterSelectorAbout){NSAlert*a=[NSAlert new];a.messageText=@"DLSS5 Native — local build";[a runModal];return;}if(selector==filterSelectorPrepare){f->bufferSpace=0;return;}if(selector!=filterSelectorStart)return;if(!dlssLayerTransaction)ReadPhotoshopLocale(f);if(f->imageMode!=plugInModeRGBColor||f->depth!=8||f->planes<3){*result=filterBadMode;return;}int w=f->filterRect.right-f->filterRect.left,h=f->filterRect.bottom-f->filterRect.top;if(w<=0||h<=0||int64_t(w)*h>(dlssLayerTransaction?96000000:24000000)){*result=filterBadParameters;return;}f->inLoPlane=f->outLoPlane=0;f->inHiPlane=f->outHiPlane=2;f->inRect=f->outRect=f->filterRect;f->maskRect={0,0,0,0};*result=f->advanceState();if(*result)return;if(!f->inData||!f->outData){*result=filterBadParameters;return;}if(dlssLayerTransaction){if(pendingResult.width!=w||pendingResult.height!=h||pendingResult.left!=f->filterRect.left||pendingResult.top!=f->filterRect.top||pendingResult.pixels.size()!=size_t(w)*h*4){*result=filterBadParameters;return;}int oc=f->outColumnBytes?:3,op=f->outPlaneBytes?:1;for(int y=0;y<h;y++)for(int x=0;x<w;x++){auto*d=(uint8_t*)f->outData+y*f->outRowBytes+x*oc;for(int k=0;k<3;k++)d[k*op]=pendingResult.pixels[(size_t(y)*w+x)*4+k];}f->inRect=f->outRect=f->maskRect={0,0,0,0};return;}pendingResult.clear();Panel*p=[Panel new];p->requestedScale=1;p->width=w;p->height=h;p->upscaleEligible=w<=8192&&h<=8192&&!f->haveMask&&f->filterRect.left==0&&f->filterRect.top==0&&w==f->imageSize.h&&h==f->imageSize.v;p->input.resize(size_t(w)*h*4);int col=f->inColumnBytes?:3,plane=f->inPlaneBytes?:1;for(int y=0;y<h;y++)for(int x=0;x<w;x++){auto*s=(uint8_t*)f->inData+y*f->inRowBytes+x*col;size_t i=(size_t(y)*w+x)*4;for(int k=0;k<3;k++)p->input[i+k]=s[k*plane];p->input[i+3]=255;}Dl_info info;dladdr((void*)&PluginMain,&info);NSString*path=[[NSString stringWithUTF8String:info.dli_fname]stringByDeletingLastPathComponent];NSString*root=[path stringByAppendingPathComponent:@"../Resources"];NSString*lib=[path stringByAppendingPathComponent:@"../Resources/Engine/libDLSSPhotoshopNative.dylib"];if(!engine)engine=dlopen(lib.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);p->process=engine?(Process)dlsym(engine,"dlss5_process"):nullptr;if(!p->process){*result=filterBadParameters;return;}p->resources=root;if(![p show]){*result=userCanceledErr;}else{pendingResult.pixels=std::move(p->output);pendingResult.scale=p->requestedScale;pendingResult.width=w*p->requestedScale;pendingResult.height=h*p->requestedScale;pendingResult.left=f->filterRect.left;pendingResult.top=f->filterRect.top;if(!DLSSListenerReady()){pendingResult.clear();NSAlert*a=[NSAlert new];a.messageText=tr(@"DLSS5: модуль применения не запущен",@"DLSS5: apply service is not running");[a runModal];*result=userCanceledErr;}else{int oc=f->outColumnBytes?:3,op=f->outPlaneBytes?:1;for(int y=0;y<h;y++)for(int x=0;x<w;x++){auto*d=(uint8_t*)f->outData+y*f->outRowBytes+x*oc;for(int k=0;k<3;k++)d[k*op]=p->input[(size_t(y)*w+x)*4+k];}*result=0;}}f->inRect=f->outRect=f->maskRect={0,0,0,0};}catch(...){*result=filterBadParameters;}}}
