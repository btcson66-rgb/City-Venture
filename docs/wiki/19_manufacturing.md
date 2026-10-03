# Manufacturing and Industrial

Implemented: `manufacturing` at `industrial`. M3 connects Harbor to Industrial in six minutes. The district includes ground, two freight lanes (van fallback), pedestrian paths and a metro spawn; the city map now allows travel.

Locations: `unit12_factory` (Unit 12 Light Industrial, monthly rent $3,800 and two-month deposit), `ferro_supply` (Rita Hale, `rita_hale`), `kessler_precision` (OEM procurement Lena Park, `lena_park`), and `shift_diner` (hireable Tomas Varga, `tomas_varga`). Their introductory conversations open Line Planner. Employee role `technician` works at Unit 12; Staff owns hiring, weekly $1,100 payroll, morale and dismissal.

Line Planner is available at factory and supplier terminals and Company OS → Manufacturing. Open the factory after registering and opening a bank account, rent or buy a machine, register as an employer, and hire Tomas. Quote an RFQ; prices over the client maximum lose to Kessler, while a low bid can be below cost. Jobs receives a 30% deposit, tracks units completed, invoices after delivery, collects on Net 30 and applies late penalties.

Ferro material POs have MOQ 200, two-day lead time, 12,000-unit shared material capacity including outstanding orders, weekly price movement and physical quality lots. Costs move cash → inventory in transit → inventory → COGS. Receiving the same PO twice does nothing.

Allocate hourly slots within seven days. The machine cannot overlap another slot or its one-hour changeover. Normal hours are weekdays 09:00–17:00; overtime pays 1.5 times the hourly wage and reduces yield by two percentage points. Outsourcing to Kessler costs $2.80/unit, consumes its own capacity and settles a traceable order rather than creating daily income. Inspection ratios 0/25/50/75/100% trade production speed against paid rework and escaped defects. Wear × technician skill × material quality determines defects. Excess customer defects cause refunds, penalties and a credit reduction. Refunds reduce unpaid AR first and cannot exceed the original invoice.

Three growth stages: one rented/purchased machine plus technician; CNC automation (2.5× capacity and reduced staffing need, requires an actual active business loan); own brand (automation plus paid mould). Brand production reserves machine time, waits on repairs/materials and creates phone-stand stock at Unit 12 for ecommerce. Target unit cost is 55% of wholesale before adverse material prices; it can exceed target rather than creating free inventory value.

Crisis events: `manufacturing_shortage` postpones existing material POs and raises prices; `manufacturing_cancel` returns the unused deposit, retaining only documented incurred cost; `manufacturing_recall` refunds part of one shipped batch, adds penalties and lowers credit. Both journal and physical/scheduled state persist in saves. Closing the company cancels manufacturing arrivals/production, liquidates raw and in-transit material once at the core recovery rate; core closure sells ecommerce finished stock, resolves Jobs and Assets, then pays creditors. Delayed brand batches continue reserving their machine until completion or closure.

Art uses the standard fallback builder until named facades arrive. See [art backlog](90_codex_art_backlog.md). All tuning is in `economy/manufacturing.json`; no daily income is granted.
