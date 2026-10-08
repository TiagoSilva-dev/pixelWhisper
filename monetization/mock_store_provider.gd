class_name MockStoreProvider
extends StoreProvider
## Stand-in for the app store in the editor, the Web build and the tests. Buying shows a fake
## confirmation sheet (MockPurchaseModal) and always succeeds when confirmed. It is not
## authoritative: with no store account behind it, the saved Premium flag stays the truth.
##
## The public vars are the knobs the tests turn.

var instant: bool = false                ## no sheet: the outcome is `next_result`, right away
var next_result: Result = Result.OK
var available: bool = true
var price: String = "$4.99"
var purchases_started: int = 0

var _host: Node


func _init(host: Node) -> void:
	_host = host


func is_available() -> bool:
	return available


func price_text() -> String:
	return price if available else ""


func owns_premium() -> bool:
	return GameState.premium


func buy_premium() -> Result:
	purchases_started += 1
	if instant:
		await _host.get_tree().process_frame   # still asynchronous, like a real store
		return next_result
	var bought: bool = await MockPurchaseModal.ask(_host, price)
	return Result.OK if bought else Result.CANCELED


func restore() -> bool:
	await _host.get_tree().process_frame
	return GameState.premium
