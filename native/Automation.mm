#import <Cocoa/Cocoa.h>
#include "PIDefines.h"
#include "PIActionsPlugin.h"
#include "PITerminology.h"
#include <stdexcept>
#include "SPInterf.h"
#include "PendingResult.h"
#include "Localization.h"
#include <cstring>
// The automation command owns the duplicate. The hidden pixel filter never edits
// document structure while Photoshop has its pixel buffers locked.
extern thread_local bool dlssLayerTransaction;
thread_local const char* dlssLaunchStage="idle";
static SPPluginRef layerServiceRef=nullptr;
static SPBasicSuite* listenerBasic=nullptr;
static DescriptorEventID previewEvent=0;
static bool listenerReady=false,commandQueued=false;
static int32 sourceLayer=0,sourceDocument=0;
static void PreviewCompleted(DescriptorEventID,PIActionDescriptor,PIDialogRecordOptions,void*);
bool DLSSListenerReady(){return listenerReady;}

static SPErr PostLayerCommand(SPBasicSuite*,void*);
namespace {
struct Permit{Permit(){dlssLayerTransaction=true;}~Permit(){dlssLayerTransaction=false;}};
struct Actions {
 SPBasicSuite*b; const PSActionControlProcs*c=nullptr;const PSActionDescriptorProcs*d=nullptr;const PSActionReferenceProcs*r=nullptr;
 explicit Actions(SPBasicSuite*basic):b(basic){}
 void acquire(){dlssLaunchStage="Acquire ActionControl v6";check(b->AcquireSuite(kPSActionControlSuite,kPSActionControlSuiteVersion,(const void**)&c));dlssLaunchStage="Acquire ActionDescriptor";check(b->AcquireSuite(kPSActionDescriptorSuite,kPSActionDescriptorSuiteVersion,(const void**)&d));dlssLaunchStage="Acquire ActionReference";check(b->AcquireSuite(kPSActionReferenceSuite,kPSActionReferenceSuiteVersion,(const void**)&r));}
 ~Actions(){if(r)b->ReleaseSuite(kPSActionReferenceSuite,kPSActionReferenceSuiteVersion);if(d)b->ReleaseSuite(kPSActionDescriptorSuite,kPSActionDescriptorSuiteVersion);if(c)b->ReleaseSuite(kPSActionControlSuite,kPSActionControlSuiteVersion);}
 static void check(SPErr e){if(e)throw e;}
 DescriptorTypeID id(const char*s){DescriptorTypeID v=0;check(c->StringIDToTypeID(s,&v));return v;}
 int32 activeID(bool document=false){PIActionReference ref=nullptr;PIActionDescriptor value=nullptr;int32 layer=0;check(r->Make(&ref));try{check(r->PutProperty(ref,classProperty,id(document?"documentID":"layerID")));check(r->PutEnumerated(ref,document?classDocument:classLayer,typeOrdinal,enumTarget));check(c->Get(&value,ref));check(d->GetInteger(value,id(document?"documentID":"layerID"),&layer));}catch(...){if(value)d->Free(value);r->Free(ref);throw;}d->Free(value);r->Free(ref);return layer;}
 void layerEvent(DescriptorEventID event,int32 layer){PIActionDescriptor desc=nullptr,result=nullptr;PIActionReference ref=nullptr;check(d->Make(&desc));try{check(r->Make(&ref));check(r->PutIdentifier(ref,classLayer,layer));check(d->PutReference(desc,keyNull,ref));check(c->Play(&result,event,desc,plugInDialogSilent));}catch(...){if(ref)r->Free(ref);if(result)d->Free(result);d->Free(desc);throw;}r->Free(ref);if(result)d->Free(result);d->Free(desc);}

 int32 historyIndex(){PIActionReference ref=nullptr;PIActionDescriptor value=nullptr;int32 index=0;check(r->Make(&ref));try{check(r->PutEnumerated(ref,classHistoryState,typeOrdinal,enumTarget));check(c->Get(&value,ref));check(d->GetInteger(value,keyItemIndex,&index));}catch(...){if(value)d->Free(value);r->Free(ref);throw;}d->Free(value);r->Free(ref);return index;}
 void restoreHistory(int32 index){PIActionReference ref=nullptr;PIActionDescriptor desc=nullptr,result=nullptr;check(r->Make(&ref));try{check(r->PutIndex(ref,classHistoryState,index));check(d->Make(&desc));check(d->PutReference(desc,keyNull,ref));check(c->Play(&result,eventSelect,desc,plugInDialogSilent));}catch(...){r->Free(ref);if(desc)d->Free(desc);if(result)d->Free(result);throw;}r->Free(ref);d->Free(desc);if(result)d->Free(result);}
 void resize(int w,int h){PIActionDescriptor desc=nullptr,result=nullptr;check(d->Make(&desc));try{check(d->PutUnitFloat(desc,keyWidth,unitPixels,w));check(d->PutUnitFloat(desc,keyHeight,unitPixels,h));check(d->PutBoolean(desc,keyConstrainProportions,true));check(d->PutEnumerated(desc,keyInterpolation,typeInterpolation,enumBicubic));check(c->Play(&result,eventImageSize,desc,plugInDialogSilent));}catch(...){if(result)d->Free(result);d->Free(desc);throw;}if(result)d->Free(result);d->Free(desc);}
 SPErr filter(){PIActionDescriptor desc=nullptr,result=nullptr;check(d->Make(&desc));Permit permit;SPErr err=c->Play(&result,id("a8a86c1f-e2e0-4356-94ad-d15550000002"),desc,plugInDialogSilent);if(result)d->Free(result);d->Free(desc);return err;}
};
}
extern "C" __attribute__((visibility("default"))) SPErr AutoPluginMain(const char*caller,const char*selector,void*message){
 @autoreleasepool {SPMessageData*m=(SPMessageData*)message;if(!m||!m->basic)return -1;
 if(m->basic->IsEqual(caller,kSPInterfaceCaller)){
  if(m->basic->IsEqual(selector,kSPInterfaceStartupSelector)){
   if(listenerReady)return 0;
   try{Actions a(m->basic);a.acquire();previewEvent=a.id("a8a86c1f-e2e0-4356-94ad-d15550000004");Actions::check(a.c->AddNotify(m->self,previewEvent,PreviewCompleted,nullptr));layerServiceRef=m->self;listenerBasic=m->basic;listenerReady=true;return 0;}catch(SPErr err){return err;}
  }
  if(m->basic->IsEqual(selector,kSPInterfaceShutdownSelector)){
   try{if(listenerReady){Actions a(m->basic);a.acquire();Actions::check(a.c->RemoveNotify(m->self,previewEvent));}}catch(...){return -1;}
   listenerReady=false;listenerBasic=nullptr;layerServiceRef=nullptr;pendingResult.clear();commandQueued=false;return 0;
  }
 }

 if(!m->basic->IsEqual(caller,kPSPhotoshopCaller)||!m->basic->IsEqual(selector,kPSDoIt))return kSPNoError;
 if(!commandQueued||pendingResult.pixels.empty())return -1;
 struct ClearResult{~ClearResult(){pendingResult.clear();commandQueued=false;}} clearResult;
 Actions a(m->basic);int32 original=0,duplicate=0;bool duplicated=false;int32 history=-1;
 try{a.acquire();original=a.activeID();if(original!=sourceLayer||a.activeID(true)!=sourceDocument)throw SPErr(-1);if(pendingResult.scale==2){history=a.historyIndex();a.resize(pendingResult.width,pendingResult.height);}a.layerEvent(eventDuplicate,original);duplicated=true;duplicate=a.activeID();if(duplicate==original||duplicate<=0)throw SPErr(-1);SPErr err=a.filter();if(!err)return kSPNoError;Actions::check(err);}
 catch(SPErr err){if(history>=0){try{a.restoreHistory(history);}catch(...){NSAlert*alert=[NSAlert new];alert.messageText=tr(@"DLSS5: ошибка применения. Проверьте историю документа.",@"DLSS5: apply failed. Check document history.");[alert runModal];}return err;}if(duplicated){try{if(duplicate<=0||duplicate==original)throw SPErr(-1);a.layerEvent(eventDelete,duplicate);a.layerEvent(eventSelect,original);}catch(...){NSAlert*alert=[NSAlert new];alert.messageText=tr(@"DLSS5: не удалось удалить временную копию слоя",@"DLSS5: could not remove the temporary layer");alert.informativeText=tr(@"Исходный слой не обрабатывался. Проверьте слои документа.",@"The original was not processed. Check the document layers.");[alert runModal];}}return err;}
 catch(...){return -1;}return -1;}
}

// Post after the public filter returns: never change document structure while
// Photoshop owns that filter's input/output buffers. No notifier: no lifetime risk.
static SPErr PostLayerCommand(SPBasicSuite*basic,void*pluginRef){
 dlssLaunchStage="Filter host references";if(!basic||!pluginRef)return -1;
 try{Actions a(basic);a.acquire();PIActionDescriptor desc=nullptr;
 dlssLaunchStage="Make descriptor";Actions::check(a.d->Make(&desc));SPErr err=0;
 try{uint32 command=0;dlssLaunchStage="Resolve hidden command";auto event=a.id("a8a86c1f-e2e0-4356-94ad-d15550000003");dlssLaunchStage="PostCommand";err=a.c->PostCommand((SPPluginRef)pluginRef,event,desc,plugInDialogSilent,nullptr,nullptr,&command);}
 catch(...){a.d->Free(desc);throw;}a.d->Free(desc);return err;
 }catch(SPErr err){return err;}catch(...){return -1;}
}


static void PreviewCompleted(DescriptorEventID event,PIActionDescriptor,PIDialogRecordOptions,void*){
 if(event!=previewEvent||!listenerReady||commandQueued||pendingResult.pixels.empty())return;
 SPErr error=0;
 try{Actions a(listenerBasic);a.acquire();sourceLayer=a.activeID();sourceDocument=a.activeID(true);commandQueued=true;error=PostLayerCommand(listenerBasic,layerServiceRef);}
 catch(SPErr e){error=e;}catch(...){error=-1;}
 if(error){commandQueued=false;pendingResult.clear();NSAlert*alert=[NSAlert new];alert.messageText=tr(@"DLSS5: не удалось запустить создание нового слоя",@"DLSS5: could not queue new layer");alert.informativeText=[NSString stringWithFormat:@"Error: %d",(int)error];[alert runModal];}
}
