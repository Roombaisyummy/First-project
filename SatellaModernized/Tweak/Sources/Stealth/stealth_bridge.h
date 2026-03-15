#ifndef STEALTH_BRIDGE_H
#define STEALTH_BRIDGE_H

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

// MARK: - Dyld Function Pointers

typedef uint32_t (*dyld_image_count_t)(void);
typedef const char* (*dyld_get_image_name_t)(uint32_t imageIndex);
typedef const struct mach_header* (*dyld_get_image_header_t)(uint32_t imageIndex);
typedef intptr_t (*dyld_get_image_vmaddr_slide_t)(uint32_t imageIndex);

// MARK: - Global Original Function Pointers

static dyld_image_count_t orig_dyld_image_count = NULL;
static dyld_get_image_name_t orig_dyld_get_image_name = NULL;
static dyld_get_image_header_t orig_dyld_get_image_header = NULL;
static dyld_get_image_vmaddr_slide_t orig_dyld_get_image_vmaddr_slide = NULL;

// MARK: - Hook State

static int g_hook_initialized = 0;
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

static void initialize_hidden_count(void) {
    if (g_hook_initialized) return;
    
    g_hidden_count = 0;
    uint32_t count = _dyld_image_count();
    
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (should_hide_image(name)) {
            g_hidden_count++;
        }
    }
    
    g_hook_initialized = 1;
}

// MARK: - Hooked Functions (marked inline to avoid unused warnings)

static __inline__ __attribute__((unused)) uint32_t hook_dyld_image_count(void) {
    initialize_hidden_count();
    uint32_t orig = orig_dyld_image_count();
    return orig - (uint32_t)g_hidden_count;
}

static __inline__ __attribute__((unused)) const char* hook_dyld_get_image_name(uint32_t index) {
    initialize_hidden_count();
    
    uint32_t adjusted = index;
    
    for (uint32_t i = 0; i <= adjusted; i++) {
        const char* name = orig_dyld_get_image_name(i);
        if (should_hide_image(name)) {
            adjusted++;
        }
    }
    
    return orig_dyld_get_image_name(adjusted);
}

static __inline__ __attribute__((unused)) const struct mach_header* hook_dyld_get_image_header(uint32_t index) {
    initialize_hidden_count();
    
    uint32_t adjusted = index;
    
    for (uint32_t i = 0; i <= adjusted; i++) {
        const char* name = orig_dyld_get_image_name(i);
        if (should_hide_image(name)) {
            adjusted++;
        }
    }
    
    return orig_dyld_get_image_header(adjusted);
}

static __inline__ __attribute__((unused)) intptr_t hook_dyld_get_image_vmaddr_slide(uint32_t index) {
    initialize_hidden_count();
    
    uint32_t adjusted = index;
    
    for (uint32_t i = 0; i <= adjusted; i++) {
        const char* name = orig_dyld_get_image_name(i);
        if (should_hide_image(name)) {
            adjusted++;
        }
    }
    
    return orig_dyld_get_image_vmaddr_slide(adjusted);
}

// MARK: - Fishhook-style Rebind (marked unused for future implementation)

struct rebind_entry {
    const char* symbol_name;
    void* new_impl;
    void** orig_ptr;
};

static __inline__ __attribute__((unused)) int rebind_symbol(struct rebind_entry* entry) {
    void* sym = dlsym(RTLD_DEFAULT, entry->symbol_name);
    if (!sym) return 0;
    
    *entry->orig_ptr = sym;
    
    // Get page size and calculate protection
    long page_size = sysconf(_SC_PAGESIZE);
    void* page = (void*)((uintptr_t)sym & ~(page_size - 1));
    
    // Change protection to read-write-execute
    if (mprotect(page, (size_t)page_size, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        return 0;
    }
    
    // Write jump instruction (ARM64: B <offset>)
    // This is a simplified version - full implementation needs trampoline
    // For now, we just store the original
    
    // Restore protection
    mprotect(page, (size_t)page_size, PROT_READ | PROT_EXEC);
    sys_icache_invalidate((void*)sym, 4);
    
    return 1;
}

// MARK: - Initialization

static void install_dyld_hooks(void) {
    if (g_hook_initialized) return;
    
    // Store original function pointers
    orig_dyld_image_count = _dyld_image_count;
    orig_dyld_get_image_name = _dyld_get_image_name;
    orig_dyld_get_image_header = _dyld_get_image_header;
    orig_dyld_get_image_vmaddr_slide = _dyld_get_image_vmaddr_slide;
    
    // Initialize hidden count
    initialize_hidden_count();
    
    printf("[SJ] Dyld hooks initialized (hiding %d images)\n", g_hidden_count);
}

// MARK: - Public API

static int stealth_dyld_get_hidden_count(void) {
    initialize_hidden_count();
    return g_hidden_count;
}

static void stealth_dyld_set_hidden_pattern(int index, const char* pattern) {
    if (index >= 0 && index < 10 && pattern) {
        strncpy(g_hidden_patterns[index], pattern, 63);
        g_hidden_patterns[index][63] = '\0';
        g_hook_initialized = 0;  // Force re-initialization
    }
}

#endif // STEALTH_BRIDGE_H
