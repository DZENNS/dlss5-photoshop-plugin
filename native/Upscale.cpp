#include "Upscale.h"
#include "onnxruntime_cxx_api.h"
#include "coreml_provider_factory.h"
#include <algorithm>
#include <array>
#include <stdexcept>
std::vector<uint8_t> Upscale2(const std::vector<uint8_t>&rgba,int w,int h,const char*model,const std::function<bool(int,int)>&progress){
 if(w<=0||h<=0||int64_t(w)*h>24000000||rgba.size()!=size_t(w)*h*4)throw std::runtime_error("Invalid upscale input");
 Ort::Env env(ORT_LOGGING_LEVEL_WARNING,"DLSS5 Upscale");Ort::SessionOptions options;options.SetIntraOpNumThreads(2);
 // Core ML maps supported operations to Apple hardware; unsupported nodes use CPU.
 Ort::ThrowOnError(OrtSessionOptionsAppendExecutionProvider_CoreML(options,0));
 Ort::Session session(env,model,options);auto memory=Ort::MemoryInfo::CreateCpu(OrtArenaAllocator,OrtMemTypeDefault);
 constexpr int tile=128,pad=96,n=tile+pad*2;std::array<int64_t,4> shape={1,3,n,n};
 std::vector<float> in(3*n*n);std::vector<uint8_t> out(size_t(w)*h*16);
 const char*inputs[]={"input"};const char*outputs[]={"output"};int done=0,total=((w+tile-1)/tile)*((h+tile-1)/tile);
 for(int y=0;y<h;y+=tile)for(int x=0;x<w;x+=tile){
  if(!progress(done,total))throw std::runtime_error("Cancelled");
  for(int yy=0;yy<n;yy++)for(int xx=0;xx<n;xx++){int sy=std::clamp(y+yy-pad,0,h-1),sx=std::clamp(x+xx-pad,0,w-1);for(int c=0;c<3;c++)in[c*n*n+yy*n+xx]=rgba[(size_t(sy)*w+sx)*4+c]/255.f;}
  auto tensor=Ort::Value::CreateTensor<float>(memory,in.data(),in.size(),shape.data(),shape.size());auto result=session.Run(Ort::RunOptions{nullptr},inputs,&tensor,1,outputs,1);auto dims=result[0].GetTensorTypeAndShapeInfo().GetShape();if(dims!=std::vector<int64_t>({1,3,n*2,n*2}))throw std::runtime_error("Unexpected upscale dimensions");const float*p=result[0].GetTensorData<float>();
  for(int yy=0;yy<std::min(tile,h-y)*2;yy++)for(int xx=0;xx<std::min(tile,w-x)*2;xx++){size_t dst=(size_t(y*2+yy)*(w*2)+x*2+xx)*4;for(int c=0;c<3;c++)out[dst+c]=uint8_t(std::clamp(p[c*n*n*4+(yy+pad*2)*(n*2)+xx+pad*2]*255.f+0.5f,0.f,255.f));out[dst+3]=rgba[(size_t(y+yy/2)*w+x+xx/2)*4+3];}done++;
 }
 if(!progress(total,total))throw std::runtime_error("Cancelled");return out;
}
