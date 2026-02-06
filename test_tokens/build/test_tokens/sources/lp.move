module test_tokens::lp {
    use sui::coin;

    public struct LP has drop {}

    fun init(witness: LP, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,
            b"ORB_LP",
            b"Orbital LP Token",
            b"LP token for Orbital Pool",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }
}
