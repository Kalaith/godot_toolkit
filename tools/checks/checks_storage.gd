extends RefCounted
## Saves: staged writes, backups, recovery, corrupt preservation, migration
## and multi-file slots.
const JsonSave = preload("res://addons/hatchery/storage/json_save.gd")
const SlotStore = preload("res://addons/hatchery/storage/slot_store.gd")
const AtomicFile = preload("res://addons/hatchery/storage/atomic_file.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func _store(name: String, version: int = 2) -> JsonSave:
	return JsonSave.new(Expect.scratch_path(name), version, func(data: Dictionary) -> bool: return data.get("coins") is float or data.get("coins") is int)


func _scribble(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func check_save_round_trip_keeps_backup():
	var store: JsonSave = _store("round_trip.json")
	var fresh: Dictionary = store.load_data()
	var first: bool = store.save_data({"schema": 2, "coins": 1})
	var second: bool = store.save_data({"schema": 2, "coins": 2})
	var loaded: Dictionary = store.load_data()
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.path + ".bak"))
	return Expect.all([
		Expect.truthy(fresh.is_empty() and store.last_error.is_empty(), "a first run starts fresh quietly"),
		Expect.truthy(first and second, "saves succeed: " + store.last_error),
		Expect.equal(loaded.get("coins"), 2, "the latest save loads"),
		Expect.equal(backup.get("coins"), 1, "the previous save is the backup"),
		Expect.falsy(FileAccess.file_exists(store.path + ".tmp"), "no staging file is left behind"),
		Expect.falsy(store.save_data({"schema": 2}), "invalid data is refused"),
	])


func check_damaged_save_recovers_and_is_preserved():
	var store: JsonSave = _store("damaged.json")
	store.save_data({"schema": 2, "coins": 5})
	store.save_data({"schema": 2, "coins": 6})
	_scribble(store.path, "{broken")
	var loaded: Dictionary = store.load_data()
	var recovered: bool = store.recovered and not store.last_error.is_empty()
	var saved: bool = store.save_data({"schema": 2, "coins": 7})
	return Expect.all([
		Expect.equal(loaded.get("coins"), 5, "the backup is recovered"),
		Expect.truthy(recovered, "recovery is reported"),
		Expect.truthy(saved, "saving continues after recovery: " + store.last_error),
		Expect.equal(FileAccess.get_file_as_string(store.path + ".corrupt"), "{broken", "the damaged file is kept as .corrupt"),
	])


func check_existing_corrupt_copy_is_never_replaced():
	var store: JsonSave = _store("twice.json")
	store.save_data({"schema": 2, "coins": 1})
	_scribble(store.path + ".corrupt", "older damage")
	_scribble(store.path, "{new damage")
	store.load_data()
	var saved: bool = store.save_data({"schema": 2, "coins": 2})
	return Expect.all([
		Expect.falsy(saved, "saving stops rather than overwrite .corrupt"),
		Expect.equal(FileAccess.get_file_as_string(store.path + ".corrupt"), "older damage", "the old .corrupt survives"),
		Expect.equal(FileAccess.get_file_as_string(store.path), "{new damage", "the new damage survives"),
	])


func check_newer_version_blocks_writes():
	var store: JsonSave = _store("future.json")
	_scribble(store.path, JSON.stringify({"schema": 9, "coins": 1}))
	var loaded: Dictionary = store.load_data()
	return Expect.all([
		Expect.truthy(loaded.is_empty() and store.writes_blocked, "a future file blocks writes"),
		Expect.falsy(store.save_data({"schema": 2, "coins": 3}), "and is not overwritten"),
	])


func check_migration_brings_old_saves_up():
	var store: JsonSave = _store("migrate.json")
	store.migrate = func(data: Dictionary) -> Dictionary:
		data["coins"] = int(data.get("gold", 0))
		data["schema"] = 2
		return data
	_scribble(store.path, JSON.stringify({"schema": 1, "gold": 40}))
	var loaded: Dictionary = store.load_data()
	return Expect.equal(loaded.get("coins"), 40, "schema 1 migrated")


func check_block_on_damage_policy():
	var store: JsonSave = _store("settings_like.json")
	store.block_on_damage = true
	_scribble(store.path, "garbage")
	store.load_data()
	return Expect.all([
		Expect.truthy(store.writes_blocked, "damage with no backup blocks writes"),
		Expect.equal(FileAccess.get_file_as_string(store.path), "garbage", "the file is untouched"),
	])


func check_keep_previous_before_reset():
	var store: JsonSave = _store("previous.json")
	store.save_data({"schema": 2, "coins": 9})
	var kept: bool = store.keep_previous()
	store.save_data({"schema": 2, "coins": 0})
	store.save_data({"schema": 2, "coins": 1})
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.path + ".previous"))
	return Expect.all([Expect.truthy(kept, "copy made"), Expect.equal(previous.get("coins"), 9, ".previous outlives rotation")])


func check_slot_store_writes_reads_and_recovers():
	var root: String = "user://checks/worlds/"
	var worlds := SlotStore.new(root, ["meta.json", "sim.bin"])
	worlds.delete("valley")
	var accept := func(_name: String, bytes: PackedByteArray) -> bool: return bytes.size() > 0 and bytes[0] != 0
	var wrote: bool = worlds.write("valley", {"meta.json": "{}".to_utf8_buffer(), "sim.bin": PackedByteArray([1, 2])})
	worlds.write("valley", {"meta.json": "{}".to_utf8_buffer(), "sim.bin": PackedByteArray([3, 4])})
	var file := FileAccess.open(worlds.folder("valley") + "sim.bin", FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0]))
	file.close()
	var read: Dictionary = worlds.read("valley", accept)
	return Expect.all([
		Expect.truthy(wrote and worlds.exists("valley"), "slot written"),
		Expect.contains(worlds.slots(), "valley", "slot listed"),
		Expect.equal(read.get("sim.bin"), PackedByteArray([1, 2]), "a damaged file falls back to its backup"),
		Expect.truthy(FileAccess.file_exists(worlds.folder("valley") + "sim.bin.corrupt"), "the damaged file is preserved"),
	])


func check_slot_store_optional_files():
	var worlds := SlotStore.new("user://checks/worlds/", ["meta.json"])
	worlds.optional = ["regions.bin"]
	worlds.delete("old")
	worlds.delete("new")
	var accept := func(_name: String, bytes: PackedByteArray) -> bool: return bytes.size() > 0 and bytes[0] != 0
	worlds.write("old", {"meta.json": "{}".to_utf8_buffer()})
	worlds.write("new", {"meta.json": "{}".to_utf8_buffer(), "regions.bin": PackedByteArray([5])})
	var old: Dictionary = worlds.read("old", accept)
	var new: Dictionary = worlds.read("new", accept)
	var file := FileAccess.open(worlds.folder("new") + "regions.bin", FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0]))
	file.close()
	DirAccess.remove_absolute(worlds.folder("new") + "regions.bin.bak")
	var damaged: Dictionary = worlds.read("new", accept)
	worlds.delete("old")
	worlds.delete("new")
	return Expect.all([
		Expect.truthy(old.has("meta.json") and not old.has("regions.bin"), "an older save without the file still reads"),
		Expect.equal(new.get("regions.bin"), PackedByteArray([5]), "a present optional file is read"),
		Expect.truthy(damaged.is_empty(), "a damaged optional file fails the read"),
	])


func check_atomic_write_reads_back():
	var path: String = Expect.scratch_path("atomic.bin")
	var error: String = AtomicFile.write(path, PackedByteArray([7, 8, 9]))
	var found: Dictionary = AtomicFile.read_with_backup(path, func(bytes: PackedByteArray) -> bool: return bytes.size() == 3)
	return Expect.all([Expect.equal(error, "", "write"), Expect.falsy(found.from_backup, "read the main file")])
