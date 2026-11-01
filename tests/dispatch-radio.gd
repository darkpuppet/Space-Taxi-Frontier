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
        check(bank.size() == 6, "Every dispatcher voice has six different pickup phrases")
        for phrase in bank:
            check(phrase.size() == 5, "Every phrase covers all five pickup pads")
            for clip in phrase:
                check(clip.get_length() > 2.5 and clip.get_length() < 5.2, "Pickup wording stays concise at the faster speech rate")
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
    for voice in range(3):
        radio.begin_level(500 + voice)
        radio.voice_index = voice
        radio.announce_gate()
        radio._process(0.2)
        check(radio.player.stream == radio.GATE_CLIPS[voice], "Each dispatcher has a matching stargate call")
        check(radio.player.stream.get_length() > 3 and radio.player.stream.get_length() < 6, "Gate announcement remains brief")
        radio.sync_fares([{"id": 777, "source": 3}])
        check(radio.player.playing and radio.pending.is_empty(), "Fare refresh cannot interrupt the stargate call")
        radio.announce_gate()
        check(radio.pending.is_empty(), "Repeated gate notification never queues duplicate speech")
    radio.begin_level(600)
    radio.announce_gate(true)
    check(radio.gate_announced and not radio.player.playing and radio.pending.is_empty(), "Muted gate opening does not play or queue speech")
    radio.announce_gate(false)
    check(radio.pending.is_empty(), "Unmuting does not replay a missed stargate announcement")
    for variant in range(6):
        radio.begin_level(700 + variant)
        var dispatcher_voice: int = radio.voice_index
        var alien: bool = variant in [1, 3, 4, 5]
        for pad in range(1, 6):
            var id: int = 2000 + variant * 10 + pad
            radio.announce_destination(id, pad, variant)
            var customer_voice: int = int(radio.pending[0]["voice"])
            check((customer_voice == radio.ROBOT_CUSTOMER_VOICE) == (variant == 5), "Only robot couriers use the dedicated synthetic robot voice")
            check((customer_voice >= 6) == alien, "Selected customer voice matches the passenger species")
            radio._process(0.2)
            check(radio.player.stream == radio.DESTINATION_CLIPS[customer_voice][pad - 1], "Customer voice and spoken platform match the passenger and fare")
            check(radio.player.stream.get_length() > 1 and radio.player.stream.get_length() < 4, "Customer destination requests stay short")
            radio.sync_fares([])
            check(radio.player.playing and radio.voice_index == dispatcher_voice, "Fare refresh preserves onboard speech and the level dispatcher")
            radio.announce_destination(id, pad, variant)
            check(radio.pending.is_empty(), "A boarding customer requests their destination only once")
            radio.silence()
    check(radio.DESTINATION_CLIPS.size() == 13, "Six human, six alien, and one dedicated robot voice are bundled")
    for bank in radio.DESTINATION_CLIPS:
        check(bank.size() == 5, "Every customer voice covers all five destinations")
        for clip in bank:
            check(clip.get_length() > 0.5 and clip.get_length() < 4, "Every customer recording is brief and nonempty")
    radio.customer_rng.seed = 72917
    radio.customer_bags.clear()
    radio.last_customer_voice.clear()
    for alien in [false, true]:
        var previous: int = -1
        for cycle in range(3):
            var heard: Dictionary = {}
            for sample in range(6):
                var chosen: int = radio._choose_customer_voice(alien)
                check((chosen >= 6) == alien, "Voice shuffle stays within the passenger species")
                check(chosen != previous, "Customer voices avoid immediate repeats, including across shuffles")
                heard[chosen] = true
                previous = chosen
            check(heard.size() == 6, "Each customer shuffle uses all six voices")
    radio.begin_level(800)
    radio.sync_fares([{"id": 100, "source": 3}, {"id": 101, "source": 4}])
    radio._process(0.5)
    var interrupted_phrase: int = radio.current_phrase
    radio.announce_destination(101, 5, 2)
    var boarded_voice: int = int(radio.pending[0]["voice"])
    check(radio.pending.size() == 2 and radio.pending[0].get("kind", "") == "destination", "Onboard customer takes priority while retaining another pickup call")
    radio._process(0.2)
    radio.sync_fares([{"id": 100, "source": 3}])
    check(radio.player.stream == radio.DESTINATION_CLIPS[boarded_voice][4], "Actual destination speech survives removal of the boarded fare from waiting")
    radio.player.stop()
    radio._finished()
    radio._process(0.5)
    check(radio.current_id == 100 and radio.current_phrase == interrupted_phrase, "Interrupted pickup resumes with the same wording after the passenger request")
    radio.begin_level(801)
    radio.announce_destination(501, 3, 0, true)
    radio.announce_destination(501, 3, 0)
    check(radio.pending.is_empty(), "Muted customer requests do not replay on unmute")
    for voice in range(3):
        radio.begin_level(900 + voice)
        radio.voice_index = voice
        radio.phrase_rng.seed = 763 + voice
        var previous_phrase: int = -1
        for cycle in range(2):
            var heard: Dictionary = {}
            for sample in range(6):
                var id: int = 4000 + voice * 100 + cycle * 10 + sample
                var pad: int = sample % 5 + 1
                var waiting: Array = [{"id": id, "source": pad}]
                radio.sync_fares(waiting)
                var chosen_phrase: int = int(radio.pending[0]["phrase"])
                radio.sync_fares(waiting)
                check(radio.pending.size() == 1 and int(radio.pending[0]["phrase"]) == chosen_phrase, "Repeated fare updates keep the chosen wording")
                radio._process(0.5)
                check(radio.voice_index == voice and radio.player.stream == radio.CLIPS[voice][chosen_phrase][pad - 1], "Random phrase retains the level voice and correct spoken pad")
                check(chosen_phrase != previous_phrase, "Pickup phrases never repeat immediately")
                heard[chosen_phrase] = true
                previous_phrase = chosen_phrase
                radio.sync_fares([])
            check(heard.size() == 6, "Every shuffled set uses all six pickup phrases for each voice")
    transmissions.clear()
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
    check(radio.player.stream == radio.CLIPS[level_voice][radio.current_phrase][int(fare["source"]) - 1], "Pad number selects the matching spoken clip")
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
    check(radio.player.stream == radio.CLIPS[level_voice][radio.current_phrase][transmissions[-1].y - 1], "First call uses the level dispatcher")
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
    check(radio.voice_index == level_voice and radio.player.stream == radio.CLIPS[level_voice][radio.current_phrase][transmissions[-1].y - 1], "Concurrent pickups share the same level voice")
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
    game.taxi.set_physics_process(false)
    game.sector.set_physics_process(false)
    level_voice = radio.voice_index
    radio._process(0.5)
    check(radio.player.playing, "Pickup call is active before the gate priority test")
    game.credits = int(game.sector_data["required_balance"])
    game.fares_in_level = 3
    game.mission_done = true
    game._open_star_gate()
    check(game.gate_active and radio.gate_announced and not radio.player.playing, "Opening the real stargate interrupts stale pickup speech")
    check(radio.pending.size() == 1 and radio.pending[0].get("kind", "") == "gate", "Real gate opening queues its announcement")
    radio._process(0.2)
    check(radio.player.stream == radio.GATE_CLIPS[level_voice] and radio.voice_index == level_voice, "Gate opening uses the level's existing dispatcher voice")
    radio.set_process(true)
    game._show_pause()
    check(not radio.can_process() and radio.player.stream == radio.GATE_CLIPS[level_voice], "Pause freezes gate transmission without losing the selected clip")
    game._resume()
    radio.set_process(false)
    game.audio.toggle_mute()
    check(not radio.player.playing and radio.pending.is_empty(), "Mute immediately stops the stargate announcement")
    game.audio.toggle_mute()
    radio.announce_gate()
    check(radio.pending.is_empty(), "Completed or muted gate calls never repeat")
    game._new_game()
    check(not radio.gate_announced and radio.pending.size() == 1, "New game resets the gate call and resumes pickup dispatch")
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
