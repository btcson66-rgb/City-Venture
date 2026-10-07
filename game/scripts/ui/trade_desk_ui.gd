class_name TradeDeskUI
extends Modal
var primary_chosen:=false
func _init() -> void:
	title_text="International Trade";icon_name="world";help_key="trade_desk";panel_size=Vector2(600,332)
static func open() -> void:UIRoot.open_modal(TradeDeskUI.new())
static func render(os: Node) -> void:
	var b:=UIK.button("Open Trade Desk",open,"primary");b.name="OpenTradeDesk";os.content.add_child(b)
static func board(box: Node, _owner: Node) -> void:
	box.add_child(UIK.wrap("Register at Customs House, lease Meridian Trade Desk, then compare real supplier and buyer quotes.",8,Art.C_WHITE,300))
func act(callback: Callable) -> void:
	var r: Dictionary=callback.call()
	if not r.get("ok",false):UIRoot.open_modal(InfoModal.make("International Trade","world",[str(r.get("error",""))]));return
	rebuild()
func add_button(parent: Node,label: String,id: String,callback: Callable,main:=false) -> void:
	var b:=UIK.button(label,act.bind(callback),"primary" if main and not primary_chosen else "")
	b.name=id;parent.add_child(b)
	if main:primary_chosen=true
func build() -> void:
	AssistantPolicy.toggle(body,"customs")
	primary_chosen=false
	var content:=UIK.vbox(5);body.add_child(UIK.scroll(content,Vector2(570,230)))
	if not TradeIndustry.S()["registered"]:
		content.add_child(UIK.wrap("✗ "+I18n.t("Apply for import and export registration at Customs House first."),9,Art.C_SKY,560))
		content.add_child(UIK.kv("Import and export registration",Fmt.money(float(TradeIndustry.cfg().get("registration_fee",200)))))
		var here=SceneRouter.world_scene()
		if here!=null and here.kind=="interior" and here.scene_id=="customs_house":add_button(content,"Register import and export business","RegisterTrade",TradeIndustry.register,true)
		return
	if not TradeIndustry.is_running():
		if not Living.has_lease("meridian_trade_office"):
			content.add_child(UIK.wrap("✗ "+I18n.t("Lease Meridian Trade Desk before opening the brokerage."),9,Art.C_SKY,560))
		else:add_button(content,"Open the trade brokerage","StartTrade",TradeIndustry.start,true)
		return
	content.add_child(UIK.kv("Company cash",Fmt.money(Ledger.cash(TradeIndustry.entity()))))
	content.add_child(UIK.kv("Delivered trades",I18n.t("%d contracts")%int(TradeIndustry.S()["completed"])))
	if not GlobalMarket.company()["bank"]:add_button(content,"Open international company account","TradeInternationalBank",GlobalMarket.open_bank)
	if TradeIndustry.stage()>=2 and not Living.has_lease("meridian_bonded_warehouse"):
		add_button(content,"Lease bonded warehouse","TradeWarehouse",TradeIndustry.lease_warehouse)
	elif TradeIndustry.stage()>=2 and not TradeIndustry.S()["agency"]:
		content.add_child(UIK.kv("Regional agency application",Fmt.money(float(TradeIndustry.cfg().get("agency_fee",2500)))))
		add_button(content,"Apply for regional agency","TradeAgency",TradeIndustry.open_agency)
	for id in TradeIndustry.S()["contracts"]:
		var contract: Dictionary=TradeIndustry.S()["contracts"][id]
		if contract["ended"]:continue
		content.add_child(UIK.wrap(I18n.t("Repeat contract: %s · %d shipments remaining")%[id,int(contract["remaining"])],8,Art.C_WHITE,560))
		if contract["error"]!="":content.add_child(UIK.wrap("✗ "+str(contract["error"]),8,Art.C_SKY,560))
		add_button(content,"Resume repeat contract" if contract["paused"] else "Pause repeat contract","TradeRepeat_"+id,TradeIndustry.pause_repeat.bind(id,not contract["paused"]),contract["paused"])
		add_button(content,"End repeat contract","TradeEndRepeat_"+id,TradeIndustry.end_repeat.bind(id))
	for d in TradeIndustry.S()["deals"].values():
		if d["status"] in ["booked","customs_hold"]:
			add_button(content,"Prepare all documents","TradeDocuments_"+str(d["id"]),_documents.bind(str(d["id"])))
		content.add_child(UIK.sep())
		content.add_child(UIK.wrap(str(d["id"])+" · "+status_text(str(d["status"])),9,Art.C_WHITE,560))
		content.add_child(UIK.wrap(I18n.t("%d units · %s → %s")%[int(d["quantity"]),I18n.t(DataDB.regions[d["quote"]["origin"]]["name"]),I18n.t(DataDB.regions[d["quote"]["destination"]]["name"])],8,Art.C_WHITE,560))
		if d["status"]=="paid" and TradeIndustry.stage()>=2 and not TradeIndustry.S()["contracts"].has(d["id"]):add_button(content,"Negotiate three repeat shipments","TradeRepeatSign_"+d["id"],TradeIndustry.sign_repeat.bind(d["id"]))
		if d["quote"]["payment"]!="tt_prepaid" and not d.get("procurement",false) and d["status"] in ["booked","delayed","customs_hold","in_transit","awaiting_bank","receivable"] and GlobalMarket.company()["bank"] and FXForward.exposure(TradeIndustry.entity(),d["quote"]["buyer_currency"],30)>=1:
			var hedge: Dictionary=FXForward.quote(d["quote"]["buyer_currency"],minf(float(d["quote"]["buyer_quote"]),FXForward.exposure(TradeIndustry.entity(),d["quote"]["buyer_currency"],30)),30)
			if hedge["ok"]:
				content.add_child(UIK.kv("Forward fee / refundable collateral",Fmt.money(float(hedge["fee"]))+" / "+Fmt.money(float(hedge["collateral"]))))
				add_button(content,"Hedge contracted receipts for 30 days","TradeHedge_"+d["id"],TradeIndustry.hedge_receipt.bind(d["id"]))
			else:content.add_child(UIK.wrap("✗ "+str(hedge["error"]),8,Art.C_SKY,560))
		if d["status"]=="delayed":
			add_button(content,"Wait three days for the port","TradeWait_"+d["id"],TradeIndustry.resolve_delay.bind(d["id"],false),true)
			add_button(content,"Pay to reroute cargo by air","TradeAir_"+d["id"],TradeIndustry.resolve_delay.bind(d["id"],true))
			add_button(content,"Return cargo to supplier at a loss","WithdrawTrade_"+d["id"],TradeIndustry.withdraw.bind(d["id"]))
		if d["status"] in ["booked","customs_hold"]:
			for key in d["documents"]:
				var present: bool=d["documents"][key]
				var label: String={"invoice":"Commercial invoice","packing_list":"Packing list","bill_of_lading":"Bill of lading"}[key]
				add_button(content,("✓ " if present else "✗ ")+I18n.t(label),"TradeDoc_"+d["id"]+"_"+key,TradeIndustry.set_document.bind(d["id"],key,not present),not present)
		if d["status"]=="customs_hold":
			content.add_child(UIK.wrap("✗ "+I18n.t(TradeIndustry.document_block(d)),8,Art.C_SKY,560))
			add_button(content,"Correct documents and clear cargo","ClearTrade_"+d["id"],TradeIndustry.clear.bind(d["id"]),true)
			add_button(content,"Return cargo to supplier at a loss","WithdrawTrade_"+d["id"],TradeIndustry.withdraw.bind(d["id"]))
		if d["quote"]["payment"]=="lc" and d["lc"]=="issued" and d["status"] in ["booked","in_transit","awaiting_bank"]:add_button(content,"Submit documents to the issuing bank","TradeBank_"+d["id"],TradeIndustry.bank_documents.bind(d["id"]),true)
	var b:=UIK.button("Compare trade route",func():UIRoot.open_modal(TradeQuoteModal.new("northridge")),"primary" if not primary_chosen else "")
	b.name="TradeCompare";footer.add_child(b)

static func status_text(status: String) -> String:
	match status:
		"booked":return I18n.t("Cargo booked")
		"delayed":return I18n.t("Port temporarily closed")
		"received":return I18n.t("Cargo received into warehouse")
		"customs_hold":return I18n.t("Cargo held at customs")
		"in_transit":return I18n.t("Cargo in transit")
		"awaiting_bank":return I18n.t("Bank documents required")
		"receivable":return I18n.t("Buyer payment pending")
		"paid":return I18n.t("Trade paid")
		"defaulted":return I18n.t("Buyer defaulted")
		"lost":return I18n.t("Cargo lost")
		"withdrawn":return I18n.t("Cargo returned")
		"unpaid_documents":return I18n.t("Unpaid documents expired")
	return I18n.t("Trade closed")

func _documents(id: String) -> Dictionary:
	var deal: Dictionary = TradeIndustry.S()["deals"].get(id,{})
	if deal.is_empty():return {"ok":false}
	for key in deal["documents"]:TradeIndustry.set_document(id,str(key),true)
	return TradeIndustry.set_code(id,str(TradeQuote.cfg()["goods"][deal["quote"]["product"]]["tariff_code"]))
