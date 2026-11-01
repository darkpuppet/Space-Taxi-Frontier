extends SceneTree
var failures: int = 0
var checks: int = 0
var transmissions: Array[Vector2i] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("FAIL: " + description)

func _run() -> void:
    var game: Node = load("res://Main.tscn").instantiate()
    game.save_file = "user://frontier_radio_test.cfg"
    root.add_child(game)
    await process_frame
    var radio: Node = game.audio.radio
    radio.set_process(false)
    radio.transmission_started.connect(func(id: int, pad: int) -> void: transmissions.append(Vector2i(id, pad)))
    check(radio.pending.is_empty() and not radio.player.playing, "Main menu has no dispatch announcements")
    check(radio.CLIPS.size() == 3, "Male, female and robot dispatchers are available")
    for bank in radio.CLIPS:
        check(bank.size() == 5, "Every voice covers all five pickup pads")
        for clip in bank:
            check(clip.get_length() > 3 and clip.get_length() < 4.4, "Faster pickup calls last about four seconds")
            check(clip is AudioStreamWAV and clip.mix_rate == 22050 and not clip.stereo, "Offline radio clips are mono PCM")
    radio.voice_rng.seed = 67291
    var selected: Dictionary = {}
    for index in range(60):
        radio.begin_level(100 + index)
        var chosen: int = radio.voice_index
        selected[chosen] = true
        radio.begin_level(100 + index)
        check(radio.voice_index == chosen, "Retrying a level preserves its dispatcher voice")
    check(selected.size() == 3, "Seeded random level selections exercise all three voices")
    game._new_game()
    game.set_process(false)
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    var level_voice: int = radio.voice_index
    var fare: Dictionary = game.dispatcher.waiting[0]
    check(radio.pending.size() == 1 and int(radio.pending[0]["pad"]) == int(fare["source"]), "New game queues the actual pickup location")
    for frame in range(30):
        game._sync_dispatch()
    check(radio.pending.size() == 1, "Repeated UI updates do not repeat a fare announcement")
    radio._process(0.5)
    check(transmissions.size() == 1 and transmissions[0] == Vector2i(fare["id"], fare["source"]), "Transmission announces the correct fare and platform")
    check(radio.player.stream == radio.CLIPS[level_voice][int(fare["source"]) - 1], "Pad number selects the matching spoken clip")
    game.audio._process(0.3)
    check(game.audio.music.volume_db < -30, "Music ducks for intelligible radio speech")
    radio.set_process(true)
    game._show_pause()
    check(not radio.can_process() and radio.current_id == int(fare["id"]), "Pause preserves the current transmission and freezes the queue")
    game._resume()
    radio.set_process(false)
    check(radio.current_id == int(fare["id"]) and radio.pending.is_empty() and radio.voice_index == level_voice, "Resume preserves the voice and does not repeat the pickup call")
    game.level = 2
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(radio.pending.size() == 2 and radio.current_id == -1, "New level resets old speech and queues both waiting fares")
    radio._process(0.5)
    level_voice = radio.voice_index
    check(radio.player.stream == radio.CLIPS[level_voice][transmissions[-1].y - 1], "First call uses the level dispatcher")
    var first: int = radio.current_id
    var sent: int = transmissions.size()
    radio._process(20)
    check(radio.current_id == first and transmissions.size() == sent and radio.pending.size() == 1, "Concurrent fares never overlap their transmissions")
    radio.player.stop()
    radio._finished()
    radio._process(0.2)
    check(radio.current_id == -1, "A squelch gap separates transmissions")
    radio._process(0.3)
    check(radio.current_id != -1 and radio.current_id != first and radio.pending.is_empty(), "Second waiting fare is announced in turn")
    check(radio.voice_index == level_voice and radio.player.stream == radio.CLIPS[level_voice][transmissions[-1].y - 1], "Concurrent pickups share the same level voice")
    game._start_level()
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    check(radio.voice_index == level_voice, "Actual level retry retains its dispatcher")
    radio.sync_fares([])
    check(not radio.player.playing and radio.pending.is_empty(), "Boarded or departed fares cancel stale speech")
    var replacement: Array[Dictionary] = [{"id": 999, "source": 4}]
    radio.sync_fares(replacement)
    check(radio.pending.size() == 1 and radio.voice_index == level_voice, "Replacement customer keeps the level dispatcher")
    game.audio.toggle_mute()
    check(radio.pending.is_empty() and not radio.player.playing, "Mute stops speech immediately")
    radio.sync_fares([{"id": 1000, "source": 5}], true)
    game.audio.toggle_mute()
    radio.sync_fares([{"id": 1000, "source": 5}])
    check(radio.pending.is_empty(), "Unmuting does not replay old calls")
    game._return_to_menu()
    check(radio.pending.is_empty() and radio.announced.is_empty() and not radio.player.playing, "Returning to menu clears dispatch speech")
    game._new_game()
    check(radio.pending.size() == 1 and radio.level_index == 0 and radio.voice_index >= 0, "New game chooses a Level 1 dispatcher and announces its customer")
    game.audio.shutdown()
    check(radio.player.stream == null and not radio.player.playing, "Shutdown releases radio audio")
    await create_timer(0.5).timeout
    var test_save: String = game.save_file
    game.free()
    await create_timer(0.2).timeout
    if FileAccess.file_exists(test_save):
        DirAccess.remove_absolute(test_save)
    print("CB dispatch radio: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
