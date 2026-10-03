extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := "user://economy"
	var months := 18
	var seeds := [101, 202, 303]
	var policies := ["cautious", "aggressive", "casual"]
	var baseline := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--baseline": baseline = true
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--months="): months = int(arg.substr(9))
		if arg.begins_with("--seed="): seeds = [int(arg.substr(7))]
		if arg.begins_with("--policy="): policies = [arg.substr(9)]
	DirAccess.make_dir_recursive_absolute(out)
	if baseline:
		for id in DataDB.economy.get("balance", {}).get("definitions", {}).get("products", {}):
			DataDB.products[id] = DataDB._read("res://data/products/" + id + ".json")
		for method in DataDB.shipping()["methods"]:
			method["cost"] = DataDB.economy["balance"]["baseline_shipping_costs"][method["id"]].duplicate()
	for seed_value in seeds:
		for policy in policies:
			var result := EconomySim.new().run(policy, seed_value, months)
			var stem := out + "/%s_%d" % [policy, seed_value]
			var json := FileAccess.open(stem + ".json", FileAccess.WRITE)
			json.store_string(JSON.stringify(result, "  "))
			json.close()
			var csv := FileAccess.open(stem + ".csv", FileAccess.WRITE)
			csv.store_csv_line(["month", "revenue", "gross_profit", "opex", "net_profit", "cash", "chapter"])
			for row in result["months"]:
				csv.store_csv_line([row["month"], str(row["revenue"]), str(row["gross_profit"]), str(row["opex"]), str(row["net_profit"]), str(row["cash"]), row["chapter"]])
			csv.close()
			await get_tree().process_frame
	get_tree().quit()
