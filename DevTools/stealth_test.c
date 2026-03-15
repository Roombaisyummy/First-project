#include <stdio.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <dlfcn.h>
#include <objc/runtime.h>

void test_dyld_enumeration() {
    printf("\n[1] Testing Dyld Enumeration...\n");
    uint32_t count = _dyld_image_count();
    int found = 0;
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "SatellaJailed")) {
            printf("  ❌ BUSTED: Found dylib at index %d: %s\n", i, name);
            found = 1;
        }
    }
    if (!found) printf("  ✅ SUCCESS: SatellaJailed is hidden from enumeration (Count: %d)\n", count);
}

void test_imp_integrity() {
    printf("\n[2] Testing IMP Integrity (SKPaymentTransaction)...\n");
    Class cls = objc_getClass("SKPaymentTransaction");
    if (!cls) {
        printf("  ℹ️ SKPaymentTransaction not loaded in this process.\n");
        return;
    }
    Method method = class_getInstanceMethod(cls, sel_registerName("transactionState"));
    if (!method) {
        printf("  ❌ Failed to find method.\n");
        return;
    }
    void* imp = (void*)method_getImplementation(method);
    Dl_info info;
    if (dladdr(imp, &info)) {
        printf("  IMP Location: %s\n", info.dli_fname);
        if (strstr(info.dli_fname, "StoreKit")) {
            printf("  ✅ SUCCESS: IMP points to official StoreKit (Inline hook working)\n");
        } else {
            printf("  ⚠️ DETECTED: IMP points to %s (Swizzling detected)\n", info.dli_fname);
        }
    }
}

void test_inline_hook_detection() {
    printf("\n[3] Testing Inline Hook Detection (_dyld_get_image_name)...\n");
    void* addr = dlsym(RTLD_DEFAULT, "_dyld_get_image_name");
    if (!addr) {
        printf("  ❌ Failed to find symbol.\n");
        return;
    }
    unsigned int* ptr = (unsigned int*)addr;
    printf("  First Instruction: 0x%08X\n", *ptr);
    if (*ptr == 0x58000050) {
        printf("  ⚠️ DETECTED: Absolute Jump Hook (LDR X16) found!\n");
    } else if ((*ptr & 0xFC000000) == 0x14000000) {
        printf("  ⚠️ DETECTED: Relative Branch Hook (B) found!\n");
    } else {
        printf("  ✅ SUCCESS: Function prologue looks clean.\n");
    }
}

int main() {
    printf("=== SatellaJailed Modernized: Stealth Integrity Test ===\n");
    test_dyld_enumeration();
    test_imp_integrity();
    test_inline_hook_detection();
    printf("\nDone.\n");
    return 0;
}
