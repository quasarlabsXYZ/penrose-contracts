
#          _          _            _             _           _            _            _      
#         /\ \       /\ \         /\ \     _    /\ \        /\ \         / /\         /\ \    
#        /  \ \     /  \ \       /  \ \   /\_\ /  \ \      /  \ \       / /  \       /  \ \   
#       / /\ \ \   / /\ \ \     / /\ \ \_/ / // /\ \ \    / /\ \ \     / / /\ \__   / /\ \ \  
#      / / /\ \_\ / / /\ \_\   / / /\ \___/ // / /\ \_\  / / /\ \ \   / / /\ \___\ / / /\ \_\ 
#     / / /_/ / // /_/_ \/_/  / / /  \/____// / /_/ / / / / /  \ \_\  \ \ \ \/___// /_/_ \/_/ 
#    / / /__\/ // /____/\    / / /    / / // / /__\/ / / / /   / / /   \ \ \     / /____/\    
#   / / /_____// /\____\/   / / /    / / // / /_____/ / / /   / / /_    \ \ \   / /\____\/    
#  / / /      / / /______  / / /    / / // / /\ \ \  / / /___/ / //_/\__/ / /  / / /______    
# / / /      / / /_______\/ / /    / / // / /  \ \ \/ / /____\/ / \ \/___/ /  / / /_______\   
# \/_/       \/__________/\/_/     \/_/ \/_/    \_\/\/_________/   \_____\/   \/__________/   
                                                                                            


%lang starknet
from starkware.cairo.common.math import unsigned_div_rem, assert_lt, abs_value, signed_div_rem

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE
from starkware.starknet.common.syscalls import (
    get_block_number, get_block_timestamp, get_caller_address
)

from utils.caistring.str import literal_from_number

from utils.arrays.array_manipulation import add_last, join

from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.access.accesscontrol.library import AccessControl

from src.interfaces.IPenroseMetadata import PenroseMetadata
from imx_starknet.immutablex.starknet.token.erc721.library import ERC721
from imx_starknet.immutablex.starknet.token.erc721_token_metadata.library import ERC721_Token_Metadata
from imx_starknet.immutablex.starknet.token.erc721_contract_metadata.library import ERC721_Contract_Metadata
from imx_starknet.immutablex.starknet.auxiliary.erc2981.unidirectional_mutable import (
    ERC2981_UniDirectional_Mutable,
)

from utils.feltpacking.examples.uint8_packed import get_element_at
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_le_felt


from src.utils.Math64x61 import (
    Math64x61_mul, 
    Math64x61_fromFelt, 
    Math64x61_sub, 
    Math64x61_div, 
    Math64x61_pow, 
    Math64x61_exp, 
    Math64x61_add, 
    Math64x61_log2, 
    Math64x61_ceil, 
    Math64x61_toFelt
)

#
# Constants
#

const MINTER_ROLE = 'MINTER_ROLE'
const BURNER_ROLE = 'BURNER_ROLE'
const DEFAULT_ADMIN_ROLE = 0x00
const TOKEN_LIMIT = 2048 # test with 8, launch with 2048
const ONE = 4294967296
const COLORSCHEME_WHITE = '000000'
const COLORSCHEME_BLACK = 'ffffff'
const SCHEME_ONE = 'qrsefghabcdttttttttt'
const SCHEME_TWO = 'abcdijklqrsstttttttt'
const SCHEME_THREE = 'efghijklmnopqrsefght'
const SCHEME_FOUR = 'mnopqrsmnopqrsmnopqr'
const SCHEME_FIVE = 'abcdefghijklmnopqrst'
const SIZE = 44
const HALF_SIZE = SIZE / 2
const TWO_POW_MAX = 374144419156711147060143317175368453031918731001856 # 2^168 - 1
const FP_ONE = 2305843009213693952
const FP_TWO = 4611686018427387904
const RECIPIENT_ADDRESS = 0x509019d5d5a1cac289753dab67650a7081f29002a1b7790fd2311104d5af194 # Testnet

#
# Storage Variables
#

@storage_var
func token_limit_storage() -> (token_limit: felt):
end

@storage_var
func seed_to_id_storage(seed: felt) -> (id: felt):
end

@storage_var
func id_to_seed_storage(id: felt) -> (seed: felt):
end

@storage_var
func id_to_scheme_storage(id: felt) -> (scheme: felt):
end

@storage_var
func id_to_price_storage(id: felt) -> (price: felt):
end

@storage_var
func id_to_block_storage(id: felt) -> (block_num: felt):
end

@storage_var
func num_token_storage() -> (num_tokens: felt):
end

@storage_var
func token_currency_address() -> (currency_address: felt):
end

#
# CRISP State
#

@storage_var
func lastPurchaseBlock() -> (i : felt):
end

@storage_var
func priceDecayStartBlock() -> (i : felt):
end

@storage_var
func nextPurchaseStartingEMS() -> (i : felt):
end

@storage_var
func nextPurchaseStartingPrice() -> (i : felt):
end

@storage_var
func lastPurchasePrice() -> (price: felt):
end

#
# CRISP parameters
#

@storage_var
func targetEMS() -> (i : felt):
end

@storage_var
func saleHalfLife() -> (i : felt):
end

@storage_var
func priceSpeed() -> (i : felt):
end

@storage_var
func priceHalfLife() -> (i : felt):
end

#
# Scheme storage vars
#

@storage_var
func scheme1_address_storage() -> (address : felt):
end

@storage_var
func scheme2_address_storage() -> (address : felt):
end

@storage_var
func scheme3_address_storage() -> (address : felt):
end

@storage_var
func scheme4_address_storage() -> (address : felt):
end

@storage_var
func scheme5_address_storage() -> (address : felt):
end


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    name : felt,
    symbol : felt,
    owner : felt,
    default_royalty_receiver : felt,
    default_royalty_fee_basis_points : felt,
    _targetBlocksPerSale : felt,
    _saleHalfLife : felt,
    _priceSpeed : felt,
    _priceHalfLife : felt,
    _startingPrice : felt,
    _tokenCurrencyAddress : felt,
    scheme1_address : felt,
    scheme2_address : felt,
    scheme3_address : felt,
    scheme4_address : felt,
    scheme5_address : felt,
):
    alloc_locals
    ERC721.initializer(name, symbol)
    ERC721_Token_Metadata.initializer()
    ERC2981_UniDirectional_Mutable.initializer(
        default_royalty_receiver, default_royalty_fee_basis_points
    )
    AccessControl.initializer()
    AccessControl._grant_role(DEFAULT_ADMIN_ROLE, owner)
    token_limit_storage.write(TOKEN_LIMIT)
    num_token_storage.write(0)

    # set vars as block number
    let block_number: felt = get_block_number()
    lastPurchaseBlock.write(block_number)
    priceDecayStartBlock.write(block_number)

    # setting CRISP parameters
    let (local shl: felt) = Math64x61_fromFelt(_saleHalfLife)
    let (ps: felt) = Math64x61_fromFelt(_priceSpeed)
    let (phl: felt) = Math64x61_fromFelt(_priceHalfLife)
    let (npsp: felt) = Math64x61_fromFelt(_startingPrice)
    let (tbps: felt) = Math64x61_fromFelt(_targetBlocksPerSale)
    let (neg_tbps: felt) = Math64x61_sub(0, tbps)
    let (tbps_div_shl: felt) = Math64x61_div(neg_tbps, shl)
    let (two_exp: felt) = Math64x61_pow(FP_TWO, tbps_div_shl)
    let (denom: felt) = Math64x61_sub(FP_ONE, two_exp)
    let (_targetEMS: felt) = Math64x61_div(FP_ONE, denom)

    #write to storage vars
    saleHalfLife.write(shl)
    priceSpeed.write(ps)
    priceHalfLife.write(phl)
    targetEMS.write(_targetEMS)
    nextPurchaseStartingEMS.write(_targetEMS)
    nextPurchaseStartingPrice.write(npsp)
    token_currency_address.write(_tokenCurrencyAddress)

    #scheme allocation
    scheme1_address_storage.write(scheme1_address)
    scheme2_address_storage.write(scheme2_address)
    scheme3_address_storage.write(scheme3_address)
    scheme4_address_storage.write(scheme4_address)
    scheme5_address_storage.write(scheme5_address)
    return ()
end

#
# View (ERC165)
#

@view
func supportsInterface{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    interfaceId : felt
) -> (success : felt):
    let (success) = ERC165.supports_interface(interfaceId)
    return (success)
end

#
# View (ERC721)
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC721.name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC721.symbol()
    return (symbol)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
    balance : Uint256
):
    let (balance : Uint256) = ERC721.balance_of(owner)
    return (balance)
end

@view
func ownerOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256
) -> (owner : felt):
    let (owner : felt) = ERC721.owner_of(tokenId)
    return (owner)
end

@view
func getApproved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256
) -> (approved : felt):
    let (approved : felt) = ERC721.get_approved(tokenId)
    return (approved)
end

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, operator : felt
) -> (isApproved : felt):
    let (isApproved : felt) = ERC721.is_approved_for_all(owner, operator)
    return (isApproved)
end

#
# View (contract metadata)
#

@view
func contractURI{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    contract_uri_len : felt, contract_uri : felt*
):
    let (contract_uri_len, contract_uri) = ERC721_Contract_Metadata.contract_uri()
    return (contract_uri_len, contract_uri)
end

#
# View (token metadata)
#

@view
func tokenURI{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256
) -> (tokenURI_len : felt, tokenURI : felt*):
    alloc_locals

    let id: felt = tokenId.low
    let (local seed: felt) = id_to_seed_storage.read(id)

    let (scheme: felt, num: felt) = get_scheme(seed)
    # id_to_scheme_storage.write(id, scheme)
    let (color_scheme) = get_color_scheme(seed)

    let (tokenURI_len: felt, tokenURI: felt*) = wrap_to_svg(id, num, color_scheme)
    # let (tokenURI_len, tokenURI) = ERC721_Token_Metadata.token_uri(tokenId)
    return (tokenURI_len, tokenURI)
end

#
# View (royalties)
#

@view
func royaltyInfo{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, salePrice : Uint256
) -> (receiver : felt, royaltyAmount : Uint256):
    let (exists) = ERC721._exists(tokenId)
    with_attr error_message("ERC721: token ID does not exist"):
        assert exists = TRUE
    end
    let (receiver : felt, royaltyAmount : Uint256) = ERC2981_UniDirectional_Mutable.royalty_info(
        tokenId, salePrice
    )
    return (receiver, royaltyAmount)
end

# This function should not be used to calculate the royalty amount and simply exposes royalty info for display purposes.
# Use royaltyInfo to calculate royalty fee amounts for orders as per EIP2981.
@view
func getDefaultRoyalty{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}() -> (
    receiver : felt, feeBasisPoints : felt
):
    let (receiver, fee_basis_points) = ERC2981_UniDirectional_Mutable.get_default_royalty()
    return (receiver, fee_basis_points)
end

@view
func getIdToSeed{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    id: felt
) -> (seed: felt):
    let (seed: felt) = id_to_seed_storage.read(id)
    return (seed)
end

func getSeedToId{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    seed: felt
) -> (id: felt):
    let (id: felt) = seed_to_id_storage.read(seed)
    return (id)
end

func getIdToScheme{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    id: felt
) -> (scheme: felt):
    let (scheme: felt) = id_to_scheme_storage.read(id)
    return (scheme)
end

@view
func getNumToken{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (num_token: felt):
    let (num_token: felt) = num_token_storage.read()
    return (num_token)
end

@view
func getTotalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (supply: felt):
    let supply: felt = TOKEN_LIMIT
    return (supply)
end

#
# View (access control)
#

@view
func hasRole{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    role : felt, account : felt
) -> (res : felt):
    let (res) = AccessControl.has_role(role, account)
    return (res)
end

@view
func getRoleAdmin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    role : felt
) -> (role_admin : felt):
    let (role_admin) = AccessControl.get_role_admin(role)
    return (role_admin)
end

@view
func getMinterRole{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    return (MINTER_ROLE)
end

@view
func getBurnerRole{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    return (BURNER_ROLE)
end

#
# Externals (ERC721)
#

@external
func approve{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    to : felt, tokenId : Uint256
):
    ERC721.approve(to, tokenId)
    return ()
end

@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt, approved : felt
):
    ERC721.set_approval_for_all(operator, approved)
    return ()
end

@external
func transferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    from_ : felt, to : felt, tokenId : Uint256
):
    ERC721.transfer_from(from_, to, tokenId)
    return ()
end

@external
func safeTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    from_ : felt, to : felt, tokenId : Uint256, data_len : felt, data : felt*
):
    ERC721.safe_transfer_from(from_, to, tokenId, data_len, data)
    return ()
end


#
# External (token metadata)
#

@external
func setBaseURI{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    base_token_uri_len : felt, base_token_uri : felt*
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    ERC721_Token_Metadata.set_base_token_uri(base_token_uri_len, base_token_uri)
    return ()
end

@external
func setTokenURI{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, tokenURI_len : felt, tokenURI : felt*
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    ERC721_Token_Metadata.set_token_uri(tokenId, tokenURI_len, tokenURI)
    return ()
end

@external
func resetTokenURI{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    ERC721_Token_Metadata.reset_token_uri(tokenId)
    return ()
end

#
# External (contract metadata)
#

@external
func setContractURI{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    contract_uri_len : felt, contract_uri : felt*
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    ERC721_Contract_Metadata.set_contract_uri(contract_uri_len, contract_uri)
    return ()
end

#
# External (royalties)
#

@external
func setDefaultRoyalty{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    receiver : felt, feeBasisPoints : felt
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    ERC2981_UniDirectional_Mutable.set_default_royalty(receiver, feeBasisPoints)
    return ()
end

@external
func setTokenRoyalty{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, receiver : felt, feeBasisPoints : felt
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    let (exists) = ERC721._exists(tokenId)
    with_attr error_message("ERC721: token ID does not exist"):
        assert exists = TRUE
    end
    ERC2981_UniDirectional_Mutable.set_token_royalty(tokenId, receiver, feeBasisPoints)
    return ()
end

@external
func resetDefaultRoyalty{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    ERC2981_UniDirectional_Mutable.reset_default_royalty()
    return ()
end

@external
func resetTokenRoyalty{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
):
    AccessControl.assert_only_role(DEFAULT_ADMIN_ROLE)
    let (exists) = ERC721._exists(tokenId)
    with_attr error_message("ERC721: token ID does not exist"):
        assert exists = TRUE
    end
    ERC2981_UniDirectional_Mutable.reset_token_royalty(tokenId)
    return ()
end

#
# External (bridgeable)
#

@external
func permissionedMint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    account : felt, tokenId : Uint256
):
    AccessControl.assert_only_role(MINTER_ROLE)
    ERC721._mint(account, tokenId)
    return ()
end

@external
func permissionedBurn{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
):
    AccessControl.assert_only_role(BURNER_ROLE)
    ERC721._burn(tokenId)
    ERC2981_UniDirectional_Mutable.reset_token_royalty(tokenId)
    return ()
end

#
# External (access control)
#

@external
func grantRole{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    role : felt, account : felt
):
    AccessControl.grant_role(role, account)
    return ()
end

@external
func revokeRole{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    role : felt, account : felt
):
    AccessControl.revoke_role(role, account)
    return ()
end

@external
func renounceRole{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    role : felt, account : felt
):
    AccessControl.renounce_role(role, account)
    return ()
end

#
# Internal svg generation
#

func get_scheme{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(seed: felt) -> (
        scheme: felt, num: felt):
    alloc_locals
    let (_, index: felt) = unsigned_div_rem(seed, 83)
    local scheme: felt
    let lt_20: felt = is_le(index, 19)
    if lt_20 == 1:
        let (z: felt) = scheme1_address_storage.read()
        tempvar scheme = z
        tempvar range_check_ptr=range_check_ptr
        return (scheme, 1)
    end
    let lt_45: felt = is_le(index, 44)
    if lt_45 == 1:
        let (z: felt) = scheme2_address_storage.read()
        tempvar scheme = z
        tempvar range_check_ptr=range_check_ptr
        return (scheme, 2)
    end
    let lt_70: felt = is_le(index, 69)
    if lt_70 == 1:
        let (z: felt) = scheme3_address_storage.read()
        tempvar scheme = z
        tempvar range_check_ptr=range_check_ptr
        return (scheme, 3)
    end
    let lt_80: felt = is_le(index, 79)
    if lt_80 == 1:
        let (z: felt) = scheme4_address_storage.read()
        tempvar scheme = z
        tempvar range_check_ptr=range_check_ptr
        return (scheme, 4)
    else:
        let (z: felt) = scheme5_address_storage.read()
        tempvar scheme = z
        tempvar range_check_ptr=range_check_ptr
    end
    return (scheme, 5)
end

func get_color_scheme{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(scheme: felt) -> (color_scheme: felt):
    alloc_locals
    let (_, index: felt) = unsigned_div_rem(scheme, 30)
    let lt_25: felt = is_le(index, 24)
    let scheme: felt = lt_25 * 1 + (1 - lt_25) * 0
    return (scheme)
end

func append_to_felt{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(res: felt, new_char: felt) -> (is_new: felt, new_str: felt):
    alloc_locals
    let lt_max_felt: felt = is_le_felt(res, TWO_POW_MAX)
    if lt_max_felt == 1:
        let new_str = res * 256 + new_char
        return (0, new_str)
    else:
        return (1, new_char)
    end
end

#recursive function for column drawing
func for_each_col{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(j: felt, y: felt, b: felt, resstr_len: felt, resstr: felt*, mod: felt, curr_str: felt, seed: felt, scheme: felt) -> (res_len: felt, res: felt*):
    alloc_locals
    local value
    if j == 2:
        return (j, resstr)
    end

    let x: felt = 2 * (b - HALF_SIZE) + 1
    let (_, seed_mod_2: felt) = signed_div_rem(seed, 2, 1000000000000000000)
    if seed_mod_2 == 1:
        let (x_abs: felt) = abs_value(x)
        tempvar _x = x_abs
        tempvar range_check_ptr=range_check_ptr
    else:
        tempvar _x = x
        tempvar range_check_ptr=range_check_ptr
    end

    let q = _x * seed
    let (w: felt, _) = signed_div_rem(q * y, ONE, 1000000000000000000)
    let (_, t: felt) = signed_div_rem(w, mod, 1000000000000000000)
    let (v: felt) = abs_value(t)
    let lt_20: felt = is_le(v, 19)
    if lt_20 == 1:
        let (scheme_char: felt) = PenroseMetadata.char_at_pos(scheme, v)
        tempvar value = scheme_char
        tempvar bitwise_ptr=bitwise_ptr
        tempvar syscall_ptr=syscall_ptr
        tempvar pedersen_ptr=pedersen_ptr
        tempvar range_check_ptr=range_check_ptr
    else:
        tempvar value = 't'
        tempvar bitwise_ptr=bitwise_ptr
        tempvar syscall_ptr=syscall_ptr
        tempvar pedersen_ptr=pedersen_ptr
        tempvar range_check_ptr=range_check_ptr
    end
    let (is_new, new_str) = append_to_felt(curr_str, value)
    if is_new == 0:
        return for_each_col(j, y, b + 1, resstr_len, resstr, mod, new_str, seed, scheme)
    else:
        if resstr_len == 0:
            let (res_len: felt, res: felt*) = add_last(0, resstr, curr_str)
        else:
            let (res_len: felt, res: felt*) = add_last(resstr_len - 1, resstr, curr_str)
        end
        return for_each_col(j + 1, y, b + 1, res_len + 1, res, mod, new_str, seed, scheme)
    end
end

#recursive function for row drawing
func for_each_row{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(i: felt, token_id: felt, output_len: felt, output: felt*, mod: felt, seed: felt, scheme: felt) -> (res_len: felt, res: felt*):
    alloc_locals
    if i == SIZE:
        return (i * 2, output)
    end

    let (resstr: felt*) = alloc()
    let y = 2 * (i - HALF_SIZE) + 1

    let (_, seed_mod_3: felt) = signed_div_rem(seed, 3, 1000000000000000000)
    if seed_mod_3 == 1:
        tempvar z = - y
        tempvar bitwise_ptr=bitwise_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        if seed_mod_3 == 2:
            let (y_abs: felt) = abs_value(y)
            tempvar z = y_abs
            tempvar bitwise_ptr=bitwise_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar z = y
            tempvar bitwise_ptr=bitwise_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        tempvar z = y
        tempvar bitwise_ptr=bitwise_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let q = z * seed
    let (col_len: felt, col: felt*) = for_each_col(0, q, 0, 0, resstr, mod, 0, seed, scheme)
    let (res_len: felt, res: felt*) = join(output_len, output, col_len, col)
    return for_each_row(i + 1, token_id, res_len, res, mod, seed, scheme)
end

@view
func draw{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(token_id: felt) -> (res_len: felt, res: felt*):
    alloc_locals

    let (seed: felt) = id_to_seed_storage.read(token_id)
    let (_, remainder: felt) = unsigned_div_rem(seed, 11)
    let mod = remainder + 20
    let (output: felt*) = alloc()
    let (scheme: felt, num: felt) = get_scheme(seed)

    let i = 0

    let (res_len: felt, res: felt*) = for_each_row(i, token_id, i, output, mod, seed, scheme)
    return (res_len, res)
end

func add_line{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(i: felt, pos: felt, step: felt, uri_len: felt, uri: felt* , token_raw_uri_len: felt, token_raw_uri: felt*) -> (res_uri_len: felt, res_uri: felt*):
    alloc_locals    
    if i == SIZE:
        return (uri_len, uri)
    end

    let (format: felt*) = alloc()
    let (str_pos: felt) = literal_from_number(pos)
    assert format[0] = '<text x=\"50%\" y=\"'
    assert format[1] = str_pos 
    assert format[2] = '%\" class=\"base\" text-anchor'
    assert format[3] = '=\"middle\">'
    assert format[4] = token_raw_uri[0]
    assert format[5] = token_raw_uri[1]
    let value = '</text>'

    let (res_len: felt, res: felt*) = add_last(6, format, value)
    let (x_len: felt, x: felt*) = join(uri_len, uri, res_len, res)
    let new_pos = pos + step

    return add_line(i + 1, new_pos, step, x_len, x, token_raw_uri_len - 2, token_raw_uri + 2)
end

func wrap_to_svg{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(token_id: felt, num: felt, color_scheme: felt) -> (res_uri_len: felt, res_uri: felt*):
    alloc_locals

    let foreground = color_scheme * COLORSCHEME_BLACK + (1 - color_scheme) * COLORSCHEME_WHITE
    let background = color_scheme * COLORSCHEME_WHITE + (1 - color_scheme) * COLORSCHEME_BLACK
    let (uri) = alloc()
    let (str_num: felt) = literal_from_number(num)
    let (str_token_id: felt) = literal_from_number(token_id)
    let str_color = color_scheme * 'black' + (1 - color_scheme) * 'white'
    
    assert uri[0]  =   'data:application/json;charset='
    assert uri[1]  =   'utf-8,{"name":"#'
    assert uri[2]  =   str_token_id
    assert uri[3]  =   '","attributes":[{"trait_type":'
    assert uri[4]  =   '"scheme","value":"'
    assert uri[5]  =   str_num
    assert uri[6]  =   '"},{"trait_type": "color","val'
    assert uri[7]  =   'ue": "'
    assert uri[8]  =   str_color
    assert uri[9]  =   '"}],"image":"data:image/svg+xm'
    assert uri[10]  =   'l,<?xml version=\"1.0\" encodi'
    assert uri[11]  =   'ng=\"UTF-8\"?><svg xmlns=\"htt'
    assert uri[12]  =   'p://www.w3.org/2000/svg\" pres'
    assert uri[13]  =   'erveAspectRatio=\"xMinYMin mee'
    assert uri[14]  =   't\" viewBox=\"0 0 400 400\"><d'
    assert uri[15]  =   'efs><style>@font-face{font-fam'
    assert uri[16]  =   'ily:\"Penrose\";src:url(data:f'
    assert uri[17]  =   'ont/ttf;base64,AAEAAAALAIAAAwA'
    assert uri[18]  =   'wT1MvMg8RDYcAAAC8AAAAYGNtYXAAs'
    assert uri[19]  =   'ADiAAABHAAAAFxnYXNwAAAAEAAAAXg'
    assert uri[20]  =   'AAAAIZ2x5ZnmFYs0AAAGAAAAHuGhlY'
    assert uri[21]  =   'WQg3OLxAAAJOAAAADZoaGVhB8ID2gA'
    assert uri[22]  =   'ACXAAAAAkaG10eFoAA/4AAAmUAAAAZ'
    assert uri[23]  =   'GxvY2EaUBw0AAAJ+AAAADRtYXhwABw'
    assert uri[24]  =   'APQAACiwAAAAgbmFtZZlKCfsAAApMA'
    assert uri[25]  =   'AABhnBvc3QAAwAAAAAL1AAAACAAAwP'
    assert uri[26]  =   'pAZAABQAAApkCzAAAAI8CmQLMAAAB6'
    assert uri[27]  =   'wAzAQkAAAAAAAAAAAAAAAAAAAABAAA'
    assert uri[28]  =   'AAAAAAAAAAAAAAAAAAABAAAAAdAPA/'
    assert uri[29]  =   '8AAQAPAAEAAAAABAAAAAAAAAAAAAAA'
    assert uri[30]  =   'gAAAAAAADAAAAAwAAABwAAQADAAAAH'
    assert uri[31]  =   'AADAAEAAAAcAAQAQAAAAAwACAACAAQ'
    assert uri[32]  =   'AAQAgADAAdP/9//8AAAAAACAAMABh/'
    assert uri[33]  =   '/3//wAB/+P/1P+kAAMAAQAAAAAAAAA'
    assert uri[34]  =   'AAAAAAAABAAH//wAPAAEAAAAAAAAAA'
    assert uri[35]  =   'AACAAA3OQEAAAAAAQAAAAAAAAAAAAI'
    assert uri[36]  =   'AADc5AQAAAAABAAAAAAAAAAAAAgAAN'
    assert uri[37]  =   'zkBAAAAAAEAAAAAAAAAAAACAAA3OQE'
    assert uri[38]  =   'AAAAAAQAA/8AEAAPAADoAAAE2Nz4BN'
    assert uri[39]  =   'zYzNSIHDgEHBgcGBw4BBwYHBgcOAQc'
    assert uri[40]  =   'GBwYHDgEHBhUzNDc+ATc2NzY3PgE3N'
    assert uri[41]  =   'jc2Nz4BNzY3AoQtLy5gMTAxMjIzYjA'
    assert uri[42]  =   'wLy4tLFQnJiQkICA3GBgTEw8PEwUFH'
    assert uri[43]  =   'wUEEw4PEhMXFzYfHyMiJiZRKystA1Y'
    assert uri[44]  =   'SDw4TBAUfBQUTDw8TExgYNyAgJCQmJ'
    assert uri[45]  =   '1QsLS4vMDBiMzIyMTAxYC4vLS0rK1E'
    assert uri[46]  =   'mJiIjHx82FxcTAAABAAD/wAQAA8AAO'
    assert uri[47]  =   'gAAASYnLgEnJiM1MhceARcWFxYXHgE'
    assert uri[48]  =   'XFhcWFx4BFxYXFhceARcWFSM0Jy4BJ'
    assert uri[49]  =   'yYnJicuAScmJyYnLgEnJicBfC0vLmA'
    assert uri[50]  =   'xMDEyMjNiMDAvLi0sVCcmJCQgIDcYG'
    assert uri[51]  =   'BMTDw8TBQUfBQQTDg8SExcXNh8fIyI'
    assert uri[52]  =   'mJlErKy0DVhIPDhMEBR8FBRMPDxMTG'
    assert uri[53]  =   'Bg3ICAkJCYnVCwtLi8wMGIzMjIxMDF'
    assert uri[54]  =   'gLi8tLSsrUSYmIiMfHzYXFxMAAAEAA'
    assert uri[55]  =   'P/ABAADwAA6AAAlFhceARcWMxUiJy4'
    assert uri[56]  =   'BJyYnJicuAScmJyYnLgEnJicmJy4BJ'
    assert uri[57]  =   'yY1MxQXHgEXFhcWFx4BFxYXFhceARc'
    assert uri[58]  =   'WFwKELS8uYDEwMTIyM2IwMC8uLSxUJ'
    assert uri[59]  =   'yYkJCAgNxgYExMPDxMFBR8FBBMODxI'
    assert uri[60]  =   'TFxc2Hx8jIiYmUSsrLSoSDw4TBAUfB'
    assert uri[61]  =   'QUTDw8TExgYNyAgJCQmJ1QsLS4vMDB'
    assert uri[62]  =   'iMzIyMTAxYC4vLS0rK1EmJiIjHx82F'
    assert uri[63]  =   'xcTAAAAAQAA/8AEAAPAADoAACUGBw4'
    assert uri[64]  =   'BBwYjFTI3PgE3Njc2Nz4BNzY3Njc+A'
    assert uri[65]  =   'Tc2NzY3PgE3NjUjFAcOAQcGBwYHDgE'
    assert uri[66]  =   'HBgcGBw4BBwYHAXwtLy5gMTAxMjIzY'
    assert uri[67]  =   'jAwLy4tLFQnJiQkICA3GBgTEw8PEwU'
    assert uri[68]  =   'FHwUEEw4PEhMXFzYfHyMiJiZRKystK'
    assert uri[69]  =   'hIPDhMEBR8FBRMPDxMTGBg3ICAkJCY'
    assert uri[70]  =   'nVCwtLi8wMGIzMjIxMDFgLi8tLSsrU'
    assert uri[71]  =   'SYmIiMfHzYXFxMAAAABAAD/wAQAA8A'
    assert uri[72]  =   'AIgAAASIHDgEHBgcGBw4BBwYHBgcOA'
    assert uri[73]  =   'QcGBwYHDgEHBhUjESE4ATEEADEwMWA'
    assert uri[74]  =   'uLy0tKytRJiYiIx8fNhcXExIPDhMEB'
    assert uri[75]  =   'R8EAAOhBQQTDg8SExcXNh8fIyImJlE'
    assert uri[76]  =   'rKy0tLy5gMTAxBAAAAQAA/8AEAAPAA'
    assert uri[77]  =   'CIAAAU0Jy4BJyYnJicuAScmJyYnLgE'
    assert uri[78]  =   'nJicmJy4BJyYjNSEROAExA+EFBBMOD'
    assert uri[79]  =   'xITFxc2Hx8jIiYmUSsrLS0vLmAxMDE'
    assert uri[80]  =   'EAEAxMDFgLi8tLSsrUSYmIiMfHzYXF'
    assert uri[81]  =   'xMSDw4TBAUf/AAAAAEAAP/ABAADwAA'
    assert uri[82]  =   'iAAATFBceARcWFxYXHgEXFhcWFx4BF'
    assert uri[83]  =   'xYXFhceARcWMxUhETgBMR8FBBMODxI'
    assert uri[84]  =   'TFxc2Hx8jIiYmUSsrLS0vLmAxMDH8A'
    assert uri[85]  =   'APAMTAxYC4vLS0rK1EmJiIjHx82Fxc'
    assert uri[86]  =   'TEg8OEwQFHwQAAAABAAD/wAQAA8AAI'
    assert uri[87]  =   'wAAFzI3PgE3Njc2Nz4BNzY3Njc+ATc'
    assert uri[88]  =   '2NzY3PgE3NjUzESE4ATE1ADEwMWAuL'
    assert uri[89]  =   'y0tKytRJiYiIx8fNhcXExIPDhMEBR/'
    assert uri[90]  =   '8ACEFBBMODxITFxc2Hx8jIiYmUSsrL'
    assert uri[91]  =   'S0vLmAxMDH8AB8AAQAA/8AEAAPAAB4'
    assert uri[92]  =   'AAAURIgcOAQcGBwYHDgEHBgcGBw4BB'
    assert uri[93]  =   'wYHBgcOAQcGFSEEADIyM2IwMC8uLSx'
    assert uri[94]  =   'UJyYkJCAgNxgYExMPDxMFBQQAQAQAB'
    assert uri[95]  =   'QUTDw8TExgYNyAgJCQmJ1QsLS4vMDB'
    assert uri[96]  =   'iMzIyAAAAAQAA/8AEAAPAAB4AABcRM'
    assert uri[97]  =   'hceARcWFxYXHgEXFhcWFx4BFxYXFhc'
    assert uri[98]  =   'eARcWFSEAMjIzYjAwLy4tLFQnJiQkI'
    assert uri[99]  =   'CA3GBgTEw8PEwUF/ABABAAFBRMPDxM'
    assert uri[100]  =   'TGBg3ICAkJCYnVCwtLi8wMGIzMjIAA'
    assert uri[101]  =   'AAAAQAA/8AEAAPAAB4AAAERIicuASc'
    assert uri[102]  =   'mJyYnLgEnJicmJy4BJyYnJicuAScmN'
    assert uri[103]  =   'SEEADIyM2IwMC8uLSxUJyYkJCAgNxg'
    assert uri[104]  =   'YExMPDxMFBQQAA8D8AAUFEw8PExMYG'
    assert uri[105]  =   'DcgICQkJidULC0uLzAwYjMyMgAAAQA'
    assert uri[106]  =   'A/8AEAAPAAB4AABMRMjc+ATc2NzY3P'
    assert uri[107]  =   'gE3Njc2Nz4BNzY3Njc+ATc2NSEAMjI'
    assert uri[108]  =   'zYjAwLy4tLFQnJiQkICA3GBgTEw8PE'
    assert uri[109]  =   'wUF/AADwPwABQUTDw8TExgYNyAgJCQ'
    assert uri[110]  =   'mJ1QsLS4vMDBiMzIyAAAAAQAIA6ID+'
    assert uri[111]  =   'APAAAMAAAEhNSED+PwQA/ADoh4AAAE'
    assert uri[112]  =   'AAP/IAB4DuAADAAATESMRHh4DuPwQA'
    assert uri[113]  =   '/AAAAABAAj/wAP4/94AAwAABSE1IQP'
    assert uri[114]  =   '4/BAD8EAeAAAAAQPi/8gEAAO4AAMAA'
    assert uri[115]  =   'AERIxEEAB4DuPwQA/AAAAIABP/EA/w'
    assert uri[116]  =   'DvAAEAAkAAAkBJwEXJQEHATcD/PwdF'
    assert uri[117]  =   'QPjFfwdA+MV/B0VA6f8HRUD4xUV/B0'
    assert uri[118]  =   'VA+MVAAAAAAEABP/EA/wDvAAEAAAJA'
    assert uri[119]  =   'ScBFwP8/B0VA+MVA6f8HRUD4xUAAAE'
    assert uri[120]  =   'ABP/EA/wDvAAEAAATAQcBNxkD4xX8H'
    assert uri[121]  =   'RUDvPwdFQPjFQAAAAEAAAAAAAAAAAA'
    assert uri[122]  =   'CAAA3OQEAAAAAAQAAAAAAAL743jFfD'
    assert uri[123]  =   'zz1AAsEAAAAAADe3086AAAAAN7fTzo'
    assert uri[124]  =   'AAP/ABAADwAAAAAgAAgAAAAAAAAABA'
    assert uri[125]  =   'AADwP/AAAAEAAAAAAAEAAABAAAAAAA'
    assert uri[126]  =   'AAAAAAAAAAAAAGQQAAAAAAAAAAAAAA'
    assert uri[127]  =   'AIAAAAEAAAABAAAAAQAAAAEAAAABAA'
    assert uri[128]  =   'AAAQAAAAEAAAABAAAAAQAAAAEAAAAB'
    assert uri[129]  =   'AAAAAQAAAAEAAAABAAACAQAAAAEAAA'
    assert uri[130]  =   'IBAAD4gQAAAQEAAAEBAAABAQAAAAAA'
    assert uri[131]  =   'AAAAAoAFAAeACgAhgDkAUIBoAHYAhA'
    assert uri[132]  =   'CSAKAArYC7AMiA1gDZgN0A4IDkAOuA'
    assert uri[133]  =   '8AD0gPcAAEAAAAZADsAAgAAAAAAAgA'
    assert uri[134]  =   'AAAAAAAAAAAAAAAAAAAAAAAAOAK4AA'
    assert uri[135]  =   'QAAAAAAAQAHAAAAAQAAAAAAAgAHAGA'
    assert uri[136]  =   'AAQAAAAAAAwAHADYAAQAAAAAABAAHA'
    assert uri[137]  =   'HUAAQAAAAAABQALABUAAQAAAAAABgA'
    assert uri[138]  =   'HAEsAAQAAAAAACgAaAIoAAwABBAkAA'
    assert uri[139]  =   'QAOAAcAAwABBAkAAgAOAGcAAwABBAk'
    assert uri[140]  =   'AAwAOAD0AAwABBAkABAAOAHwAAwABB'
    assert uri[141]  =   'AkABQAWACAAAwABBAkABgAOAFIAAwA'
    assert uri[142]  =   'BBAkACgA0AKRpY29tb29uAGkAYwBvA'
    assert uri[143]  =   'G0AbwBvAG5WZXJzaW9uIDEuMABWAGU'
    assert uri[144]  =   'AcgBzAGkAbwBuACAAMQAuADBpY29tb'
    assert uri[145]  =   '29uAGkAYwBvAG0AbwBvAG5pY29tb29'
    assert uri[146]  =   'uAGkAYwBvAG0AbwBvAG5SZWd1bGFyA'
    assert uri[147]  =   'FIAZQBnAHUAbABhAHJpY29tb29uAGk'
    assert uri[148]  =   'AYwBvAG0AbwBvAG5Gb250IGdlbmVyY'
    assert uri[149]  =   'XRlZCBieSBJY29Nb29uLgBGAG8AbgB'
    assert uri[150]  =   '0ACAAZwBlAG4AZQByAGEAdABlAGQAI'
    assert uri[151]  =   'ABiAHkAIABJAGMAbwBNAG8AbwBuAC4'
    assert uri[152]  =   'AAAADAAAAAAAAAAAAAAAAAAAAAAAAA'
    assert uri[153]  =   'AAAAAAAAAAAAAAA);}</style></de'
    assert uri[154]  =   'fs><style>.base { fill: #'
    assert uri[155]  =   foreground
    assert uri[156]  =   '; font-family: \"Penrose\",mo'
    assert uri[157]  =   'nospace;font-size:8px;}</styl'
    assert uri[158]  =   'e><rect width=\"100%\" height='
    assert uri[159]  =   '\"100%\" fill=\"#'
    assert uri[160]  =   background
    assert uri[161]  =   '\" />'

    let (token_raw_uri_len: felt, token_raw_uri: felt*) = draw(token_id)

    let i = 0
    let start = 8
    let (step, _) = unsigned_div_rem((100 - start * 2), (SIZE - 2))
    let (s_len: felt, s: felt*) = add_line(i, start, step, 162, uri, token_raw_uri_len + 1, token_raw_uri)
    let last_svg: felt = '</svg>"}'
    let (res_len: felt, res: felt*) = add_last(s_len, s, last_svg)
    return (res_len, res)
end

func _mint{bitwise_ptr : BitwiseBuiltin*, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to: felt, price: felt, block: felt):
    alloc_locals
    let (token_limit: felt) = token_limit_storage.read()
    let (num_token: felt) = num_token_storage.read()
    let (timestamp: felt) = get_block_timestamp()
    

    with_attr error_message("Collection has been minted out!"):
        assert_lt(num_token, token_limit)
    end
    
    local id: felt = num_token + 1
    local seed: felt = timestamp + id

    id_to_seed_storage.write(id, seed)
    seed_to_id_storage.write(seed, id)
    num_token_storage.write(id)
    id_to_price_storage.write(id, price)
    id_to_block_storage.write(id, block)

    let token_id: Uint256 = Uint256(id, 0)

    ERC721._mint(to, token_id)
    return ()
end

#
# CRISP functions
#

# get current EMS based on current block number. Returns 64x61 fixed-point number
@view
func getCurrentEMS{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (result : felt):
    alloc_locals
    let (lpb: felt) = lastPurchaseBlock.read()
    let (block_number: felt) = get_block_number()

    local blockInterval: felt = block_number - lpb

    let bi: felt = Math64x61_fromFelt(blockInterval)
    let (_saleHalfLife: felt) = saleHalfLife.read()
    let (local neg_bi: felt) = Math64x61_sub(0, bi)
    let (local two_exp: felt) = Math64x61_div(neg_bi, _saleHalfLife)
    let (weightonPrev: felt) = Math64x61_pow(FP_TWO, two_exp)
    let (_nextPurchaseStartingEMS: felt) = nextPurchaseStartingEMS.read()

    let (res: felt) = Math64x61_mul(_nextPurchaseStartingEMS, weightonPrev)
    
    return (res)
end

# Get quote for purchasing in current block, decaying price as needed. Returns fixed-point number
@view
func getQuote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (result: felt):
    alloc_locals
    local result: felt
    let (local block_number: felt) = get_block_number()
    let (local price_decay_start_block: felt) = priceDecayStartBlock.read()
    local before_or_after: felt = (block_number - price_decay_start_block)
    let (local is_before: felt) = is_le(block_number, price_decay_start_block)
    let (local price_half_life: felt) = priceHalfLife.read()
    let (local next_purchase_starting_price: felt) = nextPurchaseStartingPrice.read()

    if is_before == 1:
        # block number is BEFORE block that the decay is supposed to occur
        # simply returns same starting price
        tempvar range_check_ptr = range_check_ptr
        result = next_purchase_starting_price
    else:
        # decay price if current block is AFTER block that the decay is supposed to start
        
        let (decay_interval: felt) = Math64x61_fromFelt(before_or_after)
        let (neg_di: felt) = Math64x61_sub(0, decay_interval)
        let (decay: felt) = Math64x61_div(neg_di, price_half_life)
        let (exp_decay: felt) = Math64x61_exp(decay)
        let (res: felt) = Math64x61_mul(next_purchase_starting_price, exp_decay)

        tempvar range_check_ptr = range_check_ptr
        result = res
    end
    return (result)

end

# Get starting price for the next purchase before time decay. Returns fixed-point number
@view
func getNextStartingPrice{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(lastPurchasePrice: felt) -> (result: felt):

    alloc_locals
    local result: felt
    let (local next_purchase_starting_ems: felt) = nextPurchaseStartingEMS.read()
    let (local target_ems: felt) = targetEMS.read()
    let (local mismatchRatio: felt) = Math64x61_div(next_purchase_starting_ems, target_ems)
    let (local price_speed: felt) = priceSpeed.read() #price_speed = 1
    let (local is_before: felt) = is_le(mismatchRatio, FP_ONE)

    if is_before == 0:
        let (ratio: felt) = Math64x61_mul(mismatchRatio, price_speed)
        let (multiplier: felt) = Math64x61_add(FP_ONE, ratio)
        let (res: felt) = Math64x61_mul(lastPurchasePrice, multiplier)
        result = res
    else:
        result = lastPurchasePrice
    end

    return (result)
end

@view
func getPriceDecayStartBlock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (result: felt):
    alloc_locals
    local result: felt
    let (local next_purchase_starting_ems: felt) = nextPurchaseStartingEMS.read()
    let (local target_ems: felt) = targetEMS.read()

    let (local mismatchRatio: felt) = Math64x61_div(next_purchase_starting_ems, target_ems)
    let (local mmr_over_one: felt) = is_le(mismatchRatio, FP_ONE)
    let (block_number: felt) = get_block_number()
    let (sale_half_life: felt) = saleHalfLife.read()

    if mmr_over_one == 0:
        # if mismatch ratio > 1, decay should start in the future
        let (log_two: felt) = Math64x61_log2(mismatchRatio)
        # let (ceiling: felt) = Math64x61_ceil(log_two)
        let (di: felt) = Math64x61_mul(sale_half_life, log_two)
        let (decayInterval: felt) = Math64x61_toFelt(di) #di)
        let res: felt = (block_number + decayInterval)
        tempvar range_check_ptr = range_check_ptr
        result = res

    else:
        # else, decay should start at the current block
        tempvar range_check_ptr = range_check_ptr
        result = block_number
    end
    return (result)
end

@external
func mint{bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> ():
    alloc_locals
    let (price_fp: felt) = getQuote()
    let (local price: felt) = Math64x61_toFelt(price_fp)
    let (local caller: felt) = get_caller_address()
    let (last_purchase_block: felt) = get_block_number()
    let (currency_address: felt) = token_currency_address.read()
    _mint(caller, price, last_purchase_block)

    IERC20.transferFrom(currency_address, caller, RECIPIENT_ADDRESS, Uint256(price, 0))

    # update state
    let (get_current_ems: felt) = getCurrentEMS()
    let (next_purchase_starting_ems: felt) = Math64x61_add(get_current_ems, FP_ONE)
    nextPurchaseStartingEMS.write(next_purchase_starting_ems)

    # updating CRISP state
    let (next_purchase_starting_price: felt) = getNextStartingPrice(price_fp)
    nextPurchaseStartingPrice.write(next_purchase_starting_price)
    
    lastPurchaseBlock.write(last_purchase_block)

    let (price_decay_start_block: felt) = getPriceDecayStartBlock()
    priceDecayStartBlock.write(price_decay_start_block)

    lastPurchasePrice.write(price)


    # issue refund
    # no such thing as msg.value/msg.sender.call on starknet yet

    return ()
end

# Getters for CRISP parameters
@view
func getTargetEMS{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (i : felt):
    let (x: felt) = targetEMS.read()
    return (x)
end

@view
func getSaleHalfLife{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (i : felt):
    let (x_fp: felt) = saleHalfLife.read()
    let (x: felt) = Math64x61_toFelt(x_fp)
    return (x)
end

@view
func getPriceSpeed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (i : felt):
    let (x: felt) = priceSpeed.read()
    return (x)
end

@view
func getPriceHalfLife{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (i : felt):
    let (x_fp: felt) = priceHalfLife.read()
    let (x: felt) = Math64x61_toFelt(x_fp)
    return (x)
end

# Getters for CRISP state

@view
func getNextPurchaseStartingEMS{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (i : felt):
    let (x_fp: felt) = nextPurchaseStartingEMS.read()
    let (x: felt) = Math64x61_toFelt(x_fp)
    return (x)
end

@view
func getNextPurchaseStartingPrice{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (i : felt):
    let (x_fp: felt) = nextPurchaseStartingPrice.read()
    let (x: felt) = Math64x61_toFelt(x_fp)
    return (x)
end

@view
func getPurchasePrice{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) -> (price: felt):
    let (x: felt) = id_to_price_storage.read(id)
    return (x)
end

@view
func getPurchaseBlock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) -> (block: felt):
    let (x: felt) = id_to_block_storage.read(id)
    return (x)
end

