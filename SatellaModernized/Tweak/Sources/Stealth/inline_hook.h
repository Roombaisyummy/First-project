#ifndef INLINE_HOOK_H
#define INLINE_HOOK_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>
#include <sys/mman.h>

// MARK: - ARM64 Instructions

static inline uint32_t make_branch_instruction(uint64_t from, uint64_t to) {
    int64_t offset = (int64_t)to - (int64_t)from;
    uint32_t encoded = (uint32_t)((offset / 4) & 0x03FFFFFF);
    return 0x14000000 | encoded;  // B <imm26>
}

static inline uint32_t make_branch_link_instruction(uint64_t from, uint64_t to) {
    int64_t offset = (int64_t)to - (int64_t)from;
    uint32_t encoded = (uint32_t)((offset / 4) & 0x03FFFFFF);
    return 0x94000000 | encoded;  // BL <imm26>
}

static inline uint32_t make_nop_instruction(void) {
    return 0xD503201F;  // NOP
}

static inline uint32_t make_ret_instruction(void) {
    return 0xD65F03C0;  // RET
}

static inline uint32_t make_br_x17_instruction(void) {
    return 0xD61F0220;  // BR X17
}

// MARK: - Hook Structure

typedef struct inline_hook {
    void* target;
    void* replacement;
    void* trampoline;
    uint8_t original_bytes[16];  // Save up to 4 instructions
    int instruction_count;
    int is_installed;
    char name[64];
} inline_hook_t;

static inline_hook_t g_hooks[32];  // Max 32 hooks
static int g_hook_count = 0;

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
    // Set to RWX
    if (!change_memory_protection(addr, size, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE)) {
        return 0;
    }
    
    block();
    
    // Restore to RX
    change_memory_protection(addr, size, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate(addr, size);
    
    return 1;
}

// MARK: - Trampoline Creation

static void* create_trampoline(void* target, int instruction_count) {
    if (instruction_count <= 0 || instruction_count > 4) {
        return NULL;
    }
    
    size_t trampoline_size = (instruction_count + 4) * 4;  // Original + branch back + padding
    
    // Allocate executable memory
    void* trampoline = mmap(NULL, trampoline_size,
                           PROT_READ | PROT_WRITE | PROT_EXEC,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (trampoline == MAP_FAILED) {
        return NULL;
    }
    
    uint32_t* target_ptr = (uint32_t*)target;
    uint32_t* tramp_ptr = (uint32_t*)trampoline;
    
    // Copy original instructions
    for (int i = 0; i < instruction_count; i++) {
        tramp_ptr[i] = target_ptr[i];
    }
    
    // Add branch back to target (after the hook)
    uint64_t branch_back_addr = (uint64_t)target + (instruction_count * 4);
    uint64_t tramp_branch_addr = (uint64_t)trampoline + (instruction_count * 4);
    tramp_ptr[instruction_count] = make_branch_instruction(tramp_branch_addr, branch_back_addr);
    
    // Padding
    for (int i = 1; i < 4; i++) {
        tramp_ptr[instruction_count + i] = make_nop_instruction();
    }
    
    sys_icache_invalidate(trampoline, trampoline_size);
    
    return trampoline;
}

// MARK: - Hook Installation

static inline_hook_t* install_inline_hook(const char* name, void* target, void* replacement, int instruction_count) {
    if (g_hook_count >= 32 || instruction_count <= 0 || instruction_count > 4) {
        return NULL;
    }
    
    inline_hook_t* hook = &g_hooks[g_hook_count];
    
    // Initialize hook structure
    memset(hook, 0, sizeof(inline_hook_t));
    hook->target = target;
    hook->replacement = replacement;
    hook->instruction_count = instruction_count;
    strncpy(hook->name, name, 63);
    hook->name[63] = '\0';
    
    // Save original bytes
    memcpy(hook->original_bytes, target, instruction_count * 4);
    
    // Create trampoline
    hook->trampoline = create_trampoline(target, instruction_count);
    if (!hook->trampoline) {
        return NULL;
    }
    
    // Write hook (branch to replacement)
    uint64_t target_addr = (uint64_t)target;
    uint64_t replacement_addr = (uint64_t)replacement;
    
    with_write_access(target, instruction_count * 4, ^{
        uint32_t* ptr = (uint32_t*)target;
        
        for (int i = 0; i < instruction_count; i++) {
            if (i == 0) {
                ptr[i] = make_branch_instruction(target_addr, replacement_addr);
            } else {
                ptr[i] = make_nop_instruction();
            }
        }
        
        sys_icache_invalidate(target, instruction_count * 4);
    });
    
    hook->is_installed = 1;
    g_hook_count++;
    
    printf("[InlineHook] Installed: %s at %p -> %p (trampoline: %p)\n", 
           name, target, replacement, hook->trampoline);
    
    return hook;
}

static int remove_inline_hook(const char* name) {
    for (int i = 0; i < g_hook_count; i++) {
        inline_hook_t* hook = &g_hooks[i];
        
        if (strcmp(hook->name, name) == 0) {
            if (hook->is_installed) {
                // Restore original bytes
                with_write_access(hook->target, hook->instruction_count * 4, ^{
                    memcpy(hook->target, hook->original_bytes, hook->instruction_count * 4);
                    sys_icache_invalidate(hook->target, hook->instruction_count * 4);
                });
                
                // Free trampoline
                munmap(hook->trampoline, vm_page_size);
                
                hook->is_installed = 0;
                printf("[InlineHook] Removed: %s\n", name);
                return 1;
            }
        }
    }
    return 0;
}

static void* get_hook_trampoline(const char* name) {
    for (int i = 0; i < g_hook_count; i++) {
        if (strcmp(g_hooks[i].name, name) == 0) {
            return g_hooks[i].trampoline;
        }
    }
    return NULL;
}

static void remove_all_hooks(void) {
    for (int i = 0; i < g_hook_count; i++) {
        inline_hook_t* hook = &g_hooks[i];
        if (hook->is_installed) {
            remove_inline_hook(hook->name);
        }
    }
}

static int is_hook_installed(const char* name) {
    for (int i = 0; i < g_hook_count; i++) {
        if (strcmp(g_hooks[i].name, name) == 0) {
            return g_hooks[i].is_installed;
        }
    }
    return 0;
}

static int get_hook_count(void) {
    return g_hook_count;
}

// MARK: - Public API

static void* stealth_hook_install(const char* name, void* target, void* replacement) {
    return install_inline_hook(name, target, replacement, 4) ? replacement : NULL;
}

static int stealth_hook_remove(const char* name) {
    return remove_inline_hook(name);
}

static void* stealth_hook_trampoline(const char* name) {
    return get_hook_trampoline(name);
}

static void stealth_hook_remove_all(void) {
    remove_all_hooks();
}

static int stealth_hook_is_installed(const char* name) {
    return is_hook_installed(name);
}

static int stealth_hook_get_count(void) {
    return get_hook_count();
}

#endif // INLINE_HOOK_H
