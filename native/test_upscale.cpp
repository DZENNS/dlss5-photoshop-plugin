#include "Upscale.h"
#include <cassert>
#include <cstdio>
int main(int argc,char**argv){assert(argc==2);std::vector<uint8_t> input(32*32*4,128);for(int i=0;i<32*32;i++)input[i*4+3]=255;auto out=Upscale2(input,32,32,argv[1],[](int a,int b){printf("Tile %d/%d\n",a,b);fflush(stdout);return true;});assert(out.size()==64*64*4);for(int i=0;i<64*64;i++)assert(out[i*4+3]==255);puts("PASS real model x2, size and alpha");}
