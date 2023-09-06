// dllmain.cpp : Define el punto de entrada de la aplicación DLL.
#include "pch.h"
#include "mem.h"
#include "scan.h"
#include <cstring>
#include <cstdlib>

std::vector<uint8_t> convertToBytes(uintptr_t address) {
    std::vector<uint8_t> bytes;
    for (int i = 0; i < sizeof(uintptr_t); ++i) {
        bytes.push_back((address >> (i * 8)) & 0xFF);
    }
    return bytes;
}

DWORD WINAPI Meteoro(HMODULE hModule)
{   
    uintptr_t moduleBase = (uintptr_t)GetModuleHandle(L"acs.exe");    
    uintptr_t moduleBaseDwrite = (uintptr_t)GetModuleHandle(L"dwrite.dll");    

    //Scan signature to find addr conditional method to allow the use of physics lib
    char* shouldAllowPhysicsAddr = scan::ScanModIn((char*)"\x48\x89\x5C\x24\x08\x48\x89\x74\x24\x10\x57\x48\x83\xEC\x20\x65\x48\x8B\x04\x25\x58\x00\x00\x00\x0F\xB6\xF2", (char*)"xxxx?xxxx?xxxx?xxxxx?xxxxxx", "dwrite.dll");
    //your car addr    
    uintptr_t carAddr = mem::FindDMAAddy(moduleBaseDwrite + 0x104DFB0, { 0x0, 0x0, 0x1168, 0x0 });
    //patch shouldAllowMethod, return car value.
    std::vector<uint8_t> patchBytes;
    patchBytes.push_back(0x48);
    patchBytes.push_back(0xB8);
    std::vector<uint8_t> addrBytes = convertToBytes(carAddr);
    patchBytes.insert(patchBytes.end(), addrBytes.begin(), addrBytes.end());
    patchBytes.push_back(0xC3);
    mem::Patch((BYTE*)shouldAllowPhysicsAddr, patchBytes.data(), patchBytes.size());

    //surfaceAddr, has grip value.
    uintptr_t surfacePtr = carAddr + 0xB28 + 0x410;

    uintptr_t surfaceGripAddr = mem::FindDMAAddy(surfacePtr, { 0x90 });
    //grip value, set it in lua, store in lua global variables.
    uintptr_t gripVal = mem::FindDMAAddy(moduleBaseDwrite + 0x104E008, { 0x0, 0x30});

    bool bpatch = false;
    uintptr_t lastGripAddrptr = 0;
    double lastValue = *(double*)gripVal;
    while (true) {

        //get add surface grip value
        uintptr_t surfaceGripAddr = mem::FindDMAAddy(surfacePtr, { 0x90 });
        if (surfaceGripAddr != 0x0000000000000090 && (lastGripAddrptr != surfaceGripAddr || lastValue != *(double*)gripVal)) {
            *(float*)surfaceGripAddr = *(double*)gripVal;
            lastValue = *(double*)gripVal;
            lastGripAddrptr = surfaceGripAddr;
        }
        
        if (GetAsyncKeyState(VK_END) & 1) {
            //eject dll
            break;
        }

        Sleep(10);
    }

    return 0;
}

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    {
        CloseHandle(CreateThread(nullptr, 0, (LPTHREAD_START_ROUTINE)Meteoro, hModule, 0, nullptr));
    }
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}