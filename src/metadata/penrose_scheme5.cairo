%lang starknet

from starkware.cairo.common.registers import get_label_location

@view
func char_at_pos(pos: felt) -> (res : felt):
    let (data_address) = get_label_location(data)
    return ([data_address + pos])

    #scheme 5: abcdefghijklmnopqrst
    #97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116
    data:
    dw 97
    dw 98
    dw 99
    dw 100
    dw 101
    dw 102
    dw 103
    dw 104
    dw 105
    dw 106
    dw 107
    dw 108
    dw 109
    dw 110
    dw 111
    dw 112
    dw 113
    dw 114
    dw 115
    dw 116
    
end