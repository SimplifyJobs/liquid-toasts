import Foundation

/// Owns all auto-dismiss timing for the toast stack: wall-clock deadlines
/// (so backgrounding can't corrupt them), the `Task`s that fire them, and the
/// banked remaining time for toasts paused mid-interaction.
///
/// Deliberately knows nothing about the stack itself — the manager guards
/// existence and reacts to `onExpire`. Also deliberately Flutter-free, so it
/// could be unit-tested from a Flutter-free subtarget later.
@MainActor
final class DeadlineScheduler {
  /// Fired when a deadline expires. `reason` is `.timeout` (timer fired live)
  /// or `.appBackgrounded` (found past-due while foregrounding).
  var onExpire: ((_ id: String, _ reason: ToastDismissReason) -> Void)?

  /// Wall-clock deadlines. Survive backgrounding; the tasks that watch them
  /// are cancelled in the background and rebuilt on foreground.
  private var deadlines: [String: Date] = [:]
  private var tasks: [String: Task<Void, Never>] = [:]
  /// Banked remaining time for toasts paused mid-interaction (touch-down).
  private var pausedRemaining: [String: TimeInterval] = [:]
  private var backgrounded = false

  /// Arms (or re-arms) the auto-dismiss for [id]. `nil` disarms. A fresh arm
  /// supersedes any banked pause.
  func arm(id: String, duration: TimeInterval?) {
    cancelTask(id)
    pausedRemaining[id] = nil
    guard let duration else {
      deadlines[id] = nil
      return
    }
    let deadline = Date().addingTimeInterval(duration)
    deadlines[id] = deadline
    if !backgrounded { schedule(id: id, fireAt: deadline) }
  }

  /// Cancels everything known about [id] (teardown, async-action spinner).
  func disarm(id: String) {
    cancelTask(id)
    deadlines[id] = nil
    pausedRemaining[id] = nil
  }

  /// Pauses [id]'s auto-dismiss while the user is touching it: banks the
  /// remaining time and clears the wall-clock deadline so neither the timer
  /// nor a background/foreground cycle can fire mid-interaction. No-op when
  /// there is no live deadline (persistent / loading toasts).
  func pause(id: String) {
    guard let deadline = deadlines[id] else { return }
    let remaining = deadline.timeIntervalSinceNow
    guard remaining > 0 else { return }
    pausedRemaining[id] = remaining
    cancelTask(id)
    deadlines[id] = nil
  }

  /// Resumes a paused [id] with its banked remaining time. No-op if it was
  /// never paused.
  func resume(id: String) {
    guard let remaining = pausedRemaining.removeValue(forKey: id) else { return }
    let deadline = Date().addingTimeInterval(remaining)
    deadlines[id] = deadline
    if !backgrounded { schedule(id: id, fireAt: deadline) }
  }

  /// Hot restart / flush: drop all timing state.
  func removeAll() {
    for task in tasks.values { task.cancel() }
    tasks.removeAll()
    deadlines.removeAll()
    pausedRemaining.removeAll()
  }

  // MARK: - App lifecycle

  /// Cancels the watcher tasks but keeps the wall-clock deadlines — they are
  /// re-evaluated against real time on foreground.
  func appDidEnterBackground() {
    backgrounded = true
    for task in tasks.values { task.cancel() }
    tasks.removeAll()
  }

  /// Sweeps the stored deadlines: past-due ones expire immediately (reason
  /// `.appBackgrounded`), live ones get fresh watcher tasks.
  func appWillEnterForeground() {
    backgrounded = false
    let now = Date()
    for (id, deadline) in deadlines {
      if deadline <= now {
        deadlines[id] = nil
        onExpire?(id, .appBackgrounded)
      } else {
        schedule(id: id, fireAt: deadline)
      }
    }
  }

  // MARK: - Internals

  private func schedule(id: String, fireAt: Date) {
    tasks[id]?.cancel()
    tasks[id] = Task { [weak self] in
      let interval = max(0, fireAt.timeIntervalSinceNow)
      try? await Task.sleep(for: .seconds(interval))
      guard !Task.isCancelled, let self, !self.backgrounded else { return }
      self.deadlines[id] = nil
      self.onExpire?(id, .timeout)
    }
  }

  private func cancelTask(_ id: String) {
    tasks[id]?.cancel()
    tasks[id] = nil
  }
}
