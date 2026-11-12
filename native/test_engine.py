"""Exercise the actual dylib in-process, without Photoshop or a helper app."""
import ctypes as c, json, threading, sys
from pathlib import Path
root=Path(sys.argv[1]).resolve()
lib=c.CDLL(str(root/'Engine/libDLSSPhotoshopNative.dylib'))
callback=c.CFUNCTYPE(None,c.c_void_p,c.POINTER(c.c_ubyte),c.c_size_t,c.c_char_p)
lib.dlss5_process.argtypes=[c.POINTER(c.c_ubyte),c.c_size_t,c.c_int32,c.c_int32,c.c_int32,c.c_char_p,c.c_char_p,c.c_void_p,callback]
lib.dlss5_process.restype=None
w,h=128,96
source=bytes(v for y in range(h) for x in range(w) for v in (x*2,y*2,(x+y)%256,(x*3+y)%256))
arr=(c.c_ubyte*len(source)).from_buffer_copy(source)
def run(strength):
    done=threading.Event();result={}
    @callback
    def complete(ctx,data,size,error):
        result.update(error=error.decode() if error else None,pixels=c.string_at(data,size) if data else b'');done.set()
    settings=json.dumps({'intensity':strength,'processingLongEdge':512,'temporal':False}).encode()
    lib.dlss5_process(arr,len(source),w,h,4,settings,str(root).encode(),None,complete)
    assert done.wait(120),'native timeout'
    assert not result['error'],result['error']
    out=result['pixels'];assert len(out)==len(source)
    assert out[3::4]==source[3::4],'alpha changed'
    if strength==0: assert out==source,'identity changed pixels'
    else: assert out!=source,'neural pass returned original'
    print('PASS strength',strength,'bytes',len(out),'alpha preserved',flush=True)
run(0)
run(1)
