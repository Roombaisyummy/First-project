// Inline hook implementation
// Exposes ARM64 inline hooking to Swift

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>
#include <sys/mman.h>

// MARK: - ARM64 Instructions

static inline void make_absolute_jump(uint32_t* buf, uint64_t target) {
    // LDR X16, #8 (Load next 8 bytes into X16)
    buf[0] = 0x58000050;
    // BR X16 (Branch to X16)
    buf[1] = 0xD61F0200;
    // Lower 32 bits of target
    buf[2] = (uint32_t)(target & 0xFFFFFFFF);
    // Upper 32 bits of target
    buf[3] = (uint32_t)(target >> 32);
}

// MARK: - Hook Structure

typedef struct inline_hook {
    void* target;
    void* replacement;
    void* trampoline;
    uint8_t original_bytes[16];
    int instruction_count;
    int is_installed;
    char name[64];
} inline_hook_t;

static inline_hook_t g_hooks[32];
static int g_hook_count = 0;

static void clear_hook_entry(inline_hook_t* hook) {
    memset(hook, 0, sizeof(inline_hook_t));
}

// MARK: - Memory Protection

static int change_memory_protection(void* addr, size_t size, vm_prot_t prot) {
    vm_size_t page_size = vm_page_size;
    uintptr_t page_start = (uintptr_t)addr & ~(page_size - 1);
    size_t page_count = ((uintptr_t)addr + size - page_start + page_size - 1) / page_size;
    
    kern_return_t kr = vm_protect(mach_task_self_, 
                                   (vm_address_t)page_start, 
                                   page_count * page_size, 
                                   0, 
                                   prot);
    return (kr == KERN_SUCCESS) ? 1 : 0;
}

static int with_write_access(void* addr, size_t size, void (^block)(void)) {
    if (!change_memory_protection(addr, size, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE)) {
        return 0;
    }
    
    block();
    
    change_memory_protection(addr, size, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate(addr, size);
    
    return 1;
}

// MARK: - Trampoline Creation

static void* create_trampoline(void* target, int instruction_count) {
    if (instruction_count != 4) {
        return NULL;
    }
    
    // We need space for 4 original instructions + 4 for the jump back
    size_t trampoline_size = 8 * 4;
    
    void* trampoline = mmap(NULL, trampoline_size,
                           PROT_READ | PROT_WRITE | PROT_EXEC,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (trampoline == MAP_FAILED) {
        return NULL;
    }
    
    uint32_t* target_ptr = (uint32_t*)target;
    uint32_t* tramp_ptr = (uint32_t*)trampoline;
    
    // 1. Copy original 4 instructions
    for (int i = 0; i < instruction_count; i++) {
        tramp_ptr[i] = target_ptr[i];
    }
    
    // 2. Add absolute jump back to (target + 16)
    uint64_t branch_back_addr = (uint64_t)target + 16;
    make_absolute_jump(&tramp_ptr[4], branch_back_addr);
    
    sys_icache_invalidate(trampoline, trampoline_size);
    
    return trampoline;
}

// MARK: - Hook Installation

static inline_hook_t* install_inline_hook(const char* name, void* target, void* replacement, int instruction_count) {
    if (g_hook_count >= 32 || instruction_count != 4) {
        return NULL;
    }
    
    inline_hook_t* hook = &g_hooks[g_hook_count];
    
    memset(hook, 0, sizeof(inline_hook_t));
    hook->target = target;
    hook->replacement = replacement;
    hook->instruction_count = instruction_count;
    strncpy(hook->name, name, 63);
    hook->name[63] = '\0';
    
    // Save original 16 bytes
    memcpy(hook->original_bytes, target, 16);
    
    hook->trampoline = create_trampoline(target, instruction_count);
    if (!hook->trampoline) {
        return NULL;
    }
    
    uint64_t replacement_addr = (uint64_t)replacement;
    
    with_write_access(target, 16, ^{
        uint32_t* ptr = (uint32_t*)target;
        make_absolute_jump(ptr, replacement_addr);
        sys_icache_invalidate(target, 16);
    });
    
    hook->is_installed = 1;
    g_hook_count++;
    
    printf("[InlineHook] Installed: %s at %p -> %p (trampoline: %p)\n", 
           name, target, replacement, hook->trampoline);
    
    return hook;
}

// MARK: - Public API

__attribute__((used))
void* stealth_hook_install(const char* name, void* target, void* replacement) {
    inline_hook_t* hook = install_inline_hook(name, target, replacement, 4);
    // Return TRAMPOLINE (for calling original), not replacement
    return hook ? hook->trampoline : NULL;
}

__attribute__((used))
int stealth_hook_remove(const char* name) {
    for (int i = 0; i < g_hook_count; i++) {
        inline_hook_t* hook = &g_hooks[i];
        
        if (strcmp(hook->name, name) == 0 && hook->is_installed) {
            with_write_access(hook->target, (size_t)(hook->instruction_count * 4), ^{
                memcpy(hook->target, hook->original_bytes, (size_t)(hook->instruction_count * 4));
                sys_icache_invalidate(hook->target, (size_t)(hook->instruction_count * 4));
            });
            
            munmap(hook->trampoline, (size_t)vm_page_size);
            clear_hook_entry(hook);
            
            printf("[InlineHook] Removed: %s\n", name);
            return 1;
        }
    }
    return 0;
}

__attribute__((used))
void* stealth_hook_trampoline(const char* name) {
    for (int i = 0; i < g_hook_count; i++) {
        if (strcmp(g_hooks[i].name, name) == 0) {
            return g_hooks[i].trampoline;
        }
    }
    return NULL;
}

__attribute__((used))
void stealth_hook_remove_all(void) {
    for (int i = 0; i < g_hook_count; i++) {
        inline_hook_t* hook = &g_hooks[i];
        if (hook->is_installed) {
            stealth_hook_remove(hook->name);
        }
    }
    memset(g_hooks, 0, sizeof(g_hooks));
    g_hook_count = 0;
}

__attribute__((used))
int stealth_hook_is_installed(const char* name) {
    for (int i = 0; i < g_hook_count; i++) {
        if (strcmp(g_hooks[i].name, name) == 0) {
            return g_hooks[i].is_installed;
        }
    }
    return 0;
}

__attribute__((used))
int stealth_hook_get_count(void) {
    return g_hook_count;
}
