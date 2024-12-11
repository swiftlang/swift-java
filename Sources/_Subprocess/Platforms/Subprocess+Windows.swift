//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(WinSDK)

import WinSDK
import Dispatch
import SystemPackage
import FoundationEssentials

// Windows specific implementation
extension Subprocess.Configuration {
    internal func spawn(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> Subprocess {
        // Spawn differently depending on whether
        // we need to spawn as a user
        if let userCredentials = self.platformOptions.userCredentials {
            return try self.spawnAsUser(
                withInput: input,
                output: output,
                error: error,
                userCredentials: userCredentials
            )
        } else {
            return try self.spawnDirect(
                withInput: input,
                output: output,
                error: error
            )
        }
    }

    internal func spawnDirect(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> Subprocess {
        let (
            applicationName,
            commandAndArgs,
            environment,
            intendedWorkingDir
        ) = try self.preSpawn()
        var startupInfo = try self.generateStartupInfo(
            withInput: input,
            output: output,
            error: error
        )
        var processInfo: PROCESS_INFORMATION = PROCESS_INFORMATION()
        var createProcessFlags = self.generateCreateProcessFlag()
        // Give calling process a chance to modify flag and startup info
        if let configurator = self.platformOptions.preSpawnProcessConfigurator {
            try configurator(&createProcessFlags, &startupInfo)
        }
        // Spawn!
        try applicationName.withOptionalNTPathRepresentation { applicationNameW in
            try commandAndArgs.withCString(
                encodedAs: UTF16.self
            ) { commandAndArgsW in
                try environment.withCString(
                    encodedAs: UTF16.self
                ) { environmentW in
                    try intendedWorkingDir.withNTPathRepresentation { intendedWorkingDirW in
                        let created = CreateProcessW(
                            applicationNameW,
                            UnsafeMutablePointer<WCHAR>(mutating: commandAndArgsW),
                            nil,    // lpProcessAttributes
                            nil,    // lpThreadAttributes
                            true,  // bInheritHandles
                            createProcessFlags,
                            UnsafeMutableRawPointer(mutating: environmentW),
                            intendedWorkingDirW,
                            &startupInfo,
                            &processInfo
                        )
                        guard created else {
                            let windowsError = GetLastError()
                            try self.cleanupAll(
                                input: input,
                                output: output,
                                error: error
                            )
                            throw CocoaError.windowsError(
                                underlying: windowsError,
                                errorCode: .fileWriteUnknown
                            )
                        }
                    }
                }
            }
        }
        // We don't need the handle objects, so close it right away
        guard CloseHandle(processInfo.hThread) else {
            let windowsError = GetLastError()
            try self.cleanupAll(
                input: input,
                output: output,
                error: error
            )
            throw CocoaError.windowsError(
                underlying: windowsError,
                errorCode: .fileReadUnknown
            )
        }
        guard CloseHandle(processInfo.hProcess) else {
            let windowsError = GetLastError()
            try self.cleanupAll(
                input: input,
                output: output,
                error: error
            )
            throw CocoaError.windowsError(
                underlying: windowsError,
                errorCode: .fileReadUnknown
            )
        }
        let pid = Subprocess.ProcessIdentifier(
            processID: processInfo.dwProcessId,
            threadID: processInfo.dwThreadId
        )
        return Subprocess(
            processIdentifier: pid,
            executionInput: input,
            executionOutput: output,
            executionError: error,
            consoleBehavior: self.platformOptions.consoleBehavior
        )
    }

    internal func spawnAsUser(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput,
        userCredentials: Subprocess.PlatformOptions.UserCredentials
    ) throws -> Subprocess {
        let (
            applicationName,
            commandAndArgs,
            environment,
            intendedWorkingDir
        ) = try self.preSpawn()
        var startupInfo = try self.generateStartupInfo(
            withInput: input,
            output: output,
            error: error
        )
        var processInfo: PROCESS_INFORMATION = PROCESS_INFORMATION()
        var createProcessFlags = self.generateCreateProcessFlag()
        // Give calling process a chance to modify flag and startup info
        if let configurator = self.platformOptions.preSpawnProcessConfigurator {
            try configurator(&createProcessFlags, &startupInfo)
        }
        // Spawn (featuring pyamid!)
        try userCredentials.username.withCString(
            encodedAs: UTF16.self
        ) { usernameW in
            try userCredentials.password.withCString(
                encodedAs: UTF16.self
            ) { passwordW in
                try userCredentials.domain.withOptionalCString(
                    encodedAs: UTF16.self
                ) { domainW in
                    try applicationName.withOptionalNTPathRepresentation { applicationNameW in
                        try commandAndArgs.withCString(
                            encodedAs: UTF16.self
                        ) { commandAndArgsW in
                            try environment.withCString(
                                encodedAs: UTF16.self
                            ) { environmentW in
                                try intendedWorkingDir.withNTPathRepresentation { intendedWorkingDirW in
                                    let created = CreateProcessWithLogonW(
                                        usernameW,
                                        domainW,
                                        passwordW,
                                        DWORD(LOGON_WITH_PROFILE),
                                        applicationNameW,
                                        UnsafeMutablePointer<WCHAR>(mutating: commandAndArgsW),
                                        createProcessFlags,
                                        UnsafeMutableRawPointer(mutating: environmentW),
                                        intendedWorkingDirW,
                                        &startupInfo,
                                        &processInfo
                                    )
                                    guard created else {
                                        let windowsError = GetLastError()
                                        try self.cleanupAll(
                                            input: input,
                                            output: output,
                                            error: error
                                        )
                                        throw CocoaError.windowsError(
                                            underlying: windowsError,
                                            errorCode: .fileWriteUnknown
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // We don't need the handle objects, so close it right away
        guard CloseHandle(processInfo.hThread) else {
            let windowsError = GetLastError()
            try self.cleanupAll(
                input: input,
                output: output,
                error: error
            )
            throw CocoaError.windowsError(
                underlying: windowsError,
                errorCode: .fileReadUnknown
            )
        }
        guard CloseHandle(processInfo.hProcess) else {
            let windowsError = GetLastError()
            try self.cleanupAll(
                input: input,
                output: output,
                error: error
            )
            throw CocoaError.windowsError(
                underlying: windowsError,
                errorCode: .fileReadUnknown
            )
        }
        let pid = Subprocess.ProcessIdentifier(
            processID: processInfo.dwProcessId,
            threadID: processInfo.dwThreadId
        )
        return Subprocess(
            processIdentifier: pid,
            executionInput: input,
            executionOutput: output,
            executionError: error,
            consoleBehavior: self.platformOptions.consoleBehavior
        )
    }
}

// MARK: - Platform Specific Options
extension Subprocess {
    /// The collection of platform-specific settings
    /// to configure the subprocess when running
    public struct PlatformOptions: Sendable {
        /// A `UserCredentials` to use spawning the subprocess
        /// as a different user
        public struct UserCredentials: Sendable, Hashable {
            // The name of the user. This is the name
            // of the user account to run as.
            public var username: String
            // The clear-text password for the account.
            public var password: String
            // The name of the domain or server whose account database
            // contains the account.
            public var domain: String?
        }

        /// `ConsoleBehavior` defines how should the console appear
        /// when spawning a new process
        public struct ConsoleBehavior: Sendable, Hashable {
            internal enum Storage: Sendable, Hashable {
                case createNew
                case detatch
                case inherit
            }

            internal let storage: Storage

            private init(_ storage: Storage) {
                self.storage = storage
            }

            /// The subprocess has a new console, instead of
            /// inheriting its parent's console (the default).
            public static let createNew: Self = .init(.createNew)
            /// For console processes, the new process does not
            /// inherit its parent's console (the default).
            /// The new process can call the `AllocConsole`
            /// function at a later time to create a console.
            public static let detatch: Self = .init(.detatch)
            /// The subprocess inherits its parent's console.
            public static let inherit: Self = .init(.inherit)
        }

        /// `ConsoleBehavior` defines how should the window appear
        /// when spawning a new process
        public struct WindowStyle: Sendable, Hashable {
            internal enum Storage: Sendable, Hashable {
                case normal
                case hidden
                case maximized
                case minimized
            }

            internal let storage: Storage

            internal var platformStyle: WORD {
                switch self.storage {
                case .hidden: return WORD(SW_HIDE)
                case .maximized: return WORD(SW_SHOWMAXIMIZED)
                case .minimized: return WORD(SW_SHOWMINIMIZED)
                default: return WORD(SW_SHOWNORMAL)
                }
            }

            private init(_ storage: Storage) {
                self.storage = storage
            }

            /// Activates and displays a window of normal size
            public static let normal: Self = .init(.normal)
            /// Does not activate a new window
            public static let hidden: Self = .init(.hidden)
            /// Activates the window and displays it as a maximized window.
            public static let maximized: Self = .init(.maximized)
            /// Activates the window and displays it as a minimized window.
            public static let minimized: Self = .init(.minimized)
        }

        /// Sets user credentials when starting the process as another user
        public var userCredentials: UserCredentials? = nil
        /// The console behavior of the new process,
        /// default to inheriting the console from parent process
        public var consoleBehavior: ConsoleBehavior = .inherit
        /// Window style to use when the process is started
        public var windowStyle: WindowStyle = .normal
        /// Whether to create a new process group for the new
        /// process. The process group includes all processes
        /// that are descendants of this root process.
        /// The process identifier of the new process group
        /// is the same as the process identifier.
        public var createProcessGroup: Bool = false
        /// A closure to configure platform-specific
        /// spawning constructs. This closure enables direct
        /// configuration or override of underlying platform-specific
        /// spawn settings that `Subprocess` utilizes internally,
        /// in cases where Subprocess does not provide higher-level
        /// APIs for such modifications.
        ///
        /// On Windows, Subprocess uses `CreateProcessW()` as the
        /// underlying spawning mechanism. This closure allows
        /// modification of the `dwCreationFlags` creation flag
        /// and startup info `STARTUPINFOW` before
        /// they are sent to `CreateProcessW()`.
        public var preSpawnProcessConfigurator: (
            @Sendable (
                inout DWORD,
                inout STARTUPINFOW
            ) throws -> Void
        )? = nil

        public init() {}
    }
}

extension Subprocess.PlatformOptions: Hashable {
    public static func == (
        lhs: Subprocess.PlatformOptions,
        rhs: Subprocess.PlatformOptions
    ) -> Bool {
        // Since we can't compare closure equality,
        // as long as preSpawnProcessConfigurator is set
        // always returns false so that `PlatformOptions`
        // with it set will never equal to each other
        if lhs.preSpawnProcessConfigurator != nil || rhs.preSpawnProcessConfigurator != nil {
            return false
        }
        return lhs.userCredentials == rhs.userCredentials && lhs.consoleBehavior == rhs.consoleBehavior && lhs.windowStyle == rhs.windowStyle &&
            lhs.createProcessGroup == rhs.createProcessGroup
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(userCredentials)
        hasher.combine(consoleBehavior)
        hasher.combine(windowStyle)
        hasher.combine(createProcessGroup)
        // Since we can't really hash closures,
        // use an UUID such that as long as
        // `preSpawnProcessConfigurator` is set, it will
        // never equal to other PlatformOptions
        if self.preSpawnProcessConfigurator != nil {
            hasher.combine(UUID())
        }
    }
}

extension Subprocess.PlatformOptions : CustomStringConvertible, CustomDebugStringConvertible {
    internal func description(withIndent indent: Int) -> String {
        let indent = String(repeating: " ", count: indent * 4)
        return """
PlatformOptions(
\(indent)    userCredentials: \(String(describing: self.userCredentials)),
\(indent)    consoleBehavior: \(String(describing: self.consoleBehavior)),
\(indent)    windowStyle: \(String(describing: self.windowStyle)),
\(indent)    createProcessGroup: \(self.createProcessGroup),
\(indent)    preSpawnProcessConfigurator: \(self.preSpawnProcessConfigurator == nil ? "not set" : "set")
\(indent))
"""
    }

    public var description: String {
        return self.description(withIndent: 0)
    }

    public var debugDescription: String {
        return self.description(withIndent: 0)
    }
}

// MARK: - Process Monitoring
@Sendable
internal func monitorProcessTermination(
    forProcessWithIdentifier pid: Subprocess.ProcessIdentifier
) async throws -> Subprocess.TerminationStatus {
    // Once the continuation resumes, it will need to unregister the wait, so
    // yield the wait handle back to the calling scope.
    var waitHandle: HANDLE?
    defer {
        if let waitHandle {
            _ = UnregisterWait(waitHandle)
        }
    }
    guard let processHandle = OpenProcess(
        DWORD(PROCESS_QUERY_INFORMATION | SYNCHRONIZE),
        false,
        pid.processID
    ) else {
        return .exited(1)
    }

    try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        // Set up a callback that immediately resumes the continuation and does no
        // other work.
        let context = Unmanaged.passRetained(continuation as AnyObject).toOpaque()
        let callback: WAITORTIMERCALLBACK = { context, _ in
            let continuation = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as! CheckedContinuation<Void, any Error>
            continuation.resume()
        }

        // We only want the callback to fire once (and not be rescheduled.) Waiting
        // may take an arbitrarily long time, so let the thread pool know that too.
        let flags = ULONG(WT_EXECUTEONLYONCE | WT_EXECUTELONGFUNCTION)
        guard RegisterWaitForSingleObject(
            &waitHandle, processHandle, callback, context, INFINITE, flags
        ) else {
            continuation.resume(throwing: CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown)
            )
            return
        }
    }

    var status: DWORD = 0
    guard GetExitCodeProcess(processHandle, &status) else {
        // The child process terminated but we couldn't get its status back.
        // Assume generic failure.
        return .exited(1)
    }
    let exitCodeValue = CInt(bitPattern: .init(status))
    if exitCodeValue >= 0 {
        return .exited(status)
    } else {
        return .unhandledException(status)
    }
}

// MARK: - Subprocess Control
extension Subprocess {
    /// Terminate the current subprocess with the given exit code
    /// - Parameter exitCode: The exit code to use for the subprocess.
    public func terminate(withExitCode exitCode: DWORD) throws {
        guard let processHandle = OpenProcess(
            // PROCESS_ALL_ACCESS
            DWORD(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF),
            false,
            self.processIdentifier.processID
        ) else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown
            )
        }
        defer {
            CloseHandle(processHandle)
        }
        guard TerminateProcess(processHandle, exitCode) else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown
            )
        }
    }

    /// Suspend the current subprocess
    public func suspend() throws {
        guard let processHandle = OpenProcess(
            // PROCESS_ALL_ACCESS
            DWORD(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF),
            false,
            self.processIdentifier.processID
        ) else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown
            )
        }
        defer {
            CloseHandle(processHandle)
        }

        let NTSuspendProcess: Optional<(@convention(c) (HANDLE) -> LONG)> =
            unsafeBitCast(
                GetProcAddress(
                    GetModuleHandleA("ntdll.dll"),
                    "NtSuspendProcess"
                ),
                to: Optional<(@convention(c) (HANDLE) -> LONG)>.self
            )
        guard let NTSuspendProcess = NTSuspendProcess else {
            throw CocoaError(.executableNotLoadable)
        }
        guard NTSuspendProcess(processHandle) >= 0 else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown
            )
        }
    }

    /// Resume the current subprocess after suspension
    public func resume() throws {
        guard let processHandle = OpenProcess(
            // PROCESS_ALL_ACCESS
            DWORD(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF),
            false,
            self.processIdentifier.processID
        ) else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown
            )
        }
        defer {
            CloseHandle(processHandle)
        }

        let NTResumeProcess: Optional<(@convention(c) (HANDLE) -> LONG)> =
        unsafeBitCast(
            GetProcAddress(
                GetModuleHandleA("ntdll.dll"),
                "NtResumeProcess"
            ),
            to: Optional<(@convention(c) (HANDLE) -> LONG)>.self
        )
        guard let NTResumeProcess = NTResumeProcess else {
            throw CocoaError(.executableNotLoadable)
        }
        guard NTResumeProcess(processHandle) >= 0 else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileWriteUnknown
            )
        }
    }

    internal func tryTerminate() -> Error? {
        do {
            try self.terminate(withExitCode: 0)
        } catch {
            return error
        }
        return nil
    }
}

// MARK: - Executable Searching
extension Subprocess.Executable {
    // Technically not needed for CreateProcess since
    // it takes process name. It's here to support
    // Executable.resolveExecutablePath
    internal func resolveExecutablePath(withPathValue pathValue: String?) -> String? {
        switch self.storage {
        case .executable(let executableName):
            return executableName.withCString(
                encodedAs: UTF16.self
            ) { exeName -> String? in
                return pathValue.withOptionalCString(
                    encodedAs: UTF16.self
                ) { path -> String? in
                    let pathLenth = SearchPathW(
                        path,
                        exeName,
                        nil, 0, nil, nil
                    )
                    guard pathLenth > 0 else {
                        return nil
                    }
                    return withUnsafeTemporaryAllocation(
                        of: WCHAR.self, capacity: Int(pathLenth) + 1
                    ) {
                        _ = SearchPathW(
                            path,
                            exeName, nil,
                            pathLenth + 1,
                            $0.baseAddress, nil
                        )
                        return String(decodingCString: $0.baseAddress!, as: UTF16.self)
                    }
                }
            }
        case .path(let executablePath):
            // Use path directly
            return executablePath.string
        }
    }
}

// MARK: - Environment Resolution
extension Subprocess.Environment {
    internal static let pathEnvironmentVariableName = "Path"

    internal func pathValue() -> String? {
        switch self.config {
        case .inherit(let overrides):
            // If PATH value exists in overrides, use it
            if let value = overrides[.string(Self.pathEnvironmentVariableName)] {
                return value.stringValue
            }
            // Fall back to current process
            return ProcessInfo.processInfo.environment[Self.pathEnvironmentVariableName]
        case .custom(let fullEnvironment):
            if let value = fullEnvironment[.string(Self.pathEnvironmentVariableName)] {
                return value.stringValue
            }
            return nil
        }
    }
}

// MARK: - ProcessIdentifier
extension Subprocess {
    /// A platform independent identifier for a subprocess.
    public struct ProcessIdentifier: Sendable, Hashable, Codable {
        /// Windows specifc process identifier value
        public let processID: DWORD
        /// Windows specific thread identifier associated with process
        public let threadID: DWORD

        internal init(
            processID: DWORD,
            threadID: DWORD
        ) {
            self.processID = processID
            self.threadID = threadID
        }
    }
}

extension Subprocess.ProcessIdentifier: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "(processID: \(self.processID), threadID: \(self.threadID))"
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - Private Utils
extension Subprocess.Configuration {
    private func preSpawn() throws -> (
        applicationName: String?,
        commandAndArgs: String,
        environment: String,
        intendedWorkingDir: String
    ) {
        // Prepare environment
        var env: [String : String] = [:]
        switch self.environment.config {
        case .custom(let customValues):
            // Use the custom values directly
            for customKey in customValues.keys {
                guard case .string(let stringKey) = customKey,
                      let valueContainer = customValues[customKey],
                      case .string(let stringValue) = valueContainer else {
                    fatalError("Windows does not support non unicode String as environments")
                }
                env.updateValue(stringValue, forKey: stringKey)
            }
        case .inherit(let updateValues):
            // Combine current environment
            env = ProcessInfo.processInfo.environment
            for updatingKey in updateValues.keys {
                // Override the current environment values
                guard case .string(let stringKey) = updatingKey,
                      let valueContainer = updateValues[updatingKey],
                      case .string(let stringValue) = valueContainer else {
                    fatalError("Windows does not support non unicode String as environments")
                }
                env.updateValue(stringValue, forKey: stringKey)
            }
        }
        // On Windows, the PATH is required in order to locate dlls needed by
        // the process so we should also pass that to the child
        let pathVariableName = Subprocess.Environment.pathEnvironmentVariableName
        if env[pathVariableName] == nil,
           let parentPath = ProcessInfo.processInfo.environment[pathVariableName] {
            env[pathVariableName] = parentPath
        }
        // The environment string must be terminated by a double
        // null-terminator.  Otherwise, CreateProcess will fail with
        // INVALID_PARMETER.
        let environmentString = env.map {
            $0.key + "=" + $0.value
        }.joined(separator: "\0") + "\0\0"

        // Prepare arguments
        let (
            applicationName,
            commandAndArgs
        ) = try self.generateWindowsCommandAndAgruments()
        // Validate workingDir
        guard Self.pathAccessible(self.workingDirectory.string) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                .debugDescriptionErrorKey : "Failed to set working directory to \(self.workingDirectory)"
            ])
        }
        return (
            applicationName: applicationName,
            commandAndArgs: commandAndArgs,
            environment: environmentString,
            intendedWorkingDir: self.workingDirectory.string
        )
    }

    private func generateCreateProcessFlag() -> DWORD {
        var flags = CREATE_UNICODE_ENVIRONMENT
        switch self.platformOptions.consoleBehavior.storage {
        case .createNew:
            flags |= CREATE_NEW_CONSOLE
        case .detatch:
            flags |= DETACHED_PROCESS
        case .inherit:
            break
        }
        if self.platformOptions.createProcessGroup {
            flags |= CREATE_NEW_PROCESS_GROUP
        }
        return DWORD(flags)
    }

    private func generateStartupInfo(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> STARTUPINFOW {
        var info: STARTUPINFOW = STARTUPINFOW()
        info.cb = DWORD(MemoryLayout<STARTUPINFOW>.size)
        info.dwFlags |= DWORD(STARTF_USESTDHANDLES)

        if self.platformOptions.windowStyle.storage != .normal {
            info.wShowWindow = self.platformOptions.windowStyle.platformStyle
            info.dwFlags |= DWORD(STARTF_USESHOWWINDOW)
        }
        // Bind IOs
        // Input
        if let inputRead = input.getReadFileDescriptor() {
            info.hStdInput = inputRead.platformDescriptor
        }
        if let inputWrite = input.getWriteFileDescriptor() {
            // Set parent side to be uninhertable
            SetHandleInformation(
                inputWrite.platformDescriptor,
                DWORD(HANDLE_FLAG_INHERIT),
                0
            )
        }
        // Output
        if let outputWrite = output.getWriteFileDescriptor() {
            info.hStdOutput = outputWrite.platformDescriptor
        }
        if let outputRead = output.getReadFileDescriptor() {
            // Set parent side to be uninhertable
            SetHandleInformation(
                outputRead.platformDescriptor,
                DWORD(HANDLE_FLAG_INHERIT),
                0
            )
        }
        // Error
        if let errorWrite = error.getWriteFileDescriptor() {
            info.hStdError = errorWrite.platformDescriptor
        }
        if let errorRead = error.getReadFileDescriptor() {
            // Set parent side to be uninhertable
            SetHandleInformation(
                errorRead.platformDescriptor,
                DWORD(HANDLE_FLAG_INHERIT),
                0
            )
        }
        return info
    }

    private func generateWindowsCommandAndAgruments() throws -> (
        applicationName: String?,
        commandAndArgs: String
    ) {
        // CreateProcess accepts partial names
        let executableNameOrPath: String
        switch self.executable.storage {
        case .path(let path):
            executableNameOrPath = path.string
        case .executable(let name):
            // Technically CreateProcessW accepts just the name
            // of the executable, therefore we don't need to
            // actually resolve the path. However, to maintain
            // the same behavior as other platforms, still check
            // here to make sure the executable actually exists
            guard self.executable.resolveExecutablePath(
                withPathValue: self.environment.pathValue()
            ) != nil else {
                throw CocoaError(.executableNotLoadable, userInfo: [
                    .debugDescriptionErrorKey : "\(self.executable.description) is not an executable"
                ])
            }
            executableNameOrPath = name
        }
        var args = self.arguments.storage.map {
            guard case .string(let stringValue) = $0 else {
                // We should never get here since the API
                // is guarded off
                fatalError("Windows does not support non unicode String as arguments")
            }
            return stringValue
        }
        // The first parameter of CreateProcessW, `lpApplicationName`
        // is optional. If it's nil, CreateProcessW uses argument[0]
        // as the execuatble name.
        // We should only set lpApplicationName if it's different from
        // argument[0] (i.e. executablePathOverride)
        var applicationName: String? = nil
        if case .string(let overrideName) = self.arguments.executablePathOverride {
            // Use the override as argument0 and set applicationName
            args.insert(overrideName, at: 0)
            applicationName = executableNameOrPath
        } else {
            // Set argument[0] to be executableNameOrPath
            args.insert(executableNameOrPath, at: 0)
        }
        return (
            applicationName: applicationName,
            commandAndArgs: self.quoteWindowsCommandLine(args)
        )
    }

    // Taken from SCF
    private func quoteWindowsCommandLine(_ commandLine: [String]) -> String {
        func quoteWindowsCommandArg(arg: String) -> String {
            // Windows escaping, adapted from Daniel Colascione's "Everyone quotes
            // command line arguments the wrong way" - Microsoft Developer Blog
            if !arg.contains(where: {" \t\n\"".contains($0)}) {
                return arg
            }

            // To escape the command line, we surround the argument with quotes. However
            // the complication comes due to how the Windows command line parser treats
            // backslashes (\) and quotes (")
            //
            // - \ is normally treated as a literal backslash
            //     - e.g. foo\bar\baz => foo\bar\baz
            // - However, the sequence \" is treated as a literal "
            //     - e.g. foo\"bar => foo"bar
            //
            // But then what if we are given a path that ends with a \? Surrounding
            // foo\bar\ with " would be "foo\bar\" which would be an unterminated string

            // since it ends on a literal quote. To allow this case the parser treats:
            //
            // - \\" as \ followed by the " metachar
            // - \\\" as \ followed by a literal "
            // - In general:
            //     - 2n \ followed by " => n \ followed by the " metachar
            //     - 2n+1 \ followed by " => n \ followed by a literal "
            var quoted = "\""
            var unquoted = arg.unicodeScalars

            while !unquoted.isEmpty {
                guard let firstNonBackslash = unquoted.firstIndex(where: { $0 != "\\" }) else {
                    // String ends with a backslash e.g. foo\bar\, escape all the backslashes
                    // then add the metachar " below
                    let backslashCount = unquoted.count
                    quoted.append(String(repeating: "\\", count: backslashCount * 2))
                    break
                }
                let backslashCount = unquoted.distance(from: unquoted.startIndex, to: firstNonBackslash)
                if (unquoted[firstNonBackslash] == "\"") {
                    // This is  a string of \ followed by a " e.g. foo\"bar. Escape the
                    // backslashes and the quote
                    quoted.append(String(repeating: "\\", count: backslashCount * 2 + 1))
                    quoted.append(String(unquoted[firstNonBackslash]))
                } else {
                    // These are just literal backslashes
                    quoted.append(String(repeating: "\\", count: backslashCount))
                    quoted.append(String(unquoted[firstNonBackslash]))
                }
                // Drop the backslashes and the following character
                unquoted.removeFirst(backslashCount + 1)
            }
            quoted.append("\"")
            return quoted
        }
        return commandLine.map(quoteWindowsCommandArg).joined(separator: " ")
    }

    private static func pathAccessible(_ path: String) -> Bool {
        return path.withCString(encodedAs: UTF16.self) {
            let attrs = GetFileAttributesW($0)
            return attrs != INVALID_FILE_ATTRIBUTES
        }
    }
}

// MARK: - PlatformFileDescriptor Type
extension Subprocess {
    internal typealias PlatformFileDescriptor = HANDLE
}

// MARK: - Read Buffer Size
extension Subprocess {
    @inline(__always)
    internal static var readBufferSize: Int {
        // FIXME: Use Platform.pageSize here
        var sysInfo: SYSTEM_INFO = SYSTEM_INFO()
        GetSystemInfo(&sysInfo)
        return Int(sysInfo.dwPageSize)
    }
}

// MARK: - Pipe Support
extension FileDescriptor {
    internal static func pipe() throws -> (
        readEnd: FileDescriptor,
        writeEnd: FileDescriptor
    ) {
        var saAttributes: SECURITY_ATTRIBUTES = SECURITY_ATTRIBUTES()
        saAttributes.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
        saAttributes.bInheritHandle = true
        saAttributes.lpSecurityDescriptor = nil

        var readHandle: HANDLE? = nil
        var writeHandle: HANDLE? = nil
        guard CreatePipe(&readHandle, &writeHandle, &saAttributes, 0),
              readHandle != INVALID_HANDLE_VALUE,
              writeHandle != INVALID_HANDLE_VALUE,
           let readHandle: HANDLE = readHandle,
           let writeHandle: HANDLE = writeHandle else {
            throw CocoaError.windowsError(
                underlying: GetLastError(),
                errorCode: .fileReadUnknown
            )
        }
        let readFd = _open_osfhandle(
            intptr_t(bitPattern: readHandle),
            FileDescriptor.AccessMode.readOnly.rawValue
        )
        let writeFd = _open_osfhandle(
            intptr_t(bitPattern: writeHandle),
            FileDescriptor.AccessMode.writeOnly.rawValue
        )

        return (
            readEnd: FileDescriptor(rawValue: readFd),
            writeEnd: FileDescriptor(rawValue: writeFd)
        )
    }

    internal static func openDevNull(
        withAcessMode mode: FileDescriptor.AccessMode
    ) throws -> FileDescriptor {
        return try "NUL".withPlatformString {
            let handle = CreateFileW(
                $0,
                DWORD(GENERIC_WRITE),
                DWORD(FILE_SHARE_WRITE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_ATTRIBUTE_NORMAL),
                nil
            )
            guard let handle = handle,
                  handle != INVALID_HANDLE_VALUE else {
                throw CocoaError.windowsError(
                    underlying: GetLastError(),
                    errorCode: .fileReadUnknown
                )
            }
            let devnull = _open_osfhandle(
                intptr_t(bitPattern: handle),
                mode.rawValue
            )
            return FileDescriptor(rawValue: devnull)
        }
    }

    var platformDescriptor: Subprocess.PlatformFileDescriptor {
        return HANDLE(bitPattern: _get_osfhandle(self.rawValue))!
    }

    internal func read(upToLength maxLength: Int) async throws -> Data {
        // TODO: Figure out a better way to asynchornously read
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var totalBytesRead: Int = 0
                var lastError: DWORD? = nil
                let values = Array<UInt8>(
                    unsafeUninitializedCapacity: maxLength
                ) { buffer, initializedCount in
                    while true {
                        guard let baseAddress = buffer.baseAddress else {
                            initializedCount = 0
                            break
                        }
                        let bufferPtr = baseAddress.advanced(by: totalBytesRead)
                        var bytesRead: DWORD = 0
                        let readSucceed = ReadFile(
                            self.platformDescriptor,
                            UnsafeMutableRawPointer(mutating: bufferPtr),
                            DWORD(maxLength - totalBytesRead),
                            &bytesRead,
                            nil
                        )
                        if !readSucceed {
                            // Windows throws ERROR_BROKEN_PIPE when the pipe is closed
                            let error = GetLastError()
                            if error == ERROR_BROKEN_PIPE {
                                // We are done reading
                                initializedCount = totalBytesRead
                            } else {
                                // We got some error
                                lastError = error
                                initializedCount = 0
                            }
                            break
                        } else {
                            // We succesfully read the current round
                            totalBytesRead += Int(bytesRead)
                        }

                        if totalBytesRead >= maxLength {
                            initializedCount = min(maxLength, totalBytesRead)
                            break
                        }
                    }
                }
                if let lastError = lastError {
                    continuation.resume(throwing: CocoaError.windowsError(
                        underlying: lastError,
                        errorCode: .fileReadUnknown)
                    )
                } else {
                    continuation.resume(returning: Data(values))
                }
            }
        }
    }

    internal func write<S: Sequence>(_ data: S) async throws where S.Element == UInt8 {
        // TODO: Figure out a better way to asynchornously write
        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, Error>
        ) -> Void in
            DispatchQueue.global(qos: .userInitiated).async {
                let buffer = Array(data)
                buffer.withUnsafeBytes { ptr in
                    var writtenBytes: DWORD = 0
                    let writeSucceed = WriteFile(
                        self.platformDescriptor,
                        ptr.baseAddress,
                        DWORD(buffer.count),
                        &writtenBytes,
                        nil
                    )
                    if !writeSucceed {
                        continuation.resume(throwing: CocoaError.windowsError(
                            underlying: GetLastError(),
                            errorCode: .fileWriteUnknown)
                        )
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}

extension String {
    static let debugDescriptionErrorKey = "DebugDescription"
}

// MARK: - CocoaError + Win32
internal let NSUnderlyingErrorKey = "NSUnderlyingError"

extension CocoaError {
    static func windowsError(underlying: DWORD, errorCode: Code) -> CocoaError {
        let userInfo = [
            NSUnderlyingErrorKey : Win32Error(underlying)
        ]
        return CocoaError(errorCode, userInfo: userInfo)
    }
}

private extension Optional where Wrapped == String {
    func withOptionalCString<Result, Encoding>(
        encodedAs targetEncoding: Encoding.Type,
        _ body: (UnsafePointer<Encoding.CodeUnit>?) throws -> Result
    ) rethrows -> Result where Encoding : _UnicodeEncoding {
        switch self {
        case .none:
            return try body(nil)
        case .some(let value):
            return try value.withCString(encodedAs: targetEncoding, body)
        }
    }

    func withOptionalNTPathRepresentation<Result>(
        _ body: (UnsafePointer<WCHAR>?) throws -> Result
    ) throws -> Result {
        switch self {
        case .none:
            return try body(nil)
        case .some(let value):
            return try value.withNTPathRepresentation(body)
        }
    }
}

// MARK: - Remove these when merging back to SwiftFoundation
extension String {
    internal func withNTPathRepresentation<Result>(
        _ body: (UnsafePointer<WCHAR>) throws -> Result
    ) throws -> Result {
        guard !isEmpty else {
            throw CocoaError(.fileReadInvalidFileName)
        }

        var iter = self.utf8.makeIterator()
        let bLeadingSlash = if [._slash, ._backslash].contains(iter.next()), iter.next()?.isLetter ?? false, iter.next() == ._colon { true } else { false }

        // Strip the leading `/` on a RFC8089 path (`/[drive-letter]:/...` ).  A
        // leading slash indicates a rooted path on the drive for the current
        // working directory.
        return try Substring(self.utf8.dropFirst(bLeadingSlash ? 1 : 0)).withCString(encodedAs: UTF16.self) { pwszPath in
            // 1. Normalize the path first.
            let dwLength: DWORD = GetFullPathNameW(pwszPath, 0, nil, nil)
            return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
                guard GetFullPathNameW(pwszPath, DWORD($0.count), $0.baseAddress, nil) > 0 else {
                    throw CocoaError.windowsError(
                        underlying: GetLastError(),
                        errorCode: .fileReadUnknown
                    )
                }

                // 2. Perform the operation on the normalized path.
                return try body($0.baseAddress!)
            }
        }
    }
}

struct Win32Error: Error {
    public typealias Code = DWORD
    public let code: Code

    public static var errorDomain: String {
        return "NSWin32ErrorDomain"
    }

    public init(_ code: Code) {
        self.code = code
    }
}

internal extension UInt8 {
    static var _slash: UInt8 { UInt8(ascii: "/") }
    static var _backslash: UInt8 { UInt8(ascii: "\\") }
    static var _colon: UInt8 { UInt8(ascii: ":") }

    var isLetter: Bool? {
        return (0x41 ... 0x5a) ~= self || (0x61 ... 0x7a) ~= self
    }
}

#endif // canImport(WinSDK)
