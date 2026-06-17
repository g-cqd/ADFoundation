import ADFCore
import Testing

@Suite("ByteReader")
struct ByteReaderTests {
    @Test func readsLittleEndianScalarsThenSignalsEnd() {
        var bytes = [UInt8]()
        bytes.append(contentsOf: withUnsafeBytes(of: UInt32(0xDEAD_BEEF).littleEndian) { Array($0) })
        bytes.append(contentsOf: withUnsafeBytes(of: UInt64(0x0102_0304_0506_0708).littleEndian) { Array($0) })
        bytes.append(contentsOf: withUnsafeBytes(of: Double(3.5).bitPattern.littleEndian) { Array($0) })
        bytes.withUnsafeBytes { raw in
            var reader = ByteReader(raw)
            // Bind mutating reads to locals: Swift Testing's `#expect` borrows its operands
            // immutably, so a `mutating` call cannot appear directly inside it.
            let a = reader.u32()
            let b = reader.u64()
            let c = reader.f64()
            let rem = reader.remaining
            let past = reader.u32()
            #expect(a == 0xDEAD_BEEF)
            #expect(b == 0x0102_0304_0506_0708)
            #expect(c == 3.5)
            #expect(rem == 0)
            #expect(past == nil)  // past end: no trap, returns nil
        }
    }

    @Test func boundsCheckedBytesView() {
        let bytes: [UInt8] = [10, 20, 30, 40]
        bytes.withUnsafeBytes { raw in
            var reader = ByteReader(raw)
            let oob = reader.bytes(5)  // out of bounds
            let view = reader.bytes(3)
            #expect(oob == nil)
            #expect(view?.count == 3)
            #expect(reader.remaining == 1)
        }
    }

    @Test func align8AdvancesToBoundary() {
        let bytes = [UInt8](repeating: 0, count: 16)
        bytes.withUnsafeBytes { raw in
            var reader = ByteReader(raw)
            _ = reader.u32()  // offset 4
            let aligned = reader.align8()
            #expect(aligned)
            #expect(reader.offset == 8)
        }
    }
}

@Suite("ByteBufferPool")
struct ByteBufferPoolTests {
    @Test func emptyPoolYieldsFreshBuffer() {
        let pool = ByteBufferPool()
        #expect(pool.take().isEmpty)
    }

    @Test func recycleClearsButRetainsCapacity() {
        let pool = ByteBufferPool()
        var b = pool.take()
        b.append(contentsOf: [1, 2, 3, 4, 5])
        pool.recycle(b)
        let reused = pool.take()
        #expect(reused.isEmpty)
        #expect(reused.capacity >= 5)
    }

    @Test func oversizedBufferIsNotPooled() {
        let pool = ByteBufferPool(maxBufferCapacity: 8, maxPooled: 4)
        var big = pool.take()
        big.reserveCapacity(1024)
        pool.recycle(big)
        // Dropped, not pooled: the next take starts fresh with no retained large capacity.
        #expect(pool.take().capacity < 1024)
    }
}
