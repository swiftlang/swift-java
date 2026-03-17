package com.example;

/**
 * A simple HelloWorld class used for testing swift-java dependency resolution.
 */
public class HelloWorld {

    private final String greeting;

    public HelloWorld() {
        this.greeting = "Hello, World!";
    }

    public HelloWorld(String greeting) {
        this.greeting = greeting;
    }

    public String getGreeting() {
        return greeting;
    }

    @Override
    public String toString() {
        return "HelloWorld{greeting='" + greeting + "'}";
    }
}
