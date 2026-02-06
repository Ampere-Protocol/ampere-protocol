module test_tokens::usdt {
    use sui::coin;

    public struct USDT has drop {}

    fun init(witness: USDT, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"USDT",
            b"Tether USD Test",
            b"Test USDT token for Orbital Pool demo",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }
}
