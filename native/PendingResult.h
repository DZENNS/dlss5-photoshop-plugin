#pragma once
#include <vector>
#include <cstdint>
struct PendingResult {
 std::vector<uint8_t> pixels;
 int scale=1;
 int width=0,height=0,left=0,top=0;
 void clear(){pixels.clear();scale=1;width=height=left=top=0;}
};
extern PendingResult pendingResult;
