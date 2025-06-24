//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#ifndef process_shims_h
#define process_shims_h

#include "target_conditionals.h"

#if !TARGET_OS_WINDOWS
#include <unistd.h>

#if _POSIX_SPAWN
#include <spawn.h>
#endif

#if __has_include(<mach/vm_page_size.h>)
vm_size_t _subprocess_vm_size(void);
#endif

#if TARGET_OS_MAC
int _subprocess_spawn(
    pid_t * _Nonnull pid,
    const char * _Nonnull exec_path,
    const posix_spawn_file_actions_t _Nullable * _Nonnull file_actions,
    const posix_spawnattr_t _Nullable * _Nonnull spawn_attrs,
    char * _Nullable const args[_Nonnull],
    char * _Nullable const env[_Nullable],
    uid_t * _Nullable uid,
    gid_t * _Nullable gid,
    int number_of_sgroups, const gid_t * _Nullable sgroups,
    int create_session
);
#endif // TARGET_OS_MAC

int _subprocess_fork_exec(
    pid_t * _Nonnull pid,
    const char * _Nonnull exec_path,
    const char * _Nullable working_directory,
    const int file_descriptors[_Nonnull],
    char * _Nullable const args[_Nonnull],
    char * _Nullable const env[_Nullable],
    uid_t * _Nullable uid,
    gid_t * _Nullable gid,
    gid_t * _Nullable process_group_id,
    int number_of_sgroups, const gid_t * _Nullable sgroups,
    int create_session,
    void (* _Nullable configurator)(void)
);

int _was_process_exited(int status);
int _get_exit_code(int status);
int _was_process_signaled(int status);
int _get_signal_code(int status);
int _was_process_suspended(int status);

void _subprocess_lock_environ(void);
void _subprocess_unlock_environ(void);
char * _Nullable * _Nullable _subprocess_get_environ(void);

#if TARGET_OS_LINUX
int _shims_snprintf(
    char * _Nonnull str,
    int len,
    const char * _Nonnull format,
    char * _Nonnull str1,
    char * _Nonnull str2
);
#endif

#endif // !TARGET_OS_WINDOWS

#if TARGET_OS_WINDOWS

#ifndef _WINDEF_
typedef unsigned long DWORD;
typedef int BOOL;
#endif

BOOL _subprocess_windows_send_vm_close(DWORD pid);

#endif

#endif /* process_shims_h */
