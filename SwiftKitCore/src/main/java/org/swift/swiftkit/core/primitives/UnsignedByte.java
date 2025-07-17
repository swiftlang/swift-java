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

package org.swift.swiftkit.core.primitives;

import java.math.BigInteger;
import java.util.Objects;

/**
 * Represents an 32-bit unsigned integer, with a value between 0 and (@{@code 2^8 - 1}).
 *
 * <p> Equivalent to the {@code UInt8} Swift type.
 */
public final class UnsignedByte extends Number implements Comparable<UnsignedByte> {

    private final static UnsignedByte ZERO = representedByBitsOf((byte) 0);
    private final static UnsignedByte MAX_VALUE = representedByBitsOf((byte) -1);
    private final static long MASK = 0xffL;

    public final static long BIT_COUNT = 8;

    final byte value;

    private UnsignedByte(byte bits) {
        this.value = bits;
    }

    /**
     * Accept a signed Java @{code int} value, and interpret it as-if it was an unsigned value.
     * In other words, do not interpret the negative bit as "negative", but as part of the unsigned integers value.
     *
     * @param bits bit value to store in this unsigned integer
     * @return unsigned integer representation of the passed in value
     */
    public static UnsignedByte representedByBitsOf(byte bits) {
        switch (bits) {
            case 0: return ZERO;
            case 1: return Cached.V001;
            case 2: return Cached.V002;
            case 3: return Cached.V003;
            case 4: return Cached.V004;
            case 5: return Cached.V005;
            case 6: return Cached.V006;
            case 7: return Cached.V007;
            case 8: return Cached.V008;
            case 9: return Cached.V009;
            case 10: return Cached.V010;
            case 11: return Cached.V011;
            case 12: return Cached.V012;
            case 13: return Cached.V013;
            case 14: return Cached.V014;
            case 15: return Cached.V015;
            case 16: return Cached.V016;
            case 17: return Cached.V017;
            case 18: return Cached.V018;
            case 19: return Cached.V019;
            case 20: return Cached.V020;
            case 21: return Cached.V021;
            case 22: return Cached.V022;
            case 23: return Cached.V023;
            case 24: return Cached.V024;
            case 25: return Cached.V025;
            case 26: return Cached.V026;
            case 27: return Cached.V027;
            case 28: return Cached.V028;
            case 29: return Cached.V029;
            case 30: return Cached.V030;
            case 31: return Cached.V031;
            case 32: return Cached.V032;
            case 33: return Cached.V033;
            case 34: return Cached.V034;
            case 35: return Cached.V035;
            case 36: return Cached.V036;
            case 37: return Cached.V037;
            case 38: return Cached.V038;
            case 39: return Cached.V039;
            case 40: return Cached.V040;
            case 41: return Cached.V041;
            case 42: return Cached.V042;
            case 43: return Cached.V043;
            case 44: return Cached.V044;
            case 45: return Cached.V045;
            case 46: return Cached.V046;
            case 47: return Cached.V047;
            case 48: return Cached.V048;
            case 49: return Cached.V049;
            case 50: return Cached.V050;
            case 51: return Cached.V051;
            case 52: return Cached.V052;
            case 53: return Cached.V053;
            case 54: return Cached.V054;
            case 55: return Cached.V055;
            case 56: return Cached.V056;
            case 57: return Cached.V057;
            case 58: return Cached.V058;
            case 59: return Cached.V059;
            case 60: return Cached.V060;
            case 61: return Cached.V061;
            case 62: return Cached.V062;
            case 63: return Cached.V063;
            case 64: return Cached.V064;
            case 65: return Cached.V065;
            case 66: return Cached.V066;
            case 67: return Cached.V067;
            case 68: return Cached.V068;
            case 69: return Cached.V069;
            case 70: return Cached.V070;
            case 71: return Cached.V071;
            case 72: return Cached.V072;
            case 73: return Cached.V073;
            case 74: return Cached.V074;
            case 75: return Cached.V075;
            case 76: return Cached.V076;
            case 77: return Cached.V077;
            case 78: return Cached.V078;
            case 79: return Cached.V079;
            case 80: return Cached.V080;
            case 81: return Cached.V081;
            case 82: return Cached.V082;
            case 83: return Cached.V083;
            case 84: return Cached.V084;
            case 85: return Cached.V085;
            case 86: return Cached.V086;
            case 87: return Cached.V087;
            case 88: return Cached.V088;
            case 89: return Cached.V089;
            case 90: return Cached.V090;
            case 91: return Cached.V091;
            case 92: return Cached.V092;
            case 93: return Cached.V093;
            case 94: return Cached.V094;
            case 95: return Cached.V095;
            case 96: return Cached.V096;
            case 97: return Cached.V097;
            case 98: return Cached.V098;
            case 99: return Cached.V099;
            case 100: return Cached.V100;
            case 101: return Cached.V101;
            case 102: return Cached.V102;
            case 103: return Cached.V103;
            case 104: return Cached.V104;
            case 105: return Cached.V105;
            case 106: return Cached.V106;
            case 107: return Cached.V107;
            case 108: return Cached.V108;
            case 109: return Cached.V109;
            case 110: return Cached.V110;
            case 111: return Cached.V111;
            case 112: return Cached.V112;
            case 113: return Cached.V113;
            case 114: return Cached.V114;
            case 115: return Cached.V115;
            case 116: return Cached.V116;
            case 117: return Cached.V117;
            case 118: return Cached.V118;
            case 119: return Cached.V119;
            case 120: return Cached.V120;
            case 121: return Cached.V121;
            case 122: return Cached.V122;
            case 123: return Cached.V123;
            case 124: return Cached.V124;
            case 125: return Cached.V125;
            case 126: return Cached.V126;
            case 127: return Cached.V127;
            case -1: return Cached.V128;
            case -2: return Cached.V129;
            case -3: return Cached.V130;
            case -4: return Cached.V131;
            case -5: return Cached.V132;
            case -6: return Cached.V133;
            case -7: return Cached.V134;
            case -8: return Cached.V135;
            case -9: return Cached.V136;
            case -10: return Cached.V137;
            case -11: return Cached.V138;
            case -12: return Cached.V139;
            case -13: return Cached.V140;
            case -14: return Cached.V141;
            case -15: return Cached.V142;
            case -16: return Cached.V143;
            case -17: return Cached.V144;
            case -18: return Cached.V145;
            case -19: return Cached.V146;
            case -20: return Cached.V147;
            case -21: return Cached.V148;
            case -22: return Cached.V149;
            case -23: return Cached.V150;
            case -24: return Cached.V151;
            case -25: return Cached.V152;
            case -26: return Cached.V153;
            case -27: return Cached.V154;
            case -28: return Cached.V155;
            case -29: return Cached.V156;
            case -30: return Cached.V157;
            case -31: return Cached.V158;
            case -32: return Cached.V159;
            case -33: return Cached.V160;
            case -34: return Cached.V161;
            case -35: return Cached.V162;
            case -36: return Cached.V163;
            case -37: return Cached.V164;
            case -38: return Cached.V165;
            case -39: return Cached.V166;
            case -40: return Cached.V167;
            case -41: return Cached.V168;
            case -42: return Cached.V169;
            case -43: return Cached.V170;
            case -44: return Cached.V171;
            case -45: return Cached.V172;
            case -46: return Cached.V173;
            case -47: return Cached.V174;
            case -48: return Cached.V175;
            case -49: return Cached.V176;
            case -50: return Cached.V177;
            case -51: return Cached.V178;
            case -52: return Cached.V179;
            case -53: return Cached.V180;
            case -54: return Cached.V181;
            case -55: return Cached.V182;
            case -56: return Cached.V183;
            case -57: return Cached.V184;
            case -58: return Cached.V185;
            case -59: return Cached.V186;
            case -60: return Cached.V187;
            case -61: return Cached.V188;
            case -62: return Cached.V189;
            case -63: return Cached.V190;
            case -64: return Cached.V191;
            case -65: return Cached.V192;
            case -66: return Cached.V193;
            case -67: return Cached.V194;
            case -68: return Cached.V195;
            case -69: return Cached.V196;
            case -70: return Cached.V197;
            case -71: return Cached.V198;
            case -72: return Cached.V199;
            case -73: return Cached.V200;
            case -74: return Cached.V201;
            case -75: return Cached.V202;
            case -76: return Cached.V203;
            case -77: return Cached.V204;
            case -78: return Cached.V205;
            case -79: return Cached.V206;
            case -80: return Cached.V207;
            case -81: return Cached.V208;
            case -82: return Cached.V209;
            case -83: return Cached.V210;
            case -84: return Cached.V211;
            case -85: return Cached.V212;
            case -86: return Cached.V213;
            case -87: return Cached.V214;
            case -88: return Cached.V215;
            case -89: return Cached.V216;
            case -90: return Cached.V217;
            case -91: return Cached.V218;
            case -92: return Cached.V219;
            case -93: return Cached.V220;
            case -94: return Cached.V221;
            case -95: return Cached.V222;
            case -96: return Cached.V223;
            case -97: return Cached.V224;
            case -98: return Cached.V225;
            case -99: return Cached.V226;
            case -100: return Cached.V227;
            case -101: return Cached.V228;
            case -102: return Cached.V229;
            case -103: return Cached.V230;
            case -104: return Cached.V231;
            case -105: return Cached.V232;
            case -106: return Cached.V233;
            case -107: return Cached.V234;
            case -108: return Cached.V235;
            case -109: return Cached.V236;
            case -110: return Cached.V237;
            case -111: return Cached.V238;
            case -112: return Cached.V239;
            case -113: return Cached.V240;
            case -114: return Cached.V241;
            case -115: return Cached.V242;
            case -116: return Cached.V243;
            case -117: return Cached.V244;
            case -118: return Cached.V245;
            case -119: return Cached.V246;
            case -120: return Cached.V247;
            case -121: return Cached.V248;
            case -122: return Cached.V249;
            case -123: return Cached.V250;
            case -124: return Cached.V251;
            case -125: return Cached.V252;
            case -126: return Cached.V253;
            case -127: return Cached.V254;
            case -128: return Cached.V255;
        }
        return new UnsignedByte(bits);
    }

    public static UnsignedByte valueOf(long value) throws UnsignedOverflowException {
        if ((value & UnsignedByte.MASK) != value) {
            throw new UnsignedOverflowException(String.valueOf(value), UnsignedByte.class);
        }
        return representedByBitsOf((byte) value);
    }

    @Override
    public int compareTo(UnsignedByte o) {
        Objects.requireNonNull(o);
        return ((int) (value & MASK)) - ((int) (o.value & MASK));
    }

    /**
     * Warning, this value is based on the exact bytes interpreted as a signed integer.
     */
    @Override
    public int intValue() {
        return value;
    }

    @Override
    public long longValue() {
        return value;
    }

    @Override
    public float floatValue() {
        return longValue(); // rely on standard decimal -> floating point conversion
    }

    @Override
    public double doubleValue() {
        return longValue(); // rely on standard decimal -> floating point conversion
    }

    public BigInteger bigIntegerValue() {
        return BigInteger.valueOf(value);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        UnsignedByte that = (UnsignedByte) o;
        return value == that.value;
    }

    @Override
    public int hashCode() {
        return value;
    }

    private static final class Cached {
        private final static UnsignedByte V001 = new UnsignedByte((byte) 1);
        private final static UnsignedByte V002 = new UnsignedByte((byte) 2);
        private final static UnsignedByte V003 = new UnsignedByte((byte) 3);
        private final static UnsignedByte V004 = new UnsignedByte((byte) 4);
        private final static UnsignedByte V005 = new UnsignedByte((byte) 5);
        private final static UnsignedByte V006 = new UnsignedByte((byte) 6);
        private final static UnsignedByte V007 = new UnsignedByte((byte) 7);
        private final static UnsignedByte V008 = new UnsignedByte((byte) 8);
        private final static UnsignedByte V009 = new UnsignedByte((byte) 9);
        private final static UnsignedByte V010 = new UnsignedByte((byte) 10);
        private final static UnsignedByte V011 = new UnsignedByte((byte) 11);
        private final static UnsignedByte V012 = new UnsignedByte((byte) 12);
        private final static UnsignedByte V013 = new UnsignedByte((byte) 13);
        private final static UnsignedByte V014 = new UnsignedByte((byte) 14);
        private final static UnsignedByte V015 = new UnsignedByte((byte) 15);
        private final static UnsignedByte V016 = new UnsignedByte((byte) 16);
        private final static UnsignedByte V017 = new UnsignedByte((byte) 17);
        private final static UnsignedByte V018 = new UnsignedByte((byte) 18);
        private final static UnsignedByte V019 = new UnsignedByte((byte) 19);
        private final static UnsignedByte V020 = new UnsignedByte((byte) 20);
        private final static UnsignedByte V021 = new UnsignedByte((byte) 21);
        private final static UnsignedByte V022 = new UnsignedByte((byte) 22);
        private final static UnsignedByte V023 = new UnsignedByte((byte) 23);
        private final static UnsignedByte V024 = new UnsignedByte((byte) 24);
        private final static UnsignedByte V025 = new UnsignedByte((byte) 25);
        private final static UnsignedByte V026 = new UnsignedByte((byte) 26);
        private final static UnsignedByte V027 = new UnsignedByte((byte) 27);
        private final static UnsignedByte V028 = new UnsignedByte((byte) 28);
        private final static UnsignedByte V029 = new UnsignedByte((byte) 29);
        private final static UnsignedByte V030 = new UnsignedByte((byte) 30);
        private final static UnsignedByte V031 = new UnsignedByte((byte) 31);
        private final static UnsignedByte V032 = new UnsignedByte((byte) 32);
        private final static UnsignedByte V033 = new UnsignedByte((byte) 33);
        private final static UnsignedByte V034 = new UnsignedByte((byte) 34);
        private final static UnsignedByte V035 = new UnsignedByte((byte) 35);
        private final static UnsignedByte V036 = new UnsignedByte((byte) 36);
        private final static UnsignedByte V037 = new UnsignedByte((byte) 37);
        private final static UnsignedByte V038 = new UnsignedByte((byte) 38);
        private final static UnsignedByte V039 = new UnsignedByte((byte) 39);
        private final static UnsignedByte V040 = new UnsignedByte((byte) 40);
        private final static UnsignedByte V041 = new UnsignedByte((byte) 41);
        private final static UnsignedByte V042 = new UnsignedByte((byte) 42);
        private final static UnsignedByte V043 = new UnsignedByte((byte) 43);
        private final static UnsignedByte V044 = new UnsignedByte((byte) 44);
        private final static UnsignedByte V045 = new UnsignedByte((byte) 45);
        private final static UnsignedByte V046 = new UnsignedByte((byte) 46);
        private final static UnsignedByte V047 = new UnsignedByte((byte) 47);
        private final static UnsignedByte V048 = new UnsignedByte((byte) 48);
        private final static UnsignedByte V049 = new UnsignedByte((byte) 49);
        private final static UnsignedByte V050 = new UnsignedByte((byte) 50);
        private final static UnsignedByte V051 = new UnsignedByte((byte) 51);
        private final static UnsignedByte V052 = new UnsignedByte((byte) 52);
        private final static UnsignedByte V053 = new UnsignedByte((byte) 53);
        private final static UnsignedByte V054 = new UnsignedByte((byte) 54);
        private final static UnsignedByte V055 = new UnsignedByte((byte) 55);
        private final static UnsignedByte V056 = new UnsignedByte((byte) 56);
        private final static UnsignedByte V057 = new UnsignedByte((byte) 57);
        private final static UnsignedByte V058 = new UnsignedByte((byte) 58);
        private final static UnsignedByte V059 = new UnsignedByte((byte) 59);
        private final static UnsignedByte V060 = new UnsignedByte((byte) 60);
        private final static UnsignedByte V061 = new UnsignedByte((byte) 61);
        private final static UnsignedByte V062 = new UnsignedByte((byte) 62);
        private final static UnsignedByte V063 = new UnsignedByte((byte) 63);
        private final static UnsignedByte V064 = new UnsignedByte((byte) 64);
        private final static UnsignedByte V065 = new UnsignedByte((byte) 65);
        private final static UnsignedByte V066 = new UnsignedByte((byte) 66);
        private final static UnsignedByte V067 = new UnsignedByte((byte) 67);
        private final static UnsignedByte V068 = new UnsignedByte((byte) 68);
        private final static UnsignedByte V069 = new UnsignedByte((byte) 69);
        private final static UnsignedByte V070 = new UnsignedByte((byte) 70);
        private final static UnsignedByte V071 = new UnsignedByte((byte) 71);
        private final static UnsignedByte V072 = new UnsignedByte((byte) 72);
        private final static UnsignedByte V073 = new UnsignedByte((byte) 73);
        private final static UnsignedByte V074 = new UnsignedByte((byte) 74);
        private final static UnsignedByte V075 = new UnsignedByte((byte) 75);
        private final static UnsignedByte V076 = new UnsignedByte((byte) 76);
        private final static UnsignedByte V077 = new UnsignedByte((byte) 77);
        private final static UnsignedByte V078 = new UnsignedByte((byte) 78);
        private final static UnsignedByte V079 = new UnsignedByte((byte) 79);
        private final static UnsignedByte V080 = new UnsignedByte((byte) 80);
        private final static UnsignedByte V081 = new UnsignedByte((byte) 81);
        private final static UnsignedByte V082 = new UnsignedByte((byte) 82);
        private final static UnsignedByte V083 = new UnsignedByte((byte) 83);
        private final static UnsignedByte V084 = new UnsignedByte((byte) 84);
        private final static UnsignedByte V085 = new UnsignedByte((byte) 85);
        private final static UnsignedByte V086 = new UnsignedByte((byte) 86);
        private final static UnsignedByte V087 = new UnsignedByte((byte) 87);
        private final static UnsignedByte V088 = new UnsignedByte((byte) 88);
        private final static UnsignedByte V089 = new UnsignedByte((byte) 89);
        private final static UnsignedByte V090 = new UnsignedByte((byte) 90);
        private final static UnsignedByte V091 = new UnsignedByte((byte) 91);
        private final static UnsignedByte V092 = new UnsignedByte((byte) 92);
        private final static UnsignedByte V093 = new UnsignedByte((byte) 93);
        private final static UnsignedByte V094 = new UnsignedByte((byte) 94);
        private final static UnsignedByte V095 = new UnsignedByte((byte) 95);
        private final static UnsignedByte V096 = new UnsignedByte((byte) 96);
        private final static UnsignedByte V097 = new UnsignedByte((byte) 97);
        private final static UnsignedByte V098 = new UnsignedByte((byte) 98);
        private final static UnsignedByte V099 = new UnsignedByte((byte) 99);
        private final static UnsignedByte V100 = new UnsignedByte((byte) 100);
        private final static UnsignedByte V101 = new UnsignedByte((byte) 101);
        private final static UnsignedByte V102 = new UnsignedByte((byte) 102);
        private final static UnsignedByte V103 = new UnsignedByte((byte) 103);
        private final static UnsignedByte V104 = new UnsignedByte((byte) 104);
        private final static UnsignedByte V105 = new UnsignedByte((byte) 105);
        private final static UnsignedByte V106 = new UnsignedByte((byte) 106);
        private final static UnsignedByte V107 = new UnsignedByte((byte) 107);
        private final static UnsignedByte V108 = new UnsignedByte((byte) 108);
        private final static UnsignedByte V109 = new UnsignedByte((byte) 109);
        private final static UnsignedByte V110 = new UnsignedByte((byte) 110);
        private final static UnsignedByte V111 = new UnsignedByte((byte) 111);
        private final static UnsignedByte V112 = new UnsignedByte((byte) 112);
        private final static UnsignedByte V113 = new UnsignedByte((byte) 113);
        private final static UnsignedByte V114 = new UnsignedByte((byte) 114);
        private final static UnsignedByte V115 = new UnsignedByte((byte) 115);
        private final static UnsignedByte V116 = new UnsignedByte((byte) 116);
        private final static UnsignedByte V117 = new UnsignedByte((byte) 117);
        private final static UnsignedByte V118 = new UnsignedByte((byte) 118);
        private final static UnsignedByte V119 = new UnsignedByte((byte) 119);
        private final static UnsignedByte V120 = new UnsignedByte((byte) 120);
        private final static UnsignedByte V121 = new UnsignedByte((byte) 121);
        private final static UnsignedByte V122 = new UnsignedByte((byte) 122);
        private final static UnsignedByte V123 = new UnsignedByte((byte) 123);
        private final static UnsignedByte V124 = new UnsignedByte((byte) 124);
        private final static UnsignedByte V125 = new UnsignedByte((byte) 125);
        private final static UnsignedByte V126 = new UnsignedByte((byte) 126);
        private final static UnsignedByte V127 = new UnsignedByte((byte) 127);
        private final static UnsignedByte V128 = new UnsignedByte((byte) -1);
        private final static UnsignedByte V129 = new UnsignedByte((byte) -2);
        private final static UnsignedByte V130 = new UnsignedByte((byte) -3);
        private final static UnsignedByte V131 = new UnsignedByte((byte) -4);
        private final static UnsignedByte V132 = new UnsignedByte((byte) -5);
        private final static UnsignedByte V133 = new UnsignedByte((byte) -6);
        private final static UnsignedByte V134 = new UnsignedByte((byte) -7);
        private final static UnsignedByte V135 = new UnsignedByte((byte) -8);
        private final static UnsignedByte V136 = new UnsignedByte((byte) -9);
        private final static UnsignedByte V137 = new UnsignedByte((byte) -10);
        private final static UnsignedByte V138 = new UnsignedByte((byte) -11);
        private final static UnsignedByte V139 = new UnsignedByte((byte) -12);
        private final static UnsignedByte V140 = new UnsignedByte((byte) -13);
        private final static UnsignedByte V141 = new UnsignedByte((byte) -14);
        private final static UnsignedByte V142 = new UnsignedByte((byte) -15);
        private final static UnsignedByte V143 = new UnsignedByte((byte) -16);
        private final static UnsignedByte V144 = new UnsignedByte((byte) -17);
        private final static UnsignedByte V145 = new UnsignedByte((byte) -18);
        private final static UnsignedByte V146 = new UnsignedByte((byte) -19);
        private final static UnsignedByte V147 = new UnsignedByte((byte) -20);
        private final static UnsignedByte V148 = new UnsignedByte((byte) -21);
        private final static UnsignedByte V149 = new UnsignedByte((byte) -22);
        private final static UnsignedByte V150 = new UnsignedByte((byte) -23);
        private final static UnsignedByte V151 = new UnsignedByte((byte) -24);
        private final static UnsignedByte V152 = new UnsignedByte((byte) -25);
        private final static UnsignedByte V153 = new UnsignedByte((byte) -26);
        private final static UnsignedByte V154 = new UnsignedByte((byte) -27);
        private final static UnsignedByte V155 = new UnsignedByte((byte) -28);
        private final static UnsignedByte V156 = new UnsignedByte((byte) -29);
        private final static UnsignedByte V157 = new UnsignedByte((byte) -30);
        private final static UnsignedByte V158 = new UnsignedByte((byte) -31);
        private final static UnsignedByte V159 = new UnsignedByte((byte) -32);
        private final static UnsignedByte V160 = new UnsignedByte((byte) -33);
        private final static UnsignedByte V161 = new UnsignedByte((byte) -34);
        private final static UnsignedByte V162 = new UnsignedByte((byte) -35);
        private final static UnsignedByte V163 = new UnsignedByte((byte) -36);
        private final static UnsignedByte V164 = new UnsignedByte((byte) -37);
        private final static UnsignedByte V165 = new UnsignedByte((byte) -38);
        private final static UnsignedByte V166 = new UnsignedByte((byte) -39);
        private final static UnsignedByte V167 = new UnsignedByte((byte) -40);
        private final static UnsignedByte V168 = new UnsignedByte((byte) -41);
        private final static UnsignedByte V169 = new UnsignedByte((byte) -42);
        private final static UnsignedByte V170 = new UnsignedByte((byte) -43);
        private final static UnsignedByte V171 = new UnsignedByte((byte) -44);
        private final static UnsignedByte V172 = new UnsignedByte((byte) -45);
        private final static UnsignedByte V173 = new UnsignedByte((byte) -46);
        private final static UnsignedByte V174 = new UnsignedByte((byte) -47);
        private final static UnsignedByte V175 = new UnsignedByte((byte) -48);
        private final static UnsignedByte V176 = new UnsignedByte((byte) -49);
        private final static UnsignedByte V177 = new UnsignedByte((byte) -50);
        private final static UnsignedByte V178 = new UnsignedByte((byte) -51);
        private final static UnsignedByte V179 = new UnsignedByte((byte) -52);
        private final static UnsignedByte V180 = new UnsignedByte((byte) -53);
        private final static UnsignedByte V181 = new UnsignedByte((byte) -54);
        private final static UnsignedByte V182 = new UnsignedByte((byte) -55);
        private final static UnsignedByte V183 = new UnsignedByte((byte) -56);
        private final static UnsignedByte V184 = new UnsignedByte((byte) -57);
        private final static UnsignedByte V185 = new UnsignedByte((byte) -58);
        private final static UnsignedByte V186 = new UnsignedByte((byte) -59);
        private final static UnsignedByte V187 = new UnsignedByte((byte) -60);
        private final static UnsignedByte V188 = new UnsignedByte((byte) -61);
        private final static UnsignedByte V189 = new UnsignedByte((byte) -62);
        private final static UnsignedByte V190 = new UnsignedByte((byte) -63);
        private final static UnsignedByte V191 = new UnsignedByte((byte) -64);
        private final static UnsignedByte V192 = new UnsignedByte((byte) -65);
        private final static UnsignedByte V193 = new UnsignedByte((byte) -66);
        private final static UnsignedByte V194 = new UnsignedByte((byte) -67);
        private final static UnsignedByte V195 = new UnsignedByte((byte) -68);
        private final static UnsignedByte V196 = new UnsignedByte((byte) -69);
        private final static UnsignedByte V197 = new UnsignedByte((byte) -70);
        private final static UnsignedByte V198 = new UnsignedByte((byte) -71);
        private final static UnsignedByte V199 = new UnsignedByte((byte) -72);
        private final static UnsignedByte V200 = new UnsignedByte((byte) -73);
        private final static UnsignedByte V201 = new UnsignedByte((byte) -74);
        private final static UnsignedByte V202 = new UnsignedByte((byte) -75);
        private final static UnsignedByte V203 = new UnsignedByte((byte) -76);
        private final static UnsignedByte V204 = new UnsignedByte((byte) -77);
        private final static UnsignedByte V205 = new UnsignedByte((byte) -78);
        private final static UnsignedByte V206 = new UnsignedByte((byte) -79);
        private final static UnsignedByte V207 = new UnsignedByte((byte) -80);
        private final static UnsignedByte V208 = new UnsignedByte((byte) -81);
        private final static UnsignedByte V209 = new UnsignedByte((byte) -82);
        private final static UnsignedByte V210 = new UnsignedByte((byte) -83);
        private final static UnsignedByte V211 = new UnsignedByte((byte) -84);
        private final static UnsignedByte V212 = new UnsignedByte((byte) -85);
        private final static UnsignedByte V213 = new UnsignedByte((byte) -86);
        private final static UnsignedByte V214 = new UnsignedByte((byte) -87);
        private final static UnsignedByte V215 = new UnsignedByte((byte) -88);
        private final static UnsignedByte V216 = new UnsignedByte((byte) -89);
        private final static UnsignedByte V217 = new UnsignedByte((byte) -90);
        private final static UnsignedByte V218 = new UnsignedByte((byte) -91);
        private final static UnsignedByte V219 = new UnsignedByte((byte) -92);
        private final static UnsignedByte V220 = new UnsignedByte((byte) -93);
        private final static UnsignedByte V221 = new UnsignedByte((byte) -94);
        private final static UnsignedByte V222 = new UnsignedByte((byte) -95);
        private final static UnsignedByte V223 = new UnsignedByte((byte) -96);
        private final static UnsignedByte V224 = new UnsignedByte((byte) -97);
        private final static UnsignedByte V225 = new UnsignedByte((byte) -98);
        private final static UnsignedByte V226 = new UnsignedByte((byte) -99);
        private final static UnsignedByte V227 = new UnsignedByte((byte) -100);
        private final static UnsignedByte V228 = new UnsignedByte((byte) -101);
        private final static UnsignedByte V229 = new UnsignedByte((byte) -102);
        private final static UnsignedByte V230 = new UnsignedByte((byte) -103);
        private final static UnsignedByte V231 = new UnsignedByte((byte) -104);
        private final static UnsignedByte V232 = new UnsignedByte((byte) -105);
        private final static UnsignedByte V233 = new UnsignedByte((byte) -106);
        private final static UnsignedByte V234 = new UnsignedByte((byte) -107);
        private final static UnsignedByte V235 = new UnsignedByte((byte) -108);
        private final static UnsignedByte V236 = new UnsignedByte((byte) -109);
        private final static UnsignedByte V237 = new UnsignedByte((byte) -110);
        private final static UnsignedByte V238 = new UnsignedByte((byte) -111);
        private final static UnsignedByte V239 = new UnsignedByte((byte) -112);
        private final static UnsignedByte V240 = new UnsignedByte((byte) -113);
        private final static UnsignedByte V241 = new UnsignedByte((byte) -114);
        private final static UnsignedByte V242 = new UnsignedByte((byte) -115);
        private final static UnsignedByte V243 = new UnsignedByte((byte) -116);
        private final static UnsignedByte V244 = new UnsignedByte((byte) -117);
        private final static UnsignedByte V245 = new UnsignedByte((byte) -118);
        private final static UnsignedByte V246 = new UnsignedByte((byte) -119);
        private final static UnsignedByte V247 = new UnsignedByte((byte) -120);
        private final static UnsignedByte V248 = new UnsignedByte((byte) -121);
        private final static UnsignedByte V249 = new UnsignedByte((byte) -122);
        private final static UnsignedByte V250 = new UnsignedByte((byte) -123);
        private final static UnsignedByte V251 = new UnsignedByte((byte) -124);
        private final static UnsignedByte V252 = new UnsignedByte((byte) -125);
        private final static UnsignedByte V253 = new UnsignedByte((byte) -126);
        private final static UnsignedByte V254 = new UnsignedByte((byte) -127);
        private final static UnsignedByte V255 = new UnsignedByte((byte) -128);
    }
}
