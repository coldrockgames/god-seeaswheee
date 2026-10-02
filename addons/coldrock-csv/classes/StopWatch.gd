## Short utility class to measure time.[br]
## Starts automatically when constructed, but offers a [method restart] method to reset.[br]
## Use the [method millis] or [method micros] methods to get the elapsed time since start.[br]
## If you want to immediately also write the time to the log, use [method checkpoint].[br]
## It also returns the time (in microseconds), it just creates the log in addition for you.[br]
## (The [member name] you set in the constructor is part of the log line).
class_name StopWatch
extends RefCounted

## The name of this stopwatch used for logging.
var name:String

var _tstart:int
var _created:int


## Initializes the stopwatch and starts the timer.
func _init(watch_name:String = "StopWatch", log_start:bool = false) -> void:
	name = watch_name
	_tstart = Time.get_ticks_usec()
	_created = _tstart
	if log_start:
		print(watch_name, " started.")


## Restarts the stopwatch timer.[br]
## Returns the [StopWatch] instance for chaining.
func restart() -> StopWatch:
	_tstart = Time.get_ticks_usec()
	return self


## Get the total elapsed seconds since the watch has been started.
func seconds() -> float:
	var rv:float = (Time.get_ticks_usec() - _tstart) / 1000000.0
	return rv


## Get the total elapsed milliseconds since the watch has been started.
func millis() -> float:
	var rv:float = (Time.get_ticks_usec() - _tstart) / 1000.0
	return rv


## Get the total elapsed microseconds since the watch has been started.
func micros() -> int:
	var rv:int = Time.get_ticks_usec() - _tstart
	return rv


## Returns the elapsed time since this instance has been created.[br]
## This value is not affected by restarts or other operations.[br]
## If [param as_string] is true, the value is formatted (e.g., "146µs" or "35.62ms").[br]
## If [param as_string] is false, the total time in microseconds is returned as an int.
func total(as_string:bool = true) -> Variant:
	var rv:Variant
	var elapsed_micros:int = Time.get_ticks_usec() - _created
	if not as_string:
		rv = elapsed_micros
		return rv
	var logtime:float = float(elapsed_micros)
	var unit:String = "µs"
	if elapsed_micros > 1000:
		unit = "ms"
		logtime = elapsed_micros / 1000.0
	rv = str(logtime) + unit
	return rv


## Prints a checkpoint to the log.[br]
## The elapsed time is printed in microseconds while the value is less than 1000, then it is converted to milliseconds.[br]
## This function always returns the elapsed microseconds [i]since the last checkpoint[/i].
func checkpoint(action:String = "checkpoint reached after", restart_after:bool = true, decimals:int = 1) -> int:
	var rv:int = Time.get_ticks_usec() - _tstart
	var logtime:float = float(rv)
	var unit:String = "µs"
	if rv > 1000:
		unit = "ms"
		logtime = rv / 1000.0
	var dec_mask = "%." + str(decimals) + "f"
	print(name, " ", action, " ", dec_mask%logtime, unit)
	if restart_after:
		restart()
	return rv


## Prints a final [method checkpoint] to the log without restarting the StopWatch.
func finish(action:String = "finished in") -> int:
	return checkpoint(action, false)
