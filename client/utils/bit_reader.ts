export class BitReader {
    constructor(public data: Uint8Array, public offset: number = 0) {
    }

    seekByBytesOffset(offset: number) {
        this.offset += offset * 8
    }

    read(n: number) {
        let res = 0
        for (let i = 0; i < n; i++) {
            res <<= 1
            res |= (this.data[this.offset >> 3] >> (7 - (this.offset & 7))) & 1
            this.offset++
        }
        return res
    }

    readBigInt(n: number) {
        let res = 0n
        for (let i = 0; i < n; i++) {
            res <<= 1n
            res |= BigInt((this.data[this.offset >> 3] >> (7 - (this.offset & 7))) & 1)
            this.offset++
        }
        return res
    }

    uev() { // Exponential-Golomb Codes
        let leadingZeroBits = 0
        while (this.read(1) === 0) {
            leadingZeroBits++
        }
        return (1 << leadingZeroBits) - 1 + this.read(leadingZeroBits)
    }
}
   
function assert<A>(a: A, b: A) {
    if (a !== b) throw new Error(`assertion failed: ${a} !== ${b}`)
}

function test() {
    const data = new Uint8Array([0b1_010_011_0])
    const reader = new BitReader(data)
    assert(reader.uev(), 0)
    assert(reader.uev(), 1)
    assert(reader.uev(), 2)
}

test()