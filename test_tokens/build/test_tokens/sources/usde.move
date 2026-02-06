module test_tokens::usde {
    use sui::coin::{Self, TreasuryCap};

    public struct USDE has drop {}

    fun init(witness: USDE, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            6, // decimals
            b"USDE",
            b"USDe",
            b"Ethena USDe - Synthetic Dollar",
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
    }

    #[allow(lint(share_owned))]
    public entry fun transfer_treasury(
        treasury: TreasuryCap<USDE>,
        recipient: address
    ) {
        transfer::public_transfer(treasury, recipient);
    }
}
