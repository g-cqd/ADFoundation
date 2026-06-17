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

    @Test func zigzagRoundTrip() {
        for v in [Int64(0), -1, 1, -2, 2, -1000, 1000, Int64.min, Int64.max] {
            #expect(Varint.unzigzag(Varint.zigzag(v)) == v)
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
}
