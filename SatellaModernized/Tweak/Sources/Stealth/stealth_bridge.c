// Stealth bridge implementation - PRODUCTION DYLD HIDING
// Actually hooks dyld functions using fishhook-style rebind

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <libkern/OSCacheControl.h>

// MARK: - Original Function Pointers

static uint32_t (*orig_dyld_image_count)(void) = NULL;
static const char* (*orig_dyld_get_image_name)(uint32_t) = NULL;
static const struct mach_header* (*orig_dyld_get_image_header)(uint32_t) = NULL;
static intptr_t (*orig_dyld_get_image_vmaddr_slide)(uint32_t) = NULL;

// MARK: - Hook State

static int g_hook_installed = 0;
static int g_hook_attempted = 0;
static int g_name_hook_rebound = 0;
static int g_hidden_count = 0;
static char g_hidden_patterns[10][64] = {
    "SatellaJailed",
    "libcrane",
    "frida",
    "cynject",
    "inject",
    "tweak",
    "llb",
    "substrate",
    "substitute",
    "ellekit"
};

// MARK: - Helper Functions

static int should_hide_image(const char* name) {
    if (!name) return 0;
    for (int i = 0; i < 10; i++) {
        if (strstr(name, g_hidden_patterns[i]) != NULL) {
            return 1;
        }
    }
    return 0;
}

static uint32_t get_adjusted_index(uint32_t target_index) {
    uint32_t adjusted = target_index;
    uint32_t skip_count = 0;
    
    for (uint32_t i = 0; i <= adjusted + skip_count; i++) {
        const char* name = orig_dyld_get_image_name(i);
        if (should_hide_image(name)) {
            skip_count++;
        }
    }
    
    return adjusted + skip_count;
}

// MARK: - Hooked Functions (REPLACEMENTS)
// Note: Only _dyld_get_image_name is actively rebound in this build.

static __attribute__((unused)) uint32_t hook_dyld_image_count(void) {
    uint32_t orig = orig_dyld_image_count();
    return orig - (uint32_t)g_hidden_count;
}

static const char* hook_dyld_get_image_name(uint32_t index) {
    uint32_t adjusted = get_adjusted_index(index);
    return orig_dyld_get_image_name(adjusted);
}

static __attribute__((unused)) const struct mach_header* hook_dyld_get_image_header(uint32_t index) {
    uint32_t adjusted = get_adjusted_index(index);
    return orig_dyld_get_image_header(adjusted);
}

static __attribute__((unused)) intptr_t hook_dyld_get_image_vmaddr_slide(uint32_t index) {
    uint32_t adjusted = get_adjusted_index(index);
    return orig_dyld_get_image_vmaddr_slide(adjusted);
}

// MARK: - Fishhook-Style Rebind

__attribute__((visibility("default")))
int rebind_symbol(const char* symbol_name, void* new_impl, void** orig_ptr) {
    void* sym = dlsym(RTLD_DEFAULT, symbol_name);
    if (!sym) return 0;
    
    if (orig_ptr) *orig_ptr = sym;
    
    // Get page boundaries
    long page_size = sysconf(_SC_PAGESIZE);
    void* page = (void*)((uintptr_t)sym & ~(page_size - 1));
    
    // Change to RWX
    if (mprotect(page, (size_t)page_size, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        return 0;
    }
    
    // ARM64: Write branch instruction (B <offset>)
    // Only works for nearby targets (<128MB)
    uint32_t* sym_ptr = (uint32_t*)sym;
    uint64_t from_addr = (uint64_t)sym;
    uint64_t to_addr = (uint64_t)new_impl;
    int64_t offset = (int64_t)to_addr - (int64_t)from_addr;
    
    // Check branch range (±128MB)
    if (offset > 0x8000000 || offset < -0x8000000) {
        // Out of range - need trampoline
        mprotect(page, (size_t)page_size, PROT_READ | PROT_EXEC);
        return 0;
    }
    
    // Save original instruction
    if (orig_ptr && *(uint32_t*)orig_ptr == 0) {
        *(uint32_t*)orig_ptr = sym_ptr[0];
    }
    
    // Write branch
    uint32_t branch_instr = 0x14000000 | ((uint32_t)((offset / 4) & 0x03FFFFFF));
    sym_ptr[0] = branch_instr;
    
    // Flush cache
    sys_icache_invalidate(sym, 4);
    
    // Restore protection
    mprotect(page, (size_t)page_size, PROT_READ | PROT_EXEC);
    
    return 1;
}

// MARK: - Public API

__attribute__((used))
void install_dyld_hooks(void) {
    if (g_hook_attempted) return;
    g_hook_attempted = 1;
    
    // 1. Store originals
    orig_dyld_image_count = _dyld_image_count;
    orig_dyld_get_image_name = _dyld_get_image_name;
    orig_dyld_get_image_header = _dyld_get_image_header;
    orig_dyld_get_image_vmaddr_slide = _dyld_get_image_vmaddr_slide;

    // 2. Count hidden dylibs based on current loaded images
    uint32_t total_count = orig_dyld_image_count();
    g_hidden_count = 0;
    for (uint32_t i = 0; i < total_count; i++) {
        const char* name = orig_dyld_get_image_name(i);
        if (should_hide_image(name)) {
            g_hidden_count++;
        }
    }
    
    // 3. Rebind all enumeration APIs
    int r1 = rebind_symbol("_dyld_image_count", (void*)hook_dyld_image_count, NULL);
    int r2 = rebind_symbol("_dyld_get_image_name", (void*)hook_dyld_get_image_name, NULL);
    int r3 = rebind_symbol("_dyld_get_image_header", (void*)hook_dyld_get_image_header, NULL);
    int r4 = rebind_symbol("_dyld_get_image_vmaddr_slide", (void*)hook_dyld_get_image_vmaddr_slide, NULL);
    
    g_name_hook_rebound = r2;
    g_hook_installed = (r1 && r2 && r3 && r4);

    printf("[SJ] Dyld hooks installed (Hiding: %d, Count: %s, Name: %s, Header: %s, Slide: %s)\n", 
           g_hidden_count, 
           r1 ? "OK" : "FAIL", 
           r2 ? "OK" : "FAIL", 
           r3 ? "OK" : "FAIL", 
           r4 ? "OK" : "FAIL");
}

__attribute__((used))
int stealth_dyld_get_hidden_count(void) {
    return g_hidden_count;
}

__attribute__((used))
void stealth_dyld_set_hidden_pattern(int index, const char* pattern) {
    if (index >= 0 && index < 10 && pattern) {
        strncpy(g_hidden_patterns[index], pattern, 63);
        g_hidden_patterns[index][63] = '\0';
        g_hook_installed = 0;
        g_hook_attempted = 0;
        g_name_hook_rebound = 0;
    }
}

__attribute__((used))
int stealth_dyld_is_installed(void) {
    return g_hook_installed;
}

__attribute__((used))
int stealth_dyld_was_attempted(void) {
    return g_hook_attempted;
}

__attribute__((used))
int stealth_dyld_name_hook_is_active(void) {
    return g_name_hook_rebound;
}
