import { BitReader } from "./bit_reader.js"

// TODO: maybe we need to use this also on H.264?
function unescapeBSP(ebsp: Uint8Array) {
    const rbsp = new Uint8Array(ebsp.byteLength)
    let cnt = 0
    let zeroCount = 0
    for (let i=0; i<ebsp.byteLength; i++) {
        const v = ebsp[i]
        if (v === 0) {
            zeroCount++
        } else if (v === 3 && zeroCount >= 2) {
            zeroCount = 0
            continue
        }
        rbsp[cnt++] = v
    }
    return rbsp.slice(0, cnt)
}

export function parseInitNALUHEVC(initNal: Uint8Array) {
    const initNalReader = new BitReader(unescapeBSP(initNal))
    // let count = 0
    // while (initNalReader.read(8) === 0) count++
    // if (count < 2) throw new Error(`invalid initNal: ${count} leading zeros`)
    // console.log(initNal)
    if (initNalReader.read(1) !== 0) throw new Error(`invalid initNal: forbidden_zero_bit not 0`)
    const nal_unit_type = initNalReader.read(6)
    console.log("type", nal_unit_type)
    const nuh_layer_id = initNalReader.read(6)
    const nuh_temporal_id_plus1 = initNalReader.read(3)

    if (nal_unit_type === 32) { // VPS
        const vps_video_parameter_set_id = initNalReader.read(4)
        const vps_base_layer_internal_flag = initNalReader.read(1)
        const vps_base_layer_available_flag = initNalReader.read(1)
        const vps_max_layers_minus1 = initNalReader.read(6)
        const vps_max_sub_layers_minus1 = initNalReader.read(3)
        const vps_temporal_id_nesting_flag = initNalReader.read(1)
        const vps_reserved_0xffff_16bits = initNalReader.read(16)
        
        // profile_tier_level (profilePresentFlag=true, maxNumSubLayersMinus1=vps_max_sub_layers_minus1)
        const general_profile_space = initNalReader.read(2)
        const general_tier_flag = initNalReader.read(1)
        const general_profile_idc = initNalReader.read(5)
        const general_profile_compatibility_flag = []
        for (let i=0; i<32; i++) general_profile_compatibility_flag.push(initNalReader.read(1))
        const some_flags = initNalReader.readBigInt(48)
        const general_level_idc = initNalReader.read(8)

        let codecString = "hvc1."
        switch (general_profile_space) {
        case 0:
            break
        case 1:
            codecString += "A"
            break
        case 2:
            codecString += "B"
            break
        case 3:
            codecString += "C"
            break
        default:
            throw new Error("invalid general_profile_space")
        }
        codecString += general_profile_idc.toString(10)
        codecString += "."
        console.log(general_profile_compatibility_flag.map(x => x ? "1" : "0").join(""))
        codecString += parseInt(general_profile_compatibility_flag.reverse().join(""), 2).toString(16).replace(/(00)+/g, "")
        codecString += "."
        codecString += general_tier_flag ? "H" : "L"
        codecString += general_level_idc.toString(10)
        codecString += "."
        codecString += some_flags.toString(16).toUpperCase().replace(/(00)+/g, "")
        return codecString
    } else {
        throw new Error(`Unknown HEVC NAL type: ${nal_unit_type}`)
    }
}
