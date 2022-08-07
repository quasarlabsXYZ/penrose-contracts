from starkware.cairo.common.registers import get_label_location

@view
func char_at_pos(pos: felt) -> (res : felt):
    let (data_address) = get_label_location(data)
    return ([data_address + pos])

    #scheme 1: qrsefghabcdttttttttt
    #113 114 115 101 102 103 104 97 98 99 100 116 116 116 116 116 116 116 116 116
    data:
    dw 113
    dw 114
    dw 115
    dw 101
    dw 102
    dw 103
    dw 104
    dw 97
    dw 98
    dw 99
    dw 100
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