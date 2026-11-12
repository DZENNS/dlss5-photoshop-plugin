#import <objc/runtime.h>
#include "Plugin.mm"
#include <cassert>
static FilterRecord record{};
static std::vector<uint8_t> src,dst;
static bool cancelTest=false;
static int queued=0;
thread_local const char* dlssLaunchStage="test";
bool DLSSListenerReady(){return true;}
static BOOL simulate(id self,SEL){Panel*p=(Panel*)self;assert(p->width==3&&p->height==2);assert(p->input[0]==11);p->output=p->input;for(size_t i=0;i<p->output.size();i+=4)p->output[i]=42;return !cancelTest;}
static OSErr advance(){record.inData=src.data();record.outData=dst.data();return 0;}
int main(){@autoreleasepool{class_replaceMethod([Panel class],@selector(show),(IMP)simulate,"c@:");dlssLayerTransaction=false;src.assign(32,99);dst.assign(32,77);for(int y=0;y<2;y++)for(int x=0;x<3;x++){src[y*16+x*4]=11;src[y*16+x*4+1]=22;src[y*16+x*4+2]=33;}record.imageMode=plugInModeRGBColor;record.depth=8;record.planes=3;record.filterRect={2,5,4,8};record.inRowBytes=record.outRowBytes=16;record.inColumnBytes=record.outColumnBytes=4;record.inPlaneBytes=record.outPlaneBytes=1;record.advanceState=&advance;int16 result=0;intptr_t data=0;PluginMain(filterSelectorStart,&record,&data,&result);assert(result==0);assert(queued==0);assert(dst[0]==11&&dst[1]==22&&dst[2]==33);assert(pendingResult.pixels[0]==42);dlssLayerTransaction=true;PluginMain(filterSelectorStart,&record,&data,&result);assert(result==0);for(int y=0;y<2;y++)for(int x=0;x<3;x++){assert(dst[y*16+x*4]==42);assert(dst[y*16+x*4+1]==22);assert(dst[y*16+x*4+2]==33);assert(dst[y*16+x*4+3]==77);}assert(dst[15]==77);dst.assign(32,77);cancelTest=true;dlssLayerTransaction=false;PluginMain(filterSelectorStart,&record,&data,&result);assert(result==userCanceledErr);assert(queued==0);for(auto b:dst)assert(b==77);record.depth=16;PluginMain(filterSelectorStart,&record,&data,&result);assert(result==filterBadMode);puts("PASS: RGB strides, offset rectangle, channel preservation, cancel leaves destination unchanged, 16-bit rejection");}}
