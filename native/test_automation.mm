#include "Automation.mm"
thread_local bool dlssLayerTransaction=false;
PendingResult pendingResult;
#include <cassert>
#include <cstring>
#include <vector>
static PSActionControlProcs control{};static PSActionDescriptorProcs descriptor{};static PSActionReferenceProcs reference{};static SPBasicSuite basic{};
static int32 active=10;static uint32 target=0;static OSErr failure=0;static bool failDuplicate=false;static std::vector<std::pair<uint32,uint32>> events;
int main(){@autoreleasepool{
 basic.IsEqual=[](const char*a,const char*b)->SPBoolean{return strcmp(a,b)==0;};
 basic.AcquireSuite=[](const char*n,int32,const void**p)->SPErr{if(!strcmp(n,kPSActionControlSuite))*p=&control;else if(!strcmp(n,kPSActionDescriptorSuite))*p=&descriptor;else if(!strcmp(n,kPSActionReferenceSuite))*p=&reference;else return -1;return 0;};
 basic.ReleaseSuite=[](const char*,int32)->SPErr{return 0;};
 descriptor.Make=[](PIActionDescriptor*d)->OSErr{*d=(PIActionDescriptor)1;return 0;};descriptor.Free=[](PIActionDescriptor)->OSErr{return 0;};
 reference.Make=[](PIActionReference*r)->OSErr{*r=(PIActionReference)1;return 0;};reference.Free=[](PIActionReference)->OSErr{return 0;};
 reference.PutProperty=[](PIActionReference,DescriptorClassID,DescriptorKeyID)->OSErr{return 0;};
 reference.PutEnumerated=[](PIActionReference,DescriptorClassID,DescriptorEnumTypeID,DescriptorEnumID)->OSErr{return 0;};
 reference.PutIdentifier=[](PIActionReference,DescriptorClassID,uint32 n)->OSErr{target=n;return 0;};
 descriptor.PutReference=[](PIActionDescriptor,DescriptorKeyID,PIActionReference)->OSErr{return 0;};
 descriptor.GetInteger=[](PIActionDescriptor,DescriptorKeyID,int32*n)->OSErr{*n=active;return 0;};
 control.Get=[](PIActionDescriptor*d,PIActionReference)->OSErr{*d=(PIActionDescriptor)1;return 0;};
 control.StringIDToTypeID=[](const char*s,DescriptorTypeID*i)->OSErr{*i=!strcmp(s,"layerID")?1:2;return 0;};
 control.Play=[](PIActionDescriptor*r,DescriptorEventID e,PIActionDescriptor,PIDialogPlayOptions)->OSErr{*r=nullptr;events.push_back({e,target});if(e==eventDuplicate){if(failDuplicate)return -50;assert(target==10);active=20;}if(e==eventDelete)assert(target==20);if(e==eventSelect)active=target;if(e==2){assert(dlssLayerTransaction);return failure;}return 0;};

 static PIEventNotifier notifier=nullptr;static int posts=0;
 control.AddNotify=[](SPPluginRef,DescriptorEventID,PIEventNotifier n,void*)->OSErr{notifier=n;return 0;};
 control.RemoveNotify=[](SPPluginRef,DescriptorEventID)->OSErr{notifier=nullptr;return 0;};
 control.PostCommand=[](SPPluginRef,DescriptorEventID,PIActionDescriptor,PIDialogPlayOptions,PICommandNotifier,void*,uint32*)->OSErr{posts++;return 0;};
 SPMessageData startup{};startup.basic=&basic;startup.self=(SPPluginRef)9;
 assert(AutoPluginMain(kSPInterfaceCaller,kSPInterfaceStartupSelector,&startup)==0);assert(DLSSListenerReady());
 notifier(previewEvent,nullptr,(PIDialogRecordOptions)0,nullptr);assert(posts==0); // cancel/no apply
 pendingResult.pixels={1,2,3,255};
 notifier(previewEvent+1,nullptr,(PIDialogRecordOptions)0,nullptr);assert(posts==0);
 notifier(previewEvent,nullptr,(PIDialogRecordOptions)0,nullptr);assert(posts==1&&events.empty());
 notifier(previewEvent,nullptr,(PIDialogRecordOptions)0,nullptr);assert(posts==1); // no double apply
 SPMessageData msg{};msg.basic=&basic;
 assert(AutoPluginMain(kPSPhotoshopCaller,kPSDoIt,&msg)==0);assert(events.size()==2&&events[0].first==eventDuplicate&&events[1].first==2&&active==20);
 events.clear();active=10;failure=userCanceledErr;commandQueued=true;pendingResult.pixels={1};
 assert(AutoPluginMain(kPSPhotoshopCaller,kPSDoIt,&msg)==userCanceledErr);assert(events.size()==4&&events[2]==std::make_pair(uint32(eventDelete),uint32(20))&&active==10);
 events.clear();active=10;failDuplicate=true;commandQueued=true;pendingResult.pixels={1};
 assert(AutoPluginMain(kPSPhotoshopCaller,kPSDoIt,&msg)==-50);assert(events.size()==1&&active==10);

 descriptor.PutUnitFloat=[](PIActionDescriptor,DescriptorKeyID key,DescriptorUnitID unit,real64 value)->OSErr{assert(unit==unitPixels);assert(value==(key==keyWidth?200:100));return 0;};
 descriptor.PutBoolean=[](PIActionDescriptor,DescriptorKeyID,Boolean)->OSErr{return 0;};
 descriptor.PutEnumerated=[](PIActionDescriptor,DescriptorKeyID,DescriptorEnumTypeID,DescriptorEnumID)->OSErr{return 0;};
 reference.PutIndex=[](PIActionReference,DescriptorClassID cls,uint32 index)->OSErr{assert(cls==classHistoryState&&index==10);target=index;return 0;};
 events.clear();active=10;failDuplicate=false;failure=0;commandQueued=true;pendingResult.pixels={1};pendingResult.scale=2;pendingResult.width=200;pendingResult.height=100;
 assert(AutoPluginMain(kPSPhotoshopCaller,kPSDoIt,&msg)==0);assert(events.size()==3&&events[0].first==eventImageSize&&events[1].first==eventDuplicate);
 events.clear();active=10;failure=-50;commandQueued=true;pendingResult.pixels={1};pendingResult.scale=2;pendingResult.width=200;pendingResult.height=100;
 assert(AutoPluginMain(kPSPhotoshopCaller,kPSDoIt,&msg)==-50);assert(events.size()==4&&events.back().first==eventSelect&&active==10);
 assert(!dlssLayerTransaction);assert(AutoPluginMain(kSPInterfaceCaller,kSPInterfaceShutdownSelector,&startup)==0);assert(!DLSSListenerReady());puts("PASS: duplicate before filter, success retains result layer, cancel removes only duplicate and restores source, duplicate failure never runs filter");}}
