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

package com.example.swift;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.ConfinedSwiftMemorySession;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class VehicleEnumTest {
    @Test
    void bicycle() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            assertNotNull(vehicle);
        }
    }

    @Test
    void car() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            Vehicle vehicle = Vehicle.car("Porsche 911", arena);
            assertNotNull(vehicle);
        }
    }

    @Test
    void motorbike() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            Vehicle vehicle = Vehicle.motorbike("Yamaha", 750, arena);
            assertNotNull(vehicle);
        }
    }

    @Test
    void initName() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            assertFalse(Vehicle.init("bus", arena).isPresent());
            Optional<Vehicle> vehicle = Vehicle.init("car", arena);
            assertTrue(vehicle.isPresent());
            assertNotNull(vehicle.get());
        }
    }

    @Test
    void nameProperty() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            assertEquals("bicycle", vehicle.getName());
        }
    }

    @Test
    void isFasterThan() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            Vehicle bicycle = Vehicle.bicycle(arena);
            Vehicle car = Vehicle.car("Porsche 911", arena);
            assertFalse(bicycle.isFasterThan(car));
            assertTrue(car.isFasterThan(bicycle));
        }
    }

    @Test
    void upgrade() {
        try (var arena = new ConfinedSwiftMemorySession()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            assertEquals("bicycle", vehicle.getName());
            vehicle.upgrade();
            assertEquals("car", vehicle.getName());
            vehicle.upgrade();
            assertEquals("motorbike", vehicle.getName());
        }
    }
}