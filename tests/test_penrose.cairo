%lang starknet
%builtins pedersen range_check bitwise
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from protostar.asserts import (
    assert_eq, assert_not_eq, assert_signed_lt, assert_signed_le, assert_signed_gt,
    assert_unsigned_lt, assert_unsigned_le, assert_unsigned_gt, assert_signed_ge,
    assert_unsigned_ge)

from starkware.starknet.common.syscalls import (
    get_contract_address, get_block_number, get_block_timestamp, get_caller_address
)

from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq
)

from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc721.IERC721 import IERC721

from src.interfaces.Ipenrose import Penrose

from starkware.cairo.common.alloc import alloc

const SCHEME_ONE = 'efghijklmnopqrsefght'

@view
func __setup__{bitwise_ptr : BitwiseBuiltin*, syscall_ptr: felt*, range_check_ptr}():
    alloc_locals
    local target_blocks_per_sale: felt = 100
    local sale_half_life: felt = 700
    local price_speed: felt = 1
    local price_half_life: felt = 100
    local starting_price: felt = 50000000000000000 #100
    local penrose: felt
    local ETH: felt
    local sample_penrose_metadata: felt
    local decimals: felt = 1000000000000000000
    # local currency_address: felt = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
    local initial_supply: felt = 4000000 * decimals
    %{ 
        close_user_1 = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()

    %{ 
        context.ETH = deploy_contract("./src/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [4543560, 4543560, 18, ids.initial_supply, 0, ids.caller]).contract_address
        #Scheme 1 - 5 deployments
        context.sample_penrose_metadata = deploy_contract("./src/metadata/penrose_scheme1.cairo", []).contract_address
        context.penrose = deploy_contract("./src/penrose.cairo", [
            22629523177567077, 
            1346719314, 
            ids.caller, 
            ids.caller, 
            0, 
            ids.target_blocks_per_sale, 
            ids.sale_half_life, 
            ids.price_speed, 
            ids.price_half_life, 
            ids.starting_price, 
            context.ETH,
            context.sample_penrose_metadata,
            context.sample_penrose_metadata,
            context.sample_penrose_metadata,
            context.sample_penrose_metadata,
            context.sample_penrose_metadata]).contract_address 
    %}



    
    %{ close_user_1() %}

    return ()
end

# @external
# func test_for_each_col{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     let (local caller: felt) = get_caller_address()
#     local penrose: felt
#     local sample_penrose_metadata: felt
#     %{ ids.penrose = context.penrose %}
#     %{ ids.sample_penrose_metadata = context.sample_penrose_metadata %}
#     %{ print("checking") %}
    
#     let j = 0
#     let token_id = 1
#     let y = -29
#     let (resstr: felt*) = alloc()
#     let mod = 32
#     let (res_len: felt, res: felt*) = Penrose.for_each_col(penrose, j, y, j, resstr, mod, 0, 0, 1656771887, sample_penrose_metadata)
    
#     display_array_elements(res_len, res)
#     return ()
# end

# @external
# func test_append_to_felt{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     let (local caller: felt) = get_caller_address()
#     local penrose: felt
#     %{ ids.penrose = context.penrose %}
#     %{ print("checking") %}
    
#     let res = 'abcdefghijklmnopqrstt'
#     let new_char = 't'
#     let resulting_str = 'abcdefghijklmnopqrsttt'
#     let (is_new: felt, new_str: felt) = Penrose.append_to_felt(penrose, res, new_char)
#     %{ print("is new: " + str(ids.is_new) + " | new string: " + str(ids.new_str)) %}
#     assert_eq(is_new, 0)
#     assert_eq(new_str, resulting_str)

#     let res1 = 'abcdefghijklmnopqrsttt'
#     let new_char1 = 'u'
#     let resulting_str = 'u'
#     let (is_new1: felt, new_str1: felt) = Penrose.append_to_felt(penrose, res1, new_char1)
#     %{ print("is new: " + str(ids.is_new1) + " | new string: " + str(ids.new_str1)) %}
#     assert_eq(is_new1, 1)
#     assert_eq(new_str1, resulting_str)
    
#     return ()
# end

# @external
# func test_for_each_row{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     let (local caller: felt) = get_caller_address()
#     local penrose: felt
#     local sample_penrose_metadata: felt
#     %{ ids.penrose = context.penrose %}
#     %{ ids.sample_penrose_metadata = context.sample_penrose_metadata %}
#     %{ print("checking") %}
    
#     let i = 0
#     let token_id = 1
#     let (output: felt*) = alloc()
#     let mod = 10
#     let (res_len: felt, res: felt*) = Penrose.for_each_row(penrose, i, token_id, i, output, mod, 1656771887, sample_penrose_metadata)
#     display_array_elements(res_len, res)
#     return ()
# end

# @external
# func test_draw{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     local penrose: felt
#     %{ ids.penrose = context.penrose %}
#     %{ print("checking") %}
    
#     let token_id = 1
#     let (res_len: felt, res: felt*) = Penrose.draw(penrose, token_id)
#     display_array_elements(res_len, res)
#     return ()
# end

# @external
# func test_add_line{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     local penrose: felt
#     %{ ids.penrose = context.penrose %}
#     %{ print("checking") %}
    
#     let token_id = 1
#     let i = 0
#     let start = 10
#     let step = (100 - start * 2) / 16
#     let (uri: felt*) = alloc()
#     let (res_len: felt, res: felt*) = Penrose.draw(penrose, token_id)
#     let (res_uri_len: felt, res_uri: felt*) = Penrose.add_line(penrose, i, start, step, i, uri, res_len, res)
#     display_array_elements(res_uri_len, res_uri)
#     return ()
# end

# @external
# func test_wrap_to_svg{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     local penrose: felt
#     %{ ids.penrose = context.penrose %}
#     %{ print("checking") %}

#     local token_id = 1

#     Penrose.write_foreground_background(penrose, token_id)
#     let (res_len: felt, res: felt*) = Penrose.wrap_to_svg(penrose, token_id)
    
#     display_array_elements(res_len, res)

#     return ()
# end

# @external
# func test_create_penrose{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

#     local penrose: felt
#     local sample_penrose_metadata: felt
#     %{ ids.sample_penrose_metadata = context.sample_penrose_metadata %}
#     %{ ids.penrose = context.penrose %}
#     %{ close_user_1 = start_prank(11111) %}
#     %{ print("checking") %}

#     let (local caller: felt) = get_caller_address()
#     # Penrose.write_id_to_seed(penrose, 1, 192738479)
#     %{ stop_warp = warp(1234587, ids.penrose) %}
#     %{ user_1 = start_prank(11111, ids.penrose) %}
#     Penrose.create_penrose(penrose)

#     let id = 1
#     let (creator: felt) = Penrose.getIdToCreator(penrose, id)
#     let (seed: felt) = Penrose.getIdToSeed(penrose, id)
#     let (id_check: felt) = Penrose.getSeedToId(penrose, seed)
#     let (scheme: felt) = Penrose.getIdToScheme(penrose, id)
#     let (num_token: felt) = Penrose.getNumToken(penrose)
#     # let (res_len: felt, res: felt*) = Penrose.getIdToTokenUri(penrose, id)

#     assert_eq(caller, creator)
#     assert_eq(id_check, id)
#     assert_eq(scheme, sample_penrose_metadata)
#     assert_eq(num_token, 1)

#     let t_id: Uint256 = Uint256(id, 0)

#     let (test_len: felt, test: felt*) = Penrose.tokenURI(penrose, t_id)
#     display_array_elements(test_len, test)
#     %{ close_user_1 %}
#     return ()
# end
    
func display_array_elements{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}(resstr_len: felt, resstr: felt*):
    if resstr_len == 0:
        return ()
    end

    let index = [resstr]
    %{ print(str(ids.index) + ",") %}
    return display_array_elements(resstr_len - 1, resstr + 1)
end

@external
func test_starting_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    %{ ids.penrose = context.penrose %}
    let price: felt = Penrose.getQuote(penrose)
    assert_eq(price, 115292150460684697600000000000000000)
    return ()
end

@external
func test_price_decay_above_target_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ 
        ids.penrose = context.penrose 
        ids.ETH = context.ETH
        roll(0, ids.penrose) 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    Penrose.mint(contract_address=penrose)
    let initial_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ roll(50, ids.penrose) %}
    let final_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ 
        close_user_1()
        close_user_1b()
        close_user_1c()  
    %}
    assert_eq(initial_price, final_price)
    return ()
end

@external
func test_price_decay_below_target_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ 
        ids.penrose = context.penrose 
        ids.ETH = context.ETH
        roll(0, ids.penrose) 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    Penrose.mint(contract_address=penrose)
    let initial_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ roll(200, ids.penrose) %}
    let final_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ 
        close_user_1()
        close_user_1b()
        close_user_1c()  
    %}
    assert_unsigned_gt(initial_price, final_price)
    return ()

end 

@external
func test_price_increase_above_target_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ 
        ids.penrose = context.penrose 
        ids.ETH = context.ETH
        roll(0, ids.penrose) 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    Penrose.mint(contract_address=penrose)
    %{ roll(1, ids.penrose) %}
    let initial_price: felt = Penrose.getQuote(contract_address=penrose)
    Penrose.mint(contract_address=penrose)
    Penrose.mint(contract_address=penrose)
    %{ roll(4, ids.penrose) %}
    Penrose.mint(contract_address=penrose)
    let final_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ 
        close_user_1()
        close_user_1b()
        close_user_1c()  
    %}
    assert_unsigned_gt(final_price, initial_price)

    return ()
end

@external
func test_price_increase_below_target_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ 
        ids.penrose = context.penrose 
        ids.ETH = context.ETH
        roll(0, ids.penrose) 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    Penrose.mint(contract_address=penrose)
    %{ roll(1000, ids.penrose) %}
    let initial_price: felt = Penrose.getQuote(contract_address=penrose)
    Penrose.mint(contract_address=penrose)
    let final_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ 
        close_user_1()
        close_user_1b()
        close_user_1c()  
    %}
    assert_eq(final_price, initial_price)
    return ()
end

@external
func test_ems_decay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    %{ ids.penrose = context.penrose %}
    %{ roll(0, ids.penrose) %}
    let starting_ems: felt = Penrose.getCurrentEMS(contract_address=penrose)
    %{ roll(100, ids.penrose) %}
    let final_ems: felt = Penrose.getCurrentEMS(contract_address=penrose)
    assert_unsigned_gt(starting_ems, final_ems)
    return ()
end

@external
func test_ems_increase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ 
        ids.penrose = context.penrose 
        ids.ETH = context.ETH
        roll(0, ids.penrose) 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    let starting_ems: felt = Penrose.getCurrentEMS(contract_address=penrose)
    Penrose.mint(contract_address=penrose)
    let final_ems: felt = Penrose.getCurrentEMS(contract_address=penrose)
    %{ 
        close_user_1()
        close_user_1b()
        close_user_1c()  
    %}
    assert_unsigned_gt(final_ems, starting_ems)
    return ()
end

@external
func test_mint_price_zero{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ 
        ids.penrose = context.penrose
        ids.ETH = context.ETH
        roll(0, ids.penrose) 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
    %}
    let (local caller: felt) = get_caller_address()
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    Penrose.mint(contract_address=penrose)
    %{ roll(1000, ids.penrose) %}
    let initial_price: felt = Penrose.getQuote(contract_address=penrose)
    %{ roll(50000, ids.penrose) %}
    let final_price: felt = Penrose.getQuote(contract_address=penrose)
    %{
        close_user_1()
        close_user_1b()
        close_user_1c()  
    %}
    return ()
end

@external
func test_mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    alloc_locals

    local penrose: felt
    local ETH: felt
    %{ ids.penrose = context.penrose %}
    %{ ids.ETH = context.ETH %}
    %{ 
        close_user_1 = start_prank(11111, ids.penrose)
        close_user_1b = start_prank(11111, ids.ETH)
        close_user_1c = start_prank(11111)
        
    %}
    let (caller: felt) = get_caller_address()
    let pre_balance_of1: Uint256 = IERC20.balanceOf(ETH, caller)
    let pre_balance_of2: Uint256 = IERC20.balanceOf(ETH, 0x509019d5d5a1cac289753dab67650a7081f29002a1b7790fd2311104d5af194)
    let pre_allowance: Uint256 = IERC20.allowance(ETH, caller, caller)
    IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
    assert_eq(pre_balance_of1.low, 4000000000000000000000000)
    assert_eq(pre_balance_of2.low, 0)
    Penrose.mint(penrose)
    let post_allowance: Uint256 = IERC20.allowance(ETH, caller, caller)
    let post_balance_of1: Uint256 = IERC20.balanceOf(ETH, caller)
    let post_balance_of2: Uint256 = IERC20.balanceOf(ETH, 0x509019d5d5a1cac289753dab67650a7081f29002a1b7790fd2311104d5af194)
    %{ 
        close_user_1()
        close_user_1b()
        close_user_1c()
        
    %}
    assert_eq(post_balance_of1.low, 3999999950000000000000000)
    assert_eq(post_balance_of2.low, 50000000000000000)
    return ()
end

# @external
# func test_token_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
#     alloc_locals

#     local penrose: felt
#     local ETH: felt
#     %{ ids.penrose = context.penrose %}
#     %{ ids.ETH = context.ETH %}
#     %{ 
#         close_user_1 = start_prank(11111, ids.penrose)
#         close_user_1b = start_prank(11111, ids.ETH)
#         close_user_1c = start_prank(11111)
#     %}
#     let (caller: felt) = get_caller_address()
#     IERC20.approve(ETH, caller, Uint256(6969696969696969669, 0))
#     Penrose.mint(penrose)
#     let (id: felt) = Penrose.getNumToken(penrose)
#     let (token_uri_len: felt, token_uri: felt*) = Penrose.tokenURI(penrose, Uint256(id, 0))
#     display_array_elements(token_uri_len, token_uri)
#     %{ 
#         close_user_1()
#         close_user_1b()
#         close_user_1c()
        
#     %}
#     return ()
# end



