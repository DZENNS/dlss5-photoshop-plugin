#pragma once
#include <vector>
#include <cstdint>
#include <functional>
std::vector<uint8_t> Upscale2(const std::vector<uint8_t>&rgba,int w,int h,const char*model,const std::function<bool(int,int)>&progress);
