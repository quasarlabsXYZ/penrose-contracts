%lang starknet

from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq
)

@contract_interface
namespace Penrose:
    func get_raw_token_uri(token_id: felt) -> (res_uri_len: felt, res_uri: felt*):
    end

    func create_penrose():
    end

    func for_each_col(j: felt, y: felt, resstr_len: felt, resstr: felt*, mod: felt, curr_str: felt, b: felt, seed: felt, scheme: felt) -> (res_len: felt, res: felt*):
    end

    func for_each_row(i: felt, token_id: felt, output_len: felt, output: felt*, mod: felt, seed: felt, scheme: felt) -> (res_len: felt, res: felt*):
    end

    func draw(token_id:felt) -> (res_len: felt, res: felt*):
    end

    func write_id_to_seed(token_id: felt, timestamp: felt):
    end

    func add_line(i: felt, pos: felt, step: felt, uri_len: felt, uri: felt* , token_raw_uri_len: felt, token_raw_uri: felt*) -> (res_uri_len: felt, res_uri: felt*):
    end

    func write_foreground_background(token_id: felt):
    end

    func wrap_to_svg(token_id: felt) -> (res_uri_len: felt, res_uri: felt*):
    end

    func get_scheme(token_id: felt, seed: felt) -> (scheme: felt):
    end

    func getIdToCreator(id: felt) -> (creator: felt):
    end

    func getIdToSeed(id: felt) -> (seed: felt):
    end

    func getSeedToId(seed: felt) -> (id: felt):
    end

    func getIdToScheme(id: felt) -> (scheme: felt):
    end

    func getNumToken() -> (num_token: felt):
    end

    func tokenURI(tokenId: Uint256) -> (tokenURI_len: felt, tokenURI: felt*):
    end

    func append_to_felt(res: felt, new_char: felt) -> (is_new: felt, new_str: felt):
    end

    func getQuote() -> (result: felt):
    end

    func mint():
    end

    func balanceOf(account: felt):
    end

    func getPriceDecayStartBlock() -> (result: felt):
    end

    func getCurTokenId() -> (i: felt):
    end

    func blockNumber() -> (number: felt):
    end

    func getCurrentEMS() -> (result: felt):
    end

    func getNextPurchaseStartingPrice() -> (i: felt):
    end

    func hasRole(role: felt, account: felt) -> (res: felt):
    end

    func grantRole(role: felt, account: felt):
    end

    func getCallerAddress() -> (caller: felt):
    end

end