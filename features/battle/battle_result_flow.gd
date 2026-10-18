class_name BattleResultFlow
extends RefCounted
signal banner_requested(ticket: int, encounter_id: String)
signal return_requested(ticket: int, encounter_id: String)
enum Stage { NONE, HOLD, BANNER, RETURNING, SAVE_BLOCKED }
const HOLD_SECONDS: float = 2.0
const BANNER_SECONDS: float = 3.0
var ticket: int = 0
var encounter_id: String = ""
var stage: Stage = Stage.NONE
var elapsed: float = 0
func cancel() -> void:
	ticket+=1
	stage = Stage.NONE
	elapsed = 0
	encounter_id = ""
func begin(id: String, saved: bool = true, hold_completed: bool = false) -> void:
	cancel()
	encounter_id = id
	stage = Stage.HOLD if saved else Stage.SAVE_BLOCKED
	if saved and hold_completed:
		stage = Stage.BANNER
		banner_requested.emit(ticket,encounter_id)
func tick(delta: float) -> void:
	if stage not in [Stage.HOLD,Stage.BANNER]: return
	elapsed+=maxf(0,delta)
	if stage==Stage.HOLD and elapsed>=HOLD_SECONDS:
		stage = Stage.BANNER
		elapsed = 0 # grant three visible seconds even after a long stalled frame
		banner_requested.emit(ticket,encounter_id)
	elif stage==Stage.BANNER and elapsed>=BANNER_SECONDS:
		request_return()
func seconds_left() -> int:
	return ceili(maxf(0,BANNER_SECONDS-elapsed)) if stage==Stage.BANNER else 0
func request_return() -> bool:
	if stage!=Stage.BANNER: return false
	stage = Stage.RETURNING # latch synchronously before queued callbacks or another click
	return_requested.emit(ticket,encounter_id)
	return true
