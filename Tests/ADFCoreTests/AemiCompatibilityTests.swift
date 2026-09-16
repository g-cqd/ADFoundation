import ADFCore
import AemiKernel
import Testing

@Test
func `legacy and Aemi imports share buffer pool identity`() {
    let legacy = ADFCore.ByteBufferPool()
    let shared: AemiKernel.ByteBufferPool = legacy
    shared.recycle([1, 2, 3])
    #expect(legacy.take().isEmpty)
    #expect(shared === legacy)
}
