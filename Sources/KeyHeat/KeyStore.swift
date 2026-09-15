import Foundation
import SQLite3

/// Persists press counts aggregated per (UTC hour bucket, key code).
/// Only counts are stored, never the order keys were typed in, so the
/// database cannot be used to reconstruct text.
final class KeyStore {
    typealias Buckets = [Int: [Int: Int]]   // hour bucket -> key code -> count

    let url: URL
    private var db: OpaquePointer?
    private let lock = NSLock()
    private var buckets: Buckets = [:]
    private var pending: Buckets = [:]
    private var generation = 0
    private let ioQueue = DispatchQueue(label: "KeyHeat.store.io", qos: .utility)
    private var flushTimer: DispatchSourceTimer?

    init(url: URL) {
        self.url = url
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        open()
        load()
        let timer = DispatchSource.makeTimerSource(queue: ioQueue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.flush() }
        timer.resume()
        flushTimer = timer
    }

    deinit {
        flushTimer?.cancel()
        sqlite3_close(db)
    }

    // MARK: Recording

    func record(code: Int, at date: Date = Date()) {
        let hour = Int((date.timeIntervalSince1970 / 3600).rounded(.down))
        lock.lock()
        buckets[hour, default: [:]][code, default: 0] += 1
        pending[hour, default: [:]][code, default: 0] += 1
        generation += 1
        lock.unlock()
    }

    /// Copy of all counts plus a generation number that changes on every write.
    func snapshot() -> (buckets: Buckets, generation: Int) {
        lock.lock(); defer { lock.unlock() }
        return (buckets, generation)
    }

    // MARK: Persistence

    private func open() {
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            NSLog("KeyHeat: could not open database at \(url.path)")
            db = nil
            return
        }
        exec("PRAGMA journal_mode=WAL;")
        exec("""
        CREATE TABLE IF NOT EXISTS presses (
            hour    INTEGER NOT NULL,
            keycode INTEGER NOT NULL,
            count   INTEGER NOT NULL,
            PRIMARY KEY (hour, keycode)
        ) WITHOUT ROWID;
        """)
    }

    private func exec(_ sql: String) {
        guard let db else { return }
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            NSLog("KeyHeat: sqlite error: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func load() {
        guard let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT hour, keycode, count FROM presses", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        var loaded: Buckets = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let h = Int(sqlite3_column_int64(stmt, 0))
            let k = Int(sqlite3_column_int64(stmt, 1))
            let c = Int(sqlite3_column_int64(stmt, 2))
            loaded[h, default: [:]][k] = c
        }
        lock.lock()
        buckets = loaded
        generation += 1
        lock.unlock()
    }

    /// Write pending increments. Runs on ioQueue.
    private func flush() {
        lock.lock()
        let batch = pending
        pending = [:]
        lock.unlock()
        guard !batch.isEmpty, let db else { return }

        var stmt: OpaquePointer?
        let sql = """
        INSERT INTO presses (hour, keycode, count) VALUES (?, ?, ?)
        ON CONFLICT(hour, keycode) DO UPDATE SET count = count + excluded.count
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        exec("BEGIN")
        for (hour, keys) in batch {
            for (code, n) in keys {
                sqlite3_reset(stmt)
                sqlite3_bind_int64(stmt, 1, Int64(hour))
                sqlite3_bind_int64(stmt, 2, Int64(code))
                sqlite3_bind_int64(stmt, 3, Int64(n))
                sqlite3_step(stmt)
            }
        }
        exec("COMMIT")
    }

    /// Blocks until everything recorded so far is on disk. Call before quitting.
    func flushSync() {
        ioQueue.sync { flush() }
    }

    /// Delete everything, in memory and on disk.
    func reset() {
        lock.lock()
        buckets = [:]
        pending = [:]
        generation += 1
        lock.unlock()
        ioQueue.sync { exec("DELETE FROM presses") }
    }
}
