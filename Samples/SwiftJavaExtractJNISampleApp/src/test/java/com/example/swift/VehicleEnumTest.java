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
import org.swift.swiftkit.core.SwiftArena;

import java.lang.foreign.Arena;
import java.util.Optional;
import java.util.OptionalInt;

import static org.junit.jupiter.api.Assertions.*;

public class VehicleEnumTest {
    @Test
    void bicycle() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            assertNotNull(vehicle);
        }
    }

    @Test
    void car() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.car("Porsche 911", Optional.empty(), arena);
            assertNotNull(vehicle);
        }
    }

    @Test
    void motorbike() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.motorbike("Yamaha", 750, OptionalInt.empty(), arena);
            assertNotNull(vehicle);
        }
    }

    @Test
    void initName() {
        try (var arena = SwiftArena.ofConfined()) {
            assertFalse(Vehicle.init("bus", arena).isPresent());
            Optional<Vehicle> vehicle = Vehicle.init("car", arena);
            assertTrue(vehicle.isPresent());
            assertNotNull(vehicle.get());
        }
    }

    @Test
    void nameProperty() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            assertEquals("bicycle", vehicle.getName());
        }
    }

    @Test
    void isFasterThan() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle bicycle = Vehicle.bicycle(arena);
            Vehicle car = Vehicle.car("Porsche 911", Optional.empty(), arena);
            assertFalse(bicycle.isFasterThan(car));
            assertTrue(car.isFasterThan(bicycle));
        }
    }

    @Test
    void upgrade() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            assertEquals("bicycle", vehicle.getName());
            vehicle.upgrade();
            assertEquals("car", vehicle.getName());
            vehicle.upgrade();
            assertEquals("motorbike", vehicle.getName());
        }
    }

    @Test
    void getAsBicycle() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            Vehicle.Bicycle bicycle = vehicle.getAsBicycle().orElseThrow();
            assertNotNull(bicycle);
        }
    }

    @Test
    void getAsCar() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.car("BMW", Optional.empty(), arena);
            Vehicle.Car car = vehicle.getAsCar().orElseThrow();
            assertEquals("BMW", car.arg0());

            vehicle = Vehicle.car("BMW", Optional.of("Long trailer"), arena);
            car = vehicle.getAsCar().orElseThrow();
            assertEquals("Long trailer", car.trailer().orElseThrow());
        }
    }

    @Test
    void getAsMotorbike() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.motorbike("Yamaha", 750, OptionalInt.empty(), arena);
            Vehicle.Motorbike motorbike = vehicle.getAsMotorbike().orElseThrow();
            assertEquals("Yamaha", motorbike.arg0());
            assertEquals(750, motorbike.horsePower());
            assertEquals(OptionalInt.empty(), motorbike.helmets());

            vehicle = Vehicle.motorbike("Yamaha", 750, OptionalInt.of(2), arena);
            motorbike = vehicle.getAsMotorbike().orElseThrow();
            assertEquals(OptionalInt.of(2), motorbike.helmets());
        }
    }

    @Test
    void getAsTransformer() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.transformer(Vehicle.bicycle(arena), Vehicle.car("BMW", Optional.empty(), arena), arena);
            Vehicle.Transformer transformer = vehicle.getAsTransformer(arena).orElseThrow();
            assertTrue(transformer.front().getAsBicycle().isPresent());
            assertEquals("BMW", transformer.back().getAsCar().orElseThrow().arg0());
        }
    }

    @Test
    void getAsBoat() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.boat(OptionalInt.of(10), Optional.of((short) 1), arena);
            Vehicle.Boat boat = vehicle.getAsBoat().orElseThrow();
            assertEquals(OptionalInt.of(10), boat.passengers());
            assertEquals(Optional.of((short) 1), boat.length());
        }
    }

    @Test
    void associatedValuesAreCopied() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.car("BMW", Optional.empty(), arena);
            Vehicle.Car car = vehicle.getAsCar().orElseThrow();
            assertEquals("BMW", car.arg0());
            vehicle.upgrade();
            Vehicle.Motorbike motorbike = vehicle.getAsMotorbike().orElseThrow();
            assertNotNull(motorbike);
            // Motorbike should still remain
            assertEquals("BMW", car.arg0());
        }
    }

    @Test
    void getDiscriminator() {
        try (var arena = SwiftArena.ofConfined()) {
            assertEquals(Vehicle.Discriminator.BICYCLE, Vehicle.bicycle(arena).getDiscriminator());
            assertEquals(Vehicle.Discriminator.CAR, Vehicle.car("BMW", Optional.empty(), arena).getDiscriminator());
            assertEquals(Vehicle.Discriminator.MOTORBIKE, Vehicle.motorbike("Yamaha", 750, OptionalInt.empty(), arena).getDiscriminator());
            assertEquals(Vehicle.Discriminator.TRANSFORMER, Vehicle.transformer(Vehicle.bicycle(arena), Vehicle.bicycle(arena), arena).getDiscriminator());
        }
    }

    @Test
    void getCase() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.bicycle(arena);
            Vehicle.Case caseElement = vehicle.getCase(arena);
            assertInstanceOf(Vehicle.Bicycle.class, caseElement);
        }
    }

    @Test
    void switchGetCase() {
        try (var arena = SwiftArena.ofConfined()) {
            Vehicle vehicle = Vehicle.car("BMW", Optional.empty(), arena);
            switch (vehicle.getCase(arena)) {
                case Vehicle.Bicycle b:
                    fail("Was bicycle");
                    break;
                case Vehicle.Car car:
                    assertEquals("BMW", car.arg0());
                    break;
                case Vehicle.Motorbike motorbike:
                    fail("Was motorbike");
                    break;
                case Vehicle.Transformer transformer:
                    fail("Was transformer");
                    break;
                case Vehicle.Boat b:
                    fail("Was boat");
                    break;
            }
        }
    }

}