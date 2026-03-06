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

/// Android SDK version codes, mirroring `android.os.Build.VERSION_CODES`.
///
/// Source: android/platform/frameworks/base, core/java/android/os/Build.java
/// E.g. https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/master/core/java/android/os/Build.java (Apache 2.0)
public enum AndroidAPILevel: Int {
  /// The original, first, version of Android. Released publicly as Android 1.0 in September 2008.
  case BASE = 1
  /// First Android update. Released publicly as Android 1.1 in February 2009.
  case BASE_1_1 = 2
  /// Cupcake. Released publicly as Android 1.5 in April 2009.
  case CUPCAKE = 3
  /// Donut. Released publicly as Android 1.6 in September 2009.
  case DONUT = 4
  /// Eclair. Released publicly as Android 2.0 in October 2009.
  case ECLAIR = 5
  /// Eclair 0.1. Released publicly as Android 2.0.1 in December 2009.
  case ECLAIR_0_1 = 6
  /// Eclair MR1. Released publicly as Android 2.1 in January 2010.
  case ECLAIR_MR1 = 7
  /// Froyo. Released publicly as Android 2.2 in May 2010.
  case FROYO = 8
  /// Gingerbread. Released publicly as Android 2.3 in December 2010.
  case GINGERBREAD = 9
  /// Gingerbread MR1. Released publicly as Android 2.3.3 in February 2011.
  case GINGERBREAD_MR1 = 10
  /// Honeycomb. Released publicly as Android 3.0 in February 2011.
  case HONEYCOMB = 11
  /// Honeycomb MR1. Released publicly as Android 3.1 in May 2011.
  case HONEYCOMB_MR1 = 12
  /// Honeycomb MR2. Released publicly as Android 3.2 in July 2011.
  case HONEYCOMB_MR2 = 13
  /// Ice Cream Sandwich. Released publicly as Android 4.0 in October 2011.
  case ICE_CREAM_SANDWICH = 14
  /// Ice Cream Sandwich MR1. Released publicly as Android 4.03 in December 2011.
  case ICE_CREAM_SANDWICH_MR1 = 15
  /// Jelly Bean. Released publicly as Android 4.1 in July 2012.
  case JELLY_BEAN = 16
  /// Jelly Bean MR1. Released publicly as Android 4.2 in November 2012.
  case JELLY_BEAN_MR1 = 17
  /// Jelly Bean MR2. Released publicly as Android 4.3 in July 2013.
  case JELLY_BEAN_MR2 = 18
  /// KitKat. Released publicly as Android 4.4 in October 2013.
  case KITKAT = 19
  /// KitKat for watches. Released publicly as Android 4.4W in June 2014.
  case KITKAT_WATCH = 20
  /// Lollipop. Released publicly as Android 5.0 in November 2014.
  case LOLLIPOP = 21
  /// Lollipop MR1. Released publicly as Android 5.1 in March 2015.
  case LOLLIPOP_MR1 = 22
  /// Marshmallow. Released publicly as Android 6.0 in October 2015.
  case M = 23
  /// Nougat. Released publicly as Android 7.0 in August 2016.
  case N = 24
  /// Nougat MR1. Released publicly as Android 7.1 in October 2016.
  case N_MR1 = 25
  /// Oreo. Released publicly as Android 8.0 in August 2017.
  case O = 26
  /// Oreo MR1. Released publicly as Android 8.1 in December 2017.
  case O_MR1 = 27
  /// Pie. Released publicly as Android 9 in August 2018.
  case P = 28
  /// Android 10. Released publicly in September 2019.
  case Q = 29
  /// Android 11. Released publicly in September 2020.
  case R = 30
  /// Android 12.
  case S = 31
  /// Android 12L.
  case S_V2 = 32
  /// Tiramisu. Android 13.
  case TIRAMISU = 33
  /// Upside Down Cake. Android 14.
  case UPSIDE_DOWN_CAKE = 34
  /// Vanilla Ice Cream. Android 15.
  case VANILLA_ICE_CREAM = 35
  /// Baklava. Android 16 (upcoming, not yet finalized).
  case BAKLAVA = 36
  /// Magic version number for a current development build, which has not yet turned into an official release.
  case CUR_DEVELOPMENT = 10000

  /// Human-readable release name for this API level.
  public var name: String {
    switch self {
    case .BASE: "Base"
    case .BASE_1_1: "Base 1.1"
    case .CUPCAKE: "Cupcake"
    case .DONUT: "Donut"
    case .ECLAIR: "Eclair"
    case .ECLAIR_0_1: "Eclair 0.1"
    case .ECLAIR_MR1: "Eclair MR1"
    case .FROYO: "Froyo"
    case .GINGERBREAD: "Gingerbread"
    case .GINGERBREAD_MR1: "Gingerbread MR1"
    case .HONEYCOMB: "Honeycomb"
    case .HONEYCOMB_MR1: "Honeycomb MR1"
    case .HONEYCOMB_MR2: "Honeycomb MR2"
    case .ICE_CREAM_SANDWICH: "Ice Cream Sandwich"
    case .ICE_CREAM_SANDWICH_MR1: "Ice Cream Sandwich MR1"
    case .JELLY_BEAN: "Jelly Bean"
    case .JELLY_BEAN_MR1: "Jelly Bean MR1"
    case .JELLY_BEAN_MR2: "Jelly Bean MR2"
    case .KITKAT: "KitKat"
    case .KITKAT_WATCH: "KitKat Watch"
    case .LOLLIPOP: "Lollipop"
    case .LOLLIPOP_MR1: "Lollipop MR1"
    case .M: "Marshmallow"
    case .N: "Nougat"
    case .N_MR1: "Nougat MR1"
    case .O: "Oreo"
    case .O_MR1: "Oreo MR1"
    case .P: "Pie"
    case .Q: "Android 10"
    case .R: "Android 11"
    case .S: "Android 12"
    case .S_V2: "Android 12L"
    case .TIRAMISU: "Tiramisu"
    case .UPSIDE_DOWN_CAKE: "Upside Down Cake"
    case .VANILLA_ICE_CREAM: "Vanilla Ice Cream"
    case .BAKLAVA: "Baklava"
    case .CUR_DEVELOPMENT: "CUR_DEVELOPMENT"
    }
  }
}
