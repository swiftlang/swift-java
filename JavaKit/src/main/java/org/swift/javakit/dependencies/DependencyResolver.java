package org.swift.javakit.dependencies;

import org.gradle.tooling.GradleConnector;

import java.io.*;
import java.nio.file.Files;
import java.util.Arrays;

public class DependencyResolver {
    /**
     * May throw runtime exceptions including {@link org.gradle.api.internal.artifacts.ivyservice.TypedResolveException}
     * if unable to resolve a dependency.
     */
    public static String getClasspathWithDependency(String[] dependencies) throws IOException {
        File projectDir = Files.createTempDirectory("java-swift-dependencies").toFile();
        projectDir.mkdirs();

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
                    rootProject.name = "swift-java-resolve-dependencies-temp-project"
                    """);
        }

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
                    .filter(s -> s.startsWith("CLASSPATH:"))
                    .map(s -> s.substring("CLASSPATH:".length()))
                    .findFirst().orElseThrow(() -> new RuntimeException("Could not find classpath output from ':printRuntimeClasspath' task."));
            return classpath;
        }
    }

    private static class NoopOutputStream extends OutputStream {
        @Override
        public void write(int b) throws IOException {
            // ignore
        }
    }
}
