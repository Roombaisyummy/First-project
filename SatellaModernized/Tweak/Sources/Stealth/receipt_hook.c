#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <errno.h>

// Forward declare rebind_symbol from stealth_bridge.c
extern int rebind_symbol(const char* symbol_name, void* new_impl, void** orig_ptr);

// Forged binary bridge from ReceiptGenerator.swift
extern void* stealth_get_receipt_binary(size_t* size);

static const char* GHOST_PATH = "SATELLA_GHOST_RECEIPT";

static int is_receipt_path(const char* path) {
    if (!path) return 0;
    if (strstr(path, GHOST_PATH) != NULL) return 1;
    if (strstr(path, "/receipt") != NULL) return 1;
    return 0;
}

// MARK: - Originals

typedef int (*stat_t)(const char*, struct stat*);
static stat_t orig_stat = NULL;

typedef int (*access_t)(const char*, int);
static access_t orig_access = NULL;

typedef int (*open_t)(const char*, int, mode_t);
static open_t orig_open = NULL;

typedef ssize_t (*read_t)(int, void*, size_t);
static read_t orig_read = NULL;

typedef int (*close_t)(int);
static close_t orig_close = NULL;

// MARK: - State

static int g_fake_fd = -1337;
static size_t g_fake_pos = 0;

// MARK: - Hooked Functions

int h_stat(const char* path, struct stat* buf) {
    if (is_receipt_path(path)) {
        size_t size = 0;
        stealth_get_receipt_binary(&size);
        memset(buf, 0, sizeof(struct stat));
        buf->st_size = (off_t)size;
        buf->st_mode = S_IFREG | S_IRUSR | S_IRGRP | S_IROTH;
        buf->st_nlink = 1;
        buf->st_uid = 501;
        buf->st_gid = 501;
        return 0;
    }
    return orig_stat(path, buf);
}

int h_access(const char* path, int mode) {
    if (is_receipt_path(path)) return 0;
    return orig_access(path, mode);
}

int h_open(const char* path, int flags, mode_t mode) {
    if (is_receipt_path(path)) {
        g_fake_pos = 0;
        return g_fake_fd;
    }
    return orig_open(path, flags, mode);
}

ssize_t h_read(int fd, void* buf, size_t count) {
    if (fd == g_fake_fd) {
        size_t size = 0;
        void* data = stealth_get_receipt_binary(&size);
        if (g_fake_pos >= size) return 0;
        
        size_t to_read = count;
        if (g_fake_pos + to_read > size) {
            to_read = size - g_fake_pos;
        }
        
        memcpy(buf, (char*)data + g_fake_pos, to_read);
        g_fake_pos += to_read;
        return (ssize_t)to_read;
    }
    return orig_read(fd, buf, count);
}

int h_close(int fd) {
    if (fd == g_fake_fd) {
        g_fake_pos = 0;
        return 0;
    }
    return orig_close(fd);
}

// MARK: - API

__attribute__((used))
void install_posix_receipt_hooks(void) {
    rebind_symbol("stat", (void*)h_stat, (void**)&orig_stat);
    rebind_symbol("access", (void*)h_access, (void**)&orig_access);
    rebind_symbol("open", (void*)h_open, (void**)&orig_open);
    rebind_symbol("read", (void*)h_read, (void**)&orig_read);
    rebind_symbol("close", (void*)h_close, (void**)&orig_close);
}
