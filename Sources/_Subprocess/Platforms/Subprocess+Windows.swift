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

#if canImport(WinSDK)

import WinSDK
internal import Dispatch
#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

// Windows specific implementation
extension Configuration {
    internal func spawn<
        Output: OutputProtocol,
        Error: OutputProtocol
    >(
        withInput inputPipe: CreatedPipe,
        output: Output,
        outputPipe: CreatedPipe,
        error: Error,
        errorPipe: CreatedPipe
    ) throws -> Execution<Output, Error> {
        // Spawn differently depending on whether
        // we need to spawn as a user
        guard let userCredentials = self.platformOptions.userCredentials else {
            return try self.spawnDirect(
                withInput: inputPipe,
                output: output,
                outputPipe: outputPipe,
                error: error,
                errorPipe: errorPipe
            )
        }
        return try self.spawnAsUser(
            withInput: inputPipe,
            output: output,
            outputPipe: outputPipe,
            error: error,
            errorPipe: errorPipe,
            userCredentials: userCredentials
        )
    }

    internal func spawnDirect<
        Output: OutputProtocol,
        Error: OutputProtocol
    >(
        withInput inputPipe: CreatedPipe,
        output: Output,
        outputPipe: CreatedPipe,
        error: Error,
        errorPipe: CreatedPipe
    ) throws -> Execution<Output, Error> {
        let (
            applicationName,
            commandAndArgs,
            environment,
            intendedWorkingDir
        ) = try self.preSpawn()
        var startupInfo = try self.generateStartupInfo(
            withInput: inputPipe,
            output: outputPipe,
            error: errorPipe
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
                            nil,  // lpProcessAttributes
                            nil,  // lpThreadAttributes
                            true,  // bInheritHandles
                            createProcessFlags,
                            UnsafeMutableRawPointer(mutating: environmentW),
                            intendedWorkingDirW,
                            &startupInfo,
                            &processInfo
                        )
                        guard created else {
                            let windowsError = GetLastError()
                            try self.cleanupPreSpawn(
                                input: inputPipe,
                                output: outputPipe,
                                error: errorPipe
                            )
                            throw SubprocessError(
                                code: .init(.spawnFailed),
                                underlyingError: .init(rawValue: windowsError)
                            )
                        }
                    }
                }
            }
        }
        // We don't need the handle objects, so close it right away
        guard CloseHandle(processInfo.hThread) else {
            let windowsError = GetLastError()
            try self.cleanupPreSpawn(
                input: inputPipe,
                output: outputPipe,
                error: errorPipe
            )
            throw SubprocessError(
                code: .init(.spawnFailed),
                underlyingError: .init(rawValue: windowsError)
            )
        }
        guard CloseHandle(processInfo.hProcess) else {
            let windowsError = GetLastError()
            try self.cleanupPreSpawn(
                input: inputPipe,
                output: outputPipe,
                error: errorPipe
            )
            throw SubprocessError(
                code: .init(.spawnFailed),
                underlyingError: .init(rawValue: windowsError)
            )
        }
        let pid = ProcessIdentifier(
            value: processInfo.dwProcessId
        )
        return Execution(
            processIdentifier: pid,
            output: output,
            error: error,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            consoleBehavior: self.platformOptions.consoleBehavior
        )
    }

    internal func spawnAsUser<
        Output: OutputProtocol,
        Error: OutputProtocol
    >(
        withInput inputPipe: CreatedPipe,
        output: Output,
        outputPipe: CreatedPipe,
        error: Error,
        errorPipe: CreatedPipe,
        userCredentials: PlatformOptions.UserCredentials
    ) throws -> Execution<Output, Error> {
        let (
            applicationName,
            commandAndArgs,
            environment,
            intendedWorkingDir
        ) = try self.preSpawn()
        var startupInfo = try self.generateStartupInfo(
            withInput: inputPipe,
            output: outputPipe,
            error: errorPipe
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
                                        try self.cleanupPreSpawn(
                                            input: inputPipe,
                                            output: outputPipe,
                                            error: errorPipe
                                        )
                                        throw SubprocessError(
                                            code: .init(.spawnFailed),
                                            underlyingError: .init(rawValue: windowsError)
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
            try self.cleanupPreSpawn(
                input: inputPipe,
                output: outputPipe,
                error: errorPipe
            )
            throw SubprocessError(
                code: .init(.spawnFailed),
                underlyingError: .init(rawValue: windowsError)
            )
        }
        guard CloseHandle(processInfo.hProcess) else {
            let windowsError = GetLastError()
            try self.cleanupPreSpawn(
                input: inputPipe,
                output: outputPipe,
                error: errorPipe
            )
            throw SubprocessError(
                code: .init(.spawnFailed),
                underlyingError: .init(rawValue: windowsError)
            )
        }
        let pid = ProcessIdentifier(
            value: processInfo.dwProcessId
        )
        return Execution(
            processIdentifier: pid,
            output: output,
            error: error,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            consoleBehavior: self.platformOptions.consoleBehavior
        )
    }
}

// MARK: - Platform Specific Options

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
    /// An ordered list of steps in order to tear down the child
    /// process in case the parent task is cancelled before
    /// the child proces terminates.
    /// Always ends in forcefully terminate at the end.
    public var teardownSequence: [TeardownStep] = []
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
    public var preSpawnProcessConfigurator:
        (
            @Sendable (
                inout DWORD,
                inout STARTUPINFOW
            ) throws -> Void
        )? = nil

    public init() {}
}

extension PlatformOptions: CustomStringConvertible, CustomDebugStringConvertible {
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
    forProcessWithIdentifier pid: ProcessIdentifier
) async throws -> TerminationStatus {
    // Once the continuation resumes, it will need to unregister the wait, so
    // yield the wait handle back to the calling scope.
    var waitHandle: HANDLE?
    defer {
        if let waitHandle {
            _ = UnregisterWait(waitHandle)
        }
    }
    guard
        let processHandle = OpenProcess(
            DWORD(PROCESS_QUERY_INFORMATION | SYNCHRONIZE),
            false,
            pid.value
        )
    else {
        return .exited(1)
    }

    try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        // Set up a callback that immediately resumes the continuation and does no
        // other work.
        let context = Unmanaged.passRetained(continuation as AnyObject).toOpaque()
        let callback: WAITORTIMERCALLBACK = { context, _ in
            let continuation =
                Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as! CheckedContinuation<Void, any Error>
            continuation.resume()
        }

        // We only want the callback to fire once (and not be rescheduled.) Waiting
        // may take an arbitrarily long time, so let the thread pool know that too.
        let flags = ULONG(WT_EXECUTEONLYONCE | WT_EXECUTELONGFUNCTION)
        guard
            RegisterWaitForSingleObject(
                &waitHandle,
                processHandle,
                callback,
                context,
                INFINITE,
                flags
            )
        else {
            continuation.resume(
                throwing: SubprocessError(
                    code: .init(.failedToMonitorProcess),
                    underlyingError: .init(rawValue: GetLastError())
                )
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
    guard exitCodeValue >= 0 else {
        return .unhandledException(status)
    }
    return .exited(status)
}

// MARK: - Subprocess Control
@available(macOS 15.0, *) // FIXME: manually added availability
extension Execution {
    /// Terminate the current subprocess with the given exit code
    /// - Parameter exitCode: The exit code to use for the subprocess.
    public func terminate(withExitCode exitCode: DWORD) throws {
        guard
            let processHandle = OpenProcess(
                // PROCESS_ALL_ACCESS
                DWORD(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF),
                false,
                self.processIdentifier.value
            )
        else {
            throw SubprocessError(
                code: .init(.failedToTerminate),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
        defer {
            CloseHandle(processHandle)
        }
        guard TerminateProcess(processHandle, exitCode) else {
            throw SubprocessError(
                code: .init(.failedToTerminate),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
    }

    /// Suspend the current subprocess
    public func suspend() throws {
        guard
            let processHandle = OpenProcess(
                // PROCESS_ALL_ACCESS
                DWORD(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF),
                false,
                self.processIdentifier.value
            )
        else {
            throw SubprocessError(
                code: .init(.failedToSuspend),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
        defer {
            CloseHandle(processHandle)
        }

        let NTSuspendProcess: (@convention(c) (HANDLE) -> LONG)? =
            unsafeBitCast(
                GetProcAddress(
                    GetModuleHandleA("ntdll.dll"),
                    "NtSuspendProcess"
                ),
                to: Optional<(@convention(c) (HANDLE) -> LONG)>.self
            )
        guard let NTSuspendProcess = NTSuspendProcess else {
            throw SubprocessError(
                code: .init(.failedToSuspend),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
        guard NTSuspendProcess(processHandle) >= 0 else {
            throw SubprocessError(
                code: .init(.failedToSuspend),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
    }

    /// Resume the current subprocess after suspension
    public func resume() throws {
        guard
            let processHandle = OpenProcess(
                // PROCESS_ALL_ACCESS
                DWORD(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF),
                false,
                self.processIdentifier.value
            )
        else {
            throw SubprocessError(
                code: .init(.failedToResume),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
        defer {
            CloseHandle(processHandle)
        }

        let NTResumeProcess: (@convention(c) (HANDLE) -> LONG)? =
            unsafeBitCast(
                GetProcAddress(
                    GetModuleHandleA("ntdll.dll"),
                    "NtResumeProcess"
                ),
                to: Optional<(@convention(c) (HANDLE) -> LONG)>.self
            )
        guard let NTResumeProcess = NTResumeProcess else {
            throw SubprocessError(
                code: .init(.failedToResume),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
        guard NTResumeProcess(processHandle) >= 0 else {
            throw SubprocessError(
                code: .init(.failedToResume),
                underlyingError: .init(rawValue: GetLastError())
            )
        }
    }

    internal func tryTerminate() -> Swift.Error? {
        do {
            try self.terminate(withExitCode: 0)
        } catch {
            return error
        }
        return nil
    }
}

// MARK: - Executable Searching
extension Executable {
    // Technically not needed for CreateProcess since
    // it takes process name. It's here to support
    // Executable.resolveExecutablePath
    internal func resolveExecutablePath(withPathValue pathValue: String?) throws -> String {
        switch self.storage {
        case .executable(let executableName):
            return try executableName.withCString(
                encodedAs: UTF16.self
            ) { exeName -> String in
                return try pathValue.withOptionalCString(
                    encodedAs: UTF16.self
                ) { path -> String in
                    let pathLenth = SearchPathW(
                        path,
                        exeName,
                        nil,
                        0,
                        nil,
                        nil
                    )
                    guard pathLenth > 0 else {
                        throw SubprocessError(
                            code: .init(.executableNotFound(executableName)),
                            underlyingError: .init(rawValue: GetLastError())
                        )
                    }
                    return withUnsafeTemporaryAllocation(
                        of: WCHAR.self,
                        capacity: Int(pathLenth) + 1
                    ) {
                        _ = SearchPathW(
                            path,
                            exeName,
                            nil,
                            pathLenth + 1,
                            $0.baseAddress,
                            nil
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
extension Environment {
    internal static let pathVariableName = "Path"

    internal func pathValue() -> String? {
        switch self.config {
        case .inherit(let overrides):
            // If PATH value exists in overrides, use it
            if let value = overrides[Self.pathVariableName] {
                return value
            }
            // Fall back to current process
            return Self.currentEnvironmentValues()[Self.pathVariableName]
        case .custom(let fullEnvironment):
            if let value = fullEnvironment[Self.pathVariableName] {
                return value
            }
            return nil
        }
    }

    internal static func withCopiedEnv<R>(_ body: ([UnsafeMutablePointer<CChar>]) -> R) -> R {
        var values: [UnsafeMutablePointer<CChar>] = []
        guard let pwszEnvironmentBlock = GetEnvironmentStringsW() else {
            return body([])
        }
        defer { FreeEnvironmentStringsW(pwszEnvironmentBlock) }

        var pwszEnvironmentEntry: LPWCH? = pwszEnvironmentBlock
        while let value = pwszEnvironmentEntry {
            let entry = String(decodingCString: value, as: UTF16.self)
            if entry.isEmpty { break }
            values.append(entry.withCString { _strdup($0)! })
            pwszEnvironmentEntry = pwszEnvironmentEntry?.advanced(by: wcslen(value) + 1)
        }
        defer { values.forEach { free($0) } }
        return body(values)
    }
}

// MARK: - ProcessIdentifier

/// A platform independent identifier for a subprocess.
public struct ProcessIdentifier: Sendable, Hashable, Codable {
    /// Windows specifc process identifier value
    public let value: DWORD

    internal init(value: DWORD) {
        self.value = value
    }
}

extension ProcessIdentifier: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "(processID: \(self.value))"
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - Private Utils
extension Configuration {
    private func preSpawn() throws -> (
        applicationName: String?,
        commandAndArgs: String,
        environment: String,
        intendedWorkingDir: String
    ) {
        // Prepare environment
        var env: [String: String] = [:]
        switch self.environment.config {
        case .custom(let customValues):
            // Use the custom values directly
            env = customValues
        case .inherit(let updateValues):
            // Combine current environment
            env = Environment.currentEnvironmentValues()
            for (key, value) in updateValues {
                env.updateValue(value, forKey: key)
            }
        }
        // On Windows, the PATH is required in order to locate dlls needed by
        // the process so we should also pass that to the child
        let pathVariableName = Environment.pathVariableName
        if env[pathVariableName] == nil,
            let parentPath = Environment.currentEnvironmentValues()[pathVariableName]
        {
            env[pathVariableName] = parentPath
        }
        // The environment string must be terminated by a double
        // null-terminator.  Otherwise, CreateProcess will fail with
        // INVALID_PARMETER.
        let environmentString =
            env.map {
                $0.key + "=" + $0.value
            }.joined(separator: "\0") + "\0\0"

        // Prepare arguments
        let (
            applicationName,
            commandAndArgs
        ) = try self.generateWindowsCommandAndAgruments()
        // Validate workingDir
        guard Self.pathAccessible(self.workingDirectory.string) else {
            throw SubprocessError(
                code: .init(
                    .failedToChangeWorkingDirectory(self.workingDirectory.string)
                ),
                underlyingError: nil
            )
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
        withInput input: CreatedPipe,
        output: CreatedPipe,
        error: CreatedPipe
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
        if let inputRead = input.readFileDescriptor {
            info.hStdInput = inputRead.platformDescriptor
        }
        if let inputWrite = input.writeFileDescriptor {
            // Set parent side to be uninhertable
            SetHandleInformation(
                inputWrite.platformDescriptor,
                DWORD(HANDLE_FLAG_INHERIT),
                0
            )
        }
        // Output
        if let outputWrite = output.writeFileDescriptor {
            info.hStdOutput = outputWrite.platformDescriptor
        }
        if let outputRead = output.readFileDescriptor {
            // Set parent side to be uninhertable
            SetHandleInformation(
                outputRead.platformDescriptor,
                DWORD(HANDLE_FLAG_INHERIT),
                0
            )
        }
        // Error
        if let errorWrite = error.writeFileDescriptor {
            info.hStdError = errorWrite.platformDescriptor
        }
        if let errorRead = error.readFileDescriptor {
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
            do {
                _ = try self.executable.resolveExecutablePath(
                    withPathValue: self.environment.pathValue()
                )
            } catch {
                throw error
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
            if !arg.contains(where: { " \t\n\"".contains($0) }) {
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
                if unquoted[firstNonBackslash] == "\"" {
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
internal typealias PlatformFileDescriptor = HANDLE

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
            let writeHandle: HANDLE = writeHandle
        else {
            throw SubprocessError(
                code: .init(.failedToCreatePipe),
                underlyingError: .init(rawValue: GetLastError())
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

    var platformDescriptor: PlatformFileDescriptor {
        return HANDLE(bitPattern: _get_osfhandle(self.rawValue))!
    }

    internal func readChunk(upToLength maxLength: Int) async throws -> SequenceOutput.Buffer? {
        return try await withCheckedThrowingContinuation { continuation in
            self.readUntilEOF(
                upToLength: maxLength
            ) { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let bytes):
                    continuation.resume(returning: SequenceOutput.Buffer(data: bytes))
                }
            }
        }
    }

    internal func readUntilEOF(
        upToLength maxLength: Int,
        resultHandler: @Sendable @escaping (Swift.Result<[UInt8], any (Error & Sendable)>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var totalBytesRead: Int = 0
            var lastError: DWORD? = nil
            let values = [UInt8](
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
                let windowsError = SubprocessError(
                    code: .init(.failedToReadFromSubprocess),
                    underlyingError: .init(rawValue: lastError)
                )
                resultHandler(.failure(windowsError))
            } else {
                resultHandler(.success(values))
            }
        }
    }

    internal func write(
        _ array: [UInt8]
    ) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            // TODO: Figure out a better way to asynchornously write
            DispatchQueue.global(qos: .userInitiated).async {
                array.withUnsafeBytes {
                    self.write($0) { writtenLength, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: writtenLength)
                        }
                    }
                }
            }
        }
    }

    package func write(
        _ ptr: UnsafeRawBufferPointer,
        completion: @escaping (Int, Swift.Error?) -> Void
    ) {
        func _write(
            _ ptr: UnsafeRawBufferPointer,
            count: Int,
            completion: @escaping (Int, Swift.Error?) -> Void
        ) {
            var writtenBytes: DWORD = 0
            let writeSucceed = WriteFile(
                self.platformDescriptor,
                ptr.baseAddress,
                DWORD(count),
                &writtenBytes,
                nil
            )
            if !writeSucceed {
                let error = SubprocessError(
                    code: .init(.failedToWriteToSubprocess),
                    underlyingError: .init(rawValue: GetLastError())
                )
                completion(Int(writtenBytes), error)
            } else {
                completion(Int(writtenBytes), nil)
            }
        }
    }
}

extension Optional where Wrapped == String {
    fileprivate func withOptionalCString<Result, Encoding>(
        encodedAs targetEncoding: Encoding.Type,
        _ body: (UnsafePointer<Encoding.CodeUnit>?) throws -> Result
    ) rethrows -> Result where Encoding: _UnicodeEncoding {
        switch self {
        case .none:
            return try body(nil)
        case .some(let value):
            return try value.withCString(encodedAs: targetEncoding, body)
        }
    }

    fileprivate func withOptionalNTPathRepresentation<Result>(
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
            throw SubprocessError(
                code: .init(.invalidWindowsPath(self)),
                underlyingError: nil
            )
        }

        var iter = self.utf8.makeIterator()
        let bLeadingSlash =
            if [._slash, ._backslash].contains(iter.next()), iter.next()?.isLetter ?? false, iter.next() == ._colon {
                true
            } else { false }

        // Strip the leading `/` on a RFC8089 path (`/[drive-letter]:/...` ).  A
        // leading slash indicates a rooted path on the drive for the current
        // working directory.
        return try Substring(self.utf8.dropFirst(bLeadingSlash ? 1 : 0)).withCString(encodedAs: UTF16.self) {
            pwszPath in
            // 1. Normalize the path first.
            let dwLength: DWORD = GetFullPathNameW(pwszPath, 0, nil, nil)
            return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
                guard GetFullPathNameW(pwszPath, DWORD($0.count), $0.baseAddress, nil) > 0 else {
                    throw SubprocessError(
                        code: .init(.invalidWindowsPath(self)),
                        underlyingError: .init(rawValue: GetLastError())
                    )
                }

                // 2. Perform the operation on the normalized path.
                return try body($0.baseAddress!)
            }
        }
    }
}

extension UInt8 {
    static var _slash: UInt8 { UInt8(ascii: "/") }
    static var _backslash: UInt8 { UInt8(ascii: "\\") }
    static var _colon: UInt8 { UInt8(ascii: ":") }

    var isLetter: Bool? {
        return (0x41...0x5a) ~= self || (0x61...0x7a) ~= self
    }
}

extension OutputProtocol {
    internal func output(from data: [UInt8]) throws -> OutputType {
        return try data.withUnsafeBytes {
            return try self.output(from: $0)
        }
    }
}

#endif  // canImport(WinSDK)
