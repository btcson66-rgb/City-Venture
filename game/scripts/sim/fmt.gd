class_name Fmt
extends RefCounted
## Formatting helpers (money, time) shared by UI and sim text.


static func money(v: float, show_plus := false) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var cents := int(round(a * 100.0))
	var whole := cents / 100
	var frac := cents % 100
	var s := _group(whole) + "." + ("%02d" % frac)
	if neg:
		return "-$" + s
	return ("+$" if show_plus else "$") + s


static func money0(v: float, show_plus := false) -> String:
	var neg := v < 0.0
	var s := _group(int(round(absf(v))))
	if neg:
		return "-$" + s
	return ("+$" if show_plus else "$") + s


static func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


static func pct(v: float, digits := 0) -> String:
	if digits == 0:
		return "%d%%" % int(round(v * 100.0))
	return ("%." + str(digits) + "f%%") % (v * 100.0)


static func duration_min(m: int) -> String:
	if m < 60:
		return I18n.t("%d min") % m
	if m % 60 == 0:
		return I18n.t("%d h") % (m / 60)
	return I18n.t("%d h %d min") % [m / 60, m % 60]


static func stars(v: float) -> String:
	if v <= 0.0:
		return I18n.t("no reviews")
	return "%.1f★" % v
