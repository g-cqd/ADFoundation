/// Unaligned-safe little- and big-endian integer loads/stores over raw byte buffers.
///
/// On-disk and on-wire formats are byte-oriented and frequently unaligned, so these go through
/// `loadUnaligned` / `storeBytes` rather than a typed bind. Relocated from ADSQL's `ByteCodec`,
/// where the storage format is little-endian everywhere except the order-preserving key codec
/// (the one big-endian region, served by ``loadBE64(_:)``).
extension UnsafeRawBufferPointer {
    @inlinable
    public func loadLE16(_ offset: Int) -> UInt16 {
        unsafe UInt16(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt16.self))
    }
    @inlinable
    public func loadLE32(_ offset: Int) -> UInt32 {
        unsafe UInt32(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
    @inlinable
    public func loadLE64(_ offset: Int) -> UInt64 {
        unsafe UInt64(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }
    /// Big-endian 64-bit load (a single byte-swapped load, not a shift loop) for order-preserving keys.
    @inlinable
    public func loadBE64(_ offset: Int) -> UInt64 {
        unsafe UInt64(bigEndian: loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }
}

extension UnsafeMutableRawBufferPointer {
    @inlinable
    public func loadLE16(_ offset: Int) -> UInt16 {
        unsafe UInt16(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt16.self))
    }
    @inlinable
    public func loadLE32(_ offset: Int) -> UInt32 {
        unsafe UInt32(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
    @inlinable
    public func loadLE64(_ offset: Int) -> UInt64 {
        unsafe UInt64(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }
    @inlinable
    public func storeLE16(_ value: UInt16, at offset: Int) {
        unsafe storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt16.self)
    }
    @inlinable
    public func storeLE32(_ value: UInt32, at offset: Int) {
        unsafe storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt32.self)
    }
    @inlinable
    public func storeLE64(_ value: UInt64, at offset: Int) {
        unsafe storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt64.self)
    }
}
