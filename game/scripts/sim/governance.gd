class_name Governance
extends RefCounted
## Registered company service: routes tax/legal/insurance without adding a fictional sales segment.
static func is_running() -> bool:return Tax.valid(GameState.company_id())
static func segment_tag() -> String:return "shared"
static func os_tab() -> Dictionary:return {"id":"governance","label":"Governance","icon":"finance","order":91,"render":GovernanceUI.render_os}
static func board_detail() -> Callable:return func(_details,_board):pass
static func open_action(_params: Dictionary,_source: Node) -> void:UIRoot.open_modal(TaxFilingModal.new(GameState.business_entity()))
static func on_company_registered(entity: String) -> void:Tax.E(entity)
static func on_business_transferred(entity: String) -> void:Tax.transfer_seller_vat(entity)
static func prepare_journal(entity: String,lines: Array,source: Dictionary) -> Array:return Tax.separate(entity,lines,source)
static func on_ledger(entry: Dictionary) -> void:
	Brand.on_ledger(entry)
	Insurance.on_ledger(entry)
static func on_hour(_t: int,_h: int) -> void:
	Tax.on_hour()
	Legal.on_hour()
	Insurance.on_hour()
static func handle(kind: String,payload: Dictionary) -> void:
	Tax.handle(kind,payload)
	Legal.handle(kind,payload)
	Insurance.handle(kind,payload)
static func on_company_closed(entity: String) -> void:
	Tax.on_company_closed(entity)
	Legal.on_company_closed(entity)
	Insurance.on_company_closed(entity)
	Insurance.crisis_context={}
