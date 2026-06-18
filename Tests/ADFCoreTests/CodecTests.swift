import ADFCore
import Testing

@Suite("Varint")
struct VarintTests {
    @Test func roundTripAcrossArrayReader() {
        for v in [UInt64(0), 1, 127, 128, 300, 16384, 1 << 35, UInt64.max] {
            var bytes: [UInt8] = []
            Varint.append(v, to: &bytes)
            var offset = 0
            #expect(Varint.read(bytes, &offset) == v)
            #expect(offset == bytes.count)
        }
    }

    @Test func rawBufferReaderMatchesArrayReader() {
        var bytes: [UInt8] = []
        Varint.append(300, to: &bytes)
        let viaRaw = bytes.withUnsafeBytes { raw -> UInt64? in
            var offset = 0
            return Varint.read(raw, &offset)
        }
        #expect(viaRaw == 300)
    }

    @Test func truncationReturnsNil() {
        var offset = 0
        #expect(Varint.read([0x80] as [UInt8], &offset) == nil)
    }

    @Test func overflowPast64BitsReturnsNil() {
        let overlong = [UInt8](repeating: 0x80, count: 10) + [0x01]
        var offset = 0
        #expect(Varint.read(overlong, &offset) == nil)
    }

    @Test func tenthByteOverflowBitsRejected() {
        // A 10th group whose payload exceeds bit 63 must fail cleanly, not silently truncate.
        var offset = 0
        #expect(Varint.read([UInt8](repeating: 0x80, count: 9) + [0x02], &offset) == nil)
        // The maximal in-range 10-byte encoding (only bit 63 set) still decodes.
        offset = 0
        #expect(Varint.read([UInt8](repeating: 0x80, count: 9) + [0x01], &offset) == 1 << 63)
    }

    @Test func zigzagRoundTrip() {
        for v in [Int64(0), -1, 1, -2, 2, -1000, 1000, Int64.min, Int64.max] {
            #expect(Varint.unzigzag(Varint.zigzag(v)) == v)
        }
    }

    @Test func outputSpanFormMatchesArrayForm() {
        for v in [UInt64(0), 1, 127, 128, 300, 16384, 1 << 35, UInt64.max] {
            var viaArray: [UInt8] = []
            Varint.append(v, to: &viaArray)
            // Build the same varint into an exclusively-owned OutputSpan sized to the worst case.
            let viaSpan = [UInt8](capacity: Varint.maxEncodedLength) { out in
                Varint.append(v, to: &out)
            }
            #expect(viaSpan == viaArray)
            #expect(viaArray.count <= Varint.maxEncodedLength)
            var offset = 0
            #expect(Varint.read(viaSpan, &offset) == v)
            #expect(offset == viaSpan.count)
        }
    }
}

@Suite("Endian")
struct EndianTests {
    @Test func littleAndBigEndianLoads() {
        let bytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        bytes.withUnsafeBytes { raw in
            #expect(raw.loadLE16(0) == 0x0201)
            #expect(raw.loadLE32(0) == 0x0403_0201)
            #expect(raw.loadLE64(0) == 0x0807_0605_0403_0201)
            #expect(raw.loadBE64(0) == 0x0102_0304_0506_0708)
        }
    }

    @Test func storeRoundTrip() {
        var bytes = [UInt8](repeating: 0, count: 8)
        bytes.withUnsafeMutableBytes { raw in
            raw.storeLE16(0xBEEF, at: 0)
            #expect(raw.loadLE16(0) == 0xBEEF)
            raw.storeLE32(0xDEAD_BEEF, at: 0)
            #expect(raw.loadLE32(0) == 0xDEAD_BEEF)
            raw.storeLE64(0x0102_0304_0506_0708, at: 0)
            #expect(raw.loadLE64(0) == 0x0102_0304_0506_0708)
        }
    }

    @Test func loadsAndStoresAtNonZeroOffset() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes.withUnsafeMutableBytes { raw in
            raw.storeLE16(0xBEEF, at: 2)
            raw.storeLE32(0xDEAD_BEEF, at: 4)
            raw.storeLE64(0x0102_0304_0506_0708, at: 8)
            #expect(raw.loadLE16(2) == 0xBEEF)
            #expect(raw.loadLE32(4) == 0xDEAD_BEEF)
            #expect(raw.loadLE64(8) == 0x0102_0304_0506_0708)
        }
        // The mutable-buffer loads delegate to the immutable view — verify parity at a non-zero offset.
        bytes.withUnsafeBytes { raw in
            #expect(raw.loadLE16(2) == 0xBEEF)
            #expect(raw.loadBE64(8) == 0x0807_0605_0403_0201)
        }
    }

    @Test func bigEndianStoresAndLoadsRoundTrip() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes.withUnsafeMutableBytes { raw in
            raw.storeBE16(0xBEEF, at: 0)
            raw.storeBE32(0xDEAD_BEEF, at: 2)
            raw.storeBE64(0x0102_0304_0506_0708, at: 6)
            #expect(raw.loadBE16(0) == 0xBEEF)
            #expect(raw.loadBE32(2) == 0xDEAD_BEEF)
            #expect(raw.loadBE64(6) == 0x0102_0304_0506_0708)
            // Byte order really is big-endian: most-significant byte first.
            #expect(raw[0] == 0xBE)
            #expect(raw[1] == 0xEF)
        }
        // Parity through the immutable view (loads delegate there).
        bytes.withUnsafeBytes { raw in
            #expect(raw.loadBE16(0) == 0xBEEF)
            #expect(raw.loadBE32(2) == 0xDEAD_BEEF)
            #expect(raw.loadBE64(6) == 0x0102_0304_0506_0708)
        }
    }
}
