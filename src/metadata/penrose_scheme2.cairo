%lang starknet

from starkware.cairo.common.registers import get_label_location

@view
func char_at_pos(pos: felt) -> (res : felt):
    let (data_address) = get_label_location(data)
    return ([data_address + pos])

    #scheme 2: abcdijklqrsstttttttt
    #97 98 99 100 105 106 107 108 113 114 115 115 116 116 116 116 116 116 116 116
    data:
    dw 97
    dw 98
    dw 99
    dw 100
    dw 105
    dw 107
    dw 108
    dw 113
    dw 114
    dw 115
    dw 115
    dw 116
    dw 116
    dw 116
    dw 116
    dw 116
    dw 116
    dw 116
    dw 116
    dw 116
    
end