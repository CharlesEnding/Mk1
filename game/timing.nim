import std/[math, times]

type
  Tick* = float
  TickInterval* = float
  OnTick* = proc (numTicks: int) {.closure.}
  Timing* = ref object
    lastTick*: Tick
    tickInterval*: TickInterval
    hooks*: seq[OnTick]

proc newTiming*(tickInterval: TickInterval = 1.0/100): Timing =
  result = new Timing
  result.lastTick = epochTime()
  result.tickInterval = tickInterval

proc frameTick*(timing: Timing) =
  var
    interval = epochTime() - timing.lastTick
    numTicks = floor(interval / timing.tickInterval).int
  if numTicks >= 1:
    for hook in timing.hooks:
      hook(numTicks)
    timing.lastTick = epochTime()

proc register*(timing: Timing, hook: OnTick) =
  timing.hooks.add(hook)
