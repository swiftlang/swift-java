//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.javakit.dependencies;

import org.gradle.tooling.GradleConnector;
import org.swift.javakit.annotations.UsedFromSwift;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Arrays;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;

/**
 * Fetches dependencies using the Gradle resolver and returns the resulting classpath which includes
 * the fetched dependency and all of its dependencies.
 */
public class DependencyResolver {

    private static final String COMMAND_OUTPUT_LINE_PREFIX_CLASSPATH = "CLASSPATH:";
    private static final String CLASSPATH_CACHE_FILENAME = "JavaKitDependencyResolver.classpath.swift-java";

    public static String GRADLE_API_DEPENDENCY = "dev.gradleplugins:gradle-api:8.10.1";
    public static String[] BASE_DEPENDENCIES = {
            GRADLE_API_DEPENDENCY
    };

    /**
     * May throw runtime exceptions including {@link org.gradle.api.internal.artifacts.ivyservice.TypedResolveException}
     * if unable to resolve a dependency.
     */
    @UsedFromSwift
    @SuppressWarnings("unused")
    public static String resolveDependenciesToClasspath(String projectBaseDirectoryString, String[] dependencies) throws IOException {
try {
    simpleLog("Fetch dependencies: " + Arrays.toString(dependencies));
    simpleLog("projectBaseDirectoryString =  " + projectBaseDirectoryString);
    var projectBasePath = new File(projectBaseDirectoryString).toPath();

    File projectDir = Files.createTempDirectory("java-swift-dependencies").toFile();
    projectDir.mkdirs();

    if (hasDependencyResolverDependenciesLoaded()) {
        // === Resolve dependencies using Gradle API in-process
        simpleLog("Gradle API runtime dependency is available, resolve dependencies...");
        return resolveDependenciesUsingAPI(projectDir, dependencies);
    }

    // === Bootstrap the resolver dependencies and cache them
    simpleLog("Gradle API not available on classpath, bootstrap %s dependencies: %s"
            .formatted(DependencyResolver.class.getSimpleName(), Arrays.toString(BASE_DEPENDENCIES)));
    String dependencyResolverDependenciesClasspath = bootstrapDependencyResolverClasspath();
    writeDependencyResolverClasspath(projectBasePath, dependencyResolverDependenciesClasspath);

    // --- Resolve dependencies using sub-process process
    // TODO: it would be nice to just add the above classpath to the system classloader and here call the API
    //       immediately, but that's challenging and not a stable API we can rely on (hacks exist to add paths
    //       to system classloader but are not reliable).
    printBuildFiles(projectDir, dependencies);
    return resolveDependenciesWithSubprocess(projectDir);
} catch (Exception e) {
    e.printStackTrace();
    throw e;
}
    }


    /**
     * Use an external {@code gradle} invocation in order to download dependencies such that we can use `gradle-api`
     * next time we want to resolve dependencies. This uses an external process and is sligtly worse than using the API
     * directly.
     *
     * @return classpath obtained for the dependencies
     * @throws IOException                 if file IO failed during mock project creation
     * @throws SwiftJavaBootstrapException if the resolve failed for some other reason
     */
    private static String bootstrapDependencyResolverClasspath() throws IOException, SwiftJavaBootstrapException {
        var dependencies = BASE_DEPENDENCIES;
        simpleLog("Bootstrap gradle-api for DependencyResolver: " + Arrays.toString(dependencies));

        File bootstrapDir = Files.createTempDirectory("swift-java-dependency-resolver").toFile();
        bootstrapDir.mkdirs();
        simpleLog("Bootstrap dependencies using project at: %s".formatted(bootstrapDir));

        printBuildFiles(bootstrapDir, dependencies);

        var bootstrapClasspath = resolveDependenciesWithSubprocess(bootstrapDir);
        simpleLog("Prepared dependency resolver bootstrap classpath: " + bootstrapClasspath.split(":").length + " entries");

        return bootstrapClasspath;

    }

    private static String resolveDependenciesWithSubprocess(File gradleProjectDir) throws IOException {
        if (!gradleProjectDir.isDirectory()) {
            throw new IllegalArgumentException("Gradle project directory is not a directory: " + gradleProjectDir);
        }

        File stdoutFile = File.createTempFile("swift-java-bootstrap", ".stdout", gradleProjectDir);
        stdoutFile.deleteOnExit();
        File stderrFile = File.createTempFile("swift-java-bootstrap", ".stderr", gradleProjectDir);
        stderrFile.deleteOnExit();

        try {
            ProcessBuilder gradleBuilder = new ProcessBuilder("gradle", ":printRuntimeClasspath");
            gradleBuilder.directory(gradleProjectDir);
            gradleBuilder.redirectOutput(stdoutFile);
            gradleBuilder.redirectError(stderrFile);
            Process gradleProcess = gradleBuilder.start();
            gradleProcess.waitFor(10, TimeUnit.MINUTES); // TODO: must be configurable

            if (gradleProcess.exitValue() != 0) {
                throw new SwiftJavaBootstrapException("Failed to resolve bootstrap dependencies, exit code: " + gradleProcess.exitValue());
            }

            Stream<String> lines = Files.readAllLines(stdoutFile.toPath()).stream();
            var bootstrapClasspath = getClasspathFromGradleCommandOutput(lines);
            return bootstrapClasspath;
        } catch (Exception ex) {
            simpleLog("stdoutFile = " + stdoutFile);
            simpleLog("stderrFile = " + stderrFile);

            ex.printStackTrace();
            throw new SwiftJavaBootstrapException("Failed to bootstrap dependencies necessary for " +
                    DependencyResolver.class.getCanonicalName() + "!", ex);
        }
    }

    private static void writeDependencyResolverClasspath(Path projectBasePath, String dependencyResolverDependenciesClasspath) throws IOException {
        File swiftBuildDirectory = new File(String.valueOf(projectBasePath), ".build");
        swiftBuildDirectory.mkdirs();

        File dependencyResolverClasspathCacheFile = new File(swiftBuildDirectory, CLASSPATH_CACHE_FILENAME);
        dependencyResolverClasspathCacheFile.createNewFile();
        simpleLog("Cache %s dependencies classpath at: '%s'. Subsequent dependency resolutions will use gradle-api."
                .formatted(DependencyResolver.class.getSimpleName(), dependencyResolverClasspathCacheFile.toPath()));

        Files.writeString(
                dependencyResolverClasspathCacheFile.toPath(),
                dependencyResolverDependenciesClasspath,
                StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING);
    }

    /**
     * Detect if we have the necessary dependencies loaded.
     */
    private static boolean hasDependencyResolverDependenciesLoaded() {
        return hasDependencyResolverDependenciesLoaded(DependencyResolver.class.getClassLoader());
    }

    /**
     * Resolve dependencies in the passed project directory and return the resulting classpath.
     *
     * @return classpath which was resolved for the dependencies
     */
    private static String resolveDependenciesUsingAPI(File projectDir, String[] dependencies) throws FileNotFoundException {
        printBuildFiles(projectDir, dependencies);

        var connection = GradleConnector.newConnector()
                .forProjectDirectory(projectDir)
                .connect();

        try (connection) {
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            PrintStream printStream = new PrintStream(outputStream);

            connection.newBuild().forTasks(":printRuntimeClasspath")
                    .setStandardError(new NoopOutputStream())
                    .setStandardOutput(printStream)
                    .run();

            var all = outputStream.toString();
            var classpath = Arrays.stream(all.split("\n"))
                    .filter(s -> s.startsWith(COMMAND_OUTPUT_LINE_PREFIX_CLASSPATH))
                    .map(s -> s.substring(COMMAND_OUTPUT_LINE_PREFIX_CLASSPATH.length()))
                    .findFirst().orElseThrow(() -> new RuntimeException("Could not find classpath output from ':printRuntimeClasspath' task."));
            return classpath;
        }
    }

    private static String getClasspathFromGradleCommandOutput(Stream<String> lines) {
        return lines.filter(s -> s.startsWith(COMMAND_OUTPUT_LINE_PREFIX_CLASSPATH))
                .map(s -> s.substring(COMMAND_OUTPUT_LINE_PREFIX_CLASSPATH.length()))
                .findFirst().orElseThrow(() -> new RuntimeException("Could not find classpath output from gradle command output task."));
    }


    private static boolean hasDependencyResolverDependenciesLoaded(ClassLoader classLoader) {
        try {
            classLoader.loadClass("org.gradle.tooling.GradleConnector");
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    private static void printBuildFiles(File projectDir, String[] dependencies) throws FileNotFoundException {
        File buildFile = new File(projectDir, "build.gradle");
        try (PrintWriter writer = new PrintWriter(buildFile)) {
            writer.println("plugins { id 'java-library' }");
            writer.println("repositories { mavenCentral() }");

            writer.println("dependencies {");
            for (String dependency : dependencies) {
                writer.println("implementation(\"" + dependency + "\")");
            }
            writer.println("}");

            writer.println("""
                    task printRuntimeClasspath {
                        def runtimeClasspath = sourceSets.main.runtimeClasspath
                        inputs.files(runtimeClasspath)
                        doLast {
                            println("CLASSPATH:${runtimeClasspath.asPath}")
                        }
                    }
                    """);
        }

        File settingsFile = new File(projectDir, "settings.gradle.kts");
        try (PrintWriter writer = new PrintWriter(settingsFile)) {
            writer.println("""
                    rootProject.name = "swift-java-resolve-temp-project"
                    """);
        }
    }

    private static void simpleLog(String message) {
        System.err.println("[info][swift-java/" + DependencyResolver.class.getSimpleName() + "] " + message);
    }

    private static class NoopOutputStream extends OutputStream {
        @Override
        public void write(int b) throws IOException {
            // ignore
        }
    }
}
