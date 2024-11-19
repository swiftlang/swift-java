package com.example.org.swift.swiftjava.gradle

import org.gradle.api.Plugin;
import org.gradle.api.Project;

class MyCustomPlugin implements Plugin<Project> {
    @Override
    public void apply(Project project) {
        project.getTasks().register("myTask", task -> {
        task.doLast(t -> System.out.println("Hello from MyCustomPlugin!"));
    });
    }
}
