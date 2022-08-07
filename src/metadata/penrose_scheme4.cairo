%lang starknet

from starkware.cairo.common.registers import get_label_location

@view
func char_at_pos(pos: felt) -> (res : felt):
    let (data_address) = get_label_location(data)
    return ([data_address + pos])

    #scheme 4: mnopqrsmnopqrsmnopqr
    #109 110 111 112 113 114 115 109 110 111 112 113 114 115 109 110 111 112 113 114
    data:
    dw 109
    dw 110
    dw 111
    dw 112
    dw 113
    dw 114
    dw 115
    dw 109
    dw 110
    dw 111
    dw 112
    dw 113
    dw 114
    dw 115
    dw 109
    dw 110
    dw 111
    dw 112
    dw 113
    dw 114

end